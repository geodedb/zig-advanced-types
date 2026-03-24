# GAP Analysis — Resolved Items

Items closed on 2026-03-23 during initial type implementation.

## Closed

### GAP-1: URL/domain logic overlaps the existing external `uri` dependency

- **Original impact:** Risk of two competing URL libraries
- **Decision:** `Url` and `Domain` stay in `advanced-types` as standalone value types. `uri` remains the RFC 3986 parser. `Url` provides simplified value-type parsing; `Domain` validates domain names. No dependency introduced.
- **Evidence:** `src/types/url.zig` — 57 unit tests passing, no imports from `uri`.

### GAP-3: Geographic file mixes simple value types with a large helper surface

- **Original impact:** API may grow too wide if moved blindly
- **Decision:** Core types only (`LatLon`, `LatLonAlt`, `GeoPoint`) with essential ops (haversine, validation, parsing). `st_*` query helpers staged for later.
- **Evidence:** `src/types/geographic.zig` — 35 unit tests, no query-layer helpers included.

### GAP-4: `range.zig` depends on local date support

- **Original impact:** Affects package closure
- **Decision:** `DateRange` trimmed. Ships `Range(T)` generic + `IntRange`, `UintRange`, `FloatRange`. `DateRange` deferred until a datetime package is available.
- **Evidence:** `src/types/range.zig` — 52 unit tests, no datetime dependency.

## Closed on 2026-03-23 — Audit Gap Closure

### GAP-0005: README Quick Start shows nonexistent `init()` function
- **Fix:** Replaced with working Quick Start demonstrating IP parsing, vectors, geographic distance, URL parsing, and range operations.

### GAP-0006: Archive/issue URLs use underscores instead of hyphens
- **Fix:** Corrected all GitLab URLs in README.md, SUPPORT.md, CHANGELOG.md from `advanced_types` to `advanced-types`.

### GAP-0007: examples/basic.zig does not import or use the library
- **Fix:** Rewrote to `@import("advanced_types")` and demonstrate all 5 type families. Added `example` build step to `build.zig`.

### GAP-0008: docs/README.md links to 5 nonexistent pages
- **Fix:** Replaced dead links with links to actual documentation files (REQUIREMENTS.md, GAP_ANALYSIS.md, etc.).

### GAP-0009: CODEOWNERS contains placeholder @your-username
- **Fix:** Updated to `@benjiv`.

### GAP-0010: CHANGELOG.md has placeholder release date
- **Fix:** Removed placeholder `[0.1.0] - YYYY-MM-DD` section; consolidated content into `[Unreleased]`.

### Security findings closed (S1-S6)
- **S1:** Vector.parse Inf/NaN — added validation after `parseFloat`
- **S2:** FloatRange NaN bounds — added NaN/Inf check in `Range.init()` for float types
- **S3:** Vector.at() panic — added `get()` returning `?T` as safe alternative
- **S4:** Integer overflow docs — added doc comments to `add`/`sub`/`scale`/`dot`
- **S5:** LatLonAlt altitude NaN/Inf — added validation in `init()`
- **S6:** Range.span() overflow — added doc comment warning

### Quality findings closed (Q1-Q8, Q11, Q13)
- **Q1:** Vector.format writer signature — changed to `anytype`
- **Q2:** network.zig doc comments — added to all public API
- **Q3:** docs/README.md dead links — fixed
- **Q4:** examples/basic.zig — rewrote with real API usage
- **Q5:** Duplicate hex parsers — unified into `hexDigitToInt`
- **Q6:** Vector.format dead branch — removed
- **Q7:** Geographic custom helpers — replaced with `std.mem.*`
- **Q8:** Range.isEmpty misleading — renamed to `isPoint()`
- **Q11:** CI Zig version mismatch — updated to 0.15.2
- **Q13:** Example build step — added to build.zig

### Performance findings closed (P2, P3)
- **P2:** CI ReleaseFast target — added `test-release-fast` job
- **P3:** cosineDistance 3-pass — fused into single-pass loop

## Closed on 2026-03-23 — Second Gap Closure Pass

### GAP-0011: No code coverage measurement configured
- **Fix:** Added `make coverage` and `make fuzz` targets to Makefile. LLVM coverage tools (llvm-cov, llvm-profdata) are available for report generation.

### GAP-0012: AT-TEST-002 cross-feature type-extension tests not ported
- **Fix:** Created `tests/type_extensions.zig` with 11 cross-feature tests covering: IPv4 u32 roundtrip, IPv6 mapped detection, IpAddr auto-detection, subnet containment, LatLonAlt->LatLon conversion, GeoPoint interop, format/parse roundtrips (Vector, LatLon, Mac), range intersection symmetry, URL->Domain extraction.
- **Evidence:** `zig build test-extensions` — 11/11 passing. GitLab issue #11 closed.

### GAP-0013: AT-TEST-003 integration/performance tests not ported
- **Fix:** Created `tests/performance.zig` with 9 dataset integration and performance tests covering: bulk IPv4 parsing (100 valid, 100 invalid), bulk haversine (50 pairs), bulk cosine distance (50 pairs), mixed record parsing (20 rows), subnet classification (5 subnets x 20 IPs), URL batch parsing (20 URLs), range overlap detection (20 ranges), vector similarity search (10 candidates x 5 queries).
- **Evidence:** `zig build test-performance` — 9/9 passing. GitLab issue #12 closed.

### GAP-0018: No fuzzing or property-based testing for parsers
- **Fix:** Created `tests/fuzz.zig` with 10 fuzz targets (one per parser: Ipv4Addr, Ipv6Addr, IpAddr, Subnet, Mac, Url, Domain, LatLon, LatLonAlt, VectorF32). Uses Zig 0.15 `std.testing.fuzz` API. Continuous fuzzing available via `zig build test-fuzz --fuzz` or `make fuzz`.
- **Evidence:** `zig build test-fuzz` — 10/10 passing.

## Won't Do

### GAP-2: `hash.zig` is still tied to Geode internals

- **Original impact:** Prevents a clean "all advanced types" extraction
- **Reason:** `hash.zig` aliases heap/storage types that are Geode-internal. Not a portable value type. May be split into a dedicated package in a future effort.
