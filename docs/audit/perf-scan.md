# Performance Scan — Raw Findings

**Scope:** `/home/benji/src/devnw/zig/advanced-types` (pure Zig library, 5 modules in `src/types/`).
**Date:** 2026-04-18.
**Method:** Static scan (ripgrep + read) against the red-flag checklist in `codepros:perf-review`. No benchmarks were run (none exist). All claims tagged `confirmed` (verified in source) or `suspected` (plausible from static reading, needs numbers).

Phase-1 handoff goals were: (a) re-examine P5/P7/P9 "Won't Do"; (b) grep for hidden perf anti-patterns (heap allocs, O(N²) parsing, repeated string scans, `@intCast` hazards, release-mode-only asserts); (c) document integer-overflow semantic divergence ReleaseSafe vs ReleaseFast; (d) assess whether `zig build bench` is needed.

---

## Automated Red-Flag Scan Results

### Hidden Heap Allocations

| Pattern | File:Line | Evidence | Verdict | Confidence |
|---------|-----------|----------|---------|------------|
| `alloc(` / `dupe(` / `realloc(` / `ArrayList` / `std.heap` | — | `rg` across `src/`: **zero matches** | **No hidden allocations** in production paths. Zero-alloc claim holds. | confirmed |
| `Allocator` parameter | `src/types/network.zig:6` (doc comment), `src/types/vector.zig:1` (header comment) | Only mentions are in doc comments. No function signature accepts an `Allocator`. | Zero-alloc contract is structurally enforced (no API surface to violate). | confirmed |

### Repeated / Multi-Pass String Scans (P7 re-examination)

`Url.parse` is marked P7 "Won't Do — sub-microsecond for typical URLs." Static count of linear scans over the input inside a single `parse()` call (`src/types/url.zig:161-246`):

| Step | Call | File:Line | Over what slice |
|------|------|-----------|-----------------|
| 1 | `std.mem.indexOf(u8, input, "://")` | `url.zig:165` | full `input` |
| 2 | char-class validation loop over scheme | `url.zig:169-173` | scheme prefix |
| 3 | `std.mem.indexOfScalar(u8, rest, '#')` | `url.zig:181` | `rest` (full post-scheme) |
| 4 | `std.mem.indexOfScalar(u8, rest, '?')` | `url.zig:188` | `rest` (shrunk) |
| 5 | `std.mem.indexOfScalar(u8, rest, '/')` | `url.zig:197` | `rest` (shrunk) |
| 6a | `std.mem.indexOfScalar(u8, authority, ']')` (IPv6 path only) | `url.zig:214` | authority |
| 6b | `std.mem.lastIndexOfScalar(u8, authority, ':')` (non-IPv6) | `url.zig:224` | authority |

So **6 linear scans** in the common case (5 + char-class + authority colon scan), not 5. P7 undercounts by one pass but the magnitude conclusion is unchanged.

**Downstream amplification:** `Url.domain()` (`url.zig:259-265`) calls `looksLikeIpv4` (full host scan, `url.zig:302-308`) then `Domain.parse` (another full host scan, `url.zig:41-62`) — so consumers that call `parse + domain()` scan the host slice **3 additional times** (looksLikeIpv4, Domain.parse main loop, validateLabel per-label). `Url.eql` does 2× `eqlIgnoreCase` + 1 `mem.eql`.

- **P7 re-verdict:** **Accept "Won't Do" for `parse()` alone** (5-6 scans on a <2KB URL is tens of nanoseconds — not a practical hot-path concern). **Revisit if consumers use `parse + domain()` together on hot paths** — that combination triples the host scan count. Confidence: suspected (no numbers).

### IPv6 Multi-Pass

`Ipv6Addr.parse` (`src/types/network.zig:190-234`) scans:

| Step | Call | File:Line |
|------|------|-----------|
| 1 | `findDoubleColon` (linear loop over `input.len - 1`) | `network.zig:236-244` |
| 2 | `parseGroups(left, ...)` — single-pass left half | `network.zig:246-279` |
| 3 | `parseGroups(right, ...)` — single-pass right half | `network.zig:246-279` (called again) |
| 4 | Post-copy `for (0..right_count*2)` into `octets` | `network.zig:221-223` |

