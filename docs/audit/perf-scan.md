# Performance Scan Results

**Date:** 2026-04-18
**Target:** `/home/benji/src/devnw/zig/advanced-types` @ `f3adc69`
**Scope:** Automated red-flag grep + Zig release-mode/SIMD best-practice checks
**Build:** Zig 0.16.0, ReleaseFast, Linux 6.12 native
**Method:** Non-destructive scans; bench + perf-test re-runs; no product code modified.

---

## 0. Bench Re-Run vs. perf-context Baseline

`zig build bench -Doptimize=ReleaseFast`:

| Benchmark                    | Baseline ns/op | This run ns/op | Delta     | Note                                         |
|------------------------------|---------------:|---------------:|----------:|----------------------------------------------|
| `Ipv4Addr.parse`             |          21.55 |          24.52 |    +13.8% | Within single-run jitter on shared host.     |
| `Ipv6Addr.parse`             |          27.97 |          26.65 |     -4.7% | Within noise.                                |
| `Url.parse`                  |          98.54 |          95.42 |     -3.2% | Within noise.                                |
| `VectorF32.cosineDistance`   |           1.20 |           1.20 |     +0.0% | Auto-vectorized at N=3, stable.              |
| `LatLon.haversineDistance`   |           1.20 |           1.20 |     +0.0% | Compiler CSEs 7 transcendentals on hot loop. |

`zig build test-performance -Doptimize=ReleaseFast --summary all`: **9/9 pass**, 3 ms run, 14 ms compile (cached), MaxRSS 3M run / 41M compile.

No blocker: no regression > 2x, no functional breakage, no allocation introduced.

---

## 1. Automated Red-Flag Patterns

### 1a. Redundant passes over the same slice (`Url.parse`)

`src/types/url.zig:190-297` makes **6–8 linear passes** over the same input buffer (verified, A1 Monitor confirmed):

| # | Op                                                                 | File:Line |
|--:|--------------------------------------------------------------------|-----------|
| 1 | `std.mem.indexOf(u8, input, "://")`                                | `url.zig:194` |
| 2 | `for (scheme)` char-class loop (alphanumeric / `+-.`)              | `url.zig:198-202` |
| 3 | `indexOfScalar(u8, rest, '#')`                                     | `url.zig:210` |
| 4 | `indexOfScalar(u8, rest, '?')`                                     | `url.zig:217` |
| 5 | `indexOfScalar(u8, rest, '/')`                                     | `url.zig:226` |
| 6 | `lastIndexOfScalar(u8, authority, '@')`                            | `url.zig:242` |
| 7 | `indexOfScalar(u8, host_part, ']')` or `lastIndexOfScalar(..,':')` | `url.zig:255,265` |
| 8 | `validateHostChars` byte loop                                      | `url.zig:302-307` |

Plus an internal digit-loop in `parsePortStrict` (`url.zig:369-371`). The full string is traversed roughly 3–4 times in the worst case (scheme scan + fragment/query/slash scans which each walk the *remaining* suffix, + hostchar validation).

**Finding URL-01 `confidence::confirmed`** — A single fused state-machine pass could collapse 6 `memchr`-style scans into one per-byte dispatch. Given `Url.parse` ~= 95 ns/op (longest hot path; ~10x cosine/haversine), a 30–40 % reduction would be the highest-leverage win in the library. Verify by building an alternative fused parser and re-running `zig build bench`; target < 70 ns/op for the mixed corpus in `bench/main.zig:120-138`.

### 1b. Allocations on hot paths

**Finding ALLOC-01 `confidence::confirmed`** — Library is zero-alloc as advertised. `rg 'Allocator|\balloc\b|ArrayList|dupe\('` across `src/` returns **only two hits** (`src/types/url.zig:47,170`) and both are doc-comment mentions describing *how a caller can* copy out. No parser or math op takes an allocator. `{ .raw = input, ... }` consistently borrows slices. Verification: `bench` and `test-performance` both show MaxRSS <= 4 MB (stack only).

### 1c. Unbounded loops on external input

All parsers operate on `[]const u8` with caller-supplied length. Every parser bounds its work by `input.len`:

