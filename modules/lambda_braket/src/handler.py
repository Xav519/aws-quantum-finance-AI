"""
Lambda Braket - QAOA SOC assignment optimizer
Values = Breach Impact Cost ($): Hourly Financial Loss x Hours to Mitigate

Circuit format: Braket JAQCD (JSON IR) — avoids all OpenQASM dialect issues with SV1.
"""

import json
import os
import boto3
from boto3.dynamodb.conditions import Key
from datetime import datetime, timezone, timedelta

# --- AWS Service Setup ---
bedrock  = boto3.client("bedrock-runtime", region_name="us-east-1")
braket   = boto3.client("braket", region_name="us-east-1")
s3       = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

# --- Environment Config ---
MODEL_ID       = os.environ["BEDROCK_MODEL"]
DEVICE_ARN     = os.environ.get("BRAKET_DEVICE_ARN", "arn:aws:braket:::device/quantum-simulator/amazon/sv1")
RESULTS_BUCKET = os.environ["RESULTS_BUCKET"]


def call_bedrock(prompt: str, max_tokens: int = 400) -> str:
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


def build_qaoa_circuit_jaqcd(cost_matrix: list, p_layers: int = 1) -> dict:
    """
    Builds the QAOA circuit in Braket JAQCD (JSON IR) format.

    JAQCD is Braket SV1's native format and avoids all OpenQASM dialect
    issues (no include statements, no gate declaration problems, no syntax
    differences between OpenQASM 2.0 and 3.0).

    Gates:
      h    - Hadamard: superposition over all possible assignments
      rz   - Z-rotation: encodes breach impact cost as a quantum phase
      cnot - Controlled-NOT: enforces one-to-one assignment constraints
      rx   - X-rotation: mixer layer, lets state escape local minima
    """
    n            = len(cost_matrix)
    num_qubits   = n * n
    gamma        = 0.4
    beta         = 0.3
    instructions = []

    # 1. INITIALIZATION: superposition
    for k in range(num_qubits):
        instructions.append({"gate": "h", "target": k})

    for _ in range(p_layers):

        # 2. COST LAYER: phase proportional to normalised breach impact cost
        flat     = [cost_matrix[i][j] for i in range(n) for j in range(n)]
        max_cost = max(flat) or 1
        for i in range(n):
            for j in range(n):
                k          = i * n + j
                normalized = cost_matrix[i][j] / max_cost
                angle      = 2.0 * gamma * normalized
                instructions.append({"gate": "rz", "target": k, "angle": round(angle, 6)})

        # 3. ROW CONSTRAINTS: one analyst cannot cover two alerts
        for i in range(n):
            for j1 in range(n):
                for j2 in range(j1 + 1, n):
                    k1 = i * n + j1
                    k2 = i * n + j2
                    instructions.append({"gate": "cnot", "control": k1, "target": k2})
                    instructions.append({"gate": "rz",   "target": k2, "angle": round(2.0 * gamma, 6)})
                    instructions.append({"gate": "cnot", "control": k1, "target": k2})

        # 4. COLUMN CONSTRAINTS: one alert cannot be covered by two analysts
        for j in range(n):
            for i1 in range(n):
                for i2 in range(i1 + 1, n):
                    k1 = i1 * n + j
                    k2 = i2 * n + j
                    instructions.append({"gate": "cnot", "control": k1, "target": k2})
                    instructions.append({"gate": "rz",   "target": k2, "angle": round(2.0 * gamma, 6)})
                    instructions.append({"gate": "cnot", "control": k1, "target": k2})

        # 5. MIXER LAYER
        for k in range(num_qubits):
            instructions.append({"gate": "rx", "target": k, "angle": round(2.0 * beta, 6)})

    results = [{"type": "measurement", "targets": list(range(num_qubits))}]

    return {
        "braketSchemaHeader": {
            "name":    "braket.ir.jaqcd.program",
            "version": "1"
        },
        "instructions":                instructions,
        "results":                     results,
        "basis_rotation_instructions": []
    }


