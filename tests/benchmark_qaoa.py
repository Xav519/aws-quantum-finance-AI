"""
Offline QAOA benchmark (noiseless statevector, same circuit parameters as the Lambda).

    python tests/benchmark_qaoa.py              # N = 3 and 4, 20 random instances each
    python tests/benchmark_qaoa.py --n 5 --instances 5   # 25 qubits: ~3 min/instance, ~1.5 GB RAM

For each random cost matrix it reports the exact probability that one shot is a
valid assignment / the optimal assignment, and whether the best valid sample in
`--shots` sampled measurements is the optimum (what the Lambda reports).
"""

import argparse
import itertools
import os
import random
import sys
import time

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path[:0] = [os.path.join(ROOT, "modules", "lambda_braket", "src"), os.path.dirname(__file__)]

import qaoa  # noqa: E402
import statevector as sv  # noqa: E402


def run_instance(cost, shots, seed):
    n = len(cost)
    num_qubits = n * n
    h, J = qaoa.build_ising(cost)
    gammas, betas = qaoa.linear_ramp_schedule(
        qaoa.DEFAULT_LAYERS, qaoa.DEFAULT_DELTA_GAMMA, qaoa.DEFAULT_DELTA_BETA
    )
    dtype = np.complex64 if num_qubits > 20 else np.complex128
    probs = sv.simulate_qaoa(h, J, gammas, betas, num_qubits, dtype=dtype).astype(np.float64)

    perms = list(itertools.permutations(range(n)))
    optimum = min(qaoa.assignment_cost(cost, p) for p in perms)
    p_feasible = p_optimal = 0.0
    for perm in perms:
        idx = sum(1 << (num_qubits - 1 - (i * n + j)) for i, j in enumerate(perm))
        p_feasible += probs[idx]
        if qaoa.assignment_cost(cost, perm) == optimum:
            p_optimal += probs[idx]

    metrics = qaoa.analyse_counts(sv.sample_counts(probs, shots, num_qubits, seed), cost)
    return p_feasible, p_optimal, metrics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, nargs="+", default=[3, 4])
    parser.add_argument("--instances", type=int, default=20)
    parser.add_argument("--shots", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()

    print(f"p={qaoa.DEFAULT_LAYERS}  dgamma={qaoa.DEFAULT_DELTA_GAMMA}  dbeta={qaoa.DEFAULT_DELTA_BETA}  "
          f"A={qaoa.DEFAULT_PENALTY}  shots={args.shots}")
    print("N  qubits  instances  P(valid)  P(optimal)  random-guess P(optimal)  best-sample=optimum  mean gap")
    for n in args.n:
        rng = random.Random(args.seed + n)
        rows = []
        for k in range(args.instances):
            cost = [[rng.randint(10, 120) * 1000 for _ in range(n)] for _ in range(n)]
            t = time.time()
            rows.append(run_instance(cost, args.shots, args.seed + k))
            if n >= 5:
                print(f"  instance {k + 1}/{args.instances} done in {time.time() - t:.0f}s", flush=True)
        p_valid = np.mean([r[0] for r in rows])
        p_opt = np.mean([r[1] for r in rows])
        hits = sum(r[2]["qaoa_found_optimum"] for r in rows)
        gaps = [r[2]["qaoa_gap_pct"] for r in rows if r[2]["qaoa_gap_pct"] is not None]
        print(f"{n}  {n * n:>6}  {args.instances:>9}  {p_valid:8.3f}  {p_opt:10.4f}  "
              f"{1 / 2 ** (n * n):23.1e}  {hits:>11}/{args.instances:<7}  {np.mean(gaps):7.2f}%")


if __name__ == "__main__":
    main()
