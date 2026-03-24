// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! AT-TEST-002: Cross-feature type-extension coverage
//!
//! Tests that exercise type conversions, roundtrip formatting/parsing,
//! and interop between different type families in the advanced-types library.

const std = @import("std");
const lib = @import("advanced_types");
const testing = std.testing;

// ============================================================================
// 1. IPv4 -> u32 -> IPv4 roundtrip
// ============================================================================

test "type_ext: IPv4 -> u32 -> IPv4 roundtrip" {
    const original = try lib.Ipv4Addr.parse("192.168.1.1");
    const as_u32 = original.toU32();
    const restored = lib.Ipv4Addr.fromU32(as_u32);
    try testing.expect(original.eql(restored));

    // Verify the u32 value is the expected big-endian encoding
    // 192 << 24 | 168 << 16 | 1 << 8 | 1 = 0xC0A80101
    try testing.expectEqual(@as(u32, 0xC0A80101), as_u32);
}

// ============================================================================
// 2. IPv6 -> IPv4 mapped detection
// ============================================================================

test "type_ext: IPv6 -> IPv4 mapped detection" {
    const v6 = try lib.Ipv6Addr.parse("::ffff:c0a8:0101");
    const maybe_v4 = v6.toIpv4();
    try testing.expect(maybe_v4 != null);

    const v4 = maybe_v4.?;
    const expected = lib.Ipv4Addr.init(192, 168, 1, 1);
    try testing.expect(v4.eql(expected));
}

// ============================================================================
// 3. IpAddr auto-detection
// ============================================================================

test "type_ext: IpAddr auto-detection v4 vs v6" {
    const addr_v4 = try lib.IpAddr.parse("10.0.0.1");
    switch (addr_v4) {
        .v4 => |v4| {
            try testing.expectEqual(@as(u8, 10), v4.octets[0]);
            try testing.expectEqual(@as(u8, 0), v4.octets[1]);
            try testing.expectEqual(@as(u8, 0), v4.octets[2]);
            try testing.expectEqual(@as(u8, 1), v4.octets[3]);
        },
        .v6 => return error.TestUnexpectedResult,
    }

    const addr_v6 = try lib.IpAddr.parse("::1");
    switch (addr_v6) {
        .v4 => return error.TestUnexpectedResult,
        .v6 => |v6| {
            // ::1 should be the loopback address
            try testing.expect(v6.isLoopback());
        },
    }
}

// ============================================================================
// 4. Subnet contains with IpAddr
// ============================================================================

test "type_ext: subnet contains with IpAddr" {
    const subnet = try lib.Subnet.parse("10.0.0.0/8");
    const inside = try lib.IpAddr.parse("10.255.255.254");
    const outside = try lib.IpAddr.parse("11.0.0.1");

    try testing.expect(subnet.contains(inside));
    try testing.expect(!subnet.contains(outside));

    // Also verify a boundary address
    const boundary = try lib.IpAddr.parse("10.0.0.0");
    try testing.expect(subnet.contains(boundary));
}

// ============================================================================
// 5. LatLonAlt -> LatLon conversion
// ============================================================================

test "type_ext: LatLonAlt -> LatLon conversion preserves lat/lon" {
    const lla = try lib.LatLonAlt.init(48.8566, 2.3522, 35.0);
    const ll = lla.toLatLon();

    try testing.expectApproxEqAbs(@as(f64, 48.8566), ll.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 2.3522), ll.lon, 1e-10);

    // Confirm LatLonAlt retained its altitude
    try testing.expectApproxEqAbs(@as(f64, 35.0), lla.alt, 1e-10);
}

// ============================================================================
// 6. GeoPoint variant interop
// ============================================================================

test "type_ext: GeoPoint 2D/3D interop with haversine" {
    const paris_2d = lib.GeoPoint{ .point_2d = try lib.LatLon.init(48.8566, 2.3522) };
    const london_3d = lib.GeoPoint{ .point_3d = try lib.LatLonAlt.init(51.5074, -0.1278, 11.0) };

    const distance = paris_2d.haversineDistance(london_3d);

    // Paris to London is roughly 340 km; allow 10 km tolerance
    try testing.expect(distance > 330_000.0 and distance < 350_000.0);

    // Verify symmetry
    const reverse_distance = london_3d.haversineDistance(paris_2d);
    try testing.expectApproxEqAbs(distance, reverse_distance, 1e-6);
}

// ============================================================================
// 7. Vector format/parse roundtrip
// ============================================================================

test "type_ext: VectorF32 format/parse roundtrip" {
    const original = lib.VectorF32.init(.{ 3.14, -2.718, 1.618 });
    var buf: [256]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try lib.VectorF32.parse(formatted);

    for (original.data, parsed.data) |a, b| {
        try testing.expectApproxEqAbs(a, b, 1e-3);
    }
}

// ============================================================================
// 8. LatLon format/parse roundtrip
// ============================================================================

test "type_ext: LatLon format/parse roundtrip" {
    const original = try lib.LatLon.init(37.7749, -122.4194);
    var buf: [128]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try lib.LatLon.parse(formatted);

    try testing.expectApproxEqAbs(original.lat, parsed.lat, 1e-4);
    try testing.expectApproxEqAbs(original.lon, parsed.lon, 1e-4);
}

// ============================================================================
// 9. Range intersection symmetry
// ============================================================================

test "type_ext: Range intersection symmetry" {
    const a = try lib.IntRange.init(5, 15);
    const b = try lib.IntRange.init(10, 20);

    const ab = a.intersection(b);
    const ba = b.intersection(a);

    try testing.expect(ab != null);
    try testing.expect(ba != null);
    try testing.expect(ab.?.eql(ba.?));

    // Verify the intersection bounds
    try testing.expectEqual(@as(i64, 10), ab.?.lower);
    try testing.expectEqual(@as(i64, 15), ab.?.upper);

    // Also check non-overlapping case is symmetric
    const c = try lib.IntRange.init(100, 200);
    try testing.expect(a.intersection(c) == null);
    try testing.expect(c.intersection(a) == null);
}

// ============================================================================
// 10. URL -> Domain extraction
// ============================================================================

test "type_ext: URL -> Domain extraction with TLD and registeredDomain" {
    const parsed_url = try lib.Url.parse("https://shop.example.com/products?category=zig");

    // Extract domain via the Url.domain() helper
    const dom = parsed_url.domain().?;

    // Verify TLD
    try testing.expectEqualStrings("com", dom.tld().?);

    // Verify registered domain
    try testing.expectEqualStrings("example.com", dom.registeredDomain().?);

    // Verify host matches
    try testing.expectEqualStrings("shop.example.com", parsed_url.host);
}

// ============================================================================
// 11. MAC format/parse roundtrip
// ============================================================================

test "type_ext: MAC format/parse roundtrip" {
    const original = try lib.Mac.parse("AA:BB:CC:DD:EE:FF");
    var buf: [32]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try lib.Mac.parse(formatted);

    try testing.expect(original.eql(parsed));

    // Verify the formatted output is uppercase colon-separated
    try testing.expectEqualStrings("AA:BB:CC:DD:EE:FF", formatted);
}