`findDoubleColon` is a hand-rolled `indexOf("::")` — it duplicates `std.mem.indexOf(u8, input, "::")` logic. Not a perf problem (linear), but is non-idiomatic. Full parse is ~3 passes over input worst case, O(n) total — **consistent with "no multi-pass hot-spot"** claim.

Also noted: `parseGroups` returns count, and on the right-side branch there's a **stack copy** via a fresh `right_octets: [16]u8 = .{0}**16` buffer followed by a 0..right_count*2 copy loop. In Debug/ReleaseSafe this zero-init is real work; in ReleaseFast the compiler should elide. Tag: suspected redundancy; numbers needed.

No support for dotted-quad IPv4-in-IPv6 (`::ffff:192.168.1.1`) in `parse` — `hexDigitValue` rejects `.`. Not a perf issue, but a **feature gap** worth noting for completeness (not scope here).

### GeoPoint.parse double-parse (P10 re-examination)

`GeoPoint.parse` (`src/types/geographic.zig:285-299`):

```zig
const trimmed = std.mem.trim(u8, input, ...);           // scan 1 (trim)
if (... trimmed[0] != '(' or trimmed[trimmed.len-1] != ')') ...;
const inner = trimmed[1 .. trimmed.len - 1];
const comma_count = std.mem.count(u8, inner, ",");       // scan 2 (full count)
return switch (comma_count) {
    1 => .{ .point_2d = try LatLon.parse(input) },        // scan 3: re-trim + re-find-commas
    2 => .{ .point_3d = try LatLonAlt.parse(input) },     // scan 3: re-trim + re-find 2 commas
    ...
};
```

Every `GeoPoint.parse` call **re-trims + re-scans**: the dispatcher does `trim + count`, then the dispatchee (`LatLon.parse` or `LatLonAlt.parse`) does `trim + indexOfScalar(',')` all over again from the original `input`. This is P10 territory ("`GeoPoint.parse` re-parses input — Won't Do, negligible for ~30 byte inputs"). Static verdict: **P10 is accurate as stated** — for the ~30-byte strings shown in tests this is measurable only at millions-of-parses-per-second scale. However the phrasing "re-parses input" understates it: it's actually **3 passes** (trim + count + dispatchee's own trim/find). Confidence: confirmed (structural).

### Quadratic / Expensive Loops

| Check | Finding | File:Line | Confidence |
|-------|---------|-----------|------------|
| ORM-in-loop / `.find()`-in-loop | **N/A** — no queries | — | confirmed |
| Nested O(N²) in library | None. `Subnet.contains` is O(1) per call (fixed 16-byte compare). | `network.zig:461-506` | confirmed |
| O(N²) only appears in **tests**, not library | `tests/performance.zig` test #6 (20 IPs × 5 subnets) and test #8 (20 IntRange overlap) — these are **intentional correctness-at-scale** exercises, not library perf issues. | — | confirmed |
| String concat in loops / builders | `Ipv4Addr.format` / `Mac.format` use `writer.print` with `{X:0>2}` — each call goes through `std.fmt` machinery per byte (6 calls for MAC, 4 for IPv4). On a profiled hot path this is often the #1 cost, but for library formatters of fixed-size output it's acceptable. | `network.zig:113-120`, `:565-570` | suspected |

### `@intCast` Without Overflow Check in Hot Paths

All 17 `@intCast` occurrences are in `src/types/network.zig` or `vector.zig`. Each was reviewed:

