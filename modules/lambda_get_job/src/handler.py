"""
================================================================================
LAMBDA GET JOB: JOB STATUS / RESULT  (GET /jobs/{job_id})
================================================================================
  200  COMPLETE or FAILED job (the request succeeded; the job status is in the body)
  202  PENDING job (poll again)
  400  job_id is not a UUID
  404  unknown or expired job
================================================================================
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
    try:
        return str(uuid.UUID(str(value), version=4)) == value
    except ValueError:
        return False


def lambda_handler(event, context):
    job_id = (event.get("pathParameters") or {}).get("job_id")
    if not _valid_job_id(job_id):
        return json_response(400, {"error": "job_id must be a UUID"})

    item = table.get_item(Key={"job_id": job_id}).get("Item")
    if not item:
        return json_response(404, {"error": "Job not found (jobs expire after 7 days)"})

    view = jobs.result_view(item)
    return json_response(202 if item["status"] == jobs.PENDING else 200, view)
