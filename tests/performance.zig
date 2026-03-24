// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! AT-TEST-003: Performance and dataset-level integration tests for advanced-types.
//!
//! These tests exercise the library at scale with bulk operations, mixed-type
//! dataset workflows, and representative search/classification patterns.

const std = @import("std");
const lib = @import("advanced_types");
const testing = std.testing;

// ============================================================================
// Helpers
// ============================================================================

fn isFinite(val: anytype) bool {
    return !std.math.isNan(val) and !std.math.isInf(val);
}

// ============================================================================
// 1. Bulk IPv4 parsing — 100 valid addresses
// ============================================================================

test "performance: bulk IPv4 parsing of 100 valid addresses" {
    const addresses = [_][]const u8{
        "0.0.0.0",         "1.2.3.4",         "10.0.0.1",        "10.0.0.2",
        "10.0.0.3",        "10.0.0.4",        "10.0.0.5",        "10.0.0.10",
        "10.0.0.50",       "10.0.0.100",      "10.0.0.200",      "10.0.0.255",
        "10.0.1.0",        "10.0.1.1",        "10.0.2.1",        "10.0.10.1",
        "10.1.0.1",        "10.10.0.1",       "10.100.0.1",      "10.255.255.255",
        "127.0.0.1",       "127.0.0.2",       "127.0.0.3",       "127.0.0.100",
        "127.255.255.255", "172.16.0.1",      "172.16.0.2",      "172.16.1.1",
        "172.17.0.1",      "172.20.0.1",      "172.31.255.255",  "192.168.0.1",
        "192.168.0.2",     "192.168.0.10",    "192.168.0.100",   "192.168.0.200",
        "192.168.0.254",   "192.168.1.1",     "192.168.1.100",   "192.168.1.254",
        "192.168.2.1",     "192.168.10.1",    "192.168.50.1",    "192.168.100.1",
        "192.168.200.1",   "192.168.254.1",   "192.168.255.255", "198.51.100.1",
        "198.51.100.50",   "198.51.100.100",  "203.0.113.1",     "203.0.113.50",
        "203.0.113.100",   "203.0.113.200",   "208.67.222.222",  "208.67.220.220",
        "8.8.8.8",         "8.8.4.4",         "1.1.1.1",         "1.0.0.1",
        "9.9.9.9",         "149.112.112.112", "64.6.64.6",       "64.6.65.6",
        "77.88.8.8",       "77.88.8.1",       "94.140.14.14",    "94.140.15.15",
        "185.228.168.9",   "185.228.169.9",   "76.76.19.19",     "76.223.122.150",
        "156.154.70.1",    "156.154.71.1",    "199.85.126.10",   "199.85.127.10",
        "45.90.28.0",      "45.90.30.0",      "176.103.130.130", "176.103.130.131",
        "80.80.80.80",     "80.80.81.81",     "216.146.35.35",   "216.146.36.36",
        "37.235.1.174",    "37.235.1.177",    "91.239.100.100",  "89.233.43.71",
        "74.82.42.42",     "109.69.8.51",     "84.200.69.80",    "84.200.70.40",
        "223.5.5.5",       "223.6.6.6",       "119.29.29.29",    "180.76.76.76",
        "114.114.114.114", "114.114.115.115", "101.226.4.6",     "255.255.255.255",
    };

    comptime {
        if (addresses.len != 100) @compileError("Expected exactly 100 addresses");
    }

    var success_count: usize = 0;
    for (addresses) |addr_str| {
        const ip = try lib.Ipv4Addr.parse(addr_str);
        // Verify the parsed address round-trips correctly
        var buf: [16]u8 = undefined;
        const formatted = std.fmt.bufPrint(&buf, "{f}", .{ip}) catch unreachable;
        try testing.expectEqualStrings(addr_str, formatted);
        success_count += 1;
    }

    try testing.expectEqual(@as(usize, 100), success_count);
}

// ============================================================================
// 2. Bulk IPv4 invalid rejection — 100 invalid strings
// ============================================================================

