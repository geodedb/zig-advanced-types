# Performance Gap Analysis

Last updated: 2026-04-18

## Findings

| # | Finding | PerfSeverity | PerfScore | Status | Evidence | Issue | Resolution |
|---|---------|--------------|-----------|--------|----------|-------|-----------|
| P1 | No benchmark suite exists (`zig build bench`) | P1 | 80 | **Closed 2026-04-18** (d786b46) | `build.zig:6-115` (absence); `docs/audit/perf-review.md:71,87-100`; `bench/main.zig` | [#29](https://gitlab.com/devnw/zig/advanced-types/-/work_items/29) | `zig build bench` harness landed (~150 LOC, 5 benchmarks covering Ipv4/Ipv6/Url/Subnet/Vector/LatLon). Unblocks every Monitor-gated item below. |
| P2 | CI lacks ReleaseFast test target | P1 | — | **Closed** | — | — | Added `test-release-fast` job to `.gitlab-ci.yml`. |
| P3 | `cosineDistance` makes 3 independent O(N) passes | P2 | — | **Closed** | — | — | Fused into single-pass loop in `vector.zig`. |
| P4 | CI installs Zig in every job (~2.5 min wasted) | P2 | — | **Won't Do** | — | — | Requires custom Docker image; out of scope. |
| P5 | No `@Vector` SIMD intrinsics | P2 | — | **Won't Do (re-scope pending I1)** | — | — | Compiler auto-vectorizes at N=3. Phase-3 flagged a rescope candidate (S3) for N>=16 consumer workloads — gated on I1. |
| P6 | `distance()` creates unnecessary intermediate array | P3 | — | **Won't Do** | — | — | Compiler elides at N=3 in ReleaseFast (suspected; unverified without I1). |
| P7 | `Url.parse` multi-pass (**6** scans, corrected from 5) | P3 | — | **Won't Do (count corrected)** | `src/types/url.zig:165,169-173,181,188,197,214,224` | — | Sub-microsecond for typical URLs. Phase-3 corrected the scan count: `parse` itself does 6 scans (scheme `://`, scheme char-class, `#`, `?`, `/`, authority `]`-or-`:`). See A1 below for the Monitor-tracked follow-up and A2 for the downstream 3x host amplification via `domain()`. |
| P8 | `VectorF32` hardcodes N=3 (SIMD alignment) | P3 | — | **Won't Do** | — | — | Design choice; 3D spatial vector is semantically correct. |
| P9 | Haversine uses **7** transcendental calls (corrected from 6) | P3 | — | **Won't Do (count corrected)** | `src/types/geographic.zig:75-92` | — | 2x`@sin` + 2x`@cos` + 2x`@sqrt` + 1x`atan2` = 7 ops. Phase-3 corrected the count; `atan2` was previously omitted. Mathematically unavoidable for the exact great-circle form. See S1 for the precomputed-origin Monitor follow-up. |
| P10 | `GeoPoint.parse` re-parses input | P3 | — | **Won't Do** | — | — | Negligible for ~30 byte inputs. See A3 below — firmly Won't Do after phase-3 review. |
| I1 | No `zig build bench` harness (duplicates P1 re-open) | P1 | 80 | **Closed 2026-04-18** (d786b46) | `build.zig:6-115`; `docs/audit/perf-review.md:71,164-179`; `bench/main.zig` | [#29](https://gitlab.com/devnw/zig/advanced-types/-/work_items/29) | `bench/main.zig` ships with 5 benchmarks covering Ipv4/Ipv6/Url/Subnet/Vector/LatLon/GeoPoint. CI gates on exit-0 only. |
| D1 | ReleaseFast overflow-wrap not in README / root.zig | P1 | 48 | **Closed 2026-04-18** (0c2ebbd) | `README.md` (Release-mode caveats section); `src/root.zig:1-22`; `docs/audit/perf-review.md:80,102-106` | [#33](https://gitlab.com/devnw/zig/advanced-types/-/work_items/33) | "Release-mode caveats" section added to README covering `Vector.{add,sub,scale,dot,magnitudeSquared}` + `Range.span`; `//!` cross-ref in `src/root.zig`. |
| D2 | `network.zig:469` non-local `@intCast(u5)` invariant | P2 | 24 | **Closed 2026-04-18** (1234a9f) | `src/types/network.zig:563` (assert) + `:564` (shift site); `docs/audit/perf-review.md:81,108-112` | [#36](https://gitlab.com/devnw/zig/advanced-types/-/work_items/36) | `std.debug.assert(prefix_len > 0 and prefix_len < 32)` inserted immediately above the `@intCast(u5)` shift site; zero ReleaseFast cost. |
| A1 | `Url.parse` 6-scan (fused-scan candidate) | P2 | 40 | **Monitor** (duplicates P7) | `src/types/url.zig:165,169-173,181,188,197,214,224` | — | Gate: promote to Fix if I1 bench shows `Url.parse` in top-5 hot paths on a realistic URL-heavy workload. Fused state-machine rewrite is ~150 LOC with regression risk on ~30 Url tests. |
| S1 | No precomputed-origin haversine for 1-to-many sweeps | P2 | 32 | **Monitor** | `src/types/geographic.zig:75-92` | — | Gate: promote to Fix if Geode (or equivalent consumer) commits to bulk 1-to-many geo sweeps. Estimated ~15% win on 10k-point sweeps via `prepareOrigin()` caching `@sin(lat1)` / `@cos(lat1)`. |
| A3 | `GeoPoint.parse` 3-pass dispatcher | P3 | — | **Won't Do (firm)** | `src/types/geographic.zig:285-299,106-128,176-207` | — | Sub-microsecond for ~30-byte inputs; not called on in-tree hot paths. Duplicate of P10 scope; confirmed Won't Do after phase-3 review. |
| A4 | `findDoubleColon` duplicates `std.mem.indexOf` | P3 | — | **Won't Do (firm)** | `src/types/network.zig:236-244` | — | Cosmetic; single call per IPv6 parse, tens of ns at most. |
| A5 | `Ipv6Addr.parse` right-half temp stack buffer | P3 | — | **Won't Do (firm)** | `src/types/network.zig:213-223` | — | Debug/ReleaseSafe-only cost; ReleaseFast elides the zero-init. Not worth refactor risk. |
| M3 | No `Vector.normalizeInPlace` variant | P3 | — | **Won't Do (firm)** | `src/types/vector.zig:158-163` | — | API churn for a 12-byte copy at N=3 that LLVM likely keeps in registers. No consumer signal. |
| S2 | No approximate (equirectangular / sph-law-cos) geodistance | P3 | — | **Won't Do (firm)** | `src/types/geographic.zig:*` | — | Feature add, not a bug. Out of audit scope; revisit only on explicit consumer ask. |

## PerfScore Methodology

`PerfScore = Impact(1-5) x Likelihood(1-5) x 4` (range 4-100).

Impact scale: 5 = SLO-saver / 10x potential; 4 = 2-5x or significant cost; 3 = noticeable user-facing; 2 = small; 1 = hardening.
Likelihood scale: 5 = always / hot path; 4 = common; 3 = moderate; 2 = rare; 1 = edge.

## Roadmap

### Quick wins (< 1 day)

- **D2** — 1-line `std.debug.assert` at `network.zig:469`. Validation via existing `zig build test` matrix.
- **D1** — ~10-LOC doc addition to README + `src/root.zig`. No bench impact.

### Medium (1-5 days)

- **I1** — `bench/bench.zig` (~150 LOC) + `build.zig` step + optional CI gate. Unblocks A1/A2/A6/M2/M4/S1/S3 promotion decisions.

### Strategic (> 5 days, gated on I1 data)

- **A1** — Fused single-pass `Url.parse` state machine (if bench shows top-5 hot path).
- **S1** — Precomputed-origin `LatLon.haversineDistanceTo` API (if consumer commits to bulk sweeps).
- **S3 / P5 rescope** — `@Vector(16, f32)`-tiled cosine distance (if consumer uses N>=16).

## Summary

| Status | Count |
|--------|-------|
| Closed | 6 (P2, P3, P1/I1, D1, D2) |
| Monitor | 2 (A1, S1) — gated on I1 bench data now that harness exists |
| Won't Do | 10 (P4, P5, P6, P7, P8, P9, P10, A3, A4, A5, M3, S2) |
| **Total tracked** | **15 unique + re-open** |

Top-5 open risks by PerfScore (post-2026-04-18 closure):

1. **A1 — `Url.parse` 6-scan (40)** — Monitor, now decision-ready (I1 bench harness live).
2. **S1 — Precomputed-origin haversine (32)** — Monitor, gated on consumer workload.

All other top-risk items (P1, I1, D1, D2) closed via commits d786b46, 0c2ebbd, 1234a9f on 2026-04-18.

## Notes From Phase 3 / Phase 4

- **P7 scan count corrected** 5 -> 6 (authority `]`-or-`:` scan was previously uncounted).
- **P9 trig count corrected** 6 -> 7 (`atan2` was previously omitted).
- **P1 re-opened.** Phase-3 verdict: the "significant new work" argument no longer holds once the library ships hot-path claims in docs. Tracked as both P1 (re-open) and I1 (new finding) — same GitLab issue ([#29](https://gitlab.com/devnw/zig/advanced-types/-/work_items/29)).
- **A3 / A4 / A5 / M3 / S2 firmly Won't Do** per phase-3 review; recorded for audit traceability only.
