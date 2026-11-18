"""
==============================================================================
tests/test_validation.py
------------------------------------------------------------------------------
PURPOSE
  Tests for request validation (validation.py).

DETAILS
  Valid input is accepted and cleaned; malformed, oversized, non-finite,
  duplicate and script-like inputs are rejected with a clear error.
==============================================================================
"""

import math

import pytest

from validation import ValidationError, validate_request


def body(n=3, **overrides):
    """A valid request of size n; keyword arguments override individual fields."""
    data = {
        "analysts": [f"Analyst {i}" for i in range(n)],
        "alerts": [f"Threat {i}" for i in range(n)],
        "cost_matrix": [[(i + 1) * 1000 + j for j in range(n)] for i in range(n)],
    }
    data.update(overrides)
    return data


def test_valid_request_is_normalised():
    analysts, alerts, matrix = validate_request(body(analysts=["  Sarah (Network) ", "Marc", "Chen"]))
    assert analysts[0] == "Sarah (Network)"
    assert len(alerts) == 3 and len(matrix) == 3


@pytest.mark.parametrize("n", [1, 6])
def test_size_bounds(n):
    with pytest.raises(ValidationError, match="between"):
        validate_request(body(n))


@pytest.mark.parametrize("bad", [
    {"analysts": "Sarah"},
    {"analysts": ["A", "A", "B"]},
    {"analysts": ["<script>", "B", "C"]},
    {"analysts": ["x" * 61, "B", "C"]},
    {"alerts": ["T1", "T2"]},
    {"cost_matrix": [[1, 2, 3], [4, 5, 6]]},
    {"cost_matrix": [[1, 2, 3], [4, 5], [7, 8, 9]]},
    {"cost_matrix": [[1, 2, 3], [4, "5", 6], [7, 8, 9]]},
    {"cost_matrix": [[1, 2, 3], [4, True, 6], [7, 8, 9]]},
    {"cost_matrix": [[1, 2, 3], [4, -5, 6], [7, 8, 9]]},
    {"cost_matrix": [[1, 2, 3], [4, math.inf, 6], [7, 8, 9]]},
    {"cost_matrix": [[1, 2, 3], [4, 10 ** 12, 6], [7, 8, 9]]},
])
def test_rejects_malformed_input(bad):
    with pytest.raises(ValidationError):
        validate_request(body(**bad))


def test_rejects_non_object():
    with pytest.raises(ValidationError):
        validate_request([1, 2, 3])