test "performance: bulk IPv4 rejection of 100 invalid strings" {
    const invalid_inputs = [_][]const u8{
        "",                 " ",                                     "...",             "....",
        "1.2.3",            "1.2.3.4.5",                             "256.0.0.0",       "0.256.0.0",
        "0.0.256.0",        "0.0.0.256",                             "300.300.300.300", "999.999.999.999",
        "1.2.3.",           ".1.2.3",                                ".1.2.3.",         "1..2.3",
        "1.2..3",           "1.2.3..4",                              "abc.def.ghi.jkl", "a.b.c.d",
        "1.2.3.four",       "one.2.3.4",                             "1.two.3.4",       "1.2.three.4",
        "1.2.3.4.5.6",      "-1.0.0.0",                              "1.-1.0.0",        "1.0.-1.0",
        "1.0.0.-1",         "+1.0.0.0",                              "1.+1.0.0",        "1.0.+1.0",
        "1.0.0.+1",         "0x1.0x2.0x3.0x4",                       "01onal.2.3.4",    "hello",
        "world",            "192.168",                               "192",             "192.168.1",
        "1234.5.6.7",       "1.2345.6.7",                            "1.2.3456.7",      "1.2.3.4567",
        " 1.2.3.4",         "1.2.3.4 ",                              " 1.2.3.4 ",       "1. 2.3.4",
        "1.2. 3.4",         "1.2.3. 4",                              "1,2,3,4",         "1;2;3;4",
        "1:2:3:4",          "1/2/3/4",                               "[1.2.3.4]",       "(1.2.3.4)",
        "1.2.3.4/24",       "1.2.3.4:80",                            "http://1.2.3.4",  "//1.2.3.4",
        "\x00\x00\x00\x00", "\xff\xff\xff\xff",                      "null",            "undefined",
        "NaN",              "Inf",                                   "true",            "false",
        "0",                ".0.0.0",                                "0.0.0.",          "...0",
        "0...",             "1.2.3.4.",                              ".1.2.3.4",        "0.0.0.0.0",
        "1.2.3.4\n",        "1.2.3.4\t",                             "1.2.3.4\r",       "\n1.2.3.4",
        "\t1.2.3.4",        "\r1.2.3.4",                             "1\n2.3.4",        "1.2\n3.4",
        "1.2.3\n4",         "::1",                                   "fe80::1",         "::ffff:192.168.1.1",
        "2001:db8::1",      "not.an.ip.address.at.all.really.truly", "255.255.255.256", "0.0.0.0.0.0",
        "1 2.3.4",          "1.2 .3.4",                              "1.2.3 .4",        "x.y.z.w",
        "1.2.3.4.5.6.7",    "ip:1.2.3.4",                            "1.2.3.4#",        "$.$.$.0",
    };

    comptime {
        if (invalid_inputs.len != 100) @compileError("Expected exactly 100 invalid inputs");
    }

    var error_count: usize = 0;
    for (invalid_inputs) |input| {
        const result = lib.Ipv4Addr.parse(input);
        if (result) |_| {
            // Some edge cases (like "0" alone) might parse oddly; we expect an error
            // but if it doesn't error, that's a test failure
            // However, "0" with only 1 octet should fail, etc.
        } else |_| {
            error_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 100), error_count);
}

// ============================================================================
// 3. Bulk haversine distance — 50 coordinate pairs
// ============================================================================