| File:Line | Context | Safety | Verdict |
|-----------|---------|--------|---------|
| `network.zig:61-64` | `Ipv4Addr.fromU32` — `@intCast((value >> 24) & 0xFF)` into `u8` | Masked to 0xFF before cast — **safe by construction**. | safe |
| `network.zig:90`, `:107` | `Ipv4Addr.parse` — `@intCast(current_value)` where `current_value: u16` | Checked `current_value > 255` on the prior line → **safe by explicit guard**. | safe |
| `network.zig:174-175` | `Ipv6Addr.init` — `@intCast((seg >> 8) & 0xFF)` | Masked. | safe |
| `network.zig:256-257`, `:274-275` | `parseGroups` | Masked to 0xFF. | safe |
| `network.zig:456` | `Subnet.parse` — `@intCast(prefix_len)` where `prefix_len: u16` into `u8` | Guarded by `prefix_len > max_prefix` (max 128). | safe |
| `network.zig:469` | `Subnet.contains` IPv4 — `@as(u8, 32) - self.prefix_len` then `@intCast` to `u5` | If `prefix_len == 0` the function returns early; if `prefix_len >= 32` returns earlier. So at the `@intCast` site `prefix_len ∈ [1, 31]`, result `∈ [1, 31]`, fits `u5`. **Safe by prior branches but non-local** — one more early-return shuffle and this could panic. | safe; fragile |
| `network.zig:483`, `:494` | `Subnet.contains` IPv6 — `prefix_len % 8` fits in `u3`; `8 - remaining_bits` fits in `u4` → `u3` | Both `@intCast` depend on value being < 8, which is structurally true for `x % 8`. | safe |

**No hot-path `@intCast` is unchecked.** But `network.zig:469` is subtle — the safety depends on two earlier early-returns, not a local assert. Suggest inline `std.debug.assert(self.prefix_len > 0 and self.prefix_len < 32);` to catch regressions. Confidence: confirmed.

### Debug-Only Asserts Left in Release

| Pattern | Count in `src/` | Note |
|---------|----------------|------|
| `std.debug.assert` | **0** | |
| `assert(` | **0** | |
| `@panic(...)` | **1** (`vector.zig:78` `Vector.at`, out-of-bounds) | Runs in all modes (by design — matches `std` idiom for OOB). Not a debug-only artifact. |
| `unreachable` | Only in test code (inside `catch unreachable` around `std.fmt.bufPrint` — 12 occurrences, all in tests) | No production-path `unreachable`. |

**No debug-only asserts in release.** Claim verified. Confidence: confirmed.

---

## Integer-Overflow Semantics: ReleaseSafe vs ReleaseFast

The phase-1 context already flags this (`perf-context.md:124-127`) but it needs to be stated for consumers. Behavior divergence by optimize mode:

