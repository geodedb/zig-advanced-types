# Requirements

Last updated: 2026-03-21

## Functional Requirements

| ID | Requirement | Geode evidence |
|---|---|---|
| AT-REQ-001 | The library SHALL expose reusable network types and helpers. | `src/types/network.zig:5`, `:6`, `:7`, `:21`, `:70`, `:140` |
| AT-REQ-002 | The library SHALL expose floating-point and integer vector types with distance operations. | `src/types/vector.zig:8`, `:67`, `:315`, `:374` |
| AT-REQ-003 | The library SHALL expose geographic value types and core distance helpers. | `src/types/geographic.zig:8`, `:69`, `:167`, `:277`, `:380` |
| AT-REQ-004 | The library SHALL expose URL and domain parsing/formatting or explicitly defer that responsibility to `uri`. | `src/types/url.zig:3`, `:16`, `:151`, `:159`; overlap evidence `build.zig:119` |
| AT-REQ-005 | The library SHALL expose generic range support. | `src/types/range.zig:3`, `:40`, `:57`, `:124`, `:125` |
| AT-REQ-006 | The library SHALL NOT depend on Geode heap/storage hash types in its initial extraction. | `src/types/hash.zig:4`, `:5`, `:6` stay out of scope |

## Packaging Requirements

| ID | Requirement | Geode evidence |
|---|---|---|
| AT-PKG-001 | URL/domain ownership SHALL be resolved so this repo does not permanently duplicate the `uri` library. | `build.zig:119`, `src/types/url.zig:3` |
| AT-PKG-002 | Any required date/time support for `DateRange` SHALL be explicit. | `src/types/range.zig:125` |
| AT-PKG-003 | Geode-specific index wrappers SHALL remain outside this repo. | vector/spatial wrappers live under `src/index/*` |

## Test Requirements

| ID | Requirement | Geode evidence |
|---|---|---|
| AT-TEST-001 | Port source-level tests for network, vector, geographic, URL, and range types. | `src/types/network.zig:188`, `src/types/vector.zig:518`, `:549`, `:576`, `:613`, `src/types/geographic.zig:733`, `:767`, `:793`, `:810`, `:839`, `src/types/url.zig:198`, `:212`, `src/types/range.zig:127` |
| AT-TEST-002 | Preserve cross-feature type-extension coverage. | `tests/test_type_extensions.zig:8`, `:22`, `:36`, `:50`, `:76`, `:90`, `:167`, `:182`, `:200`, `:215`, `:231` |
| AT-TEST-003 | Preserve representative integration and performance coverage. | `tests/integration/dataset_integration_test.zig:125`, `:171`, `:203`, `tests/integration/test_geographic_mapping.zig:614`, `tests/integration/test_index_performance.zig:112`, `:174` |

## Documentation Requirements

- Provide one example for vector math.
- Provide one example for geographic distance/proximity.
- Provide one example for network parsing.
- Clearly document whether URL/domain support lives here or in `uri`.

## Migration Requirements

1. Extract the portable type modules first.
2. Keep Geode-specific index wrappers in Geode.
3. Revisit `hash.zig` only after its type aliases are detached from Geode internals.
