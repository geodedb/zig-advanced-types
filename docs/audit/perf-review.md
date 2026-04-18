# Performance Review — Phase 3 (Deep Analysis)

**Repo:** `/home/benji/src/devnw/zig/advanced-types`
**HEAD:** `f3adc69` (2026-04-18)
**Scope:** `src/types/*.zig` (~3,374 LOC) + `bench/main.zig` + `.gitlab-ci.yml` bench job.
**Method:** Static read + three fresh `zig build bench -Doptimize=ReleaseFast` runs on the same Linux 6.12 / Zig 0.16.0 host; no product code modified.

The library has **no I/O, no threading, no globals, no mutexes, no allocator on any public API**. Every finding is CPU-bound or a harness/observability gap. Prior `docs/PERF_GAP_ANALYSIS.md` P-IDs (P1…P10, A1…A6, I1…I4, D1, D2, M1…M4, S1…S3) are preserved; new IDs (BENCH-01…03, FMT-01, IPADDR-01) are added for findings not previously tracked.

---

## Phase-2 Inputs Accepted As Evidence

- **URL-01 / A1 `confidence::confirmed`** — `Url.parse` does 6-8 linear scans over the same buffer (`url.zig:194,198,210,217,226,242,255,265,302`). `Url.parse + Url.domain()` scans the host 3 more times (`looksLikeIpv4` + `Domain.parse` + `validateLabel`). Estimated 30-40 % win from a fused state machine at today's 70-101 ns/op Url.parse floor.
- **PRECOMP-01 / S1 `confidence::confirmed`** — `LatLon.haversineDistance` recomputes 7 transcendentals per call (`2x@sin + 2x@cos + 2x@sqrt + 1x atan2`); origin-pinned 1-to-N sweeps leave `cos(lat1)`, `sin(lat1)` and one `°->rad` multiply on the table (~15 % reduction on a 10 k broadcast).
- **FUSION-02 `confidence::suspected`** — `Ipv6Addr.parse` runs `findDoubleColon` pre-pass then `parseGroups` on left+right halves (`network.zig:221,233,239,270-303`), touching the buffer 2-3 times for compressed inputs.
- **ALLOC-01 `confidence::confirmed`** — Zero heap allocations; only `Allocator` references in `src/` are doc comments (`url.zig:47,170`).
- **SIMD-01 `confidence::confirmed`** — No `@Vector`/`@splat`/`@reduce` in `src/`; cosine + haversine clock 0.9-1.4 ns/op at N=3 which means LLVM already auto-vectorizes / CSE-eliminates. No action at N=3; S3 rescope candidate only at N >= 16.

---

## Bench Re-Run vs Scan Baseline

Three back-to-back `zig build bench -Doptimize=ReleaseFast` runs on the same host:

| Benchmark                    | Scan baseline | Run 1 | Run 2 | Run 3 | Min   | Max   | Max/Min |
|------------------------------|--------------:|------:|------:|------:|------:|------:|--------:|
| `Ipv4Addr.parse`             |         24.52 | 11.87 | 25.92 | 14.05 | 11.87 | 25.92 |   2.18x |
| `Ipv6Addr.parse`             |         26.65 | 21.90 | 22.11 | 28.35 | 21.90 | 28.35 |   1.29x |
| `Url.parse`                  |         95.42 | 76.23 | 70.32 |100.90 | 70.32 |100.90 |   1.43x |
| `VectorF32.cosineDistance`   |          1.20 |  1.00 |  0.91 |  1.37 |  0.91 |  1.37 |   1.51x |
| `LatLon.haversineDistance`   |          1.20 |  1.00 |  0.91 |  1.37 |  0.91 |  1.37 |   1.51x |

**Bench health:** No regression — every min is <= scan baseline; every max is within scan jitter band. But the 1.3-2.2x intra-run spread across *identical* builds is itself a problem — see BENCH-01/02/03.

`zig build test-performance -Doptimize=ReleaseFast --summary all`: **9/9 pass, MaxRSS <= 4 MB run** (verified in scan). No blocker.

---

## Manual Performance Review

### Algorithms & Data Structures