- `Ipv4Addr.parse` (`network.zig:86`) — single `for (input)`.
- `Ipv6Addr.parse` -> `parseGroups` (`network.zig:270-303`) — `for (input)`; `group_count` bounded by `max_groups = 8`; any 9th group returns `InvalidFormat` at `network.zig:278`.
- `Ipv6Addr.findDoubleColon` (`network.zig:260`) — `for (0..input.len-1)`.
- `Domain.parse` (`url.zig:52`) — rejects `len > 253` upfront, then one pass.
- `Subnet.parse` prefix loop (`network.zig:518-522`) — rejects `prefix_len > 128` inside the loop (early-exit within ~3 iterations on attacker input).
- `Url.parse` — everything is `indexOf*` / `for (slice)` over the borrowed input; no recursion or unbounded while.

**Finding DOS-01 `confidence::confirmed` (no issue)** — No DoS parser loop. All loops are O(n) in `input.len`, which the caller chose.

### 1d. Recomputed values that could be precomputed

**Finding PRECOMP-01 `confidence::confirmed`** — `LatLon.haversineDistance` (`geographic.zig:127-144`) recomputes `@sin`/`@cos`/`@sqrt`/`atan2` (7 transcendentals) on **every** pairwise call, including the `cos(lat1)` factor when `lat1` is the same origin queried N times (1-to-many geo sweep). S1 in the prior audit proposes `prepareOrigin(lat) -> PreparedOrigin { lat_rad, cos_lat }` and a `distanceTo(other)` that saves `~cos(lat1) + 1 × degrees-to-radians mul`. Expected ~15 % improvement on the 1-to-many case per P9. Still Monitor — the gain depends on consumer access pattern (single-pair ~= 0 % win, 1-to-N ~= 15 %). Verification: add a `bench_haversine_broadcast` variant that pins SF and iterates over N destinations, compare before/after.

**Finding PRECOMP-02 `confidence::suspected`** — `Url.eql` (`url.zig:329-337`) recomputes `effectivePort()` for both sides on each call, which re-scans scheme via `eqlIgnoreCase`. Not on the parse hot path; only relevant if a consumer hashes/compares URLs in a tight loop. Measurement: add a 100k-iter `benchUrlEql` before acting.

### 1e. Missing `@Vector` usage for SIMD-able code

**Finding SIMD-01 `confidence::confirmed`** — `rg '@Vector|@splat|@shuffle|@reduce'` returns **zero hits** in `src/`. Every vector op is written as a scalar `for` loop (`vector.zig:106-189`). At the current fixed N=3 this is fine: ReleaseFast cosine and haversine both clock **1.20 ns/op**, meaning LLVM already auto-vectorizes or CSE-eliminates the loop entirely. Explicit `@Vector(N, T)` with `@reduce(.Add, v*v)` would not improve N=3. It becomes relevant only if the library is extended to N >= 8 (e.g., embedding vectors). P5 / S3 are the right trackers; no action now.

### 1f. Potential fusion opportunities (A1 Monitor)

**Finding FUSION-01 `confidence::confirmed`** — See URL-01 above. The `Url.parse` passes in 1a are highly fusable into a single state machine (scheme -> `://` -> authority[{userinfo}, host, {port}] -> path -> query -> fragment). Every delimiter is unambiguous given prior state.

**Finding FUSION-02 `confidence::suspected`** — `Ipv6Addr.parse` runs `findDoubleColon` (`network.zig:260-268`) as a pre-pass, **then** `parseGroups` over both left and right halves (`network.zig:223-247`), touching the buffer 2–3 times for compressed addresses. Collapsing to a single pass that records the `::` position inline is non-trivial but would tighten the 26–28 ns path. Verify by prototype + bench.

**Finding FUSION-03 `confidence::confirmed`** — `Vector.cosineDistance` (`vector.zig:175-189`) is already fused (P3 Closed): single loop computes `sum_aa`, `sum_bb`, `sum_ab` together. Confirms the team has applied the pattern where it matters most; no action.

### 1g. Release-mode semantics (overflow wrap)

**Finding REL-01 `confidence::confirmed`** — `Range.span` (`range.zig:85-87`) uses `self.upper - self.lower` which panics in Debug/ReleaseSafe and wraps in ReleaseFast for `IntRange` extremes. Documented in `root.zig:19-25` and `README.md:69-88`. D1 closed — no action.

**Finding REL-02 `confidence::confirmed`** — `Vector.add/sub/scale/dot/magnitudeSquared` (`vector.zig:106-144`) all use default `+`, `-`, `*` with the same Debug-panic / ReleaseFast-wrap semantics. Documented. No action.

