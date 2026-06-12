#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024-2025 CodePros
"""
BENCH-02 (#58) -- bench regression gate.

Runs `zig build bench -Doptimize=ReleaseFast`, scrapes the
BENCH_JSON_BEGIN/END block from stdout, and compares each benchmark's
min-of-N (ns/op) against `bench/baseline.json`. A benchmark fails the
gate when its current min exceeds `baseline * tolerance`.

Tolerance rationale: BENCH-01 observed 11-17% intra-run jitter on the
reporter's shared developer workstation (see
`docs/audit/gap-close-implement-log.md` -- CP-3). A gate tighter than
that jitter would flap on unrelated pipeline noise. 30% is the smallest
tolerance that is robustly above the measured noise floor while still
catching the 2-5x regressions that matter (e.g. an accidental
allocation in a parser hot path or a debug-print left in a format
routine). The `tolerance` field in baseline.json is authoritative; the
CLI flag overrides it only for local experimentation.

Exit codes:
  0  all benchmarks within tolerance
  1  one or more benchmarks regressed beyond tolerance
  2  bench run failed, JSON block missing, or baseline malformed

Usage (from repo root):
  python3 ci/bench_gate.py                 # uses baseline tolerance
  python3 ci/bench_gate.py --tolerance 1.5 # override (debug only)
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys


def run_bench() -> str:
    """Run `zig build bench` and return its stdout+stderr combined."""
    try:
        result = subprocess.run(
            ["zig", "build", "bench", "-Doptimize=ReleaseFast"],
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
    except FileNotFoundError:
        sys.stderr.write("error: zig executable not found on PATH\n")
        sys.exit(2)
    except subprocess.TimeoutExpired:
        sys.stderr.write("error: bench run exceeded 300s timeout\n")
        sys.exit(2)

    if result.returncode != 0:
        sys.stderr.write(f"error: `zig build bench` exited {result.returncode}\n")
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        sys.exit(2)

    # The harness writes via std.debug.print, which routes to stderr on
    # most Zig versions; combine both streams defensively.
    return result.stdout + "\n" + result.stderr


def extract_json_block(output: str) -> dict[str, float]:
    """Pull the single JSON object between the sentinels."""
    begin_tag = "BENCH_JSON_BEGIN"
    end_tag = "BENCH_JSON_END"
    begin = output.find(begin_tag)
    end = output.find(end_tag)
    if begin < 0 or end < 0 or end <= begin:
        sys.stderr.write(
            "error: BENCH_JSON_BEGIN/END markers missing from bench output\n"
        )
        sys.exit(2)
    payload = output[begin + len(begin_tag) : end].strip()
    try:
        parsed = json.loads(payload)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"error: bench JSON payload malformed: {exc}\n")
        sys.stderr.write(payload + "\n")
        sys.exit(2)
    if not isinstance(parsed, dict):
        sys.stderr.write("error: bench JSON payload is not an object\n")
        sys.exit(2)
    return {str(k): float(v) for k, v in parsed.items()}


def load_baseline(path: pathlib.Path) -> tuple[dict[str, float], float]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"error: reading baseline {path}: {exc}\n")
        sys.exit(2)
    benchmarks = data.get("benchmarks")
    if not isinstance(benchmarks, dict):
        sys.stderr.write(f"error: baseline {path} missing 'benchmarks' object\n")
        sys.exit(2)
    tolerance = float(data.get("tolerance", 1.30))
    return {str(k): float(v) for k, v in benchmarks.items()}, tolerance


def main() -> int:
    repo_root = pathlib.Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--baseline",
        type=pathlib.Path,
        default=repo_root / "bench" / "baseline.json",
        help="path to baseline JSON (default: bench/baseline.json)",
    )
    parser.add_argument(
        "--tolerance",
        type=float,
        default=None,
        help="override tolerance multiplier (e.g. 1.30 for 30%% slower max)",
    )
    parser.add_argument(
        "--input",
        type=pathlib.Path,
        default=None,
        help="read bench output from file instead of running `zig build bench`",
    )
    args = parser.parse_args()

    baseline, baseline_tolerance = load_baseline(args.baseline)
    tolerance = args.tolerance if args.tolerance is not None else baseline_tolerance
    if tolerance <= 1.0:
        sys.stderr.write(
            f"error: tolerance {tolerance} must be > 1.0 (fraction slower)\n"
        )
        return 2

    if args.input is not None:
        try:
            bench_output = args.input.read_text(encoding="utf-8")
        except OSError as exc:
            sys.stderr.write(f"error: reading {args.input}: {exc}\n")
            return 2
    else:
        bench_output = run_bench()

    current = extract_json_block(bench_output)

    print(
        f"bench-gate: tolerance={tolerance:.2f}x "
        f"({(tolerance - 1.0) * 100.0:.0f}% slower allowed)"
    )
    print(
        f"{'benchmark':<32} {'baseline':>12} {'current':>12} "
        f"{'limit':>12} {'status':>8}"
    )
    print("-" * 80)

    failures: list[str] = []
    missing: list[str] = []
    for name, base in sorted(baseline.items()):
        cur = current.get(name)
        if cur is None:
            missing.append(name)
            print(
                f"{name:<32} {base:>12.2f} {'MISSING':>12} "
                f"{base * tolerance:>12.2f} {'MISSING':>8}"
            )
            continue
        limit = base * tolerance
        status = "OK" if cur <= limit else "FAIL"
        if status == "FAIL":
            failures.append(name)
        print(f"{name:<32} {base:>12.2f} {cur:>12.2f} {limit:>12.2f} {status:>8}")

    extras = sorted(set(current) - set(baseline))
    for name in extras:
        # New benchmarks are not a failure; they just aren't gated yet.
        print(f"{name:<32} {'--':>12} {current[name]:>12.2f} {'--':>12} {'NEW':>8}")

    if missing:
        sys.stderr.write(
            "error: benchmarks declared in baseline but missing from run: "
            + ", ".join(missing)
            + "\n"
        )
        return 2

    if failures:
        sys.stderr.write(
            "error: bench regression threshold exceeded: " + ", ".join(failures) + "\n"
        )
        return 1

    print("bench-gate: all benchmarks within tolerance")
    return 0


if __name__ == "__main__":
    sys.exit(main())
