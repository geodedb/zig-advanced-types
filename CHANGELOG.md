# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.4] - 2026-06-12

### Fixed

- CI bench gate: baselines now cover observed CI runner values, and the bench
  job is pinned to the dedicated x86 runner class (the company pool is
  performance-heterogeneous, ~2.5x between classes) -- the v0.1.3 tag pipeline
  failed its bench gate when scheduled onto the slower class.
- CI coverage job uses the official `kcov/kcov` image (kcov is packaged in
  neither Debian bookworm nor Ubuntu noble).

## [0.1.3] - 2026-06-12

### Changed

- `Subnet.parse` now returns `error.InvalidPrefix` (was `error.Overflow`) for
  an out-of-range prefix length, matching `Subnet.init`
- `Mac.format` writes via a single buffered `writeAll` instead of six
  `std.fmt` dispatches (~8x faster: ~6.7 ns/op vs 57.4 ns/op baseline)
- Benchmark harness de-hoisted (opaque per-iteration inputs) and all 12
  benchmarks re-baselined

### Added

- `IpAddr.isLoopback`, `IpAddr.isMulticast`, and
  `IpAddr.isSafeForOutboundFetch` forwarding to the active v4/v6 variant
- `-Dtest-filter` build option for running a subset of tests
- `IntRange`/`UintRange` parse fuzz targets (`Range.parse` is integer-only,
  so `FloatRange` has no parse path to fuzz)
- Regression test asserting the documented `Range.span` wrap behavior in
  unsafe build modes
- Build-time version-drift guard keeping `root.zig` and `build.zig.zon` in sync
- `ci/zig-sha256.lock` committed SHA-256 verification of the CI Zig toolchain
- `LatLonAlt.parse` and `GeoPoint.parse` benchmark coverage
- Network types: `Ipv4Addr`, `Ipv6Addr`, `IpAddr`, `Subnet`, `Mac`
- Vector types: `Vector(T, N)`, `VectorF32`, `VectorI32` with distance metrics
- Geographic types: `LatLon`, `LatLonAlt`, `GeoPoint` with haversine distance
- URL/domain types: `Url`, `Domain` with zero-allocation parsing
- Range types: `Range(T)`, `IntRange`, `UintRange`, `FloatRange`
- 322 tests (265 unit incl. 1 skip + 9 integration + 11 extension +
  16 parser-edges + 9 performance + 12 fuzz)
- CI/CD pipeline with SAST, dependency scanning, cross-compilation
- Documentation and gap analysis tracking

### Fixed

- `version` constant in `root.zig` synced to 0.1.2 (was stale at 0.1.0)
- Release tag-signing job fails closed and asserts the signed tag points at
  the pipeline commit
- `detect_diamond_deps.py` validates the package-hash charset before using it
  in a filesystem path

[Unreleased]: https://gitlab.com/devnw/zig/advanced-types/-/compare/v0.1.4...HEAD
[0.1.4]: https://gitlab.com/devnw/zig/advanced-types/-/compare/v0.1.3...v0.1.4
[0.1.3]: https://gitlab.com/devnw/zig/advanced-types/-/compare/v0.1.2...v0.1.3