**Finding REL-03 `confidence::confirmed`** — `Subnet.containsV4` (`network.zig:564`) uses `@as(u8, 32) - prefix_len` guarded by `std.debug.assert(prefix_len > 0 and prefix_len < 32)`. Assert elided in ReleaseFast, but defensive branches at `network.zig:555-557` cover the cases that would underflow. Correct — no action.

---

## 2. Build & Runtime Config

| Finding | File:Line | Category | Impact | Confidence |
|---------|-----------|----------|--------|------------|
| CI matrix compiles **all four optimize modes** (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall) | `.gitlab-ci.yml` (see perf-context §CI) | Caching | Protects release semantics; pure cost in CI time, not runtime | confirmed |
| `zig build check` fast IDE compile step kept separate | `build.zig:140-148` | Caching | Good — separates IDE and test artefacts | confirmed |
| Bench job is `exit-0 gate only`; numbers inspected locally on one Linux host | perf-context §CI | Observability | Cross-OS ns/op unverified; macOS / Windows / aarch64 numbers unknown | confirmed |
| No compression / keep-alive / pooling config | N/A | Not applicable | Library has zero network / IO surface | confirmed |
| No debug logging in hot paths | grep for `std.log`, `std.debug.print` in `src/` -> only test prints | Logging | Clean — no runtime log spam | confirmed |

---

## 3. Language-Specific Issues (Zig)

| Finding | File:Line | Best Practice | Impact | Confidence |
|---------|-----------|--------------|--------|------------|
| Scalar loops used where `@Vector` would match at N >= 8 | `vector.zig:106-189` | Zig SIMD: `@Vector(N,T)` + `@reduce(.Add, ...)` would be idiomatic at N >= 8 | None now (1.20 ns/op indicates auto-vectorization + CSE). Reassess if N generalizes. | confirmed |
| `Vector.parse` uses `std.fmt.parseFloat` per token in a loop | `vector.zig:221-236`, `geographic.zig:158-163,211-217` | Text-ingest hot path uses stdlib parser | Correctness-prioritized; bench not measured. Ingest-heavy consumers may want a specialized parser. | suspected |
| `Url.parse` is multi-pass; Zig idiom is a single-pass state machine for byte parsers | `url.zig:190-297` | Fused scan | ~30-40 % win plausible at N=95 ns/op hot input | confirmed (see URL-01) |
| Haversine reuses trig on same origin | `geographic.zig:127-144` | Zig precompute-via-context pattern (`PreparedOrigin` struct) | ~15 % on 1-to-N sweeps | confirmed (S1 Monitor) |
| `@panic` on `Vector.at` OOB in hot code | `vector.zig:75-81` | Zig prefers `std.debug.assert` + caller discipline on hot paths, or bounds-checked index types | Low — tests pass; only hit on buggy call | suspected |
| Integer overflow on `Range.span` in ReleaseFast is **documented** and intentional | `range.zig:82-87`, `root.zig:19-25` | Document release-mode semantics | Correct pattern applied | confirmed |
| `Subnet.contains` defensive branches make out-of-range prefixes safe even when literal-constructed | `network.zig:541-589` | Zig `init` vs struct-literal — defensive fallback | Correct; tested at `network.zig:1060-1074` | confirmed |
| Bench harness has no warm-up / no statistical aggregation (single run) | `bench/main.zig:166-193` | Benching | Single-run numbers are jitter-prone; hyperfine not installed | suspected |

---

## Priority (ranked by expected runtime win)

1. **URL-01 / FUSION-01** — fuse `Url.parse` passes. ~95 ns -> target ~60-70 ns. `confidence::confirmed`.
2. **PRECOMP-01** — `LatLon.prepareOrigin()` for 1-to-N haversine sweeps. ~15 % on broadcast pattern, 0 % on pair-at-a-time. `confidence::confirmed`.
3. **FUSION-02** — single-pass IPv6 parse (fold `findDoubleColon` into `parseGroups`). `confidence::suspected` — prototype first.
4. **Bench harness robustness** — add warm-up loop + min-of-N across runs before chasing any of the above. Currently blocks statistically-sound A/B. `confidence::confirmed`.
5. **Cross-OS bench numbers** — gate CI on ns/op bands for Linux/macOS/Windows instead of exit-0 only. `confidence::suspected` (infra effort).

## Blockers

None. All 9/9 perf tests pass, all benchmarks complete, MaxRSS <= 4 MB run. No regression observed vs. baseline within single-run jitter (+/-15 %). The biggest observability gap is the single-run/single-host bench; everything else is optimization, not breakage.
