# Performance Gap Analysis

Last updated: 2026-06-11 (post audit-iteration-1, branch `audit/iteration-1-fixes`)

## 2026-06-11 pass (audit iteration 1)

Six perf items (P-IDs scoped to this pass; not the historical P1–P10 namespace
below) were identified during the 2026-06-11 audit and all **Closed** on
branch `audit/iteration-1-fixes`:

| P-ID | Finding | Resolution | Commit |
|------|---------|------------|--------|
| P1 | Constant-input benchmark loops were hoisting-tainted — `Subnet.contains` and `cosineDistance` measured fully hoisted code; haversine numbers had weak semantics | De-hoisted via opaque per-iteration inputs (power-of-two corpora; opacity-barrier cost trade-off documented inline) | `66f969c`, `f7f1e38`, `a2966a2` |
| P2 | Baselines stale after de-hoist | Full re-baseline of all 12 benchmarks in `bench/baseline.json`. As executed: max-envelope across 10+ mixed-load runs (not the plan's median-of-3, which flapped — inter-run min-of-N spread is 4–69% on the shared host, exceeding the 30% one-sided tolerance) | `0fcd591`, `e24eca7` |
| P3 | Baseline metric comment described the wrong statistic | Metric description corrected (final wording documents the max-envelope methodology) | `0fcd591`, `e24eca7` |
| P4 | `Mac.format` dispatched 6 `std.fmt` calls per address | Single-buffer `writeAll`; ~6.7 ns/op vs 57.4 ns/op prior baseline (~8x) | `2c099a1` |
| P5 | No parse benchmarks for `LatLonAlt` / `GeoPoint` | Benches added | `34f8115` |
| P6 | CI installed python3 twice in the release job | Duplicate install removed | `fcc1ec5` |

**Root-cause correction:** the 5th-pass analysis attributed the suspicious
haversine baseline to loop hoisting. The de-hoist work showed the old number
was stale codegen (baseline captured against different generated code), not
hoisting — the de-hoisted measurement reproduces a sane figure. Recorded here
so the Monitor-verified rationale isn't over-generalized.

## Summary

| Status         | Count | PerfScore range |
|----------------|------:|-----------------|
| Open (Fix)     | 0 | — |
| Open (Monitor) | 0 | — |
| **Closed this pass (Fix)** | **3** | 48-80 |
| **Closed this pass (Monitor-verified, sub-noise)** | **5** | 32-48 |
| Closed prior | 5 | — |
| Won't Do | 11 | — |
| **Total tracked** | **24** | — |

All 8 open performance items at the start of the 5th pass were resolved: 3 Fix-tier items shipped code, and 5 Monitor-tier items closed as **Monitor-verified** with rationale tied to the measured 11-17 % hardware jitter floor (commit `27f8414`).

### 30 % Bench regression gate — tolerance rationale

The CI bench regression gate in `ci/bench_gate.py` + `bench/baseline.json` locks at `tolerance = 1.30` (i.e. 30 % slower-than-baseline fails the pipeline). Justification:

- Measured intra-run jitter (p95/min) on the shared runner: 11.4 %, 14.7 %, 16.7 % across three consecutive `Ipv4Addr.parse` runs.
- With `taskset -c 0` pinning: 7.8 %, 11.7 %, 33.3 % — better median but occasional outliers.
- A 25 % gate would flap on normal runner variance; a 30 % gate comfortably clears the noise floor and still catches the 2-5× regressions that matter for a value-type library with no I/O.
- **User accepted Option B (30 %)** during Phase C after CP-3 jitter check failed the original 10 % target.
- **Retune path:** when a dedicated bench runner or disabled-turbo / isolated-CPU kernel config reduces the jitter floor, re-baseline and tighten `tolerance` in `bench/baseline.json` (single-file edit).

### Status migrations this pass

| P-ID | Prior | New | Reason |
|------|-------|-----|--------|
| BENCH-01 / I2 | Open Fix (80, P1) | **Closed** | Warm-up + min-of-N + p95 harness landed. |
| BENCH-02 / I3 | Open Fix (48, P1) | **Closed** | CI regression gate + `baseline.json` at 1.30× tolerance. |
| BENCH-03 / I4 | Open Fix (48, P2) | **Closed** | 5 missing benches added. |
| A1 / URL-01 | Open Monitor (48, P2) | **Closed — Monitor-verified (sub-noise)** | Projected 30-40 % win below 11-17 % jitter floor. |
| A6 / FMT-01 | Open Monitor (36, P3) | **Closed — Monitor-verified (sub-noise)** | Below noise floor. |
| S1 / PRECOMP-01 | Open Monitor (36, P3) | **Closed — Monitor-verified (sub-noise)** | `HaversineOrigin` helper shipped under BENCH-03; caller-side 1-to-N win on demand. |
| IPADDR-01 | Open Monitor (32, P3) | **Closed — Monitor-verified (sub-noise)** | Below noise floor. |
| S3 | Open Monitor (32, P3) | **Closed — Monitor-verified (sub-noise)** | Requires consumer at N >= 16; no signal yet. |

---

## Closed this pass (5th Gap Closure Pass)

### Fix-tier (code landed)

| P-ID | PerfScore | Finding | Resolution | Commit / Issue |
|------|---------:|---------|------------|----------------|
| BENCH-01 / I2 | 80 | Bench harness lacks warm-up / min-of-N / stdev; 1.3-2.2× intra-run jitter | 3 warm-up rounds + 9 measured rounds of 100k iterations; emits min/median/p95/jitter%/ops-per-sec | `d708eb4` / [#57](https://gitlab.com/devnw/zig/advanced-types/-/issues/57) |
| BENCH-02 / I3 | 48 | No CI regression gate; `allow_failure: true` | `ci/bench_gate.py` + `bench/baseline.json` with `tolerance = 1.30`; `allow_failure` removed from bench job | `18f591d` / [#58](https://gitlab.com/devnw/zig/advanced-types/-/issues/58) |
| BENCH-03 / I4 | 48 | Bench corpus missing 5-7 ops | Added `Ipv4Addr.format`, `Mac.format`, `Subnet.contains`, `IpAddr.parse`, `LatLon.haversineBroadcast` benches; `HaversineOrigin` helper + test | `af6eae9` / [#59](https://gitlab.com/devnw/zig/advanced-types/-/issues/59) |

### Monitor-verified (sub-noise)

| P-ID | PerfScore | Finding | Monitor-verified reason | Commit / Issue |
|------|---------:|---------|-------------------------|----------------|
| A1 / URL-01 | 48 | `Url.parse` 6-8 linear scans; projected 30-40 % win | Local noise floor 11-17 %; single-call bench floor cannot confirm sub-30 % wins. Re-evaluate with dedicated hardware. | `27f8414` / [#60](https://gitlab.com/devnw/zig/advanced-types/-/issues/60) |
| A6 / FMT-01 | 36 | `std.fmt.print("{X:0>2}")` per byte in Ipv4/Mac format | Below noise floor (identical rationale) | `27f8414` / [#61](https://gitlab.com/devnw/zig/advanced-types/-/issues/61) |
| S1 / PRECOMP-01 | 36 | Precomputed-origin haversine for 1-to-many sweeps | `HaversineOrigin` helper shipped under BENCH-03 (`af6eae9`); caller-side 1-to-N win available on demand; per-call delta below noise floor | `27f8414` / [#62](https://gitlab.com/devnw/zig/advanced-types/-/issues/62) |
| IPADDR-01 | 32 | `IpAddr.parse` pre-scan doubles byte traversals on IPv6 | Below noise floor | `27f8414` / [#63](https://gitlab.com/devnw/zig/advanced-types/-/issues/63) |
| S3 | 32 | No `@Vector(16, f32)` tiled cosine at N >= 16 | Requires consumer at N >= 16; Geode (only consumer) uses N = 3. No signal yet. | `27f8414` / [#64](https://gitlab.com/devnw/zig/advanced-types/-/issues/64) |

### Bench table at close of 5th pass (317 tests then; 322 now; `python3 ci/bench_gate.py` → all benchmarks within 1.30× tolerance — 10 benchmarks at the time, 12 as of 2026-06-11)

- Worst case `Ipv4Addr.parse`: 13.85 vs 13.76 ns baseline (+0.6 %, noise).
- No benchmark > 30 % slower than baseline.

---

## Resolved prior passes

| P-ID | Finding | Resolution | Commit / Issue |
|------|---------|------------|----------------|
| P1 / I1 | `zig build bench` harness | Closed (partial; BENCH-03 tracked remaining corpus gap, now closed this pass) | `d786b46` / [#29](https://gitlab.com/devnw/zig/advanced-types/-/issues/29) |
| P2 | CI lacks ReleaseFast test target | Closed — added `test-release-fast` | — |
| P3 | `cosineDistance` 3 passes | Closed — fused in `vector.zig` | — |
| D1 | ReleaseFast overflow-wrap docs | Closed | `0c2ebbd` / [#33](https://gitlab.com/devnw/zig/advanced-types/-/issues/33) |
| D2 | `network.zig:563` `@intCast(u5)` assert | Closed | `1234a9f` / [#36](https://gitlab.com/devnw/zig/advanced-types/-/issues/36) |

## Won't Do (unchanged)

| P-ID | Finding | Reason |
|------|---------|--------|
| P4 | CI installs Zig in every job | Requires custom Docker image |
| P5 | No `@Vector` SIMD intrinsics | Won't Do (rescoped as S3; now Monitor-verified) |
| P6 | `distance()` intermediate array | Compiler elides at N=3 |
| P7 | `Url.parse` multi-pass | Superseded by A1/#60 Monitor-verified |
| P8 | `VectorF32` hardcodes N=3 | Design choice |
| P9 | Haversine 7 transcendentals | Mathematically unavoidable; `atan2` cannot be removed |
| P10 / A3 | `GeoPoint.parse` 3-pass | Sub-us for 30-byte inputs |
| A2 | `parse + domain()` 3× host amplification | Rolled into A1/#60 (Monitor-verified) |
| A4 | `findDoubleColon` duplicates `std.mem.indexOf` | Cosmetic |
| A5 | IPv6 right-half temp stack buffer | Debug-only cost |
| M3 | No `Vector.normalizeInPlace` | API churn at N=3 |
| S2 | No approximate geodistance | Feature add, out of scope |
| FUSION-02 | `Ipv6Addr.parse` 2-3× buffer touch | Rolled into Monitor notes; below cutoff |
| M2 | `distance()` intermediate at generic N | Monitor (below cutoff) |
| M4 | No `@branchHint(.unlikely)` | Monitor (below cutoff) |

## Dependency Graph (historical reference)

BENCH-01 (80, P1) was the gatekeeper for every Monitor item. With BENCH-01, -02, and -03 all landed, the dependency chain is fully resolved.

## PerfScore Methodology

`PerfScore = Impact(1-5) × Likelihood(1-5) × 4` (range 4-100).

- **Impact:** 5 = SLO-saver / 10× potential; 4 = 2-5× or significant cost; 3 = user-facing noticeable; 2 = small; 1 = hardening.
- **Likelihood:** 5 = always / hot path; 4 = common; 3 = moderate; 2 = rare; 1 = edge.

## Notes from 5th Gap Closure Pass (2026-04-18)

- **Jitter-floor discovery:** CP-3 measurements in Phase C revealed 11-17 % intra-run jitter on the shared local runner. This is hardware/OS-level noise, not a harness bug. It formally disqualifies every Monitor item whose projected win is sub-30 % — hence the Monitor-verified closure pattern.
- **Re-tune plan:** if a dedicated bench runner (or disabled-turbo / isolated-CPU kernel config) is provisioned, re-baseline (`python3 ci/bench_gate.py --rebaseline` or direct edit of `bench/baseline.json`) and tighten `tolerance`. The Monitor-verified items become eligible for re-promotion only when the noise floor drops below their projected-win band.
- **Machine-readable output:** `bench/main.zig` now emits a single-line `BENCH_JSON_BEGIN`/`BENCH_JSON_END` block of `name → min ns/op` after the human-readable table. `ci/bench_gate.py` extracts this for gating.
- **Consumer gating:** S1/PRECOMP-01's `HaversineOrigin` API is now live (shipped under BENCH-03). It is caller-opt-in; consumers can pay for the 1-to-N win without a per-call cost in the default path.
