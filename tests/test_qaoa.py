import itertools
import json

import numpy as np
import pytest

import qaoa
import statevector as sv

SMALL = [[3, 8], [6, 2]]
MEDIUM = [[72, 95, 98], [112, 31, 67], [56, 65, 111]]


def bits_of(index, num_qubits):
    return [(index >> (num_qubits - 1 - k)) & 1 for k in range(num_qubits)]


def qubo_energy(linear, quadratic, x):
    return sum(a * x[k] for k, a in linear.items()) + sum(
        b * x[k] * x[l] for (k, l), b in quadratic.items()
    )


def perm_index(perm, n):
    return sum(1 << (n * n - 1 - (i * n + j)) for i, j in enumerate(perm))


# --------------------------------------------------------------------------- #
# Formulation
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("cost", [SMALL, MEDIUM])
def test_qubo_ground_state_is_the_optimal_assignment(cost):
    n = len(cost)
    linear, quadratic = qaoa.build_qubo(cost)
    energies = [
        qubo_energy(linear, quadratic, bits_of(i, n * n)) for i in range(2 ** (n * n))
    ]
    ground = int(np.argmin(energies))
    best_perm = min(itertools.permutations(range(n)), key=lambda p: qaoa.assignment_cost(cost, p))
    assert ground == perm_index(best_perm, n)


@pytest.mark.parametrize("cost", [SMALL, MEDIUM])
def test_ising_matches_qubo_up_to_a_constant(cost):
    n = len(cost)
    num_qubits = n * n
    linear, quadratic = qaoa.build_qubo(cost)
    h, J = qaoa.qubo_to_ising(linear, quadratic)
    ising = sv.ising_energies(h, J, num_qubits).astype(np.float64)
    qubo = np.array([qubo_energy(linear, quadratic, bits_of(i, num_qubits)) for i in range(2 ** num_qubits)])
    offset = ising - qubo
    assert np.allclose(offset, offset[0], atol=1e-5)


def test_valid_permutations_keep_cost_ordering():
    """For feasible states, QUBO energy is the normalised cost (+ constant)."""
    n = len(MEDIUM)
    linear, quadratic = qaoa.build_qubo(MEDIUM)
    max_cost = max(max(r) for r in MEDIUM)
    diffs = []
    for perm in itertools.permutations(range(n)):
        x = bits_of(perm_index(perm, n), n * n)
        diffs.append(qubo_energy(linear, quadratic, x) - qaoa.assignment_cost(MEDIUM, perm) / max_cost)
    assert np.allclose(diffs, diffs[0])


def test_ising_is_normalised():
    h, J = qaoa.build_ising(MEDIUM)
    assert max(abs(v) for v in list(h.values()) + list(J.values())) == pytest.approx(1.0)


# --------------------------------------------------------------------------- #
# Circuit
# --------------------------------------------------------------------------- #
@pytest.mark.parametrize("cost,p", [(SMALL, 2), (MEDIUM, 2)])
def test_openqasm_circuit_matches_reference_simulation(cost, p):
    """The OpenQASM program sent to Braket implements exactly exp(-i g H_C), exp(-i b H_M)."""
    n = len(cost)
    num_qubits = n * n
    circuit = qaoa.build_qaoa_circuit(cost, p=p)
    assert circuit["braketSchemaHeader"]["name"] == "braket.ir.openqasm.program"
    gate_level = sv.simulate_openqasm(circuit["source"], num_qubits)

    h, J = qaoa.build_ising(cost)
    gammas, betas = qaoa.linear_ramp_schedule(p, qaoa.DEFAULT_DELTA_GAMMA, qaoa.DEFAULT_DELTA_BETA)
    reference = sv.simulate_qaoa(h, J, gammas, betas, num_qubits)

    assert np.allclose(gate_level, reference, atol=1e-5)