test "performance: bulk haversine distance for 50 coordinate pairs" {
    // 50 pairs of (lat1, lon1, lat2, lon2) representing real-world city pairs
    const pairs = [_][4]f64{
        .{ 40.7128, -74.0060, 51.5074, -0.1278 }, // NYC - London
        .{ 48.8566, 2.3522, 35.6762, 139.6503 }, // Paris - Tokyo
        .{ -33.8688, 151.2093, 55.7558, 37.6173 }, // Sydney - Moscow
        .{ 37.7749, -122.4194, 34.0522, -118.2437 }, // SF - LA
        .{ 52.5200, 13.4050, 41.9028, 12.4964 }, // Berlin - Rome
        .{ 1.3521, 103.8198, -6.2088, 106.8456 }, // Singapore - Jakarta
        .{ 19.4326, -99.1332, -22.9068, -43.1729 }, // Mexico City - Rio
        .{ 59.9343, 30.3351, 39.9042, 116.4074 }, // St Petersburg - Beijing
        .{ 35.6895, 139.6917, -33.8688, 151.2093 }, // Tokyo - Sydney
        .{ 51.5074, -0.1278, 48.8566, 2.3522 }, // London - Paris
        .{ 55.7558, 37.6173, 52.5200, 13.4050 }, // Moscow - Berlin
        .{ 34.0522, -118.2437, 19.4326, -99.1332 }, // LA - Mexico City
        .{ -22.9068, -43.1729, -34.6037, -58.3816 }, // Rio - Buenos Aires
        .{ 39.9042, 116.4074, 1.3521, 103.8198 }, // Beijing - Singapore
        .{ 41.9028, 12.4964, 37.9838, 23.7275 }, // Rome - Athens
        .{ 37.9838, 23.7275, 41.0082, 28.9784 }, // Athens - Istanbul
        .{ 41.0082, 28.9784, 55.7558, 37.6173 }, // Istanbul - Moscow
        .{ -34.6037, -58.3816, -33.4489, -70.6693 }, // Buenos Aires - Santiago
        .{ -33.4489, -70.6693, -12.0464, -77.0428 }, // Santiago - Lima
        .{ -12.0464, -77.0428, 4.7110, -74.0721 }, // Lima - Bogota
        .{ 4.7110, -74.0721, 10.4806, -66.9036 }, // Bogota - Caracas
        .{ 30.0444, 31.2357, -1.2921, 36.8219 }, // Cairo - Nairobi
        .{ -1.2921, 36.8219, -26.2041, 28.0473 }, // Nairobi - Johannesburg
        .{ 13.7563, 100.5018, 21.0285, 105.8542 }, // Bangkok - Hanoi
        .{ 21.0285, 105.8542, 22.3193, 114.1694 }, // Hanoi - Hong Kong
        .{ 22.3193, 114.1694, 31.2304, 121.4737 }, // Hong Kong - Shanghai
        .{ 31.2304, 121.4737, 37.5665, 126.9780 }, // Shanghai - Seoul
        .{ 37.5665, 126.9780, 35.6895, 139.6917 }, // Seoul - Tokyo
        .{ 64.1466, -21.9426, 60.1699, 24.9384 }, // Reykjavik - Helsinki
        .{ 60.1699, 24.9384, 59.3293, 18.0686 }, // Helsinki - Stockholm
        .{ 59.3293, 18.0686, 59.9139, 10.7522 }, // Stockholm - Oslo
        .{ 59.9139, 10.7522, 55.6761, 12.5683 }, // Oslo - Copenhagen
        .{ 55.6761, 12.5683, 52.3676, 4.9041 }, // Copenhagen - Amsterdam
        .{ 52.3676, 4.9041, 50.8503, 4.3517 }, // Amsterdam - Brussels
        .{ 50.8503, 4.3517, 49.6116, 6.1319 }, // Brussels - Luxembourg
        .{ 47.3769, 8.5417, 48.2082, 16.3738 }, // Zurich - Vienna
        .{ 48.2082, 16.3738, 47.4979, 19.0402 }, // Vienna - Budapest
        .{ 47.4979, 19.0402, 50.0755, 14.4378 }, // Budapest - Prague
        .{ 50.0755, 14.4378, 52.2297, 21.0122 }, // Prague - Warsaw
        .{ 52.2297, 21.0122, 54.6872, 25.2797 }, // Warsaw - Vilnius
        .{ 54.6872, 25.2797, 56.9496, 24.1052 }, // Vilnius - Riga
        .{ 56.9496, 24.1052, 59.4370, 24.7536 }, // Riga - Tallinn
        .{ 25.2048, 55.2708, 25.2760, 51.5200 }, // Dubai - Doha
        .{ 24.7136, 46.6753, 21.4225, 39.8262 }, // Riyadh - Mecca
        .{ 33.8938, 35.5018, 32.0853, 34.7818 }, // Beirut - Tel Aviv
        .{ -37.8136, 144.9631, -41.2865, 174.7762 }, // Melbourne - Wellington
        .{ 28.6139, 77.2090, 19.0760, 72.8777 }, // Delhi - Mumbai
        .{ 6.5244, 3.3792, 5.6037, -0.1870 }, // Lagos - Accra
        .{ 14.7167, -17.4677, 12.6392, -8.0029 }, // Dakar - Bamako
        .{ 36.8065, 10.1815, 33.5731, -7.5898 }, // Tunis - Casablanca
    };

    comptime {
        if (pairs.len != 50) @compileError("Expected exactly 50 coordinate pairs");
    }

    var computed: usize = 0;
    for (pairs) |p| {
        const a = try lib.LatLon.init(p[0], p[1]);
        const b = try lib.LatLon.init(p[2], p[3]);
        const dist = a.haversineDistance(b);

        // Distance must be positive (points are distinct) and finite
        try testing.expect(dist > 0.0);
        try testing.expect(isFinite(dist));

        // Distance should be less than half the Earth's circumference (~20,037 km)
        try testing.expect(dist < 20_100_000.0);

        computed += 1;
    }

    try testing.expectEqual(@as(usize, 50), computed);
}

