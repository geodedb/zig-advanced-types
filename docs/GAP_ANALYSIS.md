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
| Unit tests (`zig build test`) | 248 | Passing |
| Integration tests (`zig build test-integration`) | 9 | Passing |
| Type-extension tests (`zig build test-extensions`) | 11 | Passing |
| Performance tests (`zig build test-performance`) | 9 | Passing |
| Parser-edges tests (`zig build test-parser-edges`) | 16 | Passing (new; Q33) |
| Fuzz tests (`zig build test-fuzz`) | 10 | Passing (ported to Zig 0.16 Smith API; GAP-0020) |
| **Total runnable** | **303** | **All passing** |

## Gaps (from audit 2026-03-23; refreshed 2026-04-18)

| Gap-ID | Finding | Severity | Status | Category | Issue |
|--------|---------|----------|--------|----------|-------|
| GAP-0005 | README Quick Start shows nonexistent `init()` function | High | **Closed** | Docs | — |
| GAP-0006 | Archive/issue URLs use underscores instead of hyphens | High | **Closed** | Docs | — |
| GAP-0007 | examples/basic.zig does not import or use the library | Medium | **Closed** | Docs | — |
| GAP-0008 | docs/README.md links to 5 nonexistent pages | Medium | **Closed** | Docs | — |
| GAP-0009 | CODEOWNERS contains placeholder @your-username | Low | **Closed** | Quality | — |
| GAP-0010 | CHANGELOG.md has placeholder release date | Low | **Closed** | Docs | — |
| GAP-0011 | No code coverage measurement in CI | Medium | **Closed (report-only)** 2026-04-18 — kcov job added (`20b233c`); see `docs/audit/gap-close-blockers.md` for percentage-gate follow-up | CI/CD | [#30](https://gitlab.com/devnw/zig/advanced-types/-/issues/30) |
| GAP-0012 | AT-TEST-002 cross-feature type-extension tests not ported | Medium | **Closed** | Test | — |
| GAP-0013 | AT-TEST-003 integration/performance tests not ported | Medium | **Closed** | Test | — |
| GAP-0014 | Wire Geode to consume types from this package | High | **Blocked** (external dep — Geode repo) | Requirement | — |
| GAP-0015 | DateRange deferred — blocked on datetime package | Low | **Blocked** (external dep — datetime package) | Feature | — |
| GAP-0016 | Geographic st_* helpers staged for future release | Low | **Deferred** | Feature | — |
| GAP-0017 | Port Geode integration tests for type consumption | Medium | **Blocked** (external dep — Geode repo) | Test | — |
| GAP-0018 | Fuzz suite broken under Zig 0.16 (superseded by GAP-0020) | Critical | **Closed** 2026-04-18 — fuzz suite ported (`c0e07ee`) | Test | [#32](https://gitlab.com/devnw/zig/advanced-types/-/issues/32) |
| GAP-0019 | AT-NFR-003 — CI is Linux/x86_64 only; refutes README cross-platform claim | Critical | **Partial** 2026-04-18 — YAML jobs added w/ `allow_failure:true` (`505fe43`); dormant pending runner provisioning; see `docs/audit/gap-close-blockers.md` | Compliance | [#23](https://gitlab.com/devnw/zig/advanced-types/-/issues/23) |
| GAP-0020 | `tests/fuzz.zig` does not compile under Zig 0.16 (`std.testing.fuzz` signature change) | Critical | **Closed** 2026-04-18 — ported to Zig 0.16 Smith API (`c0e07ee`); 10/10 green | Testing | [#24](https://gitlab.com/devnw/zig/advanced-types/-/issues/24) |
| GAP-0021 | `test-extensions`, `test-performance` not in CI; `test-integration` missing ReleaseSmall | High | **Closed** 2026-04-18 — CI jobs added for test-extensions/test-performance + ReleaseSmall (`a5abd3e`) | CI/CD | [#25](https://gitlab.com/devnw/zig/advanced-types/-/issues/25) |
| GAP-0022 | Test-count drift: README 230 vs GAP_ANALYSIS 272 vs actual 262 | Low | **Closed** 2026-04-18 — reconciled to 303 across README + all ledgers (`3702dd1`) | Docs | [#27](https://gitlab.com/devnw/zig/advanced-types/-/issues/27) |

## Related Audit Documents

- [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md) — 18 closed, 2 won't-do, 20 ledger-only, 1 accepted
- [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md) — 6 closed, 2 monitor, 10 won't-do
- [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md) — 12 closed, 2 won't-do

## Acceptance Criteria

- [x] This repo builds without importing Geode storage or planner code.
- [ ] Geode consumes these types externally for vector/spatial/network features. (GAP-0014)
- [x] URL ownership is decided clearly so `advanced-types` and `uri` do not overlap indefinitely.
