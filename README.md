# advanced-types

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.15.1+-orange.svg)](https://ziglang.org/)

Portable value types for network addresses, vectors, geographic coordinates, URLs, and generic ranges. Extracted from Geode for reuse across projects.

## Features

- **Zero Dependencies**: Pure Zig standard library only
- **17 Public Types**: IP addresses, subnets, MACs, vectors, coordinates, URLs, domains, ranges
- **Zero Allocation**: All types are stack-allocated value types
- **Cross-Platform**: Linux, macOS, Windows, aarch64 support
- **230 Tests**: Comprehensive unit and integration tests

## Installation

### Using Zig Package Manager

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .advanced_types = .{
        .url = "https://gitlab.com/devnw/zig/advanced-types/-/archive/v0.1.0/advanced-types-v0.1.0.tar.gz",
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

## Requirements

- Zig 0.15.1 or later

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
