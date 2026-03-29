"""
================================================================================
LAMBDA GET JOB: DYNAMODB RESULT RETRIEVER
================================================================================
OVERVIEW:
  This function serves as the 'Status Check' endpoint for the frontend. Since 
  Quantum tasks are asynchronous, this Lambda allows the client to poll for 
  results using a unique Job ID.

CORE LOGIC:
  1. STATE POLLING: Checks the 'status' field in DynamoDB.
     - RETURNS 202 (Accepted): If the job is still 'PENDING'.
     - RETURNS 200 (OK): If the job is 'COMPLETE', returning the full result.
     - RETURNS 404/500: For missing jobs or execution errors.
  2. DATA RECONSTRUCTION: Maps raw index arrays from the Quantum/Classical 
     solvers back into human-readable Analyst-Alert pairs with costs.
  3. SERIALIZATION: Handles AWS DynamoDB 'Decimal' types to ensure the JSON 
     payload is compatible with standard web browsers.

API GATEWAY INTEGRATION:
  - Method: GET
  - Path: /jobs/{job_id}
================================================================================
"""

import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])


def decimal_serializer(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


def lambda_handler(event, context):
    job_id = (
        event.get("pathParameters", {}) or {}
    ).get("job_id") or event.get("job_id")

    if not job_id:
        return {
            "statusCode": 400,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Missing job_id"}),
        }

    resp = table.get_item(Key={"job_id": job_id})
    item = resp.get("Item")

    if not item:
        return {
            "statusCode": 404,
            "headers": cors_headers(),
            "body": json.dumps({"error": f"Job {job_id} not found"}),
        }

    status = item.get("status", "UNKNOWN")

    if status == "PENDING":
        return {
            "statusCode": 202,
            "headers": cors_headers(),
            "body": json.dumps({
                "job_id": job_id,
                "status": "PENDING",
                "message": "Quantum job is still running. Please retry in a few seconds.",
            }),
        }

    if status == "COMPLETE":
        assignment_raw   = item.get("assignment", [])
        analysts         = item.get("analysts", [])
        alerts           = item.get("alerts", [])
        total_cost       = item.get("total_cost", "0")
        cost_matrix_raw  = json.loads(item.get("cost_matrix", "[]"))  # ADD THIS

        if assignment_raw and isinstance(assignment_raw[0], (int, float, Decimal)):
            assignment_indices = [int(a) for a in assignment_raw]
            pairs = [
                {
                    "analyst": analysts[i],
                    "alert":   alerts[assignment_indices[i]],
                    "cost":    cost_matrix_raw[i][assignment_indices[i]] if cost_matrix_raw else 0  # ADD cost
                }
                for i in range(len(analysts))
            ]
        else:
            pairs = assignment_raw

        return {
            "statusCode": 200,
            "headers": cors_headers(),
            "body": json.dumps({
                "job_id":     job_id,
                "status":     "COMPLETE",
                "method":     item.get("method", "QUANTUM"),
                "assignment": pairs,
                "total_cost": total_cost,
                "narrative":  item.get("narrative", ""),
            }, default=decimal_serializer),
        }

    # FAILED or unknown
    return {
        "statusCode": 500,
        "headers": cors_headers(),
        "body": json.dumps({
            "job_id": job_id,
            "status": status,
            "message": "Job ended in an unexpected state.",
        }),
    }


def cors_headers():
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
    }