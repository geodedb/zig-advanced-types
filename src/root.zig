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
//! ## License
//!
//! Apache-2.0

const std = @import("std");

/// Library version
pub const version = "0.1.0";

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
