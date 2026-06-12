// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! # advanced-types
//!
//! Portable value types for network addresses, vectors, geographic
//! coordinates, URLs, and generic ranges.
//!
//! ## Quick Start
//!
//! ```zig
//! const types = @import("advanced_types");
//!
//! const ip = try types.Ipv4Addr.parse("192.168.1.1");
//! const coord = try types.LatLon.init(37.7749, -122.4194);
//! const v = types.VectorF32.init(.{ 1.0, 2.0, 3.0 });
//! ```
//!
//! ## Build Modes and Overflow Semantics
//!
//! Integer arithmetic on `Vector` (`add`, `sub`, `scale`, `dot`,
//! `magnitudeSquared`) and `Range.span` uses the default `+`/`-`/`*`
//! operators. Debug and ReleaseSafe panic on overflow; ReleaseFast and
//! ReleaseSmall wrap with defined two's-complement semantics. See
//! `README.md` ("Build Modes and Overflow Semantics") for details.
//!
//! ## License
//!
//! Apache-2.0

const std = @import("std");

/// Library version
pub const version = "0.1.2";

// ============================================================================
// Type modules
// ============================================================================

pub const network = @import("types/network.zig");
pub const vector = @import("types/vector.zig");
pub const geographic = @import("types/geographic.zig");
pub const url = @import("types/url.zig");
pub const range = @import("types/range.zig");

// ============================================================================
// Convenience re-exports — network types
// ============================================================================

pub const Ipv4Addr = network.Ipv4Addr;
pub const Ipv6Addr = network.Ipv6Addr;
pub const IpAddr = network.IpAddr;
pub const Subnet = network.Subnet;
pub const Mac = network.Mac;

// ============================================================================
// Convenience re-exports — vector types
// ============================================================================

pub const Vector = vector.Vector;
pub const VectorF32 = vector.VectorF32;
pub const VectorI32 = vector.VectorI32;

// ============================================================================
// Convenience re-exports — geographic types
// ============================================================================

pub const LatLon = geographic.LatLon;
pub const LatLonAlt = geographic.LatLonAlt;
pub const GeoPoint = geographic.GeoPoint;

// ============================================================================
// Convenience re-exports — URL / domain types
// ============================================================================

pub const Url = url.Url;
pub const Domain = url.Domain;

// ============================================================================
// Convenience re-exports — range types
// ============================================================================

pub const Range = range.Range;
pub const IntRange = range.IntRange;
pub const UintRange = range.UintRange;
pub const FloatRange = range.FloatRange;

// ============================================================================
// Unit Tests
// ============================================================================

test {
    // Pull in tests from all submodules
    std.testing.refAllDecls(@This());
}

// ============================================================================
// Doc Examples (Q32) -- compiled mirrors of the `//!` module doc at the top
// of this file and the Quick-Start block in README.md. They exist so that
// drift between the documentation and the public API surfaces as a build
// failure rather than a silent stale code sample.
// ============================================================================

test "doc-example-root-quickstart" {
    // Mirrors the `//!` Quick Start block.
    const ip = try Ipv4Addr.parse("192.168.1.1");
    try std.testing.expectEqualSlices(u8, &.{ 192, 168, 1, 1 }, &ip.octets);

    const coord = try LatLon.init(37.7749, -122.4194);
    try std.testing.expect(coord.lat > 37.0);

    const v = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), v.data[1], 1e-6);
}

test "doc-example-readme-quickstart" {
    // Mirrors README.md "Quick Start" fenced zig block.
    const ip = try Ipv4Addr.parse("192.168.1.1");
    try std.testing.expect(ip.isPrivate());

    const a = VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = VectorF32.init(.{ 0.9, 0.1, 0.0 });
    const dist = a.cosineDistance(b);
    try std.testing.expect(dist >= 0.0 and dist < 0.1);

    const sf = try LatLon.init(37.7749, -122.4194);
    const ny = try LatLon.init(40.7128, -74.0060);
    const meters = sf.haversineDistance(ny);
    try std.testing.expect(meters > 4_000_000.0 and meters < 4_200_000.0);

    _ = try Url.parse("https://api.example.com:8443/v1/data");

    const r1 = try IntRange.init(10, 20);
    const r2 = try IntRange.init(15, 25);
    try std.testing.expect(r1.overlaps(r2));
}
