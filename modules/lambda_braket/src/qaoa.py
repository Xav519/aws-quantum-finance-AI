"""
QAOA for the N x N analyst-to-threat assignment problem.

Pure-Python (no numpy) so it runs in the stock Lambda runtime and can be unit
tested locally.

Formulation
-----------
One binary variable x_ij per (analyst i, threat j) pair  ->  N^2 qubits,
qubit k = i * N + j.  The problem is written as a QUBO:

    E(x) = sum_ij c'_ij x_ij
         + A * sum_i (sum_j x_ij - 1)^2      (each analyst takes one threat)
         + A * sum_j (sum_i x_ij - 1)^2      (each threat gets one analyst)

where c' is the cost matrix normalised to [0, 1] and A is the constraint
penalty.  Removing one assignment from a valid permutation saves at most
c'_max = 1 but violates one row and one column (+2A), so any A > 0.5 makes
every valid permutation a local minimum. The default A = 0.75 keeps that
margin without drowning the cost signal (tuned offline, see below).

The QUBO is mapped to an Ising Hamiltonian with x = (1 - z) / 2:

    H_C = sum_k h_k Z_k + sum_{k<l} J_kl Z_k Z_l   (+ constant)

Circuit
-------
    |+>^n  ->  prod_{i=1..p} [ exp(-i gamma_i H_C) * exp(-i beta_i H_M) ]  ->  measure

with mixer H_M = -sum_k X_k (|+>^n is its ground state).  Gate mapping:
    exp(-i gamma h Z)        = Rz(2 gamma h)
    exp(-i gamma J Z_k Z_l)  = CNOT(k,l) Rz_l(2 gamma J) CNOT(k,l)
    exp(+i beta X)           = Rx(-2 beta)

Parameters follow a linear-ramp schedule (an annealing-inspired, fixed
schedule; see Montanez-Barrera & Michielsen, "Towards a universal QAOA
protocol", 2024): gamma ramps up while beta ramps down.  Each step of a
variational optimisation loop would be a separately billed SV1 task, so the
schedule is fixed and was tuned offline with the local statevector simulator
in tests/ (see README, "QAOA performance").
"""

from __future__ import annotations

import itertools
from collections import Counter
from math import factorial

DEFAULT_PENALTY = 0.75
DEFAULT_LAYERS = 16
DEFAULT_DELTA_GAMMA = 3.2
DEFAULT_DELTA_BETA = 0.6


# --------------------------------------------------------------------------- #
# Problem -> QUBO -> Ising
# --------------------------------------------------------------------------- #
def normalise_costs(cost_matrix: list[list[float]]) -> list[list[float]]:
    max_cost = max(max(row) for row in cost_matrix) or 1
    return [[c / max_cost for c in row] for row in cost_matrix]


def build_qubo(cost_matrix, penalty: float = DEFAULT_PENALTY):
    """Return (linear, quadratic) QUBO coefficients, constant term dropped.

    linear:    {k: a_k}
    quadratic: {(k, l): b_kl} with k < l
    """
    n = len(cost_matrix)
    c = normalise_costs(cost_matrix)
    linear = {}
    quadratic = {}

    # (sum x - 1)^2 = -sum x + 2 sum_{k<l} x_k x_l + 1   (x^2 = x)
    for i in range(n):
        for j in range(n):
            # one -A from its row constraint, one -A from its column constraint
            linear[i * n + j] = c[i][j] - 2 * penalty

    def add_pair(k, l):
        key = (min(k, l), max(k, l))
        quadratic[key] = quadratic.get(key, 0.0) + 2 * penalty

    for i in range(n):  # same analyst, two threats
        for j1, j2 in itertools.combinations(range(n), 2):
            add_pair(i * n + j1, i * n + j2)
    for j in range(n):  # same threat, two analysts
        for i1, i2 in itertools.combinations(range(n), 2):
            add_pair(i1 * n + j, i2 * n + j)

    return linear, quadratic


def qubo_to_ising(linear, quadratic):
    """Map x = (1 - z)/2.  Returns (h, J), constant offset dropped."""
    h = {k: -a / 2 for k, a in linear.items()}
    J = {}
    for (k, l), b in quadratic.items():
        J[(k, l)] = b / 4
        h[k] -= b / 4
        h[l] -= b / 4
    return h, J


def build_ising(cost_matrix, penalty: float = DEFAULT_PENALTY):
    """Ising coefficients rescaled so the largest |coefficient| is 1.

    Rescaling makes the gamma schedule independent of problem size and of
    the dollar magnitude of the costs.
    """
    h, J = qubo_to_ising(*build_qubo(cost_matrix, penalty))
    scale = max([abs(v) for v in h.values()] + [abs(v) for v in J.values()]) or 1
    return {k: v / scale for k, v in h.items()}, {k: v / scale for k, v in J.items()}


# --------------------------------------------------------------------------- #
# Circuit (Braket JAQCD IR)
# --------------------------------------------------------------------------- #
def linear_ramp_schedule(p: int, delta_gamma: float, delta_beta: float):
    """gamma_i ramps 0 -> delta_gamma, beta_i ramps delta_beta -> 0."""
    gammas, betas = [], []
    for i in range(1, p + 1):
        t = (i - 0.5) / p
        gammas.append(delta_gamma * t)
        betas.append(delta_beta * (1 - t))
    return gammas, betas


