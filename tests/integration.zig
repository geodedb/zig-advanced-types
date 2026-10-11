// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Integration tests for advanced-types
//!
//! These tests verify cross-module interactions and end-to-end workflows
//! that exercise multiple type families together.

const std = @import("std");
const lib = @import("advanced_types");

// ============================================================================
// Library smoke tests
// ============================================================================

test "integration: version is defined" {
    try std.testing.expectEqualStrings("0.1.6", lib.version);
}

test "integration: all public types are accessible" {
    // Network
    _ = lib.Ipv4Addr;
    _ = lib.Ipv6Addr;
    _ = lib.IpAddr;
    _ = lib.Subnet;
    _ = lib.Mac;

    // Vector
    _ = lib.VectorF32;
    _ = lib.VectorI32;
    _ = lib.Vector;

    // Geographic
    _ = lib.LatLon;
    _ = lib.LatLonAlt;
    _ = lib.GeoPoint;

    // URL
    _ = lib.Url;
    _ = lib.Domain;

    // Range
    _ = lib.Range;
    _ = lib.IntRange;
    _ = lib.UintRange;
    _ = lib.FloatRange;
}

// ============================================================================
// Cross-module: network + geographic
// ============================================================================

test "integration: parse network and geographic data from a mixed dataset" {
    // Simulate parsing a row: IP address + location
    const ip = try lib.Ipv4Addr.parse("93.184.216.34");
    const loc = try lib.LatLon.init(51.5074, -0.1278); // London

    try std.testing.expectEqual(@as(u8, 93), ip.octets[0]);
    try std.testing.expect(loc.lat > 51.0 and loc.lat < 52.0);
}

// ============================================================================
// Cross-module: vector + geographic
// ============================================================================

test "integration: convert geographic coordinates to vector for distance" {
    const sf = try lib.LatLon.init(37.7749, -122.4194);
    const ny = try lib.LatLon.init(40.7128, -74.0060);

    // Haversine ground-truth distance
    const geo_dist = sf.haversineDistance(ny);

    // Also representable as 2D vectors for Euclidean approximation in degree-space
    const v_sf = lib.Vector(f64, 2).init(.{ sf.lat, sf.lon });
    const v_ny = lib.Vector(f64, 2).init(.{ ny.lat, ny.lon });
    const degree_dist = v_sf.distance(v_ny);

    // Haversine should be in the ~4,000 km range
    try std.testing.expect(geo_dist > 4_000_000 and geo_dist < 4_200_000);
    // Degree-space euclidean should be in the ~50 degrees range
    try std.testing.expect(degree_dist > 40.0 and degree_dist < 60.0);
}

// ============================================================================
// Cross-module: range + network
// ============================================================================

test "integration: IP address u32 within a numeric range" {
    const ip_low = lib.Ipv4Addr.parse("10.0.0.0") catch unreachable;
    const ip_high = lib.Ipv4Addr.parse("10.0.0.255") catch unreachable;
    const ip_test = lib.Ipv4Addr.parse("10.0.0.42") catch unreachable;
    const ip_outside = lib.Ipv4Addr.parse("10.0.1.0") catch unreachable;

    const r = try lib.Range(u32).init(ip_low.toU32(), ip_high.toU32());
    try std.testing.expect(r.contains(ip_test.toU32()));
    try std.testing.expect(!r.contains(ip_outside.toU32()));
}

// ============================================================================
// Cross-module: subnet containment
// ============================================================================

test "integration: subnet contains parsed IPs" {
    const subnet = try lib.Subnet.parse("192.168.1.0/24");
    const inside = try lib.IpAddr.parse("192.168.1.100");
    const outside = try lib.IpAddr.parse("192.168.2.1");

    try std.testing.expect(subnet.contains(inside));
    try std.testing.expect(!subnet.contains(outside));
}

// ============================================================================
// Cross-module: URL domain parsing
// ============================================================================

test "integration: extract domain from URL and validate" {
    const parsed_url = try lib.Url.parse("https://api.example.com:8443/v1/data?key=val");

    try std.testing.expectEqualStrings("https", parsed_url.scheme);
    try std.testing.expectEqualStrings("api.example.com", parsed_url.host);
    try std.testing.expectEqual(@as(u16, 8443), parsed_url.port.?);

    // Extract domain from URL's host
    const dom = try lib.Domain.parse(parsed_url.host);
    try std.testing.expectEqualStrings("com", dom.tld().?);
    try std.testing.expectEqualStrings("example.com", dom.registeredDomain().?);
}

// ============================================================================
// Cross-module: vector distance metrics
// ============================================================================

test "integration: vector similarity search workflow" {
    const query = lib.VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const candidates = [_]lib.VectorF32{
        lib.VectorF32.init(.{ 1.0, 0.1, 0.0 }), // very similar
        lib.VectorF32.init(.{ 0.0, 1.0, 0.0 }), // orthogonal
        lib.VectorF32.init(.{ -1.0, 0.0, 0.0 }), // opposite
    };

    // Find closest by cosine distance
    var best_idx: usize = 0;
    var best_dist: f32 = candidates[0].cosineDistance(query);
    for (candidates[1..], 1..) |c, i| {
        const d = c.cosineDistance(query);
        if (d < best_dist) {
            best_dist = d;
            best_idx = i;
        }
    }

    try std.testing.expectEqual(@as(usize, 0), best_idx); // first candidate is closest
    try std.testing.expect(best_dist < 0.01); // very close to 0
}

// ============================================================================
// Cross-module: range overlap detection
// ============================================================================

test "integration: range operations for interval scheduling" {
    const meeting1 = try lib.IntRange.init(900, 1030); // 9:00-10:30
    const meeting2 = try lib.IntRange.init(1000, 1100); // 10:00-11:00
    const meeting3 = try lib.IntRange.init(1100, 1200); // 11:00-12:00

    try std.testing.expect(meeting1.overlaps(meeting2));
    try std.testing.expect(!meeting1.overlaps(meeting3));

    const conflict = meeting1.intersection(meeting2);
    try std.testing.expect(conflict != null);
    try std.testing.expectEqual(@as(i64, 1000), conflict.?.lower);
    try std.testing.expectEqual(@as(i64, 1030), conflict.?.upper);
}