| Operation | File:Line | Debug / ReleaseSafe | ReleaseFast / ReleaseSmall |
|-----------|-----------|---------------------|----------------------------|
| `Vector(T,N).add` (integer T) | `vector.zig:106-112` | **Panics** on overflow (safety check) | **Wraps** (two's complement) |
| `Vector(T,N).sub` (integer T) | `vector.zig:115-121` | **Panics** on underflow | **Wraps** |
| `Vector(T,N).scale` (integer T) | `vector.zig:124-130` | **Panics** on overflow | **Wraps** |
| `Vector(T,N).dot` (integer T) | `vector.zig:133-139` | **Panics** on accumulation overflow — note this multiplies **then** sums, so for `VectorI32` worst-case `i32 * i32` is already `i32`-overflow-able at values >46341 | **Wraps** |
| `Vector(T,N).magnitudeSquared` (integer T) | `vector.zig:142-144` | Same as `dot` | Same as `dot` |
| `Range(T).span` (integer T) | `range.zig:82-87` | **Panics** if `upper - lower` overflows `T` (documented in doc comment lines 82-84) | **Wraps** — can silently return a bogus span |
| `Range.adjacent` helper | `range.zig:173-187` | Explicitly guards `a.upper < maxInt(T)` before `+1` — **safe in both modes** | Same |

**Doc comments on `add/sub/scale/dot/magnitudeSquared` already note this** (`vector.zig:105, 114, 123, 132`). Good.
**Doc on `Range.span` notes this** (`range.zig:82-84`). Good.

**Missing public doc:** Top-level `README.md` and `src/root.zig` do not warn consumers pinning to ReleaseFast about the behavior shift. A one-line note in the README "Release-mode caveats" section would close this gap without code changes. Confidence: confirmed.

**Recommendation:** **don't change the semantics** — panic-on-overflow in Safe modes is the idiomatic Zig contract. But document it once at the module level so a consumer choosing ReleaseFast for Geode-scale embedding workloads isn't blindsided by wrap-around distances.

---

## P5 / P7 / P9 Re-Verdicts

### P5 — No `@Vector` SIMD intrinsics (Won't Do)

`Vector(T,N).cosineDistance` (`vector.zig:175-189`) and siblings use plain loops. At N=3 there is no SIMD win: a 3-wide `@Vector(3, f32)` needs padding to SSE's 128-bit / 4-wide register anyway, and modern LLVM backends auto-vectorize the tight `for (self.data, other.data) |a, b|` pattern in ReleaseFast. The P5 rationale holds **at N=3**.

**Re-verdict:** **Keep P5 Won't Do as scoped.** Caveat: the type is `Vector(T,N)` and `N` is comptime — if a consumer instantiates `Vector(f32, 128)` (embedding dim), the same loops will auto-vectorize on modern LLVM but not with the optimal unroll factor you'd get from `@Vector(16, f32)` tiles. If Geode ever uses the generic form for `N >= 16`, **revisit**. Confidence: suspected (needs `llvm-mca` / benchmark at non-default N).

### P7 — Url.parse multi-pass (Won't Do)

Counted above: **6 linear scans** in the common case, not "up to 5". The conclusion (sub-microsecond per URL) still stands for typical HTTP/S URLs <2 KB.

**Re-verdict:** **Keep P7 Won't Do, but update the P7 finding to say "up to 6 scans" for accuracy.** **Separate finding to add:** `parse + domain()` does 3 additional scans over `host`; if that combination is called per-request in a reverse-proxy consumer, the amortized cost is 2–3× a single-pass design. Confidence: suspected.

### P9 — Haversine 6 transcendentals (Won't Do)

`LatLon.haversineDistance` (`geographic.zig:75-92`) does 2× `@sin`, 2× `@cos`, 2× `@sqrt`, 1× `atan2` = **7 transcendentals** (P9 wrote "6"). Each of these is ~20-50 cycles on x86-64, so total ≈ 200-300 cycles per call, dominated by `atan2`.

**Re-verdict:** **Keep P9 Won't Do for the exact-haversine case.** But:

1. **The finding count is wrong** (6 → 7, the `atan2` was omitted). Cosmetic, but worth correcting when docs are revised.
2. `@cos(lat1) * @cos(lat2)` is **invariant across repeated distance calls with the same `lat1`** — i.e. a 1-to-many nearest-neighbor sweep where one point is fixed could precompute `@sin(lat1*to_rad)` and `@cos(lat1*to_rad)` once. The library API doesn't expose this fused form, so users can't opt in.
3. **Approximate alternatives exist** (equirectangular ≈ 2 trig ops, spherical-law-of-cosines ≈ 3 trig, Vincenty for ellipsoid precision). These are out of scope for the current P9 finding but would be **useful as opt-in variants** if Geode does bulk geo proximity.

**Recommendation:** Keep P9 Won't Do. Separately, consider a new finding — "No batched/approximate geodistance API" — if consumer workload warrants. Confidence: suspected.

---

## Build & Runtime Config

| Finding | File:Line | Impact | Confidence |
|---------|-----------|--------|------------|
| No `bench` step in `build.zig` | `build.zig:6-115` (no `addExecutable` with `bench` or `benchmark`, no `std.time.Timer`-based runner) | Cannot produce ns/op numbers; cannot gate regressions numerically in CI | confirmed |
| `test-performance` step is dataset-level, not timed | `build.zig:74-87` + `tests/performance.zig` (pass/fail only) | Verifies correctness at scale but no latency signal | confirmed |
| CI runs all 4 optimize modes (Debug/ReleaseSafe/ReleaseFast/ReleaseSmall) for tests | `.gitlab-ci.yml` (per P2 closure) | Good — overflow-semantic divergence gets coverage | confirmed |
| No build cache / Zig install cached across CI jobs | `.gitlab-ci.yml` (per P4 Won't Do) | Pipeline wall-time, not runtime | n/a to perf runtime |

---

## Bench Target Recommendation

Phase-1 declined P1 ("No benchmark suite exists") as **Won't Do**. Revisiting for this audit:

**Arguments for adding `zig build bench`:**

1. All of P5/P7/P9 rest on the assertion "too cheap to matter" without numbers. Every rejection of a SIMD/single-pass/approximate variant reduces to "trust the compiler." A 30-line `bench.zig` running each hot function 10⁶ times with `std.time.Timer` would give the library a **defensible numerical floor** so future changes that regress 5× are caught.
2. Claims on the box — "ns-scale per-op," "auto-vectorize at N=3," "single-pass cosine" — are **untested** in CI. Any LLVM regression (e.g. loss of auto-vectorization on a toolchain bump, which has happened in past Zig releases) would go silently unnoticed.
3. For a value-type library explicitly positioned as "called on hot paths," **not having one ns/op number to stand behind is a credibility gap** more than a performance gap.
4. Cost is low: no new deps, one file, runs in milliseconds, gated behind a non-default `zig build bench` step so normal test flows are unaffected.

**Arguments against (the P1 rationale):**

1. "Significant new work." True if you want statistical rigor (warmup, median/p99, CPU pinning, noise detection). False if scoped to a basic "iterations-per-second" script similar to `std.time.Timer` micro-benches in Zig's own stdlib.
2. The library is stable and all hot paths are <100 LOC each. Regression risk is empirically low.

**Recommendation:** **Revisit P1.** Propose a minimal `bench.zig` that targets the 8 functions called out in perf-context.md (IPv4/IPv6/Url/Mac/Subnet parse, cosineDistance, haversineDistance, Subnet.contains) with `std.time.Timer`-based iteration counts. Scope: one file, ~150 LOC, new `bench` step in `build.zig`. Gate CI only on "compiles and runs," not on absolute numbers, to avoid flakiness. Confidence: suspected (judgment call; the P1 "Won't Do" is defensible but now out of step with the zero-alloc / single-pass / auto-vectorize claims being re-examined in this audit).

---

## Summary of New / Revised Findings

| ID | Finding | Status vs PERF_GAP_ANALYSIS | Action |
|----|---------|-----------------------------|--------|
| P1 | No bench target | Was Won't Do | **Recommend re-open** |
| P5 | No `@Vector` SIMD | Was Won't Do @ N=3 | **Keep Won't Do**; add note: revisit if consumer uses generic `Vector(T, N>=16)` |
| P7 | `Url.parse` multi-pass | Was "up to 5 scans" Won't Do | **Keep Won't Do**; correct count (5→6); **new sub-finding: `parse + domain()` triples host scans** |
| P9 | Haversine 6 trig | Was "6 trig, mathematically unavoidable" Won't Do | **Keep Won't Do**; correct count (6→7, atan2 missed); **new sub-finding: no batched / fixed-origin / approximate API for 1-to-many** |
| P10 | `GeoPoint.parse` re-parses | Was Won't Do | **Keep Won't Do**; doc note — it's 3 passes not "re-parses once" |
| — | Int-overflow semantic divergence across modes | **Not documented at module / README level** | **New finding:** add top-level doc note |
| — | `network.zig:469` `@intCast` safety is non-local | — | **New finding:** add inline `assert` to catch regression |
| — | `IPv6Addr.parse` does not accept `::ffff:a.b.c.d` dotted-quad form | — | Feature gap, not perf; out of scope for this review |

No confirmed performance bugs. Two doc-level clarifications + one bench-target reconsideration make up the net new work. All severe anti-patterns (heap allocs, O(N²), unchecked `@intCast`, debug-asserts-in-release) were scanned and **do not occur** in the library code.
