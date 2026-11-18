"""
================================================================================
LAMBDA ORCHESTRATOR: HYBRID QUANTUM-CLASSICAL ROUTER  (POST /optimize)
================================================================================
1. Validates the request (validation.py).
2. Routes by problem size N:
   - N <= CLASSICAL_THRESHOLD -> classical Lambda, synchronous, 200 + result.
   - N >  CLASSICAL_THRESHOLD -> quantum path, asynchronous, 202 + job_id:
       a. enforces a daily quantum-job quota (cost guard for a public API),
       b. writes the PENDING job record FIRST, so GET /jobs/{id} can never 404
          for an accepted job, even if a later step fails,
       c. invokes the Braket Lambda asynchronously (InvocationType=Event).
================================================================================
"""

import base64
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

from qf_common import jobs
from qf_common.http import json_response
from validation import ValidationError, validate_request

logger = logging.getLogger()
logger.setLevel(logging.INFO)

lambda_client = boto3.client("lambda")
table = boto3.resource("dynamodb").Table(os.environ["DYNAMODB_TABLE"])

LAMBDA_CLASSICAL = os.environ["LAMBDA_CLASSICAL"]
LAMBDA_BRAKET = os.environ["LAMBDA_BRAKET"]
CLASSICAL_THRESHOLD = int(os.environ.get("CLASSICAL_THRESHOLD", "4"))
MAX_QUANTUM_JOBS_PER_DAY = int(os.environ.get("MAX_QUANTUM_JOBS_PER_DAY", "50"))
QAOA_SHOTS = int(os.environ.get("QAOA_SHOTS", "1000"))
MAX_BODY_BYTES = 16 * 1024


def _parse_body(event: dict) -> dict:
    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode("utf-8")
    if len(raw) > MAX_BODY_BYTES:
        raise ValidationError("request body too large")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValidationError("request body is not valid JSON") from exc


def _reserve_quantum_quota() -> bool:
    """Atomically increment today's quantum-job counter. False if exhausted."""
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        table.update_item(
            Key={"job_id": f"quota#{day}"},
            UpdateExpression="ADD submitted :one SET expires_at = :ttl",
            ConditionExpression="attribute_not_exists(submitted) OR submitted < :max",
            ExpressionAttributeValues={
                ":one": 1,
                ":max": MAX_QUANTUM_JOBS_PER_DAY,
                ":ttl": jobs.ttl_epoch(2),
            },
        )
        return True
    except ClientError as exc:
        if exc.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return False
        raise


def _run_classical(payload: dict) -> dict:
    resp = lambda_client.invoke(
        FunctionName=LAMBDA_CLASSICAL,
        InvocationType="RequestResponse",
        Payload=json.dumps(payload),
    )
    result = json.loads(resp["Payload"].read())
    if resp.get("FunctionError"):
        logger.error("Classical solver failed: %s", result)
        return json_response(502, {"error": "The classical solver failed. Please retry."})
    return json_response(200, result)


def _run_quantum(payload: dict) -> dict:
    if not _reserve_quantum_quota():
        return json_response(429, {
            "error": "Daily quantum job limit reached for this demo. Please try again tomorrow, "
                     "or use N <= 4 for the instant classical solver."
        })

    n = len(payload["analysts"])
    job_id = payload["job_id"]
    table.put_item(
        Item={
            "job_id": job_id,
            "status": jobs.PENDING,
            "method": "QUANTUM",
            "analysts": payload["analysts"],
            "alerts": payload["alerts"],
            "cost_matrix": json.dumps(payload["cost_matrix"]),
            "created_at": jobs.now_iso(),
            "expires_at": jobs.ttl_epoch(),
        },
        ConditionExpression="attribute_not_exists(job_id)",
    )

    try:
        lambda_client.invoke(
            FunctionName=LAMBDA_BRAKET,
            InvocationType="Event",  # fire-and-forget: no response payload
            Payload=json.dumps({"action": "submit", "job_id": job_id}),
        )
    except ClientError:
        logger.exception("Failed to dispatch quantum job %s", job_id)
        table.update_item(
            Key={"job_id": job_id},
            UpdateExpression="SET #s = :failed, #e = :err",
            ExpressionAttributeNames={"#s": "status", "#e": "error"},
            ExpressionAttributeValues={":failed": jobs.FAILED, ":err": "Could not dispatch the quantum job."},
        )
        return json_response(502, {"error": "Could not dispatch the quantum job. Please retry."})

    return json_response(202, {
        "job_id": job_id,
        "status": jobs.PENDING,
        "method": "QUANTUM",
        "qubits": n * n,
        "shots": QAOA_SHOTS,
        "message": f"QAOA circuit ({n * n} qubits, {QAOA_SHOTS:,} shots) queued for Amazon Braket SV1.",
    })


def lambda_handler(event, context):
    try:
        analysts, alerts, cost_matrix = validate_request(_parse_body(event))
    except ValidationError as exc:
        return json_response(400, {"error": str(exc)})

    payload = {
        "job_id": str(uuid.uuid4()),
        "analysts": analysts,
        "alerts": alerts,
        "cost_matrix": cost_matrix,
    }
    n = len(analysts)
    logger.info("job %s: N=%d route=%s", payload["job_id"], n,
                "classical" if n <= CLASSICAL_THRESHOLD else "quantum")

    if n <= CLASSICAL_THRESHOLD:
        return _run_classical(payload)
    return _run_quantum(payload)
