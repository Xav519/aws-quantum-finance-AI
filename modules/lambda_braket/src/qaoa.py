"""
==============================================================================
modules/lambda_braket/src/qaoa.py
------------------------------------------------------------------------------
PURPOSE
  The quantum algorithm: turns the assignment problem into a QAOA circuit, and
    turns the measured results back into answers and quality metrics.

DETAILS
  Pure Python (no numpy) so it runs in the stock Lambda runtime.

  1. Problem -> QUBO
     One qubit per (analyst i, threat j) pair: qubit k = i*N + j (25 for 5x5).
     E(x) = sum c'_ij x_ij                 (normalised dollar cost)
          + A * sum_i (sum_j x_ij - 1)^2    (each analyst takes one threat)
          + A * sum_j (sum_i x_ij - 1)^2    (each threat gets one analyst)
     Breaking a rule adds a penalty A. Dropping one assignment saves at most 1
     but breaks a row and a column (+2A), so any A > 0.5 keeps valid plans
     cheapest. A = 0.75.
  2. QUBO -> Ising Hamiltonian, with x = (1 - z) / 2:
     H_C = sum h_k Z_k + sum J_kl Z_k Z_l, rescaled so the largest |coef| = 1.
  3. Circuit (OpenQASM 3, the format Braket SV1 accepts):
     |+>^n -> repeat p times [ exp(-i g H_C), exp(-i b H_M) ] -> measure
     exp(-i g h Z)       = rz(2 g h)
     exp(-i g J Z_k Z_l) = cnot(k,l) rz_l(2 g J) cnot(k,l)
     exp(+i b X)         = rx(-2 b)        (mixer H_M = -sum X)
  4. Linear-ramp schedule (Montanez-Barrera & Michielsen, 2024): gamma ramps up
     while beta ramps down over p = 16 layers. Fixed instead of optimised,
     because each optimiser step would be a separately billed Braket task;
     tuned offline with the simulator in tests/.
  5. Decoding: a measured bitstring is valid only if every row and column has
     exactly one 1. Invalid samples are reported, never 'repaired'.
==============================================================================
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
    """Divide every cost by the largest one, so costs are between 0 and 1."""
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
        """Add the penalty weight for two qubits that may not both be 1 (same row or column)."""
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
# Circuit (Braket OpenQASM 3)
# --------------------------------------------------------------------------- #
def linear_ramp_schedule(p: int, delta_gamma: float, delta_beta: float):
    """gamma_i ramps 0 -> delta_gamma, beta_i ramps delta_beta -> 0."""
    gammas, betas = [], []
    for i in range(1, p + 1):
        t = (i - 0.5) / p
        gammas.append(delta_gamma * t)
        betas.append(delta_beta * (1 - t))
    return gammas, betas


def build_qaoa_gates(
    cost_matrix,
    p: int = DEFAULT_LAYERS,
    delta_gamma: float = DEFAULT_DELTA_GAMMA,
    delta_beta: float = DEFAULT_DELTA_BETA,
    penalty: float = DEFAULT_PENALTY,
) -> list[tuple]:
    """Gate list: ("h", q), ("rz", q, angle), ("rx", q, angle), ("cnot", c, t)."""
    num_qubits = len(cost_matrix) ** 2
    h, J = build_ising(cost_matrix, penalty)
    gammas, betas = linear_ramp_schedule(p, delta_gamma, delta_beta)

    gates = [("h", k) for k in range(num_qubits)]
    for gamma, beta in zip(gammas, betas):
        # Cost unitary exp(-i gamma H_C)
        for k in range(num_qubits):
            gates.append(("rz", k, 2 * gamma * h[k]))
        for (k, l), coupling in sorted(J.items()):
            gates += [("cnot", k, l), ("rz", l, 2 * gamma * coupling), ("cnot", k, l)]
        # Mixer exp(-i beta H_M), H_M = -sum X
        for k in range(num_qubits):
            gates.append(("rx", k, -2 * beta))
    return gates


def to_openqasm(gates: list[tuple], num_qubits: int) -> str:
    """Serialise gates as Braket-flavoured OpenQASM 3.

    SV1 constraints (from GetDevice capabilities): one qubit register, one
    classical register, every qubit measured, contiguous indices, no
    `include` (Braket's built-in gate names such as `cnot` are used instead
    of stdgates.inc's `cx`).
    """
    lines = ["OPENQASM 3.0;", f"qubit[{num_qubits}] q;", f"bit[{num_qubits}] b;"]
    for gate in gates:
        name = gate[0]
        if name == "h":
            lines.append(f"h q[{gate[1]}];")
        elif name in ("rz", "rx"):
            lines.append(f"{name}({gate[2]:.6f}) q[{gate[1]}];")
        elif name == "cnot":
            lines.append(f"cnot q[{gate[1]}], q[{gate[2]}];")
        else:
            raise ValueError(f"unsupported gate {name}")
    lines += [f"b[{k}] = measure q[{k}];" for k in range(num_qubits)]
    return "\n".join(lines) + "\n"


def build_qaoa_circuit(cost_matrix, **kwargs) -> dict:
    """Build the QAOA circuit as a Braket OpenQASM program (the action JSON)."""
    num_qubits = len(cost_matrix) ** 2
    return {
        "braketSchemaHeader": {"name": "braket.ir.openqasm.program", "version": "1"},
        "source": to_openqasm(build_qaoa_gates(cost_matrix, **kwargs), num_qubits),
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
    """Total dollar cost of an assignment (assignment[i] = threat index for analyst i)."""
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