// ============================================================================
// 4. Bulk vector cosine distance — 50 vector pairs
// ============================================================================

test "performance: bulk cosine distance for 50 vector pairs" {
    const VecF32 = lib.VectorF32;

    // 50 pairs of 3D vectors with varied orientations
    const pairs = [_][2][3]f32{
        .{ .{ 1.0, 0.0, 0.0 }, .{ 0.0, 1.0, 0.0 } },
        .{ .{ 1.0, 1.0, 0.0 }, .{ 1.0, -1.0, 0.0 } },
        .{ .{ 3.0, 4.0, 0.0 }, .{ 4.0, 3.0, 0.0 } },
        .{ .{ 1.0, 2.0, 3.0 }, .{ 4.0, 5.0, 6.0 } },
        .{ .{ 0.5, 0.5, 0.5 }, .{ 1.0, 1.0, 1.0 } },
        .{ .{ 1.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 } },
        .{ .{ 2.0, 3.0, 4.0 }, .{ -2.0, -3.0, -4.0 } },
        .{ .{ 1.0, 1.0, 1.0 }, .{ 0.0, 0.0, 1.0 } },
        .{ .{ 10.0, 0.0, 0.0 }, .{ 0.0, 10.0, 0.0 } },
        .{ .{ 5.0, 5.0, 5.0 }, .{ 5.0, 5.0, 5.0 } },
        .{ .{ 0.1, 0.2, 0.3 }, .{ 0.4, 0.5, 0.6 } },
        .{ .{ 7.0, -3.0, 2.0 }, .{ 1.0, 8.0, -4.0 } },
        .{ .{ 1.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0 } },
        .{ .{ 2.0, 2.0, 0.0 }, .{ 0.0, 2.0, 2.0 } },
        .{ .{ 3.0, 1.0, 2.0 }, .{ 2.0, 3.0, 1.0 } },
        .{ .{ -1.0, -1.0, -1.0 }, .{ 1.0, 1.0, 1.0 } },
        .{ .{ 0.3, 0.4, 0.5 }, .{ 0.5, 0.4, 0.3 } },
        .{ .{ 100.0, 1.0, 1.0 }, .{ 1.0, 100.0, 1.0 } },
        .{ .{ 8.0, 6.0, 0.0 }, .{ 6.0, 8.0, 0.0 } },
        .{ .{ 1.0, 2.0, 0.0 }, .{ -2.0, 1.0, 0.0 } },
        .{ .{ 4.0, 0.0, 3.0 }, .{ 0.0, 5.0, 0.0 } },
        .{ .{ 1.0, 3.0, 5.0 }, .{ 2.0, 4.0, 6.0 } },
        .{ .{ 9.0, 0.0, 1.0 }, .{ 1.0, 0.0, 9.0 } },
        .{ .{ 2.0, 7.0, 1.0 }, .{ 1.0, 2.0, 7.0 } },
        .{ .{ 5.0, 5.0, 0.0 }, .{ 0.0, 5.0, 5.0 } },
        .{ .{ 6.0, 2.0, 3.0 }, .{ 3.0, 6.0, 2.0 } },
        .{ .{ 1.0, 1.0, 0.0 }, .{ 0.0, 1.0, 1.0 } },
        .{ .{ 4.0, 4.0, 4.0 }, .{ 1.0, 2.0, 3.0 } },
        .{ .{ 0.0, 0.0, 1.0 }, .{ 1.0, 0.0, 0.0 } },
        .{ .{ 3.0, 3.0, 3.0 }, .{ -1.0, -1.0, -1.0 } },
        .{ .{ 2.0, 1.0, 0.0 }, .{ 0.0, 1.0, 2.0 } },
        .{ .{ 10.0, 10.0, 10.0 }, .{ 1.0, 1.0, 1.0 } },
        .{ .{ 7.0, 7.0, 0.0 }, .{ 7.0, 0.0, 7.0 } },
        .{ .{ 1.0, 5.0, 3.0 }, .{ 3.0, 1.0, 5.0 } },
        .{ .{ 8.0, 2.0, 5.0 }, .{ 5.0, 8.0, 2.0 } },
        .{ .{ 4.0, 6.0, 1.0 }, .{ 1.0, 4.0, 6.0 } },
        .{ .{ 9.0, 3.0, 6.0 }, .{ 6.0, 9.0, 3.0 } },
        .{ .{ 2.0, 8.0, 4.0 }, .{ 4.0, 2.0, 8.0 } },
        .{ .{ 1.0, 0.5, 0.25 }, .{ 0.25, 1.0, 0.5 } },
        .{ .{ 11.0, 2.0, 3.0 }, .{ 3.0, 11.0, 2.0 } },
        .{ .{ 5.0, 1.0, 7.0 }, .{ 7.0, 5.0, 1.0 } },
        .{ .{ 0.1, 0.9, 0.5 }, .{ 0.5, 0.1, 0.9 } },
        .{ .{ 6.0, 4.0, 8.0 }, .{ 8.0, 6.0, 4.0 } },
        .{ .{ 3.0, 9.0, 1.0 }, .{ 1.0, 3.0, 9.0 } },
        .{ .{ 12.0, 0.0, 5.0 }, .{ 5.0, 12.0, 0.0 } },
        .{ .{ 0.0, 7.0, 3.0 }, .{ 3.0, 0.0, 7.0 } },
        .{ .{ 2.0, 2.0, 9.0 }, .{ 9.0, 2.0, 2.0 } },
        .{ .{ 4.0, 1.0, 1.0 }, .{ 1.0, 4.0, 1.0 } },
        .{ .{ 8.0, 3.0, 7.0 }, .{ 7.0, 8.0, 3.0 } },
        .{ .{ 1.0, 6.0, 2.0 }, .{ 2.0, 1.0, 6.0 } },
    };

    comptime {
        if (pairs.len != 50) @compileError("Expected exactly 50 vector pairs");
    }

    var computed: usize = 0;
    for (pairs) |p| {
        const a = VecF32.init(p[0]);
        const b = VecF32.init(p[1]);
        const cd = a.cosineDistance(b);

        // Cosine distance is in [0, 2]
        try testing.expect(cd >= -1e-6); // allow tiny float imprecision
        try testing.expect(cd <= 2.0 + 1e-6);
        try testing.expect(isFinite(cd));

        computed += 1;
    }

    try testing.expectEqual(@as(usize, 50), computed);
}

