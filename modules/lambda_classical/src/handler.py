"""
==============================================================================
modules/lambda_classical/src/handler.py
------------------------------------------------------------------------------
PURPOSE
  Classical Lambda: solves small problems (N <= 4) exactly.

DETAILS
  1. Checks all N! possible assignments and keeps the cheapest (proven optimal).
  2. Computes the 'greedy' baseline to show how much optimization saves.
  3. Asks Claude on Amazon Bedrock for a 3-sentence board summary
     (a template is used if Bedrock is unavailable).
  4. Saves the job in DynamoDB (kept 7 days) and returns the result.
==============================================================================
"""

import json
import logging
import os

import boto3

from qf_common import jobs
from qf_common.bedrock import generate_narrative
from qf_common.solver import combinations_count, solve_exact, solve_greedy

logger = logging.getLogger()
logger.setLevel(logging.INFO)

table = boto3.resource("dynamodb").Table(os.environ["DYNAMODB_TABLE"])


def build_prompt(pairs, n, total_cost, greedy_cost, savings) -> str:
    """Text sent to Claude: only the computed figures, wrapped in <data>, plus the writing task."""
    return f"""<data>
Problem: assign {n} security analysts to {n} simultaneous cyber threats, one each, minimising total breach impact cost (hourly loss x hours to mitigate).
Method: every one of the {combinations_count(n):,} possible assignments was evaluated, so the result is the proven minimum.
Optimal assignment: {json.dumps(pairs)}
Optimal total breach impact cost: ${total_cost:,.0f}
Greedy baseline (each analyst in turn takes their cheapest open threat): ${greedy_cost:,.0f}
Saving versus greedy: ${savings:,.0f}
</data>

Write exactly 3 sentences for the board: (1) what was decided and the optimal total exposure, (2) why it is guaranteed optimal and how it compares with the greedy baseline, (3) what this means for incident-response risk. Format dollar amounts with commas."""


def fallback_narrative(n, total_cost, greedy_cost, savings) -> str:
    """Template summary used when Bedrock is unavailable (same facts, no AI)."""
    comparison = (
        f"${savings:,.0f} less than the ${greedy_cost:,.0f} a greedy assignment would have cost"
        if savings > 0 else "matching the greedy assignment in this case"
    )
    return (
        f"All {combinations_count(n):,} possible assignments of {n} analysts to {n} active threats were "
        f"evaluated, and the selected assignment minimises total breach impact at ${total_cost:,.0f}. "
        f"That is {comparison}. Because every alternative was checked, no other assignment carries "
        f"lower financial exposure."
    )


def lambda_handler(event, context):
    """Entry point (invoked by the orchestrator): solve, summarise, store, return the result."""
    job_id = event["job_id"]
    analysts = event["analysts"]
    alerts = event["alerts"]
    cost_matrix = event["cost_matrix"]
    n = len(analysts)

    assignment, total_cost = solve_exact(cost_matrix)
    _, greedy_cost = solve_greedy(cost_matrix)
    savings = greedy_cost - total_cost

    pairs = [
        {"analyst": analysts[i], "alert": alerts[j], "cost": cost_matrix[i][j]}
        for i, j in enumerate(assignment)
    ]
    narrative, narrative_source = generate_narrative(
        build_prompt(pairs, n, total_cost, greedy_cost, savings),
        fallback_narrative(n, total_cost, greedy_cost, savings),
    )

    record = {
        "job_id": job_id,
        "status": jobs.COMPLETE,
        "method": "CLASSICAL",
        "analysts": analysts,
        "alerts": alerts,
        "cost_matrix": json.dumps(cost_matrix),
        "assignment": assignment,
        "total_cost": total_cost,
        "greedy_cost": greedy_cost,
        "savings": savings,
        "combinations_evaluated": combinations_count(n),
        "narrative": narrative,
        "narrative_source": narrative_source,
        "created_at": jobs.now_iso(),
        "expires_at": jobs.ttl_epoch(),
    }
    table.put_item(Item=jobs.to_dynamo(record))
    logger.info("job %s: classical optimum %s (greedy %s)", job_id, total_cost, greedy_cost)
    # Return the plain-Python record: the Lambda runtime cannot serialise Decimal.
    return jobs.result_view(record)
