# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Network types: `Ipv4Addr`, `Ipv6Addr`, `IpAddr`, `Subnet`, `Mac`
- Vector types: `Vector(T, N)`, `VectorF32`, `VectorI32` with distance metrics
- Geographic types: `LatLon`, `LatLonAlt`, `GeoPoint` with haversine distance
- URL/domain types: `Url`, `Domain` with zero-allocation parsing
- Range types: `Range(T)`, `IntRange`, `UintRange`, `FloatRange`
- 304 tests (249 unit + 9 integration + 11 extension + 16 parser-edges + 9 performance + 10 fuzz)
- CI/CD pipeline with SAST, dependency scanning, cross-compilation
- Documentation and gap analysis tracking

[Unreleased]: https://gitlab.com/devnw/zig/advanced-types/-/compare/main...HEAD
