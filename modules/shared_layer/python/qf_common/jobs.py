"""
Job record helpers shared by every Lambda.

DynamoDB item (table `<prefix>-jobs`, hash key `job_id`):

    job_id            str   UUID v4
    status            str   PENDING | COMPLETE | FAILED
    method            str   CLASSICAL | QUANTUM
    analysts, alerts  list[str]
    cost_matrix       str   JSON-encoded N x N matrix
    created_at        str   ISO-8601 UTC
    expires_at        int   epoch seconds (DynamoDB TTL)
    -- COMPLETE --
    assignment        list[int]  optimal threat index for each analyst
    total_cost, greedy_cost, savings, combinations_evaluated
    narrative, narrative_source
    qaoa              map   (QUANTUM only) QAOA sampling metrics
    -- QUANTUM, after submission --
    braket_task_arn, qaoa_layers, shots
    -- FAILED --
    error             str   user-safe failure description
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal

JOB_TTL_DAYS = 7

PENDING = "PENDING"
COMPLETE = "COMPLETE"
FAILED = "FAILED"


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def ttl_epoch(days: int = JOB_TTL_DAYS) -> int:
    return int((datetime.now(timezone.utc) + timedelta(days=days)).timestamp())


def to_dynamo(obj):
    """Recursively convert floats to Decimal (DynamoDB rejects float)."""
    if isinstance(obj, bool) or obj is None:
        return obj
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: to_dynamo(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [to_dynamo(v) for v in obj]
    return obj


def _pairs(assignment, analysts, alerts, cost_matrix):
    return [
        {"analyst": analysts[i], "alert": alerts[int(j)], "cost": cost_matrix[i][int(j)]}
        for i, j in enumerate(assignment)
    ]


def result_view(item: dict) -> dict:
    """Shape a job item into the public API response body."""
    status = item.get("status")
    view = {
        "job_id": item["job_id"],
        "status": status,
        "method": item.get("method"),
        "created_at": item.get("created_at"),
    }

    if status == PENDING:
        view["message"] = (
            "Quantum task running on Amazon Braket SV1."
            if item.get("braket_task_arn")
            else "Submitting quantum task to Amazon Braket."
        )
        return view

    if status == FAILED:
        view["error"] = item.get("error", "The job failed.")
        return view

    analysts, alerts = item["analysts"], item["alerts"]
    cost_matrix = json.loads(item["cost_matrix"])
    view.update({
        "assignment": _pairs(item["assignment"], analysts, alerts, cost_matrix),
        "total_cost": item.get("total_cost"),
        "greedy_cost": item.get("greedy_cost"),
        "savings": item.get("savings"),
        "combinations_evaluated": item.get("combinations_evaluated"),
        "narrative": item.get("narrative", ""),
        "narrative_source": item.get("narrative_source"),
    })

    qaoa = item.get("qaoa")
    if qaoa:
        qaoa = dict(qaoa)
        if qaoa.get("qaoa_assignment") is not None:
            qaoa["qaoa_assignment"] = _pairs(qaoa["qaoa_assignment"], analysts, alerts, cost_matrix)
        view["qaoa"] = qaoa
    return view
