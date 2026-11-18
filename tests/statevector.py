"""
==============================================================================
tests/statevector.py
------------------------------------------------------------------------------
PURPOSE
  A small quantum computer simulator (numpy) used to check the circuit offline.

DETAILS
  Two independent ways to compute the result of the QAOA circuit:
    simulate_openqasm() -> reads the exact OpenQASM text sent to Braket and
                           applies it gate by gate (small sizes only).
    simulate_qaoa()     -> applies the cost step as one big phase multiplication
                           and the mixer qubit by qubit (fast enough for 25 qubits).
  If both agree, the circuit sent to AWS really implements the algorithm.
  Qubit 0 is the leftmost bit, matching the order Braket reports.
==============================================================================
"""

from __future__ import annotations

import re

import numpy as np


# --------------------------------------------------------------------------- #
# Gate-level simulator
# --------------------------------------------------------------------------- #
def _apply_1q(state, gate, target, num_qubits):
    """Apply a 2x2 gate matrix to one qubit of the state vector."""
    view = state.reshape(2 ** target, 2, 2 ** (num_qubits - target - 1))
    s0, s1 = view[:, 0, :], view[:, 1, :]
    out = np.empty_like(view)
    out[:, 0, :] = gate[0, 0] * s0 + gate[0, 1] * s1
    out[:, 1, :] = gate[1, 0] * s0 + gate[1, 1] * s1
    return out.reshape(-1)


def _apply_cnot(state, control, target, num_qubits):
    """Apply a CNOT: flip the target qubit wherever the control qubit is 1."""
    state = state.reshape([2] * num_qubits).copy()
    idx = [slice(None)] * num_qubits
    idx[control] = 1
    sub = state[tuple(idx)]
    t_axis = target if target < control else target - 1
    state[tuple(idx)] = np.flip(sub, axis=t_axis)
    return state.reshape(-1)


def _rz(theta):
    """Matrix of the Rz(theta) rotation gate."""
    return np.diag([np.exp(-0.5j * theta), np.exp(0.5j * theta)])


def _rx(theta):
    """Matrix of the Rx(theta) rotation gate."""
    c, s = np.cos(theta / 2), np.sin(theta / 2)
    return np.array([[c, -1j * s], [-1j * s, c]])


_H = np.array([[1, 1], [1, -1]]) / np.sqrt(2)


_QASM_GATE = re.compile(
    r"^(?P<name>h|rz|rx|cnot)(?:\((?P<angle>[-+0-9.eE]+)\))?\s+q\[(?P<a>\d+)\](?:,\s*q\[(?P<b>\d+)\])?;$"
)
_QASM_SKIP = re.compile(r"^(OPENQASM 3\.0;|qubit\[\d+\] q;|bit\[\d+\] b;|b\[\d+\] = measure q\[\d+\];)$")


def simulate_openqasm(source: str, num_qubits: int) -> np.ndarray:
    """Simulate the Braket OpenQASM program produced by qaoa.to_openqasm().

    Any line outside the expected subset raises, so the test also guards the
    program's syntax.
    """
    state = np.zeros(2 ** num_qubits, dtype=np.complex128)
    state[0] = 1
    measured = 0
    for line in source.strip().splitlines():
        line = line.strip()
        if _QASM_SKIP.match(line):
            measured += line.startswith("b[")
            continue
        m = _QASM_GATE.match(line)
        if not m:
            raise ValueError(f"unexpected OpenQASM line: {line!r}")
        name, a = m["name"], int(m["a"])
        if name == "h":
            state = _apply_1q(state, _H, a, num_qubits)
        elif name == "rz":
            state = _apply_1q(state, _rz(float(m["angle"])), a, num_qubits)
        elif name == "rx":
            state = _apply_1q(state, _rx(float(m["angle"])), a, num_qubits)
        else:
            state = _apply_cnot(state, a, int(m["b"]), num_qubits)
    if measured != num_qubits:
        raise ValueError("SV1 requires every qubit to be measured")
    return np.abs(state) ** 2


# --------------------------------------------------------------------------- #
# Fast QAOA simulator
# --------------------------------------------------------------------------- #
def z_value(idx: np.ndarray, num_qubits: int, k: int) -> np.ndarray:
    """Eigenvalue of Z_k (+1 for |0>, -1 for |1>) for every basis state."""
    bit = (idx >> (num_qubits - 1 - k)) & 1
    return (1 - 2 * bit).astype(np.int8)


def ising_energies(h: dict, J: dict, num_qubits: int) -> np.ndarray:
    # Z values are recomputed per term rather than cached: caching all of them
    # would need ~800 MB at 25 qubits.
    """Energy of every basis state under H = sum h Z + sum J ZZ (one number per state)."""
    idx = np.arange(2 ** num_qubits, dtype=np.int32)
    energy = np.zeros(2 ** num_qubits, dtype=np.float32)
    for k, hk in h.items():
        energy += np.float32(hk) * z_value(idx, num_qubits, k)
    for (k, l), jkl in J.items():
        zz = z_value(idx, num_qubits, k) * z_value(idx, num_qubits, l)
        energy += np.float32(jkl) * zz
    return energy


def simulate_qaoa(h, J, gammas, betas, num_qubits, dtype=np.complex128) -> np.ndarray:
    """Fast QAOA simulation: cost step as a phase multiply, mixer qubit by qubit. Returns probabilities."""
    energy = ising_energies(h, J, num_qubits)
    state = np.full(2 ** num_qubits, 2 ** (-num_qubits / 2), dtype=dtype)
    for gamma, beta in zip(gammas, betas):
        state *= np.exp(-1j * gamma * energy).astype(dtype)
        mixer = _rx(-2 * beta).astype(dtype)
        for k in range(num_qubits):
            state = _apply_1q(state, mixer, k, num_qubits)
    return np.abs(state) ** 2


def index_to_bitstring(index: int, num_qubits: int) -> str:
    """Basis-state index -> bitstring with qubit 0 first (Braket's order)."""
    return format(index, f"0{num_qubits}b")


def sample_counts(probs: np.ndarray, shots: int, num_qubits: int, seed: int = 0) -> dict:
    """Draw `shots` random measurements from the probabilities, like a real device would."""
    rng = np.random.default_rng(seed)
    probs = probs / probs.sum()
    samples = rng.choice(len(probs), size=shots, p=probs)
    values, counts = np.unique(samples, return_counts=True)
    return {index_to_bitstring(int(v), num_qubits): int(c) for v, c in zip(values, counts)}
