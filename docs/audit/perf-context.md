# Performance Context

**Root:** /home/benji/src/devnw/zig/advanced-types
**Platform:** GitLab (origin: `git@gitlab.com:devnw/zig/advanced-types.git`)
**Languages:** Pure Zig (minimum `0.16.0`; CI pins `ZIG_VERSION: "0.16.0"`)
**Type:** Zero-dependency, zero-allocator value-type library (header-only style)
**HEAD:** `f3adc69` (2026-04-18)
**Source LOC:** 3,739 in `src/types/*.zig` across 5 modules; tests 1,135 LOC; bench 193 LOC.

> Scope note: the task brief lists `NonEmpty`, `StrictFloat`, `Tagged`, and `Unit`
> as library surfaces. Those types do **not** currently exist in `src/root.zig`
> or `src/types/*.zig`. The concrete exported surfaces are `Range` (+ `IntRange`,
> `UintRange`, `FloatRange`), `Vector` (+ `VectorF32`, `VectorI32`), and the
> network/geographic/url families listed below. Treat this pass as the fresh
> baseline of the types that actually ship.

## Services & Entrypoints

This is a library; "entrypoints" are public APIs called on consumer hot paths
(network handlers, vector search, geo lookups, URL/domain validation).

| "Service" | Entrypoint | Type | Path |
|-----------|-----------|------|------|
| Build: unit tests | `zig build test` | Test harness | `build.zig:18-27` |
| Build: integration tests | `zig build test-integration` | Test harness | `build.zig:30-42` |
| Build: type-extension tests | `zig build test-extensions` | Test harness | `build.zig:45-57` |
| Build: fuzz | `zig build test-fuzz` | Fuzzer driver | `build.zig:60-72` |
| Build: parser-edge tests | `zig build test-parser-edges` | Regression | `build.zig:76-88` |
| Build: performance tests | `zig build test-performance` | Bulk-correctness | `build.zig:91-103` |
| Build: micro-bench | `zig build bench` | ns/op exe | `build.zig:124-137`; `bench/main.zig` |
| Build: check | `zig build check` | Fast IDE compile | `build.zig:140-148` |
| IPv4 parsing | `Ipv4Addr.parse` | Hot-path parser | `src/types/network.zig:77` |
| IPv6 parsing | `Ipv6Addr.parse` / `parseGroups` / `findDoubleColon` | Hot-path parser (multi-pass) | `src/types/network.zig:190`, `:236` |
| Subnet parse + CIDR membership | `Subnet.parse`, `Subnet.contains` | Hot-path classify | `src/types/network.zig:426`, `:461` |
| MAC parsing | `Mac.parse` | Hot-path parser | `src/types/network.zig:534` |
| URL parsing | `Url.parse` | Hot-path parser (~6 scans) | `src/types/url.zig:161` |
| Domain parsing | `Domain.parse` | Per-char validate, per-label bounds | `src/types/url.zig:41` |
| Vector dot / magnitude / distance | `Vector.dot`, `.magnitude`, `.distance` | Fixed N=3 CPU math | `src/types/vector.zig:133,151,166` |
| Vector cosine distance | `Vector.cosineDistance` | Fused single-pass (P3 closed) | `src/types/vector.zig:175` |
| Vector parse | `Vector.parse` | Text parser (split+trim+parseFloat) | `src/types/vector.zig:211` |
| Haversine great-circle | `LatLon.haversineDistance` | 7 transcendentals | `src/types/geographic.zig:75-92` |
| LatLon parse | `LatLon.parse` | Text parser | `src/types/geographic.zig:106` |
| Range ops | `Range.contains`, `.overlaps`, `.intersection`, `.union_`, `.span` | Branchy compare | `src/types/range.zig:45-82` |

### CI Matrix (`.gitlab-ci.yml`)

