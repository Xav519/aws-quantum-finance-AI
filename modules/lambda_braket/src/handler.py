"""
================================================================================
LAMBDA BRAKET: QAOA SUBMISSION + COMPLETION HANDLER
================================================================================
Two entry points, one function:

SUBMIT   (async invoke from the orchestrator: {"action": "submit", "job_id"})
  - Loads the PENDING job written by the orchestrator.
  - Builds the QAOA circuit (qaoa.py) and calls CreateQuantumTask with
    clientToken = job_id (retries cannot create duplicate tasks) and a
    `job_id` tag (the completion handler resolves the job from the task).

COMPLETE (EventBridge "Braket Task State Change", terminal states)
  - Reads the task's `job_id` tag; ignores tasks that are not ours.
  - Decodes the measured bitstrings and reports QAOA quality honestly:
    feasible-shot fraction, best sampled assignment, gap to the optimum.
  - Computes the exact optimum classically (N! <= 120) and returns THAT as
    the recommendation, with the QAOA metrics alongside it.

Every state transition is a conditional update on status = PENDING, so
duplicate events and Lambda retries are harmless.
================================================================================
"""

import json
import logging
import os

import boto3
from botocore.exceptions import ClientError

import qaoa
from qf_common import jobs
from qf_common.bedrock import generate_narrative
from qf_common.solver import combinations_count, solve_exact, solve_greedy

logger = logging.getLogger()
logger.setLevel(logging.INFO)

braket = boto3.client("braket")
s3 = boto3.client("s3")
table = boto3.resource("dynamodb").Table(os.environ["DYNAMODB_TABLE"])

DEVICE_ARN = os.environ["BRAKET_DEVICE_ARN"]
RESULTS_BUCKET = os.environ["RESULTS_BUCKET"]
PROJECT_TAG = os.environ["PROJECT_TAG"]
QAOA_LAYERS = int(os.environ.get("QAOA_LAYERS", qaoa.DEFAULT_LAYERS))
QAOA_SHOTS = int(os.environ.get("QAOA_SHOTS", "1000"))


# --------------------------------------------------------------------------- #
# State helpers
# --------------------------------------------------------------------------- #
def _update_if_pending(job_id: str, fields: dict) -> bool:
    names, values, sets = {"#status": "status"}, {":pending": jobs.PENDING}, []
    for i, (key, value) in enumerate(fields.items()):
        names[f"#f{i}"] = key
        values[f":v{i}"] = value
        sets.append(f"#f{i} = :v{i}")
    try:
        table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET " + ", ".join(sets),
            ConditionExpression="#status = :pending",
            ExpressionAttributeNames=names,
            ExpressionAttributeValues=jobs.to_dynamo(values),
        )
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            logger.info("job %s is no longer PENDING; skipping update", job_id)
            return False
        raise


def _fail(job_id: str, message: str) -> None:
    _update_if_pending(job_id, {"status": jobs.FAILED, "error": message})


# --------------------------------------------------------------------------- #
# Submit
# --------------------------------------------------------------------------- #
def _device_parameters(num_qubits: int) -> str:
    # Required for gate-model devices; this schema is specific to simulators.
    # QPUs need their own device-parameter schema (see README, roadmap).
    return json.dumps({
        "braketSchemaHeader": {
            "name": "braket.device_schema.simulators.gate_model_simulator_device_parameters",
            "version": "1",
        },
        "paradigmParameters": {
            "braketSchemaHeader": {"name": "braket.device_schema.gate_model_parameters", "version": "1"},
            "qubitCount": num_qubits,
            "disableQubitRewiring": False,
        },
    })


def handle_submit(event: dict) -> dict:
    job_id = event["job_id"]
    item = table.get_item(Key={"job_id": job_id}).get("Item")
    if not item:
        logger.error("submit: job %s not found", job_id)
        return {"job_id": job_id, "status": "NOT_FOUND"}
    if item.get("status") != jobs.PENDING or item.get("braket_task_arn"):
        logger.info("submit: job %s already submitted or finished", job_id)
        return {"job_id": job_id, "status": item.get("status")}

    cost_matrix = json.loads(item["cost_matrix"])
    num_qubits = len(cost_matrix) ** 2

    try:
        circuit = qaoa.build_qaoa_circuit(cost_matrix, p=QAOA_LAYERS)
        response = braket.create_quantum_task(
            clientToken=job_id,
            action=json.dumps(circuit, separators=(",", ":")),
            deviceArn=DEVICE_ARN,
            deviceParameters=_device_parameters(num_qubits),
            outputS3Bucket=RESULTS_BUCKET,
            outputS3KeyPrefix=f"braket-results/{job_id}",
            shots=QAOA_SHOTS,
            tags={"job_id": job_id, "project": PROJECT_TAG},
        )
    except Exception:
        logger.exception("submit: CreateQuantumTask failed for job %s", job_id)
        _fail(job_id, "The quantum task could not be submitted to Amazon Braket.")
        raise  # surfaces in the Errors metric / alarm; the retry sees FAILED and exits

    task_arn = response["quantumTaskArn"]
    _update_if_pending(job_id, {
        "braket_task_arn": task_arn,
        "qaoa_layers": QAOA_LAYERS,
        "shots": QAOA_SHOTS,
        "gate_count": len(circuit["instructions"]),
        "submitted_at": jobs.now_iso(),
    })
    logger.info("submit: job %s -> %s (%d gates)", job_id, task_arn, len(circuit["instructions"]))
    return {"job_id": job_id, "status": jobs.PENDING, "braket_task_arn": task_arn}


# --------------------------------------------------------------------------- #
# Complete
# --------------------------------------------------------------------------- #
def _load_counts(task: dict):
    key = f"{task['outputS3Directory']}/results.json"
    obj = s3.get_object(Bucket=task["outputS3Bucket"], Key=key)
    return qaoa.counts_from_result(json.loads(obj["Body"].read()))


def build_prompt(pairs, n, total_cost, greedy_cost, metrics) -> str:
    if metrics["qaoa_cost"] is None:
        qaoa_line = "None of the sampled bitstrings encoded a valid assignment."
    elif metrics["qaoa_found_optimum"]:
        qaoa_line = f"The best valid sample matched the proven optimum (${metrics['qaoa_cost']:,.0f})."
    else:
        qaoa_line = (
            f"The best valid sample cost ${metrics['qaoa_cost']:,.0f}, "
            f"{metrics['qaoa_gap_pct']}% above the proven optimum."
        )
    return f"""<data>
Problem: assign {n} security analysts to {n} simultaneous cyber threats, one each, minimising total breach impact cost.
Quantum step: a {n * n}-qubit QAOA circuit was run on the Amazon Braket SV1 simulator and measured {metrics['shots']:,} times. {metrics['feasible_fraction']:.1%} of measurements were valid assignments and {metrics['optimal_fraction']:.1%} were the optimal one. {qaoa_line}
Verification: all {combinations_count(n):,} possible assignments were also checked classically; the recommendation below is that proven optimum.
Recommended assignment: {json.dumps(pairs)}
Optimal total breach impact cost: ${total_cost:,.0f}
Greedy baseline (each analyst in turn takes their cheapest open threat): ${greedy_cost:,.0f}
</data>

Write exactly 3 sentences for the board: (1) the recommended assignment's total exposure and its saving versus the greedy baseline, (2) how the quantum circuit performed and that the result was verified classically, (3) why running this pipeline on a simulator today is useful preparation for larger optimisation problems, without claiming any quantum advantage. Format dollar amounts with commas."""


def fallback_narrative(n, total_cost, greedy_cost, metrics) -> str:
    if metrics["qaoa_cost"] is None:
        qaoa_text = "none of its samples encoded a valid assignment"
    elif metrics["qaoa_found_optimum"]:
        qaoa_text = "its best valid sample matched the optimum"
    else:
        qaoa_text = f"its best valid sample was {metrics['qaoa_gap_pct']}% above the optimum"
    return (
        f"The recommended assignment of {n} analysts to {n} threats minimises total breach impact at "
        f"${total_cost:,.0f}, versus ${greedy_cost:,.0f} for a greedy assignment. A {n * n}-qubit QAOA "
        f"circuit on Amazon Braket SV1 produced {metrics['feasible_fraction']:.1%} valid samples and "
        f"{qaoa_text}; all {combinations_count(n):,} assignments were then checked classically to confirm "
        f"the optimum. The same pipeline can target larger problems and real quantum hardware as both mature."
    )


def handle_complete(event: dict) -> dict:
    detail = event.get("detail", {})
    task_arn = detail.get("quantumTaskArn", "")
    task = braket.get_quantum_task(quantumTaskArn=task_arn)
    tags = task.get("tags") or {}
    job_id = tags.get("job_id")
    if not job_id or tags.get("project") != PROJECT_TAG:
        logger.info("complete: task %s does not belong to this project; ignoring", task_arn)
        return {"status": "IGNORED"}

    item = table.get_item(Key={"job_id": job_id}).get("Item")
    if not item or item.get("status") != jobs.PENDING:
        logger.info("complete: job %s missing or already finalised", job_id)
        return {"job_id": job_id, "status": "IGNORED"}

    task_status = task.get("status", detail.get("status"))
    if task_status != "COMPLETED":
        logger.warning("complete: task %s ended %s: %s", task_arn, task_status, task.get("failureReason"))
        _fail(job_id, f"The quantum task ended with status {task_status}.")
        return {"job_id": job_id, "status": jobs.FAILED}

    try:
        analysts, alerts = item["analysts"], item["alerts"]
        cost_matrix = json.loads(item["cost_matrix"])
        n = len(analysts)

        metrics = qaoa.analyse_counts(_load_counts(task), cost_matrix)
        assignment, total_cost = solve_exact(cost_matrix)
        _, greedy_cost = solve_greedy(cost_matrix)
        pairs = [
            {"analyst": analysts[i], "alert": alerts[j], "cost": cost_matrix[i][j]}
            for i, j in enumerate(assignment)
        ]
        metrics["layers"] = int(item.get("qaoa_layers", QAOA_LAYERS))
        metrics["qubits"] = n * n

        narrative, narrative_source = generate_narrative(
            build_prompt(pairs, n, total_cost, greedy_cost, metrics),
            fallback_narrative(n, total_cost, greedy_cost, metrics),
        )

        _update_if_pending(job_id, {
            "status": jobs.COMPLETE,
            "assignment": assignment,
            "total_cost": total_cost,
            "greedy_cost": greedy_cost,
            "savings": greedy_cost - total_cost,
            "combinations_evaluated": combinations_count(n),
            "qaoa": metrics,
            "narrative": narrative,
            "narrative_source": narrative_source,
            "completed_at": jobs.now_iso(),
        })
    except Exception:
        logger.exception("complete: post-processing failed for job %s", job_id)
        _fail(job_id, "The quantum result could not be processed.")
        raise

    logger.info("complete: job %s feasible=%.3f gap=%s", job_id,
                metrics["feasible_fraction"], metrics["qaoa_gap_pct"])
    return {"job_id": job_id, "status": jobs.COMPLETE}


def lambda_handler(event, context):
    if event.get("source") == "aws.braket":
        return handle_complete(event)
    if event.get("action") == "submit":
        return handle_submit(event)
    raise ValueError("Unrecognised event")