def test_circuit_shape_and_payload_size_for_n5():
    n, p = 5, qaoa.DEFAULT_LAYERS
    cost = [[(i * 7 + j * 3) % 11 + 1 for j in range(n)] for i in range(n)]
    gates = qaoa.build_qaoa_gates(cost, p=p)

    pairs_per_layer = 2 * n * (n * (n - 1) // 2)       # same-row + same-column pairs
    expected = n * n + p * (n * n + 3 * pairs_per_layer + n * n)
    assert len(gates) == expected
    assert {g[0] for g in gates} == {"h", "rz", "rx", "cnot"}

    source = qaoa.build_qaoa_circuit(cost, p=p)["source"]
    lines = source.strip().splitlines()
    # SV1 rules: header, one qubit + one bit register, no include, all qubits measured
    assert lines[:3] == ["OPENQASM 3.0;", f"qubit[{n * n}] q;", f"bit[{n * n}] b;"]
    assert "include" not in source and "cx " not in source
    assert lines[-(n * n):] == [f"b[{k}] = measure q[{k}];" for k in range(n * n)]
    assert len(lines) == 3 + expected + n * n
    assert len(json.dumps(qaoa.build_qaoa_circuit(cost, p=p))) < 200_000


def test_qaoa_concentrates_probability_on_the_optimum():
    n = len(MEDIUM)
    num_qubits = n * n
    h, J = qaoa.build_ising(MEDIUM)
    gammas, betas = qaoa.linear_ramp_schedule(
        qaoa.DEFAULT_LAYERS, qaoa.DEFAULT_DELTA_GAMMA, qaoa.DEFAULT_DELTA_BETA
    )
    probs = sv.simulate_qaoa(h, J, gammas, betas, num_qubits)

    best_perm = min(itertools.permutations(range(n)), key=lambda p: qaoa.assignment_cost(MEDIUM, p))
    p_opt = probs[perm_index(best_perm, n)]
    p_feasible = sum(probs[perm_index(p, n)] for p in itertools.permutations(range(n)))

    # Uniform sampling of 9 qubits hits the optimum with p = 1/512 ~ 0.002.
    assert p_opt > 0.2
    assert p_feasible > 0.5
    assert p_opt == pytest.approx(max(probs))  # the optimum is the most likely outcome


# --------------------------------------------------------------------------- #
# Decoding
# --------------------------------------------------------------------------- #
def test_bitstring_to_assignment():
    assert qaoa.bitstring_to_assignment("010100001", 3) == [1, 0, 2]
    assert qaoa.bitstring_to_assignment("110000001", 3) is None   # analyst 0 on two threats
    assert qaoa.bitstring_to_assignment("100100001", 3) is None   # threat 0 covered twice
    assert qaoa.bitstring_to_assignment("000100001", 3) is None   # analyst 0 idle
    assert qaoa.bitstring_to_assignment("0101", 3) is None        # wrong length


def test_counts_from_result_reorders_measured_qubits():
    result = {"measuredQubits": [1, 0], "measurements": [[1, 0], [1, 0], [0, 0]]}
    assert qaoa.counts_from_result(result) == {"01": 2, "00": 1}


def test_counts_from_probabilities():
    result = {"measurementProbabilities": {"10": 0.75, "01": 0.25}, "taskMetadata": {"shots": 100}}
    assert qaoa.counts_from_result(result) == {"10": 75, "01": 25}


def test_analyse_counts_reports_best_sample_and_gap():
    cost = SMALL  # optimum: [0, 1] -> 5 ; other permutation [1, 0] -> 14
    counts = {"1001": 10, "0110": 30, "1111": 60}
    m = qaoa.analyse_counts(counts, cost)
    assert m["qaoa_assignment"] == [0, 1]
    assert m["qaoa_cost"] == 5
    assert m["qaoa_found_optimum"] is True
    assert m["feasible_fraction"] == pytest.approx(0.4)
    assert m["optimal_fraction"] == pytest.approx(0.1)


def test_analyse_counts_with_no_feasible_sample():
    m = qaoa.analyse_counts({"1111": 5, "0000": 5}, SMALL)
    assert m["qaoa_assignment"] is None
    assert m["qaoa_cost"] is None
    assert m["qaoa_gap_pct"] is None
    assert m["feasible_fraction"] == 0
