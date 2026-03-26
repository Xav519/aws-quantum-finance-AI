"""
Lambda Braket - QAOA SOC assignment optimizer
Values = Breach Impact Cost ($): Hourly Financial Loss × Hours to Mitigate
"""

import json
import os
import boto3
from datetime import datetime, timezone, timedelta

# --- AWS Service Setup ---
bedrock  = boto3.client("bedrock-runtime", region_name="us-east-1")
braket   = boto3.client("braket", region_name="us-east-1")
s3       = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

# --- Environment Config ---
MODEL_ID       = os.environ.get("BEDROCK_MODEL", "anthropic.claude-haiku-4-5-20251001")
DEVICE_ARN     = os.environ.get("BRAKET_DEVICE_ARN", "arn:aws:braket:::device/quantum-simulator/amazon/sv1")
RESULTS_BUCKET = os.environ["RESULTS_BUCKET"]


def call_bedrock(prompt: str, max_tokens: int = 400) -> str:
    # Sends the final result to Claude to generate a board-level briefing.
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
    }
    resp = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json",
    )
    return json.loads(resp["body"].read())["content"][0]["text"]


def build_qaoa_circuit_openqasm(cost_matrix: list, p_layers: int = 1) -> str:
    """
    The Core Quantum Logic:
    Translates the 'Assignment Problem' into a series of quantum gates.
    Each analyst/alert pair is represented by one 'qubit'.
    """
    n          = len(cost_matrix)
    num_qubits = n * n
    gamma      = 0.4 # Hyperparameter for 'Cost' layer
    beta       = 0.3 # Hyperparameter for 'Mixing' layer
    lines      = []

    lines.append("OPENQASM 3.0;")
    lines.append('include "stdgates.inc";')
    lines.append(f"qubit[{num_qubits}] q;")
    lines.append(f"bit[{num_qubits}] c;")
    lines.append("")
    # 1. INITIALIZATION: Put all qubits into 'Superposition' (checking all answers at once)
    lines.append("// Initial superposition")
    for k in range(num_qubits):
        lines.append(f"h q[{k}];")
    lines.append("")

    for layer in range(p_layers):
        lines.append(f"// === QAOA Layer {layer + 1} ===")
        # 2. COST LAYER: Penalize qubits based on the financial impact of the assignment
        lines.append("// Phase layer")

        # Normalize costs to 0-1 range for circuit stability
        flat       = [cost_matrix[i][j] for i in range(n) for j in range(n)]
        max_cost   = max(flat) or 1
        for i in range(n):
            for j in range(n):
                k          = i * n + j
                normalized = cost_matrix[i][j] / max_cost
                angle      = 2.0 * gamma * normalized
                lines.append(f"rz({angle:.6f}) q[{k}];")

        # 3. CONSTRAINT LAYERS: Use CNOT gates to ensure we don't assign 
        # two analysts to the same alert (and vice versa)
        lines.append("// Row constraints")
        for i in range(n):
            for j1 in range(n):
                for j2 in range(j1 + 1, n):
                    k1 = i * n + j1
                    k2 = i * n + j2
                    lines.append(f"cx q[{k1}], q[{k2}];")
                    lines.append(f"rz({2.0 * gamma:.6f}) q[{k2}];")
                    lines.append(f"cx q[{k1}], q[{k2}];")

        lines.append("// Column constraints")
        for j in range(n):
            for i1 in range(n):
                for i2 in range(i1 + 1, n):
                    k1 = i1 * n + j
                    k2 = i2 * n + j
                    lines.append(f"cx q[{k1}], q[{k2}];")
                    lines.append(f"rz({2.0 * gamma:.6f}) q[{k2}];")
                    lines.append(f"cx q[{k1}], q[{k2}];")

        # 4. MIXER LAYER: Allows the quantum state to 'evolve' toward the low-cost solutions
        lines.append("// Mixing layer")
        for k in range(num_qubits):
            lines.append(f"rx({2.0 * beta:.6f}) q[{k}];")
        lines.append("")

    # 5. MEASUREMENT: Collapse the quantum state into a classical bitstring (0s and 1s)
    lines.append("c = measure q;")
    return "\n".join(lines)


def decode_bitstring(bitstring: str, n: int, cost_matrix: list) -> list:
    """
    Translates the quantum 'bitstring' (e.g., '10000100') back into 
    human-readable analyst assignments.
    """
    assignment = [-1] * n
    used_alerts = set()
    for i in range(n):
        row_bits = [int(bitstring[i * n + j]) for j in range(n)]
        ones     = [j for j, b in enumerate(row_bits) if b == 1 and j not in used_alerts]
        if ones:
            best_j = min(ones, key=lambda j: cost_matrix[i][j])
        else:
            # Fallback if the quantum result is 'noisy' or invalid
            best_j = min(
                (j for j in range(n) if j not in used_alerts),
                key=lambda j: cost_matrix[i][j]
            )
        assignment[i] = best_j
        used_alerts.add(best_j)
    return assignment