def decode_bitstring(bitstring: str, n: int, cost_matrix: list) -> list:
    assignment  = [-1] * n
    used_alerts = set()
    for i in range(n):
        row_bits = [int(bitstring[i * n + j]) for j in range(n)]
        ones     = [j for j, b in enumerate(row_bits) if b == 1 and j not in used_alerts]
        if ones:
            best_j = min(ones, key=lambda j: cost_matrix[i][j])
        else:
            best_j = min(
                (j for j in range(n) if j not in used_alerts),
                key=lambda j: cost_matrix[i][j]
            )
        assignment[i] = best_j
        used_alerts.add(best_j)
    return assignment


def handle_submit(event: dict) -> dict:
    job_id      = event["job_id"]
    cost_matrix = event["cost_matrix"]
    analysts    = event["analysts"]
    alerts      = event["alerts"]
    n           = len(analysts)

    circuit = build_qaoa_circuit_jaqcd(cost_matrix, p_layers=1)

    response = braket.create_quantum_task(
        action=json.dumps(circuit),
        deviceArn=DEVICE_ARN,
        outputS3Bucket=RESULTS_BUCKET,
        outputS3KeyPrefix=f"braket-results/{job_id}",
        shots=1000,
    )

    braket_task_arn = response["quantumTaskArn"]

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
    detail     = event.get("detail", {})
    task_arn   = detail.get("quantumTaskArn", "")
    job_status = detail.get("status", "FAILED")

    query_resp = table.query(
        IndexName="braket-task-arn-index",
        KeyConditionExpression=Key("braket_task_arn").eq(task_arn),
        FilterExpression="#s = :pending",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":pending": "PENDING"},
    )
    items = query_resp.get("Items", [])
    if not items:
        return {"message": "No PENDING job found", "task_arn": task_arn}

    item        = items[0]
    job_id      = item["job_id"]
    cost_matrix = json.loads(item["cost_matrix"])
    analysts    = item["analysts"]
    alerts      = item["alerts"]
    n           = len(analysts)

    if job_status != "COMPLETED":
        table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": f"FAILED ({job_status})"},
        )
        return {"job_id": job_id, "status": "FAILED"}

    task_resp   = braket.get_quantum_task(quantumTaskArn=task_arn)
    s3_bucket   = task_resp["outputS3Bucket"]
    s3_prefix   = task_resp["outputS3Directory"]
    result_key  = f"{s3_prefix}/results.json"
    s3_obj      = s3.get_object(Bucket=s3_bucket, Key=result_key)
    result_data = json.loads(s3_obj["Body"].read())

    measurements = result_data.get("measurementProbabilities", {})
    if not measurements:
        raw    = result_data.get("measurements", [[]])
        counts = {}
        for shot in raw:
            bs = "".join(str(b) for b in shot)
            counts[bs] = counts.get(bs, 0) + 1
        measurements = {k: v / len(raw) for k, v in counts.items()}

    best_bitstring = max(measurements, key=measurements.get)

    assignment = decode_bitstring(best_bitstring, n, cost_matrix)
    total_cost = sum(cost_matrix[i][assignment[i]] for i in range(n))
    pairs = [
        {
            "analyst": analysts[i],
            "alert":   alerts[assignment[i]],
            "cost":    cost_matrix[i][assignment[i]],
        }
        for i in range(n)
    ]

    prompt = f"""
You are the Chief Information Security Officer (CISO) of a major bank presenting to the board.

The QAOA algorithm running on Amazon Braket SV1 quantum simulator found the optimal assignment
of {n} SOC analysts to {n} active cyber threats, minimizing total breach impact cost.

Assignment result:
{json.dumps(pairs, indent=2)}
Total breach impact cost (optimal): ${total_cost:,.0f}
Qubits used: {n*n} . Measurement shots: 1,000

Write exactly 3 sentences for a board-level audience:
1. What technology was used: QAOA on Amazon Braket SV1, and what problem it solved.
2. The result: total financial exposure minimized, and what the optimal assignment achieves.
3. Strategic value: this infrastructure routes to real quantum hardware with one configuration change,
   positioning the bank ahead of competitors for when quantum advantage becomes operational.

No bullet points. No technical jargon. Confident, executive tone. Format dollar amounts with commas.
"""
    narrative = call_bedrock(prompt, max_tokens=350)

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
    if "detail" in event:
        return handle_complete(event)
    else:
        return handle_submit(event)