// ============================================================================
// 5. Dataset integration: mixed record parsing — 20 rows
// ============================================================================

test "performance: mixed dataset record parsing for 20 rows" {
    // Each "row" is (ip_string, coordinate_string, vector_string)
    const rows = [_]struct {
        ip: []const u8,
        coord: []const u8,
        vec: []const u8,
    }{
        .{ .ip = "93.184.216.34", .coord = "(51.5074, -0.1278)", .vec = "[1.0, 2.5, 3.7]" },
        .{ .ip = "8.8.8.8", .coord = "(37.3861, -122.0839)", .vec = "[0.5, 0.5, 0.5]" },
        .{ .ip = "1.1.1.1", .coord = "(-33.8688, 151.2093)", .vec = "[10.0, 20.0, 30.0]" },
        .{ .ip = "192.168.1.1", .coord = "(40.7128, -74.0060)", .vec = "[3.0, 4.0, 0.0]" },
        .{ .ip = "10.0.0.1", .coord = "(48.8566, 2.3522)", .vec = "[7.0, 8.0, 9.0]" },
        .{ .ip = "172.16.0.1", .coord = "(35.6762, 139.6503)", .vec = "[1.0, 0.0, 0.0]" },
        .{ .ip = "203.0.113.50", .coord = "(-22.9068, -43.1729)", .vec = "[5.5, 6.5, 7.5]" },
        .{ .ip = "198.51.100.1", .coord = "(55.7558, 37.6173)", .vec = "[2.0, 3.0, 4.0]" },
        .{ .ip = "149.112.112.112", .coord = "(52.5200, 13.4050)", .vec = "[0.1, 0.2, 0.3]" },
        .{ .ip = "208.67.222.222", .coord = "(41.9028, 12.4964)", .vec = "[9.0, 8.0, 7.0]" },
        .{ .ip = "77.88.8.8", .coord = "(59.9343, 30.3351)", .vec = "[4.0, 4.0, 4.0]" },
        .{ .ip = "9.9.9.9", .coord = "(1.3521, 103.8198)", .vec = "[6.0, 1.0, 2.0]" },
        .{ .ip = "64.6.64.6", .coord = "(19.4326, -99.1332)", .vec = "[3.0, 3.0, 3.0]" },
        .{ .ip = "94.140.14.14", .coord = "(13.7563, 100.5018)", .vec = "[8.0, 2.0, 5.0]" },
        .{ .ip = "185.228.168.9", .coord = "(28.6139, 77.2090)", .vec = "[1.0, 1.0, 1.0]" },
        .{ .ip = "76.76.19.19", .coord = "(37.5665, 126.9780)", .vec = "[11.0, 12.0, 13.0]" },
        .{ .ip = "156.154.70.1", .coord = "(22.3193, 114.1694)", .vec = "[0.0, 5.0, 0.0]" },
        .{ .ip = "199.85.126.10", .coord = "(25.2048, 55.2708)", .vec = "[2.0, 7.0, 1.0]" },
        .{ .ip = "45.90.28.0", .coord = "(-37.8136, 144.9631)", .vec = "[4.0, 6.0, 8.0]" },
        .{ .ip = "80.80.80.80", .coord = "(30.0444, 31.2357)", .vec = "[9.0, 3.0, 6.0]" },
    };

    comptime {
        if (rows.len != 20) @compileError("Expected exactly 20 dataset rows");
    }

    var processed: usize = 0;
    for (rows) |row| {
        const ip = try lib.Ipv4Addr.parse(row.ip);
        const coord = try lib.LatLon.parse(row.coord);
        const vec = try lib.VectorF32.parse(row.vec);

        // IP must have 4 valid octets
        var octet_sum: u16 = 0;
        for (ip.octets) |o| {
            octet_sum += @as(u16, o);
        }
        try testing.expect(octet_sum > 0 or std.mem.eql(u8, row.ip, "0.0.0.0"));

        // Coordinate must be in valid range
        try testing.expect(coord.lat >= -90.0 and coord.lat <= 90.0);
        try testing.expect(coord.lon >= -180.0 and coord.lon <= 180.0);

        // Vector must have 3 finite elements
        for (vec.data) |v| {
            try testing.expect(isFinite(v));
        }

        processed += 1;
    }

    try testing.expectEqual(@as(usize, 20), processed);
}

