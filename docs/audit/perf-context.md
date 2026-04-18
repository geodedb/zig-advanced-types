# Performance Context

**Root:** /home/benji/src/devnw/zig/advanced-types
**Platform:** GitLab (origin: `git@gitlab.com:devnw/zig/advanced-types.git`)
**Language:** Pure Zig 0.15.1+ (toolchain in CI: `ZIG_VERSION: "0.16.0"`)
**Type:** Header-only style value-type library, zero external deps, zero allocator for all core ops
**Source LOC:** ~3,374 in `src/types/*.zig` (5 modules). Tests ~1,094 LOC.

## Services & Entrypoints

This is a library — "entrypoints" are public APIs called by consumers (typically
on hot paths in network, db, and embedding/search code).

| "Service" | Entrypoint | Type | Path |
|-----------|-----------|------|------|
| IPv4 parsing | `Ipv4Addr.parse` | Hot-path parser | `src/types/network.zig:77` |
| IPv6 parsing | `Ipv6Addr.parse` | Hot-path parser | `src/types/network.zig:190` |
| Subnet parse + CIDR membership | `Subnet.parse`, `Subnet.contains` | Hot-path classify | `src/types/network.zig:426`, `:461` |
| MAC parsing | `Mac.parse` | Hot-path parser | `src/types/network.zig:534` |
| URL parsing | `Url.parse` | Hot-path parser (up to 5 scans) | `src/types/url.zig:161` |
| Domain parsing | `Domain.parse` | Hot-path parser | `src/types/url.zig:41` |
| Vector dot / magnitude / distance | `Vector.dot`, `magnitude`, `distance` | CPU math, fixed N=3 | `src/types/vector.zig:133`, `:151`, `:166` |
| Vector cosine distance | `Vector.cosineDistance` | CPU math (fused single-pass, P3 closed) | `src/types/vector.zig:175` |
| Vector parse | `Vector.parse` | Text parser (split+trim) | `src/types/vector.zig:211` |
| Haversine great-circle distance | `LatLon.haversineDistance` | CPU math, 2x `@sin`, 2x `@cos`, `@sqrt`x2, `atan2` | `src/types/geographic.zig:75` |
| LatLon parse | `LatLon.parse` | Text parser | `src/types/geographic.zig:106` |
| Range ops | `Range.contains`, `overlaps`, `intersection`, `union_` | Trivial branchy compare | `src/types/range.zig:45`-`:79` |

## Workload Characteristics

Library has no runtime RPS/SLO of its own — SLO proxies are derived from the
expected workloads of consumers (Geode index/vector search, network handlers).

| Parameter | Value | Source | Confidence |
|-----------|-------|--------|------------|
| SLO: zero hidden allocation in core ops | Must-hold | README "Zero Allocation"; `src/types/network.zig:6`; grep confirms only `Allocator` mention in `src/` is a doc comment | confirmed |
| SLO: ns-scale per-op on hot parsers | Target | Implied by "called on hot paths in network/db code"; no explicit budget documented | suspected |
| SLO: cosine distance single-pass | Enforced | `docs/PERF_GAP_ANALYSIS.md` P3 Closed; `vector.zig:175-189` loops once | confirmed |
| Vector dimension | N=3 (fixed) | `src/types/vector.zig:261` (`VectorF32 = Vector(f32, 3)`) | confirmed |
| RPS / Concurrency / Data size | UNKNOWN | No consumer-workload doc; would need Geode traffic profile to confirm | unknown |
| Optimization modes tested in CI | Debug, ReleaseSafe, ReleaseFast, ReleaseSmall | `.gitlab-ci.yml:117-167` (P2 closed) | confirmed |

## Performance Model (Hypothesized Hot Components)

