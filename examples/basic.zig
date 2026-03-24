// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Basic usage example for advanced-types

const std = @import("std");
const types = @import("advanced_types");

pub fn main() !void {
    const print = std.debug.print;

    print("advanced-types Examples\n", .{});
    print("=======================\n\n", .{});

    // --- Network types ---
    print("Network types:\n", .{});
    const ip = try types.Ipv4Addr.parse("192.168.1.1");
    print("  Parsed: {d}.{d}.{d}.{d}\n", .{ ip.octets[0], ip.octets[1], ip.octets[2], ip.octets[3] });
    print("  Private: {}\n", .{ip.isPrivate()});

    const subnet = try types.Subnet.parse("10.0.0.0/8");
    const test_ip = try types.IpAddr.parse("10.1.2.3");
    print("  10.1.2.3 in 10.0.0.0/8: {}\n\n", .{subnet.contains(test_ip)});

    // --- Vector types ---
    print("Vector types:\n", .{});
    const a = types.VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = types.VectorF32.init(.{ 4.0, 5.0, 6.0 });
    print("  dot product: {d}\n", .{a.dot(b)});
    print("  cosine distance: {d}\n\n", .{a.cosineDistance(b)});

    // --- Geographic types ---
    print("Geographic types:\n", .{});
    const sf = try types.LatLon.init(37.7749, -122.4194);
    const ny = try types.LatLon.init(40.7128, -74.0060);
    const dist_km = sf.haversineDistance(ny) / 1000.0;
    print("  SF to NYC: {d:.0} km\n\n", .{dist_km});

    // --- URL types ---
    print("URL types:\n", .{});
    const url = try types.Url.parse("https://api.example.com:8443/v1/data?key=val");
    print("  scheme: {s}, host: {s}, port: {d}\n", .{ url.scheme, url.host, url.port.? });
    const dom = try types.Domain.parse(url.host);
    print("  TLD: {s}\n\n", .{dom.tld().?});

    // --- Range types ---
    print("Range types:\n", .{});
    const r1 = try types.IntRange.init(10, 20);
    const r2 = try types.IntRange.init(15, 25);
    print("  [10,20] contains 15: {}\n", .{r1.contains(15)});
    print("  [10,20] overlaps [15,25]: {}\n\n", .{r1.overlaps(r2)});

    print("Example completed successfully!\n", .{});
}
