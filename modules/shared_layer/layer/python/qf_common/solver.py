"""
==============================================================================
modules/shared_layer/layer/python/qf_common/solver.py
------------------------------------------------------------------------------
PURPOSE
  Classical solvers for the N x N assignment problem.

DETAILS
  solve_exact  -> tries all N! assignments and returns the cheapest. Instant for
                  N <= 5 (at most 120) and easy to verify. Larger N would use
                  the Hungarian algorithm (scipy.optimize.linear_sum_assignment).
  solve_greedy -> the 'intuition' baseline: each analyst, in order, takes the
                  cheapest threat still open. Shows what optimization saves.
==============================================================================
"""

from __future__ import annotations

import itertools
from math import factorial


def assignment_cost(cost_matrix, assignment) -> float:
    """Total cost of an assignment (assignment[i] = threat index for analyst i)."""
    return sum(cost_matrix[i][j] for i, j in enumerate(assignment))


def solve_exact(cost_matrix) -> tuple[list[int], float]:
    """Try every assignment and return (best assignment, its cost). Guaranteed optimal."""
    n = len(cost_matrix)
    best = min(
        itertools.permutations(range(n)),
        key=lambda perm: assignment_cost(cost_matrix, perm),
    )
    return list(best), assignment_cost(cost_matrix, best)


def solve_greedy(cost_matrix) -> tuple[list[int], float]:
    """Each analyst in turn takes the cheapest open threat. Returns (assignment, cost)."""
    n = len(cost_matrix)
    taken: set[int] = set()
    assignment = []
    for i in range(n):
        j = min((j for j in range(n) if j not in taken), key=lambda j: cost_matrix[i][j])
        taken.add(j)
        assignment.append(j)
    return assignment, assignment_cost(cost_matrix, assignment)


def combinations_count(n: int) -> int:
    """Number of possible assignments for N analysts: N! (N factorial)."""
    return factorial(n)