| Component | Resource | Why | File:Line |
|-----------|----------|-----|-----------|
| `Ipv4Addr.parse` | CPU, branch-pred | Byte-wise loop with branches on `.`, digit, `>255`. Called per-request in ACLs/logs. | `src/types/network.zig:77-110` |
| `Ipv6Addr.parse` / `parseGroups` / `findDoubleColon` | CPU, branch-pred | Multiple scans: `findDoubleColon` is O(n), then left+right group parse. Variable-length, harder to predict. | `src/types/network.zig:190-279` |
| `Url.parse` | CPU, branch-pred | ~5 linear scans (scheme `://`, `#`, `?`, `/`, `:`). P7 Won't-Do but remains a candidate for fused scan if URL-heavy consumers emerge. | `src/types/url.zig:161-246` |
| `Domain.parse` | CPU | Per-char validation + per-label bounds check; called for every host in URL validation downstream. | `src/types/url.zig:41-62` |
| `Subnet.contains` (IPv6) | CPU | `std.mem.eql` over `full_bytes` + masked bit compare. Called NxM in classification loops (see perf test #6). | `src/types/network.zig:461-506` |
| `Vector.cosineDistance` | CPU, FP, SIMD-candidate | At N=3 compiler auto-vectorizes per P5 rationale. Risk if dim is generalized beyond 3. | `src/types/vector.zig:175-189` |
| `Vector.distance` | CPU, FP | `sub().magnitude()` materializes an intermediate `[N]T`. P6 notes compiler elides at N=3 in ReleaseFast. | `src/types/vector.zig:166-169` |
| `LatLon.haversineDistance` | CPU, FP | 2x `@sin`, 2x `@cos`, 2x `@sqrt`, 1x `atan2` = ~7 transcendentals. Dominant cost in bulk geo scans. P9 mathematically unavoidable. | `src/types/geographic.zig:75-92` |
| `Vector.parse` / `LatLon.parse` | CPU, FP parse | `std.fmt.parseFloat` per token; brittle for ingest-heavy paths. | `src/types/vector.zig:211-236`, `geographic.zig:106-128` |

## External Dependencies

| Dependency | Type | Connection Pooling | Timeout | Path |
|-----------|------|-------------------|---------|------|
| None (std only) | stdlib | N/A | N/A | `build.zig.zon` has no deps |

Consumer context: CI pulls GitLab components (`security-sast`, `zig-format`,
`sbom-generate`, `release-semantic`) — none affect runtime perf, only pipeline
wall-time. CI installs Zig per job (P4 Won't-Do; adds ~2.5 min per job).

## Baseline Measurements

Run on `main` (52cce4d, 2026-04-18) with Zig 0.16.0, ReleaseFast, native target.
All 9 perf tests and 233 unit tests pass; execution time is dominated by
compile, not run.

| Benchmark | Command | Result | Date |
|-----------|---------|--------|------|
| Unit tests (ReleaseFast) | `zig build test -Doptimize=ReleaseFast --summary all` | 233/233 pass; run 8 ms; compile 26 s; MaxRSS 4M run / 571M compile | 2026-04-18 |
| Performance tests (ReleaseFast) | `zig build test-performance -Doptimize=ReleaseFast --summary all` | 9/9 pass; run 4 ms total; compile 23 s; MaxRSS 4M run / 537M compile | 2026-04-18 |

Perf tests cover (see `tests/performance.zig`):

1. Bulk IPv4 parsing x100 valid
2. Bulk IPv4 rejection x100 invalid
3. Bulk haversine x50 city pairs
4. Bulk cosine distance x50 vector pairs
5. Mixed dataset parse x20 rows (IP + LatLon + VectorF32)
6. Subnet classification: 20 IPs vs 5 subnets (nested loop)
7. URL batch parse x20
8. Range overlap detection: O(N^2) over 20 IntRanges
9. Vector similarity search: 5 queries over 10 candidates

These are **correctness-at-scale** tests, not micro-benchmarks — they validate
behavior but yield no ns/op numbers. No `b.addExecutable` bench target exists;
no `bench` / `perf` named executables. P1 ("No benchmark suite exists") was
marked **Won't Do** in `docs/PERF_GAP_ANALYSIS.md`.

## Available Profiling Tools

| Tool | Available | Version |
|------|-----------|---------|
| zig | yes | 0.16.0 (`/home/benji/.local/share/mise/shims/zig`) |
| perf | yes | `/usr/bin/perf` |
| hyperfine | no | — |
| pprof | no | — |
| Zig built-in fuzzer | yes | `zig build test --fuzz` (used in CI `fuzz` stage with 60 s timeout) |

## Consumer Constraints (Library Perf Contract)

Since these types are called on hot paths (Geode vector search, network stacks,
log/metric tagging), the implicit contract is:

- **No heap allocation in any parse/math op.** Confirmed: only one
  `Allocator`-mentioning line exists in `src/`, and it is in a doc comment
  (`src/types/network.zig:6`). Zero constructor takes an allocator.
- **Stack-only value semantics.** All types are plain `struct`s holding fixed
  arrays / scalars; URL/Domain store `[]const u8` slices *into the caller's
  input* — lifetime of `Url.scheme`, `.host`, `.path`, `.query`, `.fragment`,
  `.raw` is bound to the original input buffer.
- **Branch-predictable parsing** for parsers called per-request: IPv4, MAC,
  Subnet, Domain all use single-pass byte loops with tight state machines.
  IPv6 + URL have multi-pass scans (acknowledged as acceptable in PERF_GAP).
- **SIMD-friendly vector math** at N=3: `Vector` uses plain loops that Zig
  auto-vectorizes in ReleaseFast. No `@Vector` intrinsics. P5/P8 explicitly
  chose not to force-SIMD at N=3.
- **Debug vs Release behavior:** `add`/`sub`/`scale`/`dot` on integer
  `Vector` panic on overflow in Debug/ReleaseSafe, wrap in ReleaseFast
  (`vector.zig:105`, etc.). `Range.span` has the same caveat (`range.zig:82`).
  Consumers embedding these on hot paths should pin to ReleaseFast or
  ReleaseSafe and be aware of the semantic shift.

## Unknowns & Assumptions

- **No ns/op numbers exist.** Would need `zig build bench` target (executable
  using `std.time.Timer` or similar) to land real baselines. PERF_GAP P1
  explicitly declined this as scope. **Recommendation: revisit for audit.**
- **No @Vector / SIMD usage.** Relying on compiler auto-vectorization at N=3.
  If consumers ever want N=128/384/768 (embedding-model dimensions), the
  generic `Vector(T,N)` would need SIMD-conscious rework — current P5/P8
  explicitly scoped this out.
- **Multi-pass URL parse.** P7 Won't-Do at sub-microsecond per URL, but if a
  reverse-proxy-style consumer materializes, a single-pass scan becomes
  attractive.
- **Haversine transcendental count.** 6–7 FP transcendentals per call. For
  bulk geo (e.g., 10k-pt nearest-neighbor sweep), batching / approximation
  could matter. P9 flagged "mathematically unavoidable" — but approximate
  variants (equirectangular, Vincenty) are standard alternatives worth listing.
- **Consumer workload profile is unknown.** No doc describes realistic RPS,
  batch sizes, or latency budgets for downstream Geode code. Would unblock
  targeted benchmark selection.
- **Integer overflow semantics on `Vector`/`Range`** differ across optimize
  modes; no doc warns consumers choosing ReleaseFast.