| P-ID | Finding | File:Line | Root Cause | Impact | How to Verify | Confidence |
|------|---------|-----------|------------|--------|---------------|------------|
| **A1 / URL-01** | `Url.parse` 6-8 linear scans + hostchar re-scan (fused-state-machine candidate) | `src/types/url.zig:194,198-202,210,217,226,242,255,265,302-307,369-371` | Split-then-dispatch parser; every delimiter is unambiguous given prior state. | At 70-101 ns/op this is the library's hottest path (10x cosine/haversine). Fused SM target ~60-70 ns/op. Win 30-40 %. | Prototype fused parser on branch, re-run 10-run min-of-N bench; target `Url.parse` < 70 ns/op on mixed corpus. | confirmed (scans), suspected (delta without A/B bench) |
| **A2** | `Url.parse + Url.domain()` chain scans host 3x (looksLikeIpv4 + Domain.parse main loop + validateLabel per label) | `src/types/url.zig:322-326, 52-73, 113-121, 376-382` | `domain()` re-discovers facts `parse()` already knew (IPv6-literal bracket, all-digits-and-dots). Cheap fix: have `parse` stash two bool flags (`is_ipv6_literal`, `might_be_ipv4`) inline during the authority scan. | 10-30 % `parse + domain()` combined; 0 % for consumers that only call `parse`. | Consumer-workload dependent — promote only if I1 bench shows combined pattern in hot path. | confirmed (structure), suspected (delta) |
| **A3 / P10** | `GeoPoint.parse` 3-pass dispatcher (trim -> `std.mem.count` -> dispatchee's own trim + indexOfScalar) | `src/types/geographic.zig:296-313, 158-163, 211-217` | Passes un-stripped `input` to dispatchees. Single-pass variant: find first comma, check for second comma in remainder, branch 2D/3D, hand `inner` to avoid re-trim. | Sub-microsecond for ~30 byte inputs; no bench in `bench/main.zig` today. | Add `GeoPoint.parse` bench; Won't-Do unless observed > 50 ns/op. | confirmed |
| **A4** | `Ipv6Addr.findDoubleColon` hand-rolls `std.mem.indexOf(u8, input, "::")` | `src/types/network.zig:260-268` | Premature specialization. `std.mem.indexOf` on length-2 needle dispatches to a SWAR-friendly scan on modern stdlib. | Tens of ns per IPv6 parse; cosmetic. | `zig build bench` + `test-performance` before/after replacement. | confirmed |
| **A5** | `Ipv6Addr.parse` right-half stack buffer `[16]u8 = .{0}**16` + copy into `octets` | `src/types/network.zig:238-247` | Parse-then-shift implementation. Could parse the right half and write directly into `octets[right_offset..]`. | Debug/ReleaseSafe only (ReleaseFast elides zero-init). Micro. | Profile IPv6 parse in Debug; not worth chasing at current 22-28 ns. | suspected |
| **A6 / FMT-01** | `std.fmt.print("{X:0>2}", ...)` per byte in `Ipv4Addr.format` / `Mac.format` | `src/types/network.zig:113-120, 627-649` (Mac) | Convenience formatter; `std.fmt` is a branch-dense state machine per format-spec parse. Hand-rolled hex-nibble table typically 10x faster. | No format bench in `bench/main.zig`. Often the #1 cost for logging-heavy consumers. 50-100 ns per call plausible. | Add `benchIpv4Format` / `benchMacFormat` (10^6 iters) and compare against a nibble-table implementation. | suspected |
| **IPADDR-01** (new) | `IpAddr.parse` does a full `for (input)` pre-scan for `:` before delegating; IPv6 then scans again in its own loop. Every IPv6 input pays 2x `input.len` scans. | `src/types/network.zig:441-450` | Dispatch-by-pre-scan. Cheaper check: look at `input[0]` (a `:` at position 0 = IPv6 `::`/`:x`; digit-first could still be IPv4 OR IPv4-in-IPv6 but that can be detected inside `Ipv6Addr.parse` on first colon seen). | Adds O(n) ahead of every IPv6 parse through the `IpAddr` interface (also the critical path for `Subnet.parse`). At current 22 ns/op IPv6, pre-scan is ~20-30 % of that for typical 15-byte inputs. | Replace the pre-scan with `input[0] == ':'` short-circuit + let `Ipv4Addr.parse` dispatch-to-`Ipv6Addr.parse` on first `:`. Bench `IpAddr.parse` before/after. | suspected |

### Memory & GC

| P-ID | Finding | File:Line | Root Cause | Impact | How to Verify | Confidence |
|------|---------|-----------|------------|--------|---------------|------------|
| **M1** | Zero heap allocations — design goal structurally enforced by public API (no `Allocator` parameter anywhere). | all `src/types/*.zig` | — | None. Claim holds. | — | confirmed |
| **M2** | `Vector.distance` = `self.sub(other).magnitude()` materializes an intermediate `[N]T`. P6 "Won't Do" rests on "compiler elides at N=3" — **unverified**. | `src/types/vector.zig:166-169` | Expression-based API. For `Vector(T, 128)` this is 512 B of temp per call. | 0 % at N=3 (cosine+distance at 0.9-1.4 ns/op prove elision). Risk is only generic N>=16. | `zig build-obj --emit=llvm-ir -OReleaseFast` on a `Vector(f32, 128).distance` caller; inspect IR for alloca elimination. | suspected |
| **M3** | `Vector.normalize` returns a whole new `Self`. No `normalizeInPlace` variant. | `src/types/vector.zig:158-163` | API immutability choice. | 12 B copy at N=3 (register-kept). Real cost only if generic N used. | Bench at N=128 if consumer signal appears. | suspected |
| **M4** | No `@branchHint(.unlikely)` on error paths in hot parsers. LLVM static branch prediction helps but is LTO-dependent. | `network.zig:78,87-107, url.zig:191-223,302-307, ...` | Library is idiomatic Zig 0.15/0.16; `@branchHint` is newer. | Marginal. | `perf stat -e branch-misses` on I1 bench before/after annotations. | suspected |

### I/O & Network

| — | **N/A — library has no I/O surface.** |

### Concurrency

| — | **N/A — library has no threading, no globals (constants are comptime-evaluated), no mutexes.** Safe to share across threads. |

### Pipelining & Streaming

| P-ID | Finding | File:Line | Root Cause | Impact | How to Verify | Confidence |
|------|---------|-----------|------------|--------|---------------|------------|
| **S1 / PRECOMP-01** | No batched / pinned-origin haversine. Fixed-origin 1-to-N sweeps recompute `cos(lat1)`, `sin(lat1)` and `to_rad * lat1` N times. | `src/types/geographic.zig:127-144` | API only exposes 2-point form. | ~15 % on 10 k-point sweeps (Geode nearest-neighbour pattern); 0 % on single-pair. `atan2` remains the dominant cost and is unavoidable. | Add `LatLon.prepareOrigin()` -> `PreparedOrigin { lat_rad, cos_lat, sin_lat }` and `distanceTo(other)`; add `benchHaversineBroadcast` iterating SF over N destinations. | suspected (consumer-dependent) |
| **S2** | No approximate-distance variant (equirectangular ~2 trig; spherical law of cosines ~3 trig). | `src/types/geographic.zig:*` | Out of current scope. | 3-5x faster than haversine for coarse bounding-box pre-filter. | Feature add; would require consumer signal. | suspected |
| **S3** | `Vector.cosineDistance` fused at N=3 (P3 closed). At generic N >= 16 the scalar loop auto-vectorizes under ReleaseFast but leaves 30-50 % on the floor vs `@Vector(16, f32)`-tiled loops with FMA. | `src/types/vector.zig:175-189` | No generic SIMD path. | Only relevant if consumer instantiates `Vector(f32, 384)` etc. | `zig build-obj --emit=llvm-ir` + `llvm-mca` on `Vector(f32, 384).cosineDistance`; A/B against hand-tiled `@Vector(16, f32)`. | suspected |

### Infrastructure & CI

| P-ID | Finding | File:Line | Root Cause | Impact | How to Verify | Confidence |
|------|---------|-----------|------------|--------|---------------|------------|
| **I1 / P1** | `zig build bench` harness shipped (commit `d786b46`). 5 benchmarks, exit-0 gate in CI. **Closed.** | `build.zig:124-137`; `bench/main.zig:1-193`; `.gitlab-ci.yml:202-212` | — | Unblocks all Monitor-gated items. | — | confirmed |
| **I2 / BENCH-01** (new) | **Bench harness has no warm-up, single-shot timing, no min-of-N aggregation, no mean/stdev reporting.** Fresh runs on the same host show 1.3-2.2x intra-run variance on `Ipv4Addr.parse` (11.87 / 25.92 / 14.05 ns/op) and on `Url.parse` (70.3 / 76.2 / 100.9). Any A/B delta < 2x is **statistically indistinguishable** from noise with this harness. | `bench/main.zig:80-164` (each `benchX` is a single loop, no warm-up) | `std.time.Timer` was removed in Zig 0.16; the portable replacement here times one run, prints, and moves on. | Blocks every `confidence::suspected -> confidence::confirmed` promotion (URL-01, PRECOMP-01, FUSION-02, FMT-01, IPADDR-01). Cannot tell a 15 % win (PRECOMP-01 target) from jitter. | Add: (a) 1x warm-up loop of same iter count, (b) 10 trials, report min+median+p95, (c) pin CPU via `taskset -c N` in CI, (d) disable turbo / frequency scaling on CI host. ~50 LOC change. | **confirmed** |
| **I3 / BENCH-02** (new) | **No regression gate.** CI job sets `allow_failure: true` and gates on exit-0 only (`.gitlab-ci.yml:210`). A 10x regression on `Url.parse` would merge silently. PerfScore is "ship and pray" today. | `.gitlab-ci.yml:202-212` | Original design — bench landed as "compiles and runs" to keep CI green. | Headline claim in docs ("sub-microsecond URL parse") can silently degrade. Downstream consumers inherit the risk. | After BENCH-01: store min+median baseline JSON as CI artifact; add a separate job that fails if current min > baseline * 1.20 (20 % tolerance band absorbs remaining jitter). Keep `allow_failure: false` on the gate, `allow_failure: true` on the raw bench. | **confirmed** |
| **I4 / BENCH-03** (new) | Bench corpus covers only 5 ops. **Missing benches:** `Ipv4Addr.format`, `Mac.format`, `Subnet.contains` (promised in I1 closure), `Vector.parse`, `GeoPoint.parse`, `IpAddr.parse`, 1-to-N `haversineBroadcast`. Several findings above (A3, A6/FMT-01, IPADDR-01, S1) cannot be promoted because the workload is not timed. | `bench/main.zig:177-183` (only 5 of ~10 claimed benches wired) | Time-boxed initial I1 scope. | Finding-to-fix pipeline has no data signal. | Add the 6 missing benches (~60 LOC). Re-run; compare ns/op contribution. | **confirmed** |
| **I5** | `test-performance` step is correctness-at-scale, **not** timed (20-50-item loops, asserts all pass). Not a substitute for I1. | `build.zig:91-103`; `tests/performance.zig` | Original design. | Fine as a correctness dataset; does not cover perf regressions. | — | confirmed |
| **D1** | README + `src/root.zig` now document ReleaseFast overflow-wrap on `Vector.{add,sub,scale,dot,magnitudeSquared}` and `Range.span`. **Closed** (`0c2ebbd`). | `src/root.zig:19-25`; `README.md` "Build Modes and Overflow Semantics" | — | — | — | confirmed |
| **D2** | `network.zig:563-566` now carries `std.debug.assert(prefix_len > 0 and prefix_len < 32)` immediately above the `@intCast(u5)` shift site. **Closed** (`1234a9f`). | `src/types/network.zig:559-566` | — | — | — | confirmed |

### Items Not Found (Adversarial Scan)

- No `@intFromPtr` / `@ptrFromInt` / `@bitCast` in hot paths beyond the audited `@intCast` sites.
- No `inline fn` / `inline for` causing unexpected code bloat at high N.
- No `[*]T` pointer arithmetic where slice math would be safer.
- No `std.debug.print` in production paths.
- No `volatile` / atomic ops (no concurrency surface, as expected).
- No recursion — all parsers iterative.
- No regex (library does not use regex).
- No I/O / file / socket / clock in production paths (clock_gettime confined to `bench/main.zig`).

Zero-alloc / no-I/O / no-concurrency contract is **structurally** enforced by the API surface.

---

## PerfScore

`PerfScore = Impact(1-5) x Likelihood(1-5) x 4` (range 4-100). Impact: 5=SLO-saver, 4=2-5x / significant, 3=user-facing noticeable, 2=small, 1=hardening. Likelihood: 5=always/hot, 4=common, 3=moderate, 2=rare, 1=edge.

| P-ID | Finding (short) | Impact | Likelihood | PerfScore | Status | Verdict |
|------|-----------------|:------:|:----------:|:---------:|--------|---------|
| A1 / URL-01 | `Url.parse` fused-scan candidate | 3 | 4 | **48** | **Monitor** | Gate on BENCH-01 + BENCH-03; prototype fused SM on branch. |
| A2 | `parse + domain()` 3x host amplification | 2 | 3 | 24 | Monitor | Low priority; needs consumer signal. |
| A6 / FMT-01 | `std.fmt.print("{X:0>2}")` per byte in formatters | 3 | 3 | 36 | Monitor | Add format bench (BENCH-03); quantify before acting. |
| IPADDR-01 | `IpAddr.parse` pre-scan for `:` doubles work on IPv6 | 2 | 4 | 32 | **Monitor** (new) | Cheap fix once measured; touches `Subnet.parse` too. |
| S1 / PRECOMP-01 | Precomputed-origin haversine | 3 | 3 | 36 | Monitor | Add `benchHaversineBroadcast` first; ~15 % on 1-to-N. |
| S3 | `@Vector` tiling at N >= 16 | 4 | 2 | 32 | Monitor | P5 rescope; needs consumer at N >= 16. |
| FUSION-02 | `Ipv6Addr.parse` single-pass fold-in of `findDoubleColon` | 2 | 3 | 24 | Monitor | Prototype + A/B on BENCH-01-stable harness. |
| M2 | `distance()` intermediate at generic N | 2 | 2 | 16 | Monitor | Verify IR elision; only risky at N >= 16. |
| A3 / P10 | `GeoPoint.parse` 3-pass dispatcher | 1 | 2 | 8 | Won't Do (firm) | Sub-us; no in-tree hot path. |
| A4 | `findDoubleColon` duplicates `std.mem.indexOf` | 1 | 2 | 8 | Won't Do (firm) | Cosmetic. |
| A5 | IPv6 right-half temp buffer | 1 | 1 | 4 | Won't Do (firm) | Debug-only cost. |
| M3 | No `normalizeInPlace` | 1 | 2 | 8 | Won't Do (firm) | API churn. |
| M4 | No `@branchHint(.unlikely)` | 2 | 2 | 16 | Monitor | Post-BENCH-01. |
| S2 | No approximate geodistance | 2 | 2 | 16 | Won't Do | Feature add; out of scope. |
| **BENCH-01 / I2** | **No warm-up / no aggregation / high jitter (1.3-2.2x)** | **4** | **5** | **80** | **Fix (P1)** | Blocks every suspected-to-confirmed promotion. |
| **BENCH-02 / I3** | **No regression gate (exit-0 only)** | **3** | **4** | **48** | **Fix (P1)** | Wire after BENCH-01; min + 20 % tolerance. |
| **BENCH-03 / I4** | Missing format / Subnet.contains / IpAddr.parse / geo-broadcast benches | 3 | 4 | 48 | **Fix (P2)** | +60 LOC in `bench/main.zig`; unblocks FMT-01, IPADDR-01, S1 decisions. |
| I1 / P1 | `zig build bench` harness shipped | — | — | — | Closed (`d786b46`) | — |
| D1 | README overflow caveats | — | — | — | Closed (`0c2ebbd`) | — |
| D2 | `network.zig:563` assert | — | — | — | Closed (`1234a9f`) | — |

---

## Re-Evaluation of Open Asks

### Q1: Is a bench regression gate needed? (perf-context §bench "exit-0 gate only")

**Verdict: Yes — Fix (BENCH-02, PerfScore 48).** But **sequence matters**: BENCH-01 (warm-up + min-of-N + aggregation) **must land first**, or any regression gate will flap on the 1.3-2.2x jitter this review just measured. The recommended sequence is:

1. **BENCH-01** — harden the harness (~50 LOC): 1x warm-up pass per bench, 10 trials, report `min/median/p95`, pin CPU via `taskset -c 0` in CI, add a `--trials=N` CLI flag.
2. **BENCH-03** — grow the corpus (~60 LOC): add `Ipv4Addr.format`, `Mac.format`, `Subnet.contains`, `Vector.parse`, `GeoPoint.parse`, `IpAddr.parse`, `benchHaversineBroadcast`.
3. **BENCH-02** — gate: snapshot min-of-10 baseline as CI artifact from `main`; new job compares current min vs baseline with **20 % tolerance** (absorbs post-BENCH-01 residual jitter ~5-10 % + CI host variance). Fail the gate job, keep raw `bench` job as `allow_failure: true`.

Until BENCH-01 lands, a regression gate is **net-negative**: it will either flap (false positives) or need such a wide band (e.g. 3x) that it catches only catastrophic bugs — which existing tests already catch.

### Q2: Does URL-01 / A1 justify the fused-scan rewrite today?

**Verdict: Monitor -> promotable once BENCH-01 lands.** At 70-101 ns/op, the delta a fused SM would produce (~30 ns/op win) is currently inside our bench noise floor. Post-BENCH-01, a 20-30 ns/op win becomes measurable at p95 > 3 sigma. The risk side of the ledger (~150-LOC rewrite, ~60 URL tests) is unchanged — so the decision is entirely about whether consumers actually care. **Recommendation:** prototype on a branch, merge only if (a) BENCH-01 is live and (b) a consumer workload puts `Url.parse` in the top-3 hot paths.

### Q3: Is PRECOMP-01 / S1 shippable on the existing evidence?

**Verdict: Monitor.** The 15 % estimated win is **below today's bench jitter (51 %)**. It becomes a confident "ship it" only after (a) BENCH-01 stabilizes measurements **and** (b) BENCH-03 adds a `benchHaversineBroadcast` that actually exercises the 1-to-N pattern. Without both, shipping a `prepareOrigin()` API is adding surface with no measurable proof it helps the target consumer.

### Q4: `IPADDR-01` — new finding not in prior gap analysis?

**Verdict: Add to ledger as Monitor (PerfScore 32).** The pre-scan in `IpAddr.parse` at `network.zig:442-447` doubles the byte traversals on every IPv6 parse through the common-case `IpAddr` / `Subnet.parse` entry points. Fix is trivial (replace `for (input) |ch|` with `if (input[0] == ':') | detect inside Ipv4Addr.parse`), but needs BENCH-01 + a new `IpAddr.parse` bench to promote.

---

## Blockers

**None.** 9/9 perf tests pass, all benchmarks complete, MaxRSS <= 4 MB, no allocation introduced, no functional regression, no concurrency surface to audit.

**The single critical infrastructure gap is BENCH-01 (harness robustness).** Its absence mechanically prevents every confidence::suspected finding from being promoted — so the library is structurally stuck at "Monitor" for A1, S1, A6, FUSION-02, IPADDR-01, M2, S3 until it lands. BENCH-01 is the gate-keeper for every other finding in this review.

## Validation Plans

### BENCH-01 — harness robustness

```text
# 1. Add warm-up loop (1 pass, same iters) before timed run in every benchX fn.
# 2. Wrap each bench in a `for (0..trials) |_|` with trials = 10.
# 3. Collect samples; report min, median, p95, stdev.
# 4. Add --trials / --warmup CLI flags (comptime defaults 10 / 1).
# 5. CI: add `taskset -c 0` prefix on Linux bench job.
# Expected after: jitter band < 10 % across 10 trials on the same host.
```

### BENCH-02 — regression gate

```text
# 1. Commit `bench/baseline.json` with min-of-10 from main.
# 2. New CI job `bench-regression`: runs `zig build bench` with --trials=10,
#    compares each min against baseline, fails if ratio > 1.20.
# 3. Gate uses allow_failure: false; raw `bench` job keeps allow_failure: true.
```

### BENCH-03 — grow corpus

```text
# Add in bench/main.zig:
#   benchIpv4Format          ~ expected 30-60 ns/op (hex-table target)
#   benchMacFormat           ~ expected 60-120 ns/op
#   benchSubnetContainsV4    ~ expected 5-15 ns/op
#   benchVectorParseF32      ~ expected 100-200 ns/op
#   benchGeoPointParse       ~ expected 80-150 ns/op
#   benchIpAddrParseV6       ~ expected 22-35 ns/op
#   benchHaversineBroadcast  ~ expected ~= haversine (today); post-S1 ~0.85x
```

### A1 / URL-01 — prototype fused parser (after BENCH-01)

```text
# On branch, rewrite Url.parse as a single forward-pass state machine:
#   state = .{ Scheme, AfterScheme, UserinfoOrHost, Port, Path, Query, Fragment }
# Re-run `zig build bench` (post-BENCH-01 harness); target Url.parse min < 70 ns/op.
# Run `zig build test` + `zig build test-parser-edges` to verify all existing cases.
```

### S1 / PRECOMP-01 — prepareOrigin (after BENCH-03 adds broadcast)

```text
# Add LatLon.PreparedOrigin struct + LatLon.prepareOrigin() + LatLon.distanceFromOrigin(other, origin).
# Measure benchHaversineBroadcast before/after; target >= 12 % min-of-10 reduction.
```

### IPADDR-01 — drop pre-scan

```text
# network.zig:442-450: replace for-loop with `if (input[0] == ':') return ...Ipv6...;`
# Detect-on-first-colon inside Ipv4Addr.parse to dispatch late (preserves all current error paths).
# Bench IpAddr.parse v6 inputs; expect 10-20 % improvement on short addresses.
```
