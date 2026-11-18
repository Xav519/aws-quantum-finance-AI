"""
==============================================================================
modules/lambda_orchestrator/src/validation.py
------------------------------------------------------------------------------
PURPOSE
  Checks every POST /optimize request before anything else happens.

DETAILS
  Rejects (HTTP 400) anything unexpected: wrong types, sizes outside 2..5,
  non-square matrices, negative/infinite/huge costs, duplicate names, or names
  with unusual characters. Everything that reaches DynamoDB, Braket or the AI
  prompt has passed through here.
==============================================================================
"""

from __future__ import annotations

import math
import re

MIN_N = 2
MAX_N = 5            # N^2 qubits; SV1 supports up to 34, and QAOA quality drops fast with N
MAX_COST = 1_000_000_000
MAX_LABEL_LEN = 60
LABEL_RE = re.compile(r"^[\w][\w .,'()&/+-]*$", re.UNICODE)


class ValidationError(ValueError):
    """Raised for any invalid request; its message is returned to the user (HTTP 400)."""
    pass


def _labels(value, field: str, n_expected: int | None = None) -> list[str]:
    """Validate a list of analyst or threat names (type, length, characters, uniqueness, size)."""
    if not isinstance(value, list) or not value:
        raise ValidationError(f"'{field}' must be a non-empty list of names")
    out = []
    for name in value:
        if not isinstance(name, str):
            raise ValidationError(f"every entry in '{field}' must be a string")
        name = name.strip()
        if not 1 <= len(name) <= MAX_LABEL_LEN or not LABEL_RE.match(name):
            raise ValidationError(
                f"'{field}' entries must be 1-{MAX_LABEL_LEN} characters: letters, digits, "
                "spaces and . , ' ( ) & / + -"
            )
        out.append(name)
    if len(set(out)) != len(out):
        raise ValidationError(f"'{field}' must not contain duplicates")
    if n_expected is not None and len(out) != n_expected:
        raise ValidationError("'analysts', 'alerts' and 'cost_matrix' dimensions must all match")
    return out


def _cost(value) -> float | int:
    """Validate one cost: a real, finite number between 0 and MAX_COST."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValidationError("every cost must be a number")
    if not math.isfinite(value) or value < 0 or value > MAX_COST:
        raise ValidationError(f"every cost must be between 0 and {MAX_COST:,}")
    return int(value) if float(value).is_integer() else float(value)


def validate_request(body: dict) -> tuple[list[str], list[str], list[list[float]]]:
    """Return (analysts, alerts, cost_matrix) or raise ValidationError."""
    if not isinstance(body, dict):
        raise ValidationError("request body must be a JSON object")

    analysts = _labels(body.get("analysts"), "analysts")
    n = len(analysts)
    if not MIN_N <= n <= MAX_N:
        raise ValidationError(f"problem size must be between {MIN_N} and {MAX_N}")
    alerts = _labels(body.get("alerts"), "alerts", n)

    matrix = body.get("cost_matrix")
    if not isinstance(matrix, list) or len(matrix) != n:
        raise ValidationError("'analysts', 'alerts' and 'cost_matrix' dimensions must all match")
    cost_matrix = []
    for row in matrix:
        if not isinstance(row, list) or len(row) != n:
            raise ValidationError("'cost_matrix' must be a square N x N matrix")
        cost_matrix.append([_cost(v) for v in row])

    return analysts, alerts, cost_matrix
