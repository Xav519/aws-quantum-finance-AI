"""
==============================================================================
modules/lambda_get_job/src/handler.py
------------------------------------------------------------------------------
PURPOSE
  get-job Lambda: answers GET /jobs/{job_id} while a browser waits for a quantum job.

DETAILS
  Responses:
    202 -> job still PENDING (poll again)
    200 -> job COMPLETE (full result) or FAILED (error message in the body)
    400 -> job_id is not a valid UUID
    404 -> unknown job, or older than 7 days
==============================================================================
"""

import logging
import os
import uuid

import boto3

from qf_common import jobs
from qf_common.http import json_response

logger = logging.getLogger()
logger.setLevel(logging.INFO)

table = boto3.resource("dynamodb").Table(os.environ["DYNAMODB_TABLE"])


def _valid_job_id(value) -> bool:
    """True only for a canonical UUID v4 string (rejects anything else, e.g. 'quota#...')."""
    try:
        return str(uuid.UUID(str(value), version=4)) == value
    except ValueError:
        return False


def lambda_handler(event, context):
    """Entry point for GET /jobs/{job_id}: look up the job and return its public view."""
    job_id = (event.get("pathParameters") or {}).get("job_id")
    if not _valid_job_id(job_id):
        return json_response(400, {"error": "job_id must be a UUID"})

    item = table.get_item(Key={"job_id": job_id}).get("Item")
    if not item:
        return json_response(404, {"error": "Job not found (jobs expire after 7 days)"})

    view = jobs.result_view(item)
    return json_response(202 if item["status"] == jobs.PENDING else 200, view)
