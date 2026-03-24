# GAP Analysis

Last updated: 2026-03-23

Repository status: types implemented from spec; Geode source not yet wired as consumer.

## Goal

Create one reusable package for portable value types currently embedded in Geode:

- network types
- vector types
- geographic types
- URL/domain types
- generic ranges

## Intended Boundary

Move into this library:

| Geode source | Why it belongs here |
|---|---|
| `src/types/network.zig:5`, `:6`, `:7`, `:21`, `:70`, `:140` | Reusable IP/subnet/MAC types and helpers |
| `src/types/vector.zig:8`, `:19`, `:50`, `:67`, `:315`, `:374` | Portable vector value types and distance operations |
| `src/types/geographic.zig:8`, `:22`, `:69`, `:167`, `:277`, `:380`, `:511`, `:552`, `:688` | Core geographic values plus useful spatial helpers |
| `src/types/url.zig:3`, `:16`, `:88`, `:151`, `:159` | Generic URL and domain parsing/formatting |
| `src/types/range.zig:3`, `:40`, `:57`, `:73`, `:124`, `:125` | Generic range support and common aliases |

Keep in Geode for now:

| Geode source | Why it stays |
|---|---|
| `src/types/hash.zig:4`, `:5`, `:6`, `:18` | This file aliases storage/heap-defined hash types and is not yet cleanly independent |

## Concrete Gaps

| Gap | Status | Decision / Resolution |
|---|---|---|
| URL/domain logic overlaps the existing external `uri` dependency | **Closed** | `Url` and `Domain` stay in `advanced-types` as standalone value types. `uri` remains the RFC 3986 parser — no overlap. `Url` provides simplified parsing for the value-type use case; `Domain` validates domain names. No dependency on `uri`. |
| `hash.zig` is still tied to Geode internals | **Won't Do** | Left in Geode. Not a portable value type — aliases heap/storage types. May be split into a dedicated package later. |
| Geographic file mixes simple value types with a large helper surface | **Closed** | Core types only: `LatLon`, `LatLonAlt`, `GeoPoint` with essential ops (haversine, validation, parsing). `st_*` query helpers are query-layer concerns — staged for a later release. |
| `range.zig` depends on local date support | **Closed** | `DateRange` trimmed. Ships `Range(T)` generic plus `IntRange`, `UintRange`, `FloatRange` aliases. `DateRange` can be added when a date/datetime package is available. |

## Implemented Public API

All types are exported from `src/root.zig`:

| Type | Module | Description |
|---|---|---|
| `Ipv4Addr` | `network` | IPv4 address (parse, format, classify, u32 roundtrip) |
| `Ipv6Addr` | `network` | IPv6 address (parse with `::`, format, classify, v4-mapped detection) |
| `IpAddr` | `network` | Tagged union of v4/v6 with auto-detecting parse |
| `Subnet` | `network` | CIDR notation with `contains` check |
| `Mac` | `network` | MAC address (colon/hyphen parse, classify) |
| `VectorF32` | `vector` | 3D f32 vector (add/sub/scale/dot/magnitude/normalize/distance/cosine) |
| `VectorI32` | `vector` | 3D i32 vector (add/sub/scale/dot) |
| `Vector(T, N)` | `vector` | Generic N-dimensional vector |
| `LatLon` | `geographic` | 2D coordinate with haversine distance |
| `LatLonAlt` | `geographic` | 3D coordinate (lat/lon/altitude) |
| `GeoPoint` | `geographic` | Tagged union of 2D/3D |
| `Url` | `url` | Parsed URL components (scheme, host, port, path, query, fragment) |
| `Domain` | `url` | Validated domain name with label iteration |
| `Range(T)` | `range` | Generic inclusive range with contains/overlaps/intersection |
| `IntRange` | `range` | `Range(i64)` |
| `UintRange` | `range` | `Range(u64)` |
| `FloatRange` | `range` | `Range(f64)` |

## Tests

| Test suite | Count | Status |
|---|---|---|
| Unit tests (`zig build test`) | 233 | Passing |
| Integration tests (`zig build test-integration`) | 9 | Passing |
| Type-extension tests (`zig build test-extensions`) | 11 | Passing |
| Performance tests (`zig build test-performance`) | 9 | Passing |
| Fuzz tests (`zig build test-fuzz`) | 10 | Passing |
| **Total** | **272** | **All passing** |

## Gaps (from audit 2026-03-23)

| Gap-ID | Finding | Severity | Status | Category |
|--------|---------|----------|--------|----------|
| GAP-0005 | README Quick Start shows nonexistent `init()` function | High | **Closed** | Docs |
| GAP-0006 | Archive/issue URLs use underscores instead of hyphens | High | **Closed** | Docs |
| GAP-0007 | examples/basic.zig does not import or use the library | Medium | **Closed** | Docs |
| GAP-0008 | docs/README.md links to 5 nonexistent pages | Medium | **Closed** | Docs |
| GAP-0009 | CODEOWNERS contains placeholder @your-username | Low | **Closed** | Quality |
| GAP-0010 | CHANGELOG.md has placeholder release date | Low | **Closed** | Docs |
| GAP-0011 | No code coverage measurement configured | Medium | **Closed** | CI/CD |
| GAP-0012 | AT-TEST-002 cross-feature type-extension tests not ported | Medium | **Closed** | Test |
| GAP-0013 | AT-TEST-003 integration/performance tests not ported | Medium | **Closed** | Test |
| GAP-0014 | Wire Geode to consume types from this package | High | **Blocked** | Requirement |
| GAP-0015 | DateRange deferred — blocked on datetime package | Low | **Blocked** | Feature |
| GAP-0016 | Geographic st_* helpers staged for future release | Low | **Deferred** | Feature |
| GAP-0017 | Port Geode integration tests for type consumption | Medium | **Blocked** | Test |
| GAP-0018 | No fuzzing or property-based testing for parsers | Low | **Closed** | Test |

## Related Audit Documents

- [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md) — 10 closed, 3 won't-do
- [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md) — 2 closed, 8 won't-do
- [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md) — 6 closed, 1 won't-do

## Acceptance Criteria

- [x] This repo builds without importing Geode storage or planner code.
- [ ] Geode consumes these types externally for vector/spatial/network features. (GAP-0014)
- [x] URL ownership is decided clearly so `advanced-types` and `uri` do not overlap indefinitely.
