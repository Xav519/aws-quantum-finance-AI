"""
==============================================================================
modules/shared_layer/layer/python/qf_common/http.py
------------------------------------------------------------------------------
PURPOSE
  Builds API Gateway responses (HTTP API, payload format 2.0).

DETAILS
  Converts DynamoDB Decimal numbers to normal JSON numbers and adds no-cache /
  nosniff headers. CORS headers are deliberately absent: API Gateway's CORS
  configuration owns them.
==============================================================================
"""

from __future__ import annotations

import json
from decimal import Decimal


def _default(obj):
    """Teach json.dumps to write DynamoDB Decimal values as normal numbers."""
    if isinstance(obj, Decimal):
        return int(obj) if obj == obj.to_integral_value() else float(obj)
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def json_response(status_code: int, body: dict) -> dict:
    """Build the response dict API Gateway expects: status code, headers, JSON body."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body, default=_default),
    }