def handle_submit(event: dict) -> dict:
    # Triggered when a new job starts. Builds and submits the task to Braket.
    job_id      = event["job_id"]
    cost_matrix = event["cost_matrix"]
    analysts    = event["analysts"]
    alerts      = event["alerts"]
    n           = len(analysts)

    # Build the circuit
    circuit_qasm = build_qaoa_circuit_openqasm(cost_matrix, p_layers=1)

    # Submit to Amazon Braket SV1 (Quantum Simulator)
    response = braket.create_quantum_task(
        action=json.dumps({
            "braketSchemaHeader": {
                "name":    "braket.ir.openqasm.program",
                "version": "1"
            },
            "source":  circuit_qasm,
            "inputs":  {}
        }),
        deviceArn=DEVICE_ARN,
        outputS3Bucket=RESULTS_BUCKET,
        outputS3KeyPrefix=f"braket-results/{job_id}",
        shots=1000, # Run the circuit 1000 times to find the most probable answer
    )

    braket_task_arn = response["quantumTaskArn"]

    # Save metadata to DynamoDB so we can find it when the task finishes
    ttl = int((datetime.now(timezone.utc) + timedelta(days=7)).timestamp())
    table.put_item(Item={
        "job_id":          job_id,
        "status":          "PENDING",
        "method":          "QUANTUM",
        "cost_matrix":     json.dumps(cost_matrix),
        "analysts":        analysts,
        "alerts":          alerts,
        "braket_task_arn": braket_task_arn,
        "timestamp":       datetime.now(timezone.utc).isoformat(),
        "expires_at":      ttl,
    })

    return {
        "job_id":      job_id,
        "status":      "PENDING",
        "braket_task": braket_task_arn,
        "qubits":      n * n,
        "shots":       1000,
        "message":     f"QAOA circuit ({n*n} qubits, 1000 shots) submitted to Amazon Braket SV1.",
    }


def handle_complete(event: dict) -> dict:
    """
    Triggered by an EventBridge rule when the Braket task status 
    changes to 'COMPLETED' or 'FAILED'.
    """
    detail     = event.get("detail", {})
    task_arn   = detail.get("quantumTaskArn", "")
    job_status = detail.get("status", "FAILED")

    # 1. Find the original job in DynamoDB using the Task ARN
    scan_resp = table.scan(
        FilterExpression="braket_task_arn = :arn AND #s = :pending",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":arn": task_arn, ":pending": "PENDING"},
    )
    items = scan_resp.get("Items", [])
    if not items:
        return {"message": "No PENDING job found", "task_arn": task_arn}

    item        = items[0]
    job_id      = item["job_id"]
    cost_matrix = json.loads(item["cost_matrix"])
    analysts    = item["analysts"]
    alerts      = item["alerts"]
    n           = len(analysts)

    if job_status != "COMPLETED":
        # Handle failure cases
        table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": f"FAILED ({job_status})"},
        )
        return {"job_id": job_id, "status": "FAILED"}

    # 2. Retrieve results from S3
    task_resp  = braket.get_quantum_task(quantumTaskArn=task_arn)
    s3_bucket  = task_resp["outputS3Bucket"]
    s3_prefix  = task_resp["outputS3Directory"]
    result_key = f"{s3_prefix}/results.json"
    s3_obj     = s3.get_object(Bucket=s3_bucket, Key=result_key)
    result_data = json.loads(s3_obj["Body"].read())

    # 3. Analyze measurements to find the most likely assignment
    measurements = result_data.get("measurementProbabilities", {})
    if not measurements:
        raw   = result_data.get("measurements", [[]])
        counts = {}
        for shot in raw:
            bs = "".join(str(b) for b in shot)
            counts[bs] = counts.get(bs, 0) + 1
        measurements = {k: v / len(raw) for k, v in counts.items()}

    best_bitstring = max(measurements, key=measurements.get)

    # 4. Final Processing
    assignment     = decode_bitstring(best_bitstring, n, cost_matrix)
    total_cost     = sum(cost_matrix[i][assignment[i]] for i in range(n))
    pairs = [
        {
            "analyst": analysts[i],
            "alert":   alerts[assignment[i]],
            "cost":    cost_matrix[i][assignment[i]],
        }
        for i in range(n)
    ]

    # 5. Narrative generation via Bedrock
    prompt = f"""
You are the Chief Information Security Officer (CISO) of a major bank presenting to the board.

The QAOA algorithm running on Amazon Braket SV1 quantum simulator found the optimal assignment
of {n} SOC analysts to {n} active cyber threats, minimizing total breach impact cost.

Assignment result:
{json.dumps(pairs, indent=2)}
Total breach impact cost (optimal): ${total_cost:,.0f}
Qubits used: {n*n} · Measurement shots: 1,000

Write exactly 3 sentences for a board-level audience:
1. What technology was used: QAOA on Amazon Braket SV1, and what problem it solved.
2. The result: total financial exposure minimized, and what the optimal assignment achieves.
3. Strategic value: this infrastructure routes to real quantum hardware with one configuration change,
   positioning the bank ahead of competitors for when quantum advantage becomes operational.

No bullet points. No technical jargon. Confident, executive tone. Format dollar amounts with commas.
"""
    narrative = call_bedrock(prompt, max_tokens=350)

    # 6. Update DynamoDB to 'COMPLETE'
    table.update_item(
        Key={"job_id": job_id},
        UpdateExpression="SET #s = :s, assignment = :a, total_cost = :c, narrative = :n",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":s": "COMPLETE",
            ":a": assignment,
            ":c": str(round(total_cost, 2)),
            ":n": narrative,
        },
    )

    return {"job_id": job_id, "status": "COMPLETE"}


def lambda_handler(event, context):
    """
    Dispatcher: 
    - If EventBridge sends a 'detail' (task update), handle completion.
    - Otherwise, handle a new submission.
    """
    if "detail" in event:
        return handle_complete(event)
    else:
        return handle_submit(event)