// ============================================================================
// 6. Subnet classification workflow — 5 subnets, 20 IPs
// ============================================================================

test "performance: subnet classification of 20 IPs against 5 subnets" {
    const subnets_raw = [_][]const u8{
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "198.51.100.0/24",
        "203.0.113.0/24",
    };

    var subnets: [5]lib.Subnet = undefined;
    for (subnets_raw, 0..) |s, i| {
        subnets[i] = try lib.Subnet.parse(s);
    }

    const ip_strs = [_][]const u8{
        "10.0.0.1", // in 10.0.0.0/8
        "10.255.255.255", // in 10.0.0.0/8
        "172.16.0.1", // in 172.16.0.0/12
        "172.31.255.255", // in 172.16.0.0/12
        "172.32.0.1", // NOT in any
        "192.168.0.1", // in 192.168.0.0/16
        "192.168.255.254", // in 192.168.0.0/16
        "192.169.0.1", // NOT in any
        "198.51.100.1", // in 198.51.100.0/24
        "198.51.100.254", // in 198.51.100.0/24
        "198.51.101.1", // NOT in any
        "203.0.113.1", // in 203.0.113.0/24
        "203.0.113.200", // in 203.0.113.0/24
        "203.0.114.1", // NOT in any
        "8.8.8.8", // NOT in any
        "1.1.1.1", // NOT in any
        "10.10.10.10", // in 10.0.0.0/8
        "172.20.5.3", // in 172.16.0.0/12
        "192.168.100.50", // in 192.168.0.0/16
        "255.255.255.255", // NOT in any
    };

    // Expected subnet index for each IP (-1 means no match)
    const expected_subnet = [_]i8{
        0, 0, 1, 1, -1, 2, 2, -1, 3, 3, -1, 4, 4, -1, -1, -1, 0, 1, 2, -1,
    };

    comptime {
        if (ip_strs.len != 20) @compileError("Expected exactly 20 IPs");
        if (expected_subnet.len != 20) @compileError("Expected exactly 20 expected values");
    }

    for (ip_strs, expected_subnet, 0..) |ip_str, expected, idx| {
        _ = idx;
        const ip = try lib.Ipv4Addr.parse(ip_str);
        const addr = lib.IpAddr{ .v4 = ip };

        var found_subnet: i8 = -1;
        for (subnets, 0..) |subnet, si| {
            if (subnet.contains(addr)) {
                found_subnet = @intCast(si);
                break;
            }
        }

        try testing.expectEqual(expected, found_subnet);
    }
}

// ============================================================================
// 7. URL batch parsing — 20 valid URLs with varying components
// ============================================================================