def _h(target):
    return {"type": "h", "target": target}


def _rz(target, angle):
    return {"type": "rz", "target": target, "angle": round(angle, 6)}


def _rx(target, angle):
    return {"type": "rx", "target": target, "angle": round(angle, 6)}


def _cnot(control, target):
    return {"type": "cnot", "control": control, "target": target}


def build_qaoa_circuit(
    cost_matrix,
    p: int = DEFAULT_LAYERS,
    delta_gamma: float = DEFAULT_DELTA_GAMMA,
    delta_beta: float = DEFAULT_DELTA_BETA,
    penalty: float = DEFAULT_PENALTY,
) -> dict:
    """Build the QAOA circuit as a Braket JAQCD program.

    Measurement is implicit in JAQCD when shots > 0, so `results` is empty.
    """
    n = len(cost_matrix)
    num_qubits = n * n
    h, J = build_ising(cost_matrix, penalty)
    gammas, betas = linear_ramp_schedule(p, delta_gamma, delta_beta)

    instructions = [_h(k) for k in range(num_qubits)]
    for gamma, beta in zip(gammas, betas):
        # Cost unitary exp(-i gamma H_C)
        for k in range(num_qubits):
            instructions.append(_rz(k, 2 * gamma * h[k]))
        for (k, l), coupling in sorted(J.items()):
            instructions += [_cnot(k, l), _rz(l, 2 * gamma * coupling), _cnot(k, l)]
        # Mixer exp(-i beta H_M), H_M = -sum X
        for k in range(num_qubits):
            instructions.append(_rx(k, -2 * beta))

    return {
        "braketSchemaHeader": {"name": "braket.ir.jaqcd.program", "version": "1"},
        "instructions": instructions,
        "results": [],
        "basis_rotation_instructions": [],
    }


# --------------------------------------------------------------------------- #
# Decoding measurement results
# --------------------------------------------------------------------------- #
def bitstring_to_assignment(bitstring: str, n: int):
    """Return the permutation encoded by a bitstring, or None if infeasible.

    Feasible means exactly one '1' in every row and every column.
    """
    if len(bitstring) != n * n:
        return None
    assignment = []
    for i in range(n):
        row = bitstring[i * n:(i + 1) * n]
        if row.count("1") != 1:
            return None
        assignment.append(row.index("1"))
    if len(set(assignment)) != n:
        return None
    return assignment


def assignment_cost(cost_matrix, assignment) -> float:
    return sum(cost_matrix[i][j] for i, j in enumerate(assignment))


def counts_from_result(result_data: dict) -> Counter:
    """Extract bitstring counts from a Braket results.json payload.

    Bitstrings are ordered by qubit index (qubit 0 first), re-ordered via
    `measuredQubits` if the device reports them out of order.
    """
    measured = result_data.get("measuredQubits")
    shots = result_data.get("measurements")
    if shots:
        order = None
        if measured and list(measured) != sorted(measured):
            order = sorted(range(len(measured)), key=lambda i: measured[i])
        counts = Counter()
        for shot in shots:
            if order:
                shot = [shot[i] for i in order]
            counts["".join(str(int(b)) for b in shot)] += 1
        return counts

    probs = result_data.get("measurementProbabilities") or {}
    total = result_data.get("taskMetadata", {}).get("shots") or 1000
    return Counter({bs: round(p * total) for bs, p in probs.items()})


def analyse_counts(counts: Counter, cost_matrix) -> dict:
    """Summarise a QAOA run against the exact optimum.

    Returns the best *feasible sampled* assignment (standard practice for
    sampling-based QAOA), plus quality metrics.  If no shot is feasible,
    `qaoa_assignment` is None: nothing is repaired or invented.
    """
    n = len(cost_matrix)
    total_shots = sum(counts.values()) or 1

    optimum_cost = min(
        assignment_cost(cost_matrix, perm)
        for perm in itertools.permutations(range(n))
    )

    feasible_shots = 0
    optimal_shots = 0
    best_assignment, best_cost = None, None
    for bitstring, count in counts.items():
        assignment = bitstring_to_assignment(bitstring, n)
        if assignment is None:
            continue
        feasible_shots += count
        cost = assignment_cost(cost_matrix, assignment)
        if cost == optimum_cost:
            optimal_shots += count
        if best_cost is None or cost < best_cost:
            best_assignment, best_cost = assignment, cost

    if best_cost is None:
        gap = None
    elif optimum_cost > 0:
        gap = round((best_cost - optimum_cost) / optimum_cost * 100, 2)
    else:
        gap = 0.0

    return {
        "shots": total_shots,
        "distinct_bitstrings": len(counts),
        "feasible_fraction": round(feasible_shots / total_shots, 4),
        "optimal_fraction": round(optimal_shots / total_shots, 4),
        "qaoa_assignment": best_assignment,
        "qaoa_cost": best_cost,
        "qaoa_gap_pct": gap,
        "qaoa_found_optimum": best_cost is not None and best_cost == optimum_cost,
        # Probability a uniformly random permutation is optimal, for context
        "random_baseline_optimal_fraction": round(
            sum(
                1 for perm in itertools.permutations(range(n))
                if assignment_cost(cost_matrix, perm) == optimum_cost
            ) / factorial(n), 4
        ),
    }

