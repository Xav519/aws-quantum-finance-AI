"""API Gateway (HTTP API, payload format 2.0) response helpers.

CORS headers are intentionally absent: the HTTP API's cors_configuration
owns CORS and overrides anything returned by the integration.
"""

from __future__ import annotations

import json
from decimal import Decimal


def _default(obj):
    if isinstance(obj, Decimal):
        return int(obj) if obj == obj.to_integral_value() else float(obj)
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def json_response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
        },
        "body": json.dumps(body, default=_default),
    }