test "performance: batch parsing of 20 URLs with varying components" {
    const urls = [_]struct {
        raw: []const u8,
        scheme: []const u8,
        host: []const u8,
        port: ?u16,
        has_path: bool,
        has_query: bool,
        has_fragment: bool,
    }{
        .{ .raw = "https://example.com", .scheme = "https", .host = "example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "http://example.com:8080/api", .scheme = "http", .host = "example.com", .port = 8080, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://www.google.com/search?q=zig+lang", .scheme = "https", .host = "www.google.com", .port = null, .has_path = true, .has_query = true, .has_fragment = false },
        .{ .raw = "http://localhost:3000/api/v1/users", .scheme = "http", .host = "localhost", .port = 3000, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://docs.example.com/page#section-2", .scheme = "https", .host = "docs.example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = true },
        .{ .raw = "http://api.example.com:9090/v2/data?limit=100&offset=0", .scheme = "http", .host = "api.example.com", .port = 9090, .has_path = true, .has_query = true, .has_fragment = false },
        .{ .raw = "https://cdn.example.com/assets/logo.png", .scheme = "https", .host = "cdn.example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "ftp://files.example.com/pub/data.zip", .scheme = "ftp", .host = "files.example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://example.com:443/secure", .scheme = "https", .host = "example.com", .port = 443, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "http://example.com:80/default", .scheme = "http", .host = "example.com", .port = 80, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://shop.example.com/products?category=books&sort=price#results", .scheme = "https", .host = "shop.example.com", .port = null, .has_path = true, .has_query = true, .has_fragment = true },
        .{ .raw = "http://blog.example.com/2024/01/hello-world", .scheme = "http", .host = "blog.example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://mail.example.com/inbox?unread=true", .scheme = "https", .host = "mail.example.com", .port = null, .has_path = true, .has_query = true, .has_fragment = false },
        .{ .raw = "http://192.168.1.1/admin", .scheme = "http", .host = "192.168.1.1", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://sub.domain.example.com/path/to/resource", .scheme = "https", .host = "sub.domain.example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "http://example.com/path?key=value", .scheme = "http", .host = "example.com", .port = null, .has_path = true, .has_query = true, .has_fragment = false },
        .{ .raw = "https://example.com/page#top", .scheme = "https", .host = "example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = true },
        .{ .raw = "http://test.example.com:5000/health", .scheme = "http", .host = "test.example.com", .port = 5000, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "https://example.com/a/b/c/d/e", .scheme = "https", .host = "example.com", .port = null, .has_path = true, .has_query = false, .has_fragment = false },
        .{ .raw = "http://example.com/search?q=hello+world&lang=en#first", .scheme = "http", .host = "example.com", .port = null, .has_path = true, .has_query = true, .has_fragment = true },
    };

    comptime {
        if (urls.len != 20) @compileError("Expected exactly 20 URLs");
    }

    var parsed_count: usize = 0;
    for (urls) |entry| {
        const u = try lib.Url.parse(entry.raw);

        try testing.expectEqualStrings(entry.scheme, u.scheme);
        try testing.expectEqualStrings(entry.host, u.host);
        try testing.expectEqual(entry.port, u.port);
        try testing.expect(u.path.len > 0);
        try testing.expectEqual(entry.has_query, u.query != null);
        try testing.expectEqual(entry.has_fragment, u.fragment != null);

        // Verify effective port is sane
        const ep = u.effectivePort();
        try testing.expect(ep > 0 or
            (!std.ascii.eqlIgnoreCase(u.scheme, "http") and
                !std.ascii.eqlIgnoreCase(u.scheme, "https")));

        parsed_count += 1;
    }

    try testing.expectEqual(@as(usize, 20), parsed_count);
}

// ============================================================================
// 8. Range overlap detection — 20 ranges, find all overlapping pairs
// ============================================================================

test "performance: range overlap detection among 20 ranges" {
    const range_defs = [_][2]i64{
        .{ 0, 10 },      .{ 5, 15 },      .{ 20, 30 },     .{ 25, 35 },
        .{ 40, 50 },     .{ 100, 200 },   .{ 150, 250 },   .{ 300, 400 },
        .{ -50, -10 },   .{ -30, -5 },    .{ -100, -80 },  .{ -85, -60 },
        .{ 1000, 2000 }, .{ 1500, 2500 }, .{ 3000, 4000 }, .{ 10, 20 },
        .{ 50, 60 },     .{ 55, 65 },     .{ 70, 80 },     .{ 75, 85 },
    };

    comptime {
        if (range_defs.len != 20) @compileError("Expected exactly 20 ranges");
    }

    var ranges: [20]lib.IntRange = undefined;
    for (range_defs, 0..) |rd, i| {
        ranges[i] = try lib.IntRange.init(rd[0], rd[1]);
    }

    // Known overlapping pairs (0-indexed):
    //  (0,1): [0,10] & [5,15]
    //  (0,15): [0,10] & [10,20]
    //  (1,2): [5,15] & [20,30]? NO - [5,15] doesn't overlap [20,30]
    //  (1,15): [5,15] & [10,20]
    //  (2,3): [20,30] & [25,35]
    //  (2,15): [20,30] & [10,20]
    //  (4,16): [40,50] & [50,60]
    //  (5,6): [100,200] & [150,250]
    //  (8,9): [-50,-10] & [-30,-5]
    //  (10,11): [-100,-80] & [-85,-60]
    //  (12,13): [1000,2000] & [1500,2500]
    //  (16,17): [50,60] & [55,65]
    //  (18,19): [70,80] & [75,85]

    var overlap_count: usize = 0;
    for (0..20) |i| {
        for (i + 1..20) |j| {
            if (ranges[i].overlaps(ranges[j])) {
                // For every overlapping pair, verify the intersection exists
                const inter = ranges[i].intersection(ranges[j]);
                try testing.expect(inter != null);

                // The intersection must be contained in both ranges
                const isect = inter.?;
                try testing.expect(ranges[i].containsRange(isect));
                try testing.expect(ranges[j].containsRange(isect));

                overlap_count += 1;
            }
        }
    }

    // We expect exactly 12 overlapping pairs among the 20 ranges
    try testing.expectEqual(@as(usize, 12), overlap_count);
    // And a reasonable upper bound (can't be more than C(20,2) = 190)
    try testing.expect(overlap_count <= 190);
}

// ============================================================================
// 9. Vector similarity search — find closest to query among 10 candidates
// ============================================================================

test "performance: vector similarity search among 10 candidates" {
    const VecF32 = lib.VectorF32;

    const candidates = [_][3]f32{
        .{ 1.0, 0.0, 0.0 }, // 0: unit x
        .{ 0.0, 1.0, 0.0 }, // 1: unit y
        .{ 0.0, 0.0, 1.0 }, // 2: unit z
        .{ 1.0, 1.0, 0.0 }, // 3: diagonal xy
        .{ 1.0, 0.0, 1.0 }, // 4: diagonal xz
        .{ 0.0, 1.0, 1.0 }, // 5: diagonal yz
        .{ 1.0, 1.0, 1.0 }, // 6: diagonal xyz
        .{ -1.0, 0.0, 0.0 }, // 7: negative x
        .{ 0.5, 0.5, 0.0 }, // 8: small diagonal xy
        .{ 3.0, 4.0, 0.0 }, // 9: (3,4,0) direction
    };

    const queries = [_]struct {
        vec: [3]f32,
        expected_closest: usize,
    }{
        // Query close to unit x -> should match candidate 0
        .{ .vec = .{ 10.0, 0.1, 0.1 }, .expected_closest = 0 },
        // Query close to unit y -> should match candidate 1
        .{ .vec = .{ 0.1, 10.0, 0.1 }, .expected_closest = 1 },
        // Query close to unit z -> should match candidate 2
        .{ .vec = .{ 0.1, 0.1, 10.0 }, .expected_closest = 2 },
        // Query in negative x direction -> should match candidate 7
        .{ .vec = .{ -5.0, 0.0, 0.0 }, .expected_closest = 7 },
        // Query in (1,1,1) direction -> should match candidate 6
        .{ .vec = .{ 5.0, 5.0, 5.0 }, .expected_closest = 6 },
    };

    for (queries) |q| {
        const query_vec = VecF32.init(q.vec);

        var best_idx: usize = 0;
        var best_dist: f32 = query_vec.cosineDistance(VecF32.init(candidates[0]));

        for (candidates[1..], 1..) |cand_data, ci| {
            const cand = VecF32.init(cand_data);
            const dist = query_vec.cosineDistance(cand);
            if (dist < best_dist) {
                best_dist = dist;
                best_idx = ci;
            }
        }

        try testing.expectEqual(q.expected_closest, best_idx);

        // The best distance should be very small (nearly same direction)
        try testing.expect(best_dist < 0.1);
        try testing.expect(isFinite(best_dist));
    }
}
