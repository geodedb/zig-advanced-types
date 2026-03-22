# GAP Analysis

Last updated: 2026-03-21

Repository status: bootstrapped from `../zig-template`; no Geode code has been moved yet.

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

| Gap | Evidence | Impact | Required fix |
|---|---|---|---|
| URL/domain logic overlaps the existing external `uri` dependency | Geode already imports `uri` via `build.zig:119` while also defining `src/types/url.zig:3` | Risk of two competing URL libraries | Decide whether `Url`/`Domain` stay here or are merged into `uri` |
| `hash.zig` is still tied to Geode internals | `src/types/hash.zig:4`, `:5`, `:6` alias `heap` types | Prevents a clean “all advanced types” extraction | Leave hashing local or split it into a later dedicated package |
| Geographic file mixes simple value types with a large helper surface | `src/types/geographic.zig:511` through `:688` adds many `st_*` helpers | API may grow too wide if moved blindly | Decide whether to keep only core types first and stage higher-level helpers later |
| `range.zig` depends on local date support | `src/types/range.zig:125` aliases `DateRange` via `datetime.zig` | Affects package closure | Either include the minimal date type dependency or trim `DateRange` initially |

## Tests And Benchmarks To Carry Over

| Geode test / benchmark | Coverage provided |
|---|---|
| `src/types/network.zig:188` | Network type integration sanity check |
| `src/types/vector.zig:518`, `:549`, `:576`, `:613` | Vector parsing, math, encoding, and error handling |
| `src/types/geographic.zig:733`, `:767`, `:793`, `:810`, `:839` | Geographic parsing, math, encoding, and validation |
| `src/types/url.zig:198`, `:212` | URL normalization and domain parsing |
| `src/types/range.zig:127` | Range behavior |
| `tests/test_type_extensions.zig:8`, `:22`, `:36`, `:50`, `:76`, `:90`, `:167`, `:182`, `:200`, `:215`, `:231` | Cross-feature type coverage |
| `tests/integration/dataset_integration_test.zig:125`, `:171`, `:203` | Dataset-level network, geographic, and vector flows |
| `tests/integration/test_geographic_mapping.zig:614` | Geographic query performance reference |
| `tests/integration/test_index_performance.zig:112`, `:174` | Vector and spatial performance references |

## Proposed Public API

Initial public surface should export:

- `IpAddr`
- `Subnet`
- `Mac`
- `VectorF32`
- `VectorI32`
- `LatLon`
- `LatLonAlt`
- `GeoPoint`
- `Url`
- `Domain`
- `Range`
- `IntRange`

The library should avoid exposing Geode-specific index wrappers or hash/storage types.

## Extraction Plan

1. Move the five portable type families into this repo.
2. Decide whether `Url`/`Domain` converge with `uri` before locking the API.
3. Leave `hash.zig` behind initially.
4. Port the source-level tests and the Geode integration tests listed above.
5. Update Geode index wrappers to consume these types from this repo.

## Acceptance Criteria

- This repo builds without importing Geode storage or planner code.
- Geode consumes these types externally for vector/spatial/network features.
- URL ownership is decided clearly so `advanced-types` and `uri` do not overlap indefinitely.
