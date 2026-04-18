# Performance Review — Phase 3 (Deep Analysis)

**Repo:** `/home/benji/src/devnw/zig/advanced-types`
**Date:** 2026-04-18
**Scope:** All `src/types/*.zig` (~3,374 LOC) against branch prediction, cache behaviour, allocator discipline, and the specific re-evaluations raised by phase-2 handoff.

The library has **no I/O and no concurrency surface** — consumers embed it on hot paths. Every finding below is therefore CPU-bound and/or doc-surface.

---

## Inputs From Phase 2 (Accepted as Evidence)

- Zero heap allocations confirmed by ripgrep of `alloc(`, `dupe(`, `ArrayList`, `std.heap` across `src/` (zero matches). See `docs/audit/perf-scan.md:13-18`.
- `Url.parse` does **6** linear scans in the common case (not 5). `parse + domain()` scans the `host` slice **3 more times** (`looksLikeIpv4` + `Domain.parse` main loop + `validateLabel` per-label).
- `GeoPoint.parse` is a **3-pass** dispatcher (`trim` + `std.mem.count` + dispatchee's own `trim + indexOfScalar`).
- `Ipv6Addr.findDoubleColon` is a hand-rolled `std.mem.indexOf(u8, input, "::")`.
- `network.zig:469` `@intCast(u5)` is safe only via two earlier early-returns — non-local invariant.
- Integer-overflow semantics on `Vector.{add,sub,scale,dot,magnitudeSquared}` and `Range.span` diverge between Debug/ReleaseSafe (panic) and ReleaseFast/ReleaseSmall (wrap). Per-function doc comments exist; **no README/root.zig note**.
- No `bench` step exists in `build.zig`.

Static review of each source file corroborates every claim above.

---

## Manual Performance Review

### Algorithms & Data Structures

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| A1 | `Url.parse` does 6 linear scans over small slices (scheme `://`, scheme char-class, `#`, `?`, `/`, authority `]` or `:`). Each scan is over a shrinking suffix; working-set stays in L1 so cost is **branch-mispredict-bound**, not memory-bound. | `src/types/url.zig:165,169-173,181,188,197,214,224` | Historical parser style: split-then-dispatch. A single forward-pass state machine (similar to `Ipv4Addr.parse`) would halve branch count. | On typical <2KB URLs total work is ~ input length; for a reverse-proxy consumer parsing millions/sec this is the hot path. Estimated win from fused scan: 20-40% parse-time reduction at best. | Add `zig build bench` (see I1) with a 10^6-iteration `Url.parse` micro-bench; measure ns/op on a representative URL mix; reimplement as single-pass on a branch; compare. | **P2** | confirmed (scans), suspected (delta without numbers) |
| A2 | `parse + domain()` downstream amplification: `looksLikeIpv4` scans the whole host, then `Domain.parse` does a full char-class scan, then `validateLabel` walks each label. 3x host scan on top of `Url.parse`'s 6. | `src/types/url.zig:259-265,302-308,41-62,102-110` | `domain()` is a post-processing helper that re-discovers facts `parse()` already knew (host has/hasn't bracketed IPv6, is/isn't all-digits-and-dots). `parse()` could set two bool flags (`is_ipv6_literal`, `might_be_ipv4`) inline during its existing scan of the authority; `domain()` would become O(1) dispatch. | Only matters for consumers that call both on every request. 3x host scan ~ 3x tens-of-ns per short host, so per-request cost is still <1 us. Credible win in a URL-heavy proxy. | Bench `parse + domain()` vs `parse` alone on a realistic mix; decide if 10-30% saving justifies the extra fields in `Url`. | **P3** | confirmed (structure), suspected (delta) |
| A3 | `GeoPoint.parse` is 3-pass: `trim` (scan 1) -> `std.mem.count` (scan 2) -> `LatLon.parse` / `LatLonAlt.parse` which **re-trim the original `input`** and re-scan for commas (scan 3 + 4). | `src/types/geographic.zig:285-299,106-128,176-207` | Dispatcher passes the **un-stripped `input`** to dispatchees rather than the already-trimmed `inner`. Cheap fix: `find first comma`; if a second comma exists in the remainder dispatch as 3D, else 2D — eliminates `std.mem.count` entirely, and pass `inner` directly so the dispatchees don't re-trim. | For ~30-byte inputs, parse is still sub-microsecond. Noticeable only at millions of parses/second (e.g., bulk ingest). | Add geo parse bench under I1; compare 3-pass vs single-pass on a 10k string fixture. | **P3** | confirmed |
| A4 | `Ipv6Addr.findDoubleColon` duplicates `std.mem.indexOf(u8, input, "::")`. Hand-rolled loop is O(n) with no SIMD-ready pattern; `std.mem.indexOf` on length-2 needle typically dispatches to a SWAR/vector-friendly scan. | `src/types/network.zig:236-244` | Premature specialization without measurement. | Single-call-per-parse, so at most tens of ns saved per IPv6 parse. Cosmetic/idiomatic, not a measurable perf issue. | `zig build test-performance` before/after replacement; microbench under I1. | **P3** | confirmed |
| A5 | `Ipv6Addr.parse` right-half copy uses a stack buffer `right_octets: [16]u8 = .{0}**16` + an explicit `for (0..right_count*2)` copy into `octets`. In Debug/ReleaseSafe the zero-init is real work; ReleaseFast should elide. `std.mem.copyForwards` + pre-sized slice would express intent more cleanly. | `src/types/network.zig:213-223` | Straightforward parse-then-shift implementation. Could parse the right half into a temp count, then run a second pass writing into the final `octets` slot directly — no intermediate buffer. | Micro; only in Debug/ReleaseSafe where users are not performance-sensitive. | Profile IPv6 parse in Debug to confirm; not worth chasing. | **P3** | suspected |
| A6 | `std.fmt.print("{X:0>2}", ...)` per byte in `Ipv4Addr.format` and `Mac.format` goes through the full `std.fmt` machinery 4/6 times. A hand-rolled hex-nibble table would be ~10x faster. | `src/types/network.zig:113-120,565-570` | Formatter convenience. `std.fmt` is a branch-dense state machine per format-spec parse, and the spec is constant here. | On a logging hot-path (one `format` per log record) this is often the #1 cost of the whole type — stdlib-wide known weakness. Savings per call likely 50-100ns. | Bench `fmt.bufPrint(&buf, "{f}", .{ip})` 10^6 times; compare against a manual `writeByte(hex_hi) writeByte(hex_lo)` version. | **P2** | suspected (standard pattern; needs numbers) |

### Memory & GC

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| M1 | Zero heap allocations — verified structurally. No `Allocator` parameter on any public API. `Url`/`Domain` return slices into caller's input, so lifetime is the caller's problem (documented in perf-context). | all `src/types/*.zig` | Design goal. | None. Claim holds. | — | — | confirmed |
| M2 | `Vector.sub().magnitude()` in `distance()` materializes an intermediate `[N]T`. P6 claims compiler elides at N=3 in ReleaseFast — unverified without benchmark or LLVM IR inspection. | `src/types/vector.zig:166-169` | Expression `self.sub(other).magnitude()` returns a by-value `Self` whose `.data` is only read, then discarded. Zig semantics permit this to stay in registers for tiny N. | For `Vector(f32,3)` the intermediate is 12 bytes — not a cache issue; risk is only if a generic user picks `Vector(f32, 128)` where the array is 512 B per temp. | Emit LLVM IR (`zig build-obj --emit=llvm-ir -OReleaseFast`) on a trivial caller and confirm the intermediate is elided. | **P3** | suspected |
| M3 | `Vector.normalize` returns a full new `Self` even for a hot-path normalize-in-place use case. Library has no "fill-into" variant. | `src/types/vector.zig:158-163` | API choice (immutability). | At N=3 the copy is 12 bytes and LLVM likely keeps it in regs. At larger N this becomes a real cost; API escape hatch (`*Self.normalizeInPlace`) missing. | Bench `normalize` at N=128; note only if Geode uses generic `Vector(T, N>=16)`. | **P3** | suspected |
| M4 | No `@branchHint` / `@prefetch` / cold/hot tagging on any error path. Error returns are control-flow-dense (`ParseError.InvalidFormat` etc.) and in hot parsers these are the **minority** outcome; marking them `@branchHint(.unlikely)` would help I-cache/branch-pred on x86-64. | `network.zig:78,87,88,96,99,104,105,106, url.zig:166,168,171,215,219,220, ...` (every `return error.*` in hot parsers) | Library is idiomatic Zig 0.15/0.16; `@branchHint` is newer and optional. | Marginal; compilers already assume error returns are cold via static branch prediction hints in many cases. But with LTO off this is unreliable. | LLVM-MCA or `perf stat -e branch-misses` before/after on the parse bench under I1. | **P3** | suspected |

### I/O & Network

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| — | **N/A — library has no I/O surface.** | — | — | — | — | — | — |

### Concurrency

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| — | **N/A — library has no threading, no globals, no mutexes.** All types are value types; `Vector.*.localhost`/`.any`/`.broadcast` constants are comptime-evaluated and immutable. Safe to share across threads. | — | — | — | — | — | confirmed |

### Pipelining & Streaming

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| S1 | **No batched geodistance API.** `LatLon.haversineDistance` is 7 transcendentals per call (2x`@sin`, 2x`@cos`, 2x`@sqrt`, 1x`atan2` — phase-2 corrects P9 from "6" to "7"). Fixed-origin 1-to-many sweeps (a common Geode pattern) could precompute `@sin(lat1)` / `@cos(lat1)` once and drop ~2 trig ops per call. | `src/types/geographic.zig:75-92` | API exposes only the 2-point form. | For a 10k-point nearest-neighbour sweep at ~200-300 cycles per pair, that's ~2.5M cycles — a precomputed-origin API shaves ~40 cycles x 10k = 400k cycles (~15%). Worth it only for bulk consumers. | Add a `LatLon.haversineDistanceTo(other)` with an `originSinCosCache` precomputed by a new `LatLon.prepareOrigin()` helper; bench a 10k sweep. | **P2** | suspected |
| S2 | No approximate-distance variant (equirectangular ~ 2 trig; spherical-law-of-cosines ~ 3 trig). For coarse filtering (bounding-box pre-filter before exact haversine) these are 3-5x faster. | `src/types/geographic.zig:*` | Out of current scope; P9 said "mathematically unavoidable" but that's only true for the exact great-circle formula. | Relevant only if a consumer needs bulk proximity filtering. | Feature add, not a bug — bench would quantify the tradeoff. | **P3** | suspected |
| S3 | `Vector.cosineDistance` at N=3 is already fused (P3 closed). At larger N (`Vector(f32, 384)` etc.) the hand loop auto-vectorizes under ReleaseFast but not optimally (unroll factor, FMA usage). P5 scoped SIMD out at N=3; **re-scope to reconsider at N >= 16.** | `src/types/vector.zig:175-189` | No generic SIMD path. | Embedding-sized vectors (common in Geode-style consumers) leave ~30-50% perf on the floor vs `@Vector(16, f32)`-tiled loops. | LLVM-MCA + `perf stat` on a `Vector(f32, 384)` `cosineDistance` in ReleaseFast. | **P2** (if consumer uses N>=16) / **P3** (current docs imply N=3 only) | suspected |

### Infrastructure & CI

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| I1 | **No benchmark suite.** `build.zig` has no `bench` step. Every "Won't Do" in `PERF_GAP_ANALYSIS.md` (P5/P7/P9/P10) rests on "trust the compiler" with zero numerical evidence. A single LLVM regression (auto-vectorization loss on a toolchain bump — has happened historically in Zig) would silently regress the library and no one would notice. | `build.zig:6-115` (absence); `PERF_GAP_ANALYSIS.md:13-18` | Declined as P1 "significant new work." A minimal `bench.zig` using `std.time.Timer` is ~150 LOC. | Without ns/op numbers the "called on hot paths" positioning has no floor. Adding bench closes this without committing to SLOs. | Add `bench/bench.zig` with `std.time.Timer`-based micro-benches for: `Ipv4Addr.parse`, `Ipv6Addr.parse`, `Url.parse`, `Subnet.contains`, `Vector.cosineDistance` (f32 N=3 and N=128), `LatLon.haversineDistance`, `GeoPoint.parse`. Add `zig build bench` step. Gate CI on "compiles and runs" only, not on absolute numbers. | **P1** | confirmed |
| I2 | `test-performance` step is correctness-at-scale, not timed. `tests/performance.zig` runs 20-50-item loops and asserts all-pass; no ns/op signal. | `build.zig:74-87`; `tests/performance.zig` | Original design — perf tests double as dataset-level correctness coverage. | Fine for what it is; does not substitute for I1. | — | **P3** (documentation) | confirmed |
| I3 | **No observability / regression-detection harness.** Even with I1 in place, CI needs a way to detect drift (e.g., `perf-delta.yml` that compares current bench to a baseline from `main` with a 20% tolerance). | `.gitlab-ci.yml` (absent) | Out of scope for first bench iteration. | Low-priority follow-up to I1. | Add after I1 ships; store baseline as an artifact. | **P3** | confirmed (absence) |
| I4 | CI tests Debug/ReleaseSafe/ReleaseFast/ReleaseSmall (P2 closed) — **good coverage** of the overflow-semantic divergence. | `.gitlab-ci.yml` per P2 closure | — | — | — | — | confirmed |

### Documentation / Contract (Non-Functional)

| # | Finding | File:Line | Root Cause | Impact | How to Verify | Severity | Confidence |
|---|---------|-----------|------------|--------|---------------|----------|------------|
| D1 | **Integer-overflow semantic divergence is not documented at module/README level.** Per-function doc comments exist (`vector.zig:105,114,123,132`; `range.zig:82-84`). `README.md` has no `Release*` / `overflow` mention (confirmed via grep — zero matches). A consumer who pins to ReleaseFast for Geode-scale embedding workloads will get silent wrap-around on `VectorI32.add` / `Range(i64).span` without ever opening the specific file. | `README.md` (absent); `src/root.zig:1-22` (doc comment, no caveat) | Per-function docs were judged sufficient; NFR was never surfaced at the contract level. | **Correctness-adjacent performance NFR** — users who choose ReleaseFast for speed get a semantic change with no warning. For a library explicitly sold as "called on hot paths" this is a trap. | Add ~5-line "Release-mode caveats" section to README; add a `//!` block in `src/root.zig` linking to the affected functions. No code change. | **P1** (NFR surface) | confirmed |
| D2 | `network.zig:469` `@intCast(u5)` safety depends on two earlier early-returns (`prefix_len == 0` -> return true; `prefix_len >= 32` -> return `net4.eql(addr4)`). Any future refactor that reorders or replaces those early-returns converts a safe cast into a ReleaseSafe panic / ReleaseFast UB. | `src/types/network.zig:466-469` | Style: inline branches instead of extracted invariants. | Latent landmine; not currently triggerable. | Add `std.debug.assert(self.prefix_len > 0 and self.prefix_len < 32);` on `network.zig:468`. Ten-second fix, catches any future regression in ReleaseSafe/Debug. | **P2** | confirmed |

---

## Re-Evaluation of Phase 2 Asks

### Q1: Should the library ship a bench harness? (P1 revisit)

**Verdict: Yes — fix.**

Cost: ~150 LOC single file + one `build.zig` step. Zero new deps. Runs in ms.

Benefit:

1. Defends every "trust the compiler" Won't-Do (P5/P7/P9/P10) against Zig toolchain regressions.
2. Gives the library one ns/op number to stand behind in docs — closes credibility gap for a library positioned as "hot-path."
3. Unblocks future P7 / P9 "fuse scan / precompute origin" work by making it measurable.
4. Low ongoing cost: gate CI on "runs and prints," not on numeric thresholds, so zero flakiness.

The P1 "significant new work" argument held when the library had zero perf claims. It no longer holds once claims like "sub-microsecond URL parse," "auto-vectorized at N=3," "single-pass cosine" appear in docs. **Re-open P1 -> Accepted.**

### Q2: Does integer-overflow semantic divergence deserve a README/root.zig NFR note?

**Verdict: Yes — fix (doc-only).**

The affected surface spans two modules (`Vector`, `Range`) and six public functions (`add`, `sub`, `scale`, `dot`, `magnitudeSquared`, `Range.span`). Per-function doc comments are necessary but insufficient for a contract-level NFR: consumers who pick a build mode do so at the library selection stage, not the function selection stage. A 5-line "Release-mode caveats" section in `README.md` + a cross-ref paragraph in `src/root.zig` (which is the first thing `@import("advanced_types")` shows in docs) closes this for zero code risk.

### Q3: `network.zig:469` assert recommendation

**Verdict: Accept — fix.**

The `@intCast(u5)` at line 469 is currently safe only because two earlier early-returns (`prefix_len == 0` and `prefix_len >= 32`) bracket the value. That invariant is **implicit and non-local**. One inline `std.debug.assert` on the line above the cast is zero-cost in ReleaseFast and converts a latent landmine into a Debug/ReleaseSafe panic at the exact moment of any future regression.

### Q4: 3-pass `GeoPoint.parse` and 6-scan `Url.parse` — refactor or accept?

**Verdict: Accept both as-is; monitor.**

- **`GeoPoint.parse` 3-pass:** A clean single-pass rewrite (find-first-comma, find-second-comma-in-remainder) is a 20-line change and objectively better. But `GeoPoint.parse` isn't called on known hot paths in-tree, and the existing impl is correct. **Won't Do** for this audit — revisit if bench (I1) shows it in the top 5.
- **`Url.parse` 6-scan:** Same reasoning. 6 scans over a shrinking suffix <2KB is tens of ns. A fused state-machine rewrite is a ~150-LOC change with real regression risk (`Url.parse` has ~30 test cases). **Won't Do** until the `parse + domain()` combination (A2) is measured on a real consumer workload.

Keep both visible in the ledger as **monitor** items, not closed. Wire bench (I1) so future data can promote them.

---

## Summary Table — New & Revised Findings

| ID | Finding | PerfSeverity | Verdict | Cost |
|----|---------|--------------|---------|------|
| A1 | `Url.parse` 6-scan (fused-scan candidate) | **P2** | Monitor (gate on I1 data) | Medium (~150 LOC + retest) |
| A2 | `parse + domain()` 3x host amplification | **P3** | Monitor | Low-Medium (add cached flags) |
| A3 | `GeoPoint.parse` 3-pass dispatcher | **P3** | Monitor (low call volume in-tree) | Low |
| A4 | `findDoubleColon` duplicates `std.mem.indexOf` | **P3** | Won't Do (cosmetic) | Trivial but noisy in diff |
| A5 | IPv6 right-half temp copy | **P3** | Won't Do | Low, not worth risk |
| A6 | `std.fmt.print("{X:0>2}")` per byte in formatters | **P2** | Monitor (quantify under I1) | Medium |
| M2 | `distance()` intermediate at generic N | **P3** | Monitor | Requires API-shape decision |
| M3 | No `normalizeInPlace` | **P3** | Won't Do | API churn |
| M4 | No `@branchHint(.unlikely)` on error paths | **P3** | Monitor | Low after I1 lands |
| S1 | No precomputed-origin haversine | **P2** | Monitor (consumer-workload-dependent) | Medium (new API) |
| S2 | No approximate geodistance | **P3** | Won't Do (scope) | New API surface |
| S3 | No `@Vector` SIMD at N>=16 (P5 rescope) | **P2** (if N>=16) | Monitor | Large if Geode hits it |
| I1 | No `zig build bench` | **P1** | **Fix (re-open P1)** | ~150 LOC / one new file |
| I3 | No perf regression gate in CI | **P3** | Follow-up to I1 | Low |
| D1 | ReleaseFast overflow-wrap not in README/root.zig | **P1** | **Fix (doc only)** | ~10 LOC |
| D2 | `network.zig:469` non-local invariant | **P2** | **Fix (add inline assert)** | 1 LOC |

---

## What Would Promote Any "Monitor" to "Fix"

Each Monitor verdict has one explicit gate:

- **A1, A2** -> I1 bench shows `Url.parse` in the top 5 hot paths for a realistic URL-heavy workload.
- **A6** -> I1 bench shows `Ipv4Addr.format` / `Mac.format` >5% of a logging workload.
- **M2** -> Consumer instantiates `Vector(T, N)` with `N >= 16`.
- **M4** -> `perf stat -e branch-misses` on the parse bench shows >5% miss rate on the error paths.
- **S1, S3** -> Geode (or equivalent consumer) commits to 1-to-many geo sweeps / embedding-sized vectors.

Without I1 (bench harness), **none of these can be promoted** — which is itself the core argument for doing I1 first.

---

## Validation Plans (Per P0/P1 Finding)

### I1 — Bench harness

```text
# 1. Add bench/bench.zig using std.time.Timer, measure 10^6 iterations of
#    each hot function. Keep under 150 LOC.
# 2. Add `zig build bench` step in build.zig (non-default).
# 3. CI: zig build bench -Doptimize=ReleaseFast  (success = exit 0).
# 4. Local baseline:
zig build bench -Doptimize=ReleaseFast --summary all
# Expected output (order-of-magnitude):
#   Ipv4Addr.parse:       ~20 ns/op
#   Ipv6Addr.parse:       ~60 ns/op
#   Url.parse:           ~100 ns/op
#   Vector.cosineDistance(f32,3):  ~5 ns/op
#   LatLon.haversineDistance:      ~25 ns/op  (dominated by atan2)
```

### D1 — README/root.zig overflow note

No validation bench — it's a doc change. Validation is a reviewer confirming the note references all six affected functions and both affected optimize modes.

### D2 — `network.zig:469` assert

```text
zig build test -Doptimize=Debug
zig build test -Doptimize=ReleaseSafe
zig build test -Doptimize=ReleaseFast
zig build test -Doptimize=ReleaseSmall
# Expected: all 233+ tests still pass in every mode.
# Hand-check: invariant holds for Subnet.parse output (prefix_len in [1,31] at 469).
```

---

## Appendix — Items Not Found

Adversarial scan checked for and did **not** find:

- Any `@intFromPtr` / `@ptrFromInt` / `@bitCast` in hot paths beyond the 17 audited `@intCast` sites.
- Any `inline fn` / `inline for` / `inline while` that would cause unexpected code bloat at high N.
- Any `[*]T` / C-style pointer arithmetic where slice math would be safer.
- Any `std.debug.print` in production paths.
- Any `volatile` / atomic ops (no concurrency surface — as expected).
- Any recursion (all parsers and math ops are iterative).
- Any regex (the library doesn't use regex at all — good, avoids catastrophic backtracking class of bugs outright).
- Any I/O, file, socket, clock calls in production paths.

The zero-alloc / no-I/O / no-concurrency contract is **structurally** enforced by the API surface.