Debian-bookworm-slim; Zig installed per job (P4 Won't-Do). All Zig optimize
modes exercised:

- `test` / `test-integration` (Debug)
- `test-release-safe`, `test-release-fast`, `test-release-small`
- `test-integration-release-{safe,fast,small}`
- `test-extensions`, `test-parser-edges`, `test-performance`
- `bench` (ReleaseFast, exit-0 gate only; numbers inspected locally)
- Cross-OS: `test-macos`, `test-windows`, `test-linux-aarch64`
- Fuzz job runs Zig built-in fuzzer; kcov coverage job (`20bda63`).

## Workload Characteristics

No runtime RPS/SLO exists for the library; SLO proxies are inherited from
expected consumers (Geode vector search, network handlers).

| Parameter | Value | Source | Confidence |
|-----------|-------|--------|------------|
| SLO: zero hidden allocation in core ops | Must-hold | README "Zero Allocation"; `src/types/network.zig:6`; only `Allocator` mentions in `src/` are doc comments at `url.zig:47,170` | confirmed |
| SLO: ns-scale hot parsers | Target | Bench baselines below (Ipv4=21 ns/op, Ipv6=28 ns/op, Url=99 ns/op) | confirmed |
| SLO: cosine distance single-pass | Enforced | `docs/PERF_GAP_ANALYSIS.md` P3 Closed; `vector.zig:175-189` | confirmed |
| Vector dimension | N=3 (fixed re-exports) | `src/types/vector.zig` `VectorF32 = Vector(f32, 3)` | confirmed |
| Release-mode overflow wrap documented | Yes | `README.md:69-88` "Build Modes and Overflow Semantics"; `src/root.zig:19-25` | confirmed (D1 closed via `d786b46`, `0c2ebbd`) |
| Optimization modes gated in CI | Debug, ReleaseSafe, ReleaseFast, ReleaseSmall | `.gitlab-ci.yml:117-221` | confirmed |
| Consumer RPS / concurrency / data size | UNKNOWN | No consumer-workload doc tracked | unknown |

## Performance Model (Hypothesized Hot Components)

| Component | Resource | Why | File:Line |
|-----------|----------|-----|-----------|
| `Ipv4Addr.parse` | CPU, branch-pred | Byte-loop, branches on `.`, digit, `>255`; per-request in ACLs/logs | `src/types/network.zig:77-110` |
| `Ipv6Addr.parse` / `parseGroups` / `findDoubleColon` | CPU, branch-pred | O(n) scan + left+right group parse; variable-length | `src/types/network.zig:190-279` |
| `Url.parse` | CPU, branch-pred | ~6 linear scans (scheme `://`, scheme char-class, `#`, `?`, `/`, authority `]`/`:`). A1 Monitor | `src/types/url.zig:161-246` |
| `Domain.parse` | CPU | Per-char validation, per-label bounds; called downstream from URL validation | `src/types/url.zig:41-62` |
| `Subnet.contains` (IPv6) | CPU | `std.mem.eql` + masked bit-compare; NxM in classification loops | `src/types/network.zig:461-506` |
| `Vector.cosineDistance` | CPU, FP, SIMD-candidate | N=3 auto-vectorized; risk if generalized (P5 Won't-Do, rescope candidate S3) | `src/types/vector.zig:175-189` |
| `Vector.distance` | CPU, FP | `sub().magnitude()`; P6 notes compiler elides at N=3 in ReleaseFast | `src/types/vector.zig:166-169` |
| `LatLon.haversineDistance` | CPU, FP | 2x `@sin` + 2x `@cos` + 2x `@sqrt` + 1x `atan2` (7 ops). S1 Monitor (precomputed-origin API) | `src/types/geographic.zig:75-92` |
| `Vector.parse` / `LatLon.parse` | CPU, FP parse | `std.fmt.parseFloat` per token; ingest-heavy paths brittle | `src/types/vector.zig:211-236`, `geographic.zig:106-128` |

## External Dependencies

| Dependency | Type | Connection Pooling | Timeout | Path |
|-----------|------|-------------------|---------|------|
| None (std only) | stdlib | N/A | N/A | `build.zig.zon:6` (`.dependencies = .{}`) |

CI-only external components (no runtime impact): `gitlab.com/devnw/ci-catalog/security-sast`, `zig-format`, `sbom-generate`, `release-semantic`.

## Baseline Measurements

Run on `main` (`f3adc69`, 2026-04-18) with Zig 0.16.0, ReleaseFast, native target (Linux 6.12).

### Micro-bench (ns/op; `zig build bench -Doptimize=ReleaseFast`)

| Benchmark | Iterations | ns/op | ops/sec |
|-----------|-----------:|------:|--------:|
| `Ipv4Addr.parse` | 100,000 | 21.55 | 46,414,395 |
| `Ipv6Addr.parse` | 100,000 | 27.97 | 35,749,601 |
| `Url.parse` | 100,000 | 98.54 | 10,147,652 |
| `VectorF32.cosineDistance` | 100,000 | 1.20 | 832,182,148 |
| `LatLon.haversineDistance` | 100,000 | 1.20 | 832,126,750 |

### Test suites

| Benchmark | Command | Result | Date |
|-----------|---------|--------|------|
| Unit tests (ReleaseFast) | `zig build test -Doptimize=ReleaseFast --summary all` | 248/248 pass; run 7 ms; MaxRSS 4M run / 41M compile (cached) | 2026-04-18 |
| Performance tests (ReleaseFast) | `zig build test-performance -Doptimize=ReleaseFast --summary all` | 9/9 pass; run 5 ms; compile 23 s; MaxRSS 3M run / 541M compile | 2026-04-18 |

Perf tests in `tests/performance.zig` exercise (correctness-at-scale, not ns/op):

1. Bulk IPv4 parsing x100 valid
2. Bulk IPv4 rejection x100 invalid
3. Bulk haversine x50 city pairs
4. Bulk cosine distance x50 vector pairs
5. Mixed dataset parse x20 rows (IP + LatLon + VectorF32)
6. Subnet classification: 20 IPs vs 5 subnets (nested loop)
7. URL batch parse x20
8. Range overlap detection: O(N^2) over 20 IntRanges
9. Vector similarity search: 5 queries over 10 candidates

## Available Profiling Tools

| Tool | Available | Version / Path |
|------|-----------|-----------------|
| zig | yes | 0.16.0 (`/home/benji/.local/share/mise/shims/zig`) |
| perf | yes | `/usr/bin/perf` |
| Zig built-in fuzzer | yes | `zig build test --fuzz`; CI `fuzz` stage |
| kcov coverage | yes (CI only) | `.gitlab-ci.yml` coverage job (`20bda63`) |
| hyperfine | no | — |
| pprof | no | — |

## Consumer Constraints (Library Perf Contract)

- **No heap allocation in any parse/math op.** Confirmed: `src/` references to
  `Allocator` are doc comments only (`src/types/url.zig:47,170`, `network.zig:6`).
  No constructor/parser takes an allocator.
- **Stack-only value semantics.** URL/Domain store `[]const u8` slices *into
  the caller's input buffer* — lifetime of `Url.scheme|host|path|query|fragment|raw`
  is bound to that buffer.
- **Branch-predictable parsing** for per-request paths: IPv4, MAC, Subnet,
  Domain are single-pass byte loops. IPv6 + URL use multi-pass scans
  (A1/A5 acknowledged).
- **SIMD-friendly at N=3.** Plain loops; no `@Vector` intrinsics. Relies on
  LLVM auto-vectorization. P5/P8 explicitly deferred explicit SIMD.
- **Release-mode overflow semantics are documented** (D1 closed). `Vector`
  `add/sub/scale/dot/magnitudeSquared` and `Range.span` panic in Debug/
  ReleaseSafe and wrap in ReleaseFast/ReleaseSmall — see `README.md:69-88`
  and `src/root.zig:19-25`.

## Unknowns & Assumptions

- **ns/op baselines now exist** but are single-host, single-run (one Linux
  box); cross-OS macOS/Windows runs are gated on CI exit-0 only, so absolute
  numbers there remain unknown.
- **No @Vector / SIMD usage.** Compiler auto-vectorization at N=3 is assumed,
  not verified by disassembly in this pass. If consumers ask for N>=16, S3
  rescope would be required.
- **Consumer workload profile UNKNOWN.** No doc describes Geode (or other)
  RPS, batch sizes, latency budgets. Would unblock A1 (`Url.parse` fused
  scan) and S1 (precomputed-origin haversine) Monitor -> Fix decisions.
- **Haversine transcendental count (7).** P9 corrected from 6; S1 offers
  ~15 % win on 1-to-many sweeps via `prepareOrigin()`. Still Monitor.
- **Task-brief types not present.** `NonEmpty`, `StrictFloat`, `Tagged`,
  `Unit` are not exported in this repo at `f3adc69`; only `Range`, `Vector`,
  `network.*`, `geographic.*`, `url.*` ship.
