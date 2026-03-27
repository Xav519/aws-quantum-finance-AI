
"""
Lambda Orchestrator
  - N <= 4 → Classical brute-force
  - N >= 5 → Quantum QAOA on Braket SV1
  - Values represent Breach Impact Cost ($): Hourly Loss × Hours to Mitigate
"""

import json
import os
import uuid
import boto3

# --- AWS Service Initialization ---
lambda_client = boto3.client("lambda")
dynamodb      = boto3.resource("dynamodb")
# Accesses a DynamoDB table defined in my Lambda environment variables
table         = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

# --- Configuration Settings ---
# These variables tell the code which other Lambda functions to call
LAMBDA_CLASSICAL    = os.environ["LAMBDA_CLASSICAL"]
LAMBDA_BRAKET       = os.environ["LAMBDA_BRAKET"]
# Default threshold: if N > 4, it switches to Quantum mode
CLASSICAL_THRESHOLD = int(os.environ.get("CLASSICAL_THRESHOLD", "4"))


def lambda_handler(event, context):
    """
    Main entry point: Receives analysts/alerts data and routes it
    to the appropriate solver.
    """
    # 1. Parse the incoming JSON data
    body = event.get("body", "{}")
    if isinstance(body, str):
        try:
            body = json.loads(body)
        except json.JSONDecodeError:
            return api_response(400, {"error": "Invalid JSON body"})

    # 2. Extract input data (Analysts, Alerts, and the Cost Matrix)
    analysts    = body.get("analysts")
    alerts      = body.get("alerts")
    cost_matrix = body.get("cost_matrix")

    # 3. Validation: Ensure all necessary data is present
    if not analysts or not alerts or not cost_matrix:
        return api_response(400, {
            "error": "Missing required fields: analysts, alerts, cost_matrix"
        })

    n = len(analysts)

    # 4. Dimension Check: Ensure the lists are the same size
    if n != len(alerts) or n != len(cost_matrix):
        return api_response(400, {
            "error": "analysts, alerts, and cost_matrix dimensions must all match"
        })

    # 5. Boundary Check: This specific logic only handles small scale (2 to 6)
    if n < 2 or n > 6:
        return api_response(400, {
            "error": "Problem size must be between 2 and 6"
        })

    # 6. Generate a unique ID for this specific calculation job
    job_id  = str(uuid.uuid4())
    payload = {
        "job_id":      job_id,
        "analysts":    analysts,
        "alerts":      alerts,
        "cost_matrix": cost_matrix,
    }

    # 7. ROUTING LOGIC: Small problem? Use Classical. Large problem? Use Quantum.
    if n <= CLASSICAL_THRESHOLD:
        # --- CLASSICAL ROUTE ---
        # Calls a standard Lambda function and waits for the immediate result
        resp   = lambda_client.invoke(
            FunctionName=LAMBDA_CLASSICAL,
            InvocationType="RequestResponse",
            Payload=json.dumps(payload),
        )
        result = json.loads(resp["Payload"].read())

        if "errorMessage" in result:
            return api_response(500, {"error": result["errorMessage"]})

        return api_response(200, result)

    else:
        # --- QUANTUM ROUTE ---
        # Calls the Braket (Quantum) Lambda function
        # Note: This usually returns a 'PENDING' status because Quantum jobs take longer
        braket_resp   = lambda_client.invoke(
            FunctionName=LAMBDA_BRAKET,
            InvocationType="Event",          # fire-and-forget
            Payload=json.dumps(payload),
        )
        submit_result = json.loads(braket_resp["Payload"].read())

        if "errorMessage" in submit_result:
            return api_response(500, {"error": submit_result["errorMessage"]})

        # Return 202 Accepted (Processing)
        return api_response(202, {
            "job_id":   job_id,
            "status":   "PENDING",
            "method":   "QUANTUM",
            "qubits":   submit_result.get("qubits", n * n),
            "shots":    submit_result.get("shots", 1000),
            "message":  (
                f"N={n} exceeds classical threshold ({CLASSICAL_THRESHOLD}). "
                f"QAOA circuit ({n*n} qubits, 1000 shots) submitted to Amazon Braket SV1."
            ),
        })


def api_response(status_code: int, body: dict) -> dict:
    """
    Helper function to format the output for AWS API Gateway.
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type":                "application/json",
            "Access-Control-Allow-Origin": "*", # CORS enabled
        },
        "body": json.dumps(body),
    }