"""
Classical solvers for the N x N assignment problem.

`solve_exact` enumerates all N! permutations. That is deliberate: for the
N <= 5 sizes this demo accepts (at most 120 permutations) it is instant and
trivially verifiable. Production systems at larger N would use the Hungarian
algorithm (O(N^3), e.g. scipy.optimize.linear_sum_assignment).

`solve_greedy` is the "intuition" baseline: each analyst, in order, takes the
cheapest threat still open. It shows what the optimisation is worth.
"""

from __future__ import annotations

import itertools
from math import factorial


def assignment_cost(cost_matrix, assignment) -> float:
    return sum(cost_matrix[i][j] for i, j in enumerate(assignment))


def solve_exact(cost_matrix) -> tuple[list[int], float]:
    n = len(cost_matrix)
    best = min(
        itertools.permutations(range(n)),
        key=lambda perm: assignment_cost(cost_matrix, perm),
    )
    return list(best), assignment_cost(cost_matrix, best)


def solve_greedy(cost_matrix) -> tuple[list[int], float]:
    n = len(cost_matrix)
    taken: set[int] = set()
    assignment = []
    for i in range(n):
        j = min((j for j in range(n) if j not in taken), key=lambda j: cost_matrix[i][j])
        taken.add(j)
        assignment.append(j)
    return assignment, assignment_cost(cost_matrix, assignment)


def combinations_count(n: int) -> int:
    return factorial(n)
