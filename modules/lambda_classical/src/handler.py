"""
Lambda Classical - Brute-force SOC assignment optimizer
Values = Breach Impact Cost ($): Hourly Financial Loss × Hours to Mitigate
"""

import json
import os
import itertools
import boto3
from datetime import datetime, timezone, timedelta

# --- AWS Service Setup ---
# Bedrock is used here to generate the "Executive Narrative"
bedrock  = boto3.client("bedrock-runtime", region_name="us-east-1")
dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
# Uses Claude 4.5 by default if not specified in environment variables
MODEL_ID = os.environ.get("BEDROCK_MODEL", "us.anthropic.claude-3-5-haiku-20241022-v1:0")


def call_bedrock(prompt: str, max_tokens: int = 400) -> str:
    """
    Sends a prompt to Amazon Bedrock (Anthropic Claude) and returns the text response.
    """
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


def brute_force(cost_matrix: list) -> tuple:
    """
    The "Classical" math: checks EVERY possible analyst-to-alert pair.
    For N=4, there are 24 combinations. For N=10, there are 3.6 million!
    """
    n         = len(cost_matrix)
    best_cost = float("inf")
    best_perm = None
    # itertools.permutations generates every possible pairing order
    for perm in itertools.permutations(range(n)):
        # Calculate total cost for THIS specific combination
        cost = sum(cost_matrix[i][perm[i]] for i in range(n))
        # If this is the cheapest we've seen so far, save it
        if cost < best_cost:
            best_cost = cost
            best_perm = list(perm)
    return best_perm, best_cost


def lambda_handler(event, context):
    """
    Main Logic: Receives the job, solves it, asks AI to explain it, and saves it.
    """
    job_id      = event.get("job_id", context.aws_request_id)
    analysts    = event["analysts"]
    alerts      = event["alerts"]
    cost_matrix = event["cost_matrix"]
    n           = len(analysts)

    # 1. RUN THE MATH: Find the best assignment and the total cost
    assignment, total_cost = brute_force(cost_matrix)
    pairs = [
        {
            "analyst": analysts[i],
            "alert":   alerts[assignment[i]],
            "cost":    cost_matrix[i][assignment[i]],
        }
        for i in range(n)
    ]

    # 2. CALCULATE SAVINGS: Just for the board report to show efficiency
    all_costs   = [cost_matrix[i][j] for i in range(n) for j in range(n)]
    worst_case  = sum(sorted(all_costs, reverse=True)[:n])
    savings     = worst_case - total_cost

    # 3. GENERATE THE STORY: Ask Bedrock to act as a CISO
    prompt = f"""
You are the Chief Information Security Officer (CISO) of a major bank presenting to the board.

Your Security Operations Center just used a brute-force optimization algorithm to find the globally optimal assignment of analysts to active cyber threats.
It evaluated every possible combination ({factorial(n):,} total) to find the absolute minimum financial exposure.

Assignment result:
{json.dumps(pairs, indent=2)}

Total breach impact cost (optimal): ${total_cost:,.0f}
Combinations evaluated: {factorial(n):,}

Write exactly 3 sentences for a board-level audience:
1. What was optimized: the assignment of {n} SOC analysts to {n} active cyber threats, minimizing total breach impact cost in dollars.
2. The key insight: why brute-force guarantees the global optimum (not a greedy local minimum), and what the total financial exposure is.
3. The business value: what this means for the bank's risk posture and incident response efficiency.

No bullet points. No technical jargon. Confident, executive tone. Dollar amounts should be formatted with commas.
"""
    narrative = call_bedrock(prompt, max_tokens=350)

    # 4. PERSISTENCE: Save the result to DynamoDB with a 7-day expiration (TTL)
    ttl = int((datetime.now(timezone.utc) + timedelta(days=7)).timestamp())
    table.put_item(Item={
        "job_id":     job_id,
        "status":     "COMPLETE",
        "method":     "CLASSICAL",
        "assignment": assignment,
        "total_cost": str(round(total_cost, 2)),
        "narrative":  narrative,
        "analysts":   analysts,
        "alerts":     alerts,
        "timestamp":  datetime.now(timezone.utc).isoformat(),
        "expires_at": ttl,
    })

    # 5. RETURN: Send the final data back to the Orchestrator/API
    return {
        "job_id":     job_id,
        "status":     "COMPLETE",
        "method":     "CLASSICAL",
        "assignment": pairs,
        "total_cost": round(total_cost, 2),
        "narrative":  narrative,
    }


def factorial(n):
    # Simple math helper to calculate total combinations (N!)
    r = 1
    for i in range(2, n + 1):
        r *= i
    return r