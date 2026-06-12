# advanced-types

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.16.0+-orange.svg)](https://ziglang.org/)

Portable value types for network addresses, vectors, geographic coordinates, URLs, and generic ranges. Extracted from Geode for reuse across projects.

## Features

- **Zero Dependencies**: Pure Zig standard library only
- **17 Public Types**: IP addresses, subnets, MACs, vectors, coordinates, URLs, domains, ranges
- **Zero Allocation**: All types are stack-allocated value types
- **Cross-Platform**: Linux, macOS, Windows, aarch64 support
- **322 Tests**: Comprehensive unit, integration, type-extension, parser-edges, performance, and fuzz tests (all suites green on Zig 0.16.0)

## Installation

### Using Zig Package Manager

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .advanced_types = .{
        .url = "https://gitlab.com/devnw/zig/advanced-types/-/archive/v0.1.2/advanced-types-v0.1.2.tar.gz",
        .hash = "...",
    },
},
```

Then in your `build.zig`:

```zig
const advanced_types = b.dependency("advanced_types", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("advanced_types", advanced_types.module("advanced_types"));
```

## API Overview

| Type | Key methods | Contract notes |
| ---- | ----------- | -------------- |
| `Ipv4Addr` / `Ipv6Addr` | `parse`, `format`, `eql`, `isLoopback`, `isMulticast`, `isSafeForOutboundFetch` | `isSafeForOutboundFetch` is an SSRF gate (rejects loopback/private/link-local/CGNAT/multicast/reserved), not a routability check |
| `IpAddr` | `parse`, `format`, `eql`, `isLoopback`, `isMulticast`, `isSafeForOutboundFetch` | Tagged union over v4/v6; `parse` dispatches on `:`; classification methods forward to the active variant |
| `Subnet` | `parse`, `init`, `contains`, `format`, `eql` | `parse`/`init` return `error.InvalidPrefix` for out-of-range prefix; `contains` is defensive (mixed v4/v6 or out-of-range prefix returns `false` rather than panicking) |
| `Mac` | `parse`, `format`, `eql`, `isBroadcast`, `isMulticast`, `isLocallyAdministered` | Accepts `:` and `-` separators; formats uppercase colon-separated |
| `Url` | `parse`, `effectivePort`, `domain`, `eql`, `format` | `effectivePort` returns `0` as a no-known-default sentinel for unknown schemes; component slices borrow the input buffer (caller owns lifetime) |
| `Domain` | `parse`, `labels`, `tld`, `registeredDomain`, `eql`, `format` | ASCII-only per RFC 952/1123; IDN/Punycode out of scope (see SECURITY.md) |
| `LatLon` / `LatLonAlt` / `GeoPoint` | `parse`, `init`, `eql`, `haversineDistance`, `haversineBroadcast` / `HaversineOrigin` | `init` validates coordinate ranges; `HaversineOrigin` precomputes the origin for one-to-many distance loops |
| `Vector(T, N)` / `VectorF32` | `init`, `at`, `get`, `add`, `sub`, `scale`, `dot`, `magnitude`, `normalize`, `distance`, `cosineDistance`, `parse`, `format` | `at` asserts bounds (panics in safe modes); `get` returns `?T`; integer arithmetic wraps in ReleaseFast/ReleaseSmall (see below) |
| `Range(T)` / `IntRange` / `UintRange` / `FloatRange` | `init`, `contains`, `containsRange`, `overlaps`, `intersection`, `union_`, `span`, `parse`, `format` | `init` validates `lower <= upper`; `span` can wrap on extreme integer ranges in unsafe modes (see below); `parse` supports integer element types only |

## Quick Start

```zig
const types = @import("advanced_types");

// Network: parse and classify IP addresses
const ip = try types.Ipv4Addr.parse("192.168.1.1");
const is_private = ip.isPrivate(); // true

// Vectors: similarity search with cosine distance
const a = types.VectorF32.init(.{ 1.0, 0.0, 0.0 });
const b = types.VectorF32.init(.{ 0.9, 0.1, 0.0 });
const dist = a.cosineDistance(b); // ~0.005

// Geographic: haversine distance between coordinates
const sf = try types.LatLon.init(37.7749, -122.4194);
const ny = try types.LatLon.init(40.7128, -74.0060);
const meters = sf.haversineDistance(ny); // ~4,129 km

// URL: zero-allocation parsing
const url = try types.Url.parse("https://api.example.com:8443/v1/data");

// Ranges: interval operations
const r1 = try types.IntRange.init(10, 20);
const r2 = try types.IntRange.init(15, 25);
const overlap = r1.overlaps(r2); // true
```

## Build Modes and Overflow Semantics

Several arithmetic methods rely on Zig's default `+`, `-`, and `*` operators.
In **Debug** and **ReleaseSafe** modes the compiler inserts safety checks and
integer overflow causes an `IntegerOverflow` panic. In **ReleaseFast** and
**ReleaseSmall** modes those checks are elided, so overflow wraps modulo
`2^bits` with defined two's-complement behavior.

Methods affected:

- `Vector.add`, `Vector.sub`, `Vector.scale`, `Vector.dot`, and
  `Vector.magnitudeSquared` on integer vectors (e.g. `VectorI32`).
- `Range(T).span` for integer element types (e.g. `IntRange`) when
  `end - start` exceeds the representable range.

Floating-point analogues (`VectorF32`, `FloatRange`) are unaffected; IEEE-754
behavior is the same across all modes.

If you need guaranteed trapping on overflow in release builds, build with
`-Doptimize=ReleaseSafe`. If you rely on wrapping, operate on unsigned types
or pre-check the inputs.

## Requirements

- Zig 0.16.0 or later

## Building

```bash
# Build the library
make build

# Run tests
make test

# Quick development iteration
make dev

# Full CI pipeline
make ci
```

## Documentation

See the [docs](docs/) directory for detailed documentation.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for security policy and vulnerability reporting.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
