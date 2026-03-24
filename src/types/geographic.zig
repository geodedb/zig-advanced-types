// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Core geographic value types for representing positions on Earth.
//!
//! Provides `LatLon` (2D), `LatLonAlt` (3D), and `GeoPoint` (tagged union)
//! with validation, haversine distance calculations, formatting, and parsing.

const std = @import("std");
const math = std.math;
const testing = std.testing;

// ============================================================================
// Errors
// ============================================================================

pub const GeoError = error{
    LatitudeOutOfRange,
    LongitudeOutOfRange,
    InvalidFormat,
    InvalidCharacter,
};

// ============================================================================
// Constants
// ============================================================================

/// Mean radius of the Earth in meters (WGS-84 spherical approximation).
const earth_radius_m: f64 = 6_371_000.0;

// ============================================================================
// LatLon
// ============================================================================

/// A 2D geographic coordinate (latitude, longitude) in decimal degrees.
///
/// Latitude ranges from -90 (south pole) to 90 (north pole).
/// Longitude ranges from -180 to 180 (positive = east).
pub const LatLon = struct {
    lat: f64,
    lon: f64,

    /// Create a `LatLon` with range validation.
    ///
    /// Returns `GeoError.LatitudeOutOfRange` if lat is outside [-90, 90].
    /// Returns `GeoError.LongitudeOutOfRange` if lon is outside [-180, 180].
    pub fn init(lat: f64, lon: f64) GeoError!LatLon {
        if (lat < -90.0 or lat > 90.0 or math.isNan(lat)) {
            return GeoError.LatitudeOutOfRange;
        }
        if (lon < -180.0 or lon > 180.0 or math.isNan(lon)) {
            return GeoError.LongitudeOutOfRange;
        }
        return .{ .lat = lat, .lon = lon };
    }

    /// Create a `LatLon` without validation. Use only with trusted data.
    pub fn initUnchecked(lat: f64, lon: f64) LatLon {
        return .{ .lat = lat, .lon = lon };
    }

    /// Test equality of two `LatLon` values (exact bitwise comparison).
    pub fn eql(self: LatLon, other: LatLon) bool {
        return self.lat == other.lat and self.lon == other.lon;
    }

    /// Compute the great-circle distance to `other` in meters using the
    /// haversine formula.
    ///
    /// ```
    /// a = sin²(Δlat/2) + cos(lat1) · cos(lat2) · sin²(Δlon/2)
    /// c = 2 · atan2(√a, √(1−a))
    /// d = R · c
    /// ```
    pub fn haversineDistance(self: LatLon, other: LatLon) f64 {
        const to_rad = math.pi / 180.0;

        const lat1 = self.lat * to_rad;
        const lat2 = other.lat * to_rad;
        const d_lat = (other.lat - self.lat) * to_rad;
        const d_lon = (other.lon - self.lon) * to_rad;

        const sin_d_lat_2 = @sin(d_lat / 2.0);
        const sin_d_lon_2 = @sin(d_lon / 2.0);

        const a = sin_d_lat_2 * sin_d_lat_2 +
            @cos(lat1) * @cos(lat2) * sin_d_lon_2 * sin_d_lon_2;

        const c = 2.0 * math.atan2(@sqrt(a), @sqrt(1.0 - a));

        return earth_radius_m * c;
    }

    /// Format as `(lat, lon)`, e.g. `(37.7749, -122.4194)`.
    pub fn format(self: LatLon, writer: anytype) !void {
        try writer.print("({d}, {d})", .{ self.lat, self.lon });
    }

    /// Parse a `LatLon` from the string format `(lat, lon)`.
    ///
    /// Accepts optional whitespace around the comma and inside the parentheses.
    /// Returns `GeoError.InvalidFormat` if the structure is wrong.
    /// Returns `GeoError.InvalidCharacter` if numeric parsing fails.
    /// Returns `GeoError.LatitudeOutOfRange` / `GeoError.LongitudeOutOfRange`
    /// if the parsed values are out of range.
    pub fn parse(input: []const u8) GeoError!LatLon {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        if (trimmed.len < 3 or trimmed[0] != '(' or trimmed[trimmed.len - 1] != ')') {
            return GeoError.InvalidFormat;
        }

        const inner = trimmed[1 .. trimmed.len - 1];

        const comma_pos = std.mem.indexOfScalar(u8, inner, ',') orelse return GeoError.InvalidFormat;

        const lat_str = std.mem.trim(u8, inner[0..comma_pos], &std.ascii.whitespace);
        const lon_str = std.mem.trim(u8, inner[comma_pos + 1 ..], &std.ascii.whitespace);

        if (lat_str.len == 0 or lon_str.len == 0) {
            return GeoError.InvalidFormat;
        }

        const lat = std.fmt.parseFloat(f64, lat_str) catch return GeoError.InvalidCharacter;
        const lon = std.fmt.parseFloat(f64, lon_str) catch return GeoError.InvalidCharacter;

        return init(lat, lon);
    }
};

// ============================================================================
// LatLonAlt
// ============================================================================

/// A 3D geographic coordinate (latitude, longitude, altitude).
///
/// Altitude is in meters above sea level (can be negative for below sea level).
pub const LatLonAlt = struct {
    lat: f64,
    lon: f64,
    alt: f64,

    /// Create a `LatLonAlt` with lat/lon range validation.
    pub fn init(lat: f64, lon: f64, alt: f64) GeoError!LatLonAlt {
        if (lat < -90.0 or lat > 90.0 or math.isNan(lat)) {
            return GeoError.LatitudeOutOfRange;
        }
        if (lon < -180.0 or lon > 180.0 or math.isNan(lon)) {
            return GeoError.LongitudeOutOfRange;
        }
        if (std.math.isNan(alt) or std.math.isInf(alt)) return GeoError.InvalidFormat;
        return .{ .lat = lat, .lon = lon, .alt = alt };
    }

    /// Create a `LatLonAlt` without validation. Use only with trusted data.
    pub fn initUnchecked(lat: f64, lon: f64, alt: f64) LatLonAlt {
        return .{ .lat = lat, .lon = lon, .alt = alt };
    }

    /// Drop altitude and return a `LatLon`.
    pub fn toLatLon(self: LatLonAlt) LatLon {
        return .{ .lat = self.lat, .lon = self.lon };
    }

    /// Test equality of two `LatLonAlt` values (exact bitwise comparison).
    pub fn eql(self: LatLonAlt, other: LatLonAlt) bool {
        return self.lat == other.lat and self.lon == other.lon and self.alt == other.alt;
    }

    /// Format as `(lat, lon, alt)`, e.g. `(37.7749, -122.4194, 10)`.
    pub fn format(self: LatLonAlt, writer: anytype) !void {
        try writer.print("({d}, {d}, {d})", .{ self.lat, self.lon, self.alt });
    }

    /// Parse a `LatLonAlt` from the string format `(lat, lon, alt)`.
    pub fn parse(input: []const u8) GeoError!LatLonAlt {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        if (trimmed.len < 5 or trimmed[0] != '(' or trimmed[trimmed.len - 1] != ')') {
            return GeoError.InvalidFormat;
        }

        const inner = trimmed[1 .. trimmed.len - 1];

        // Find first comma (separates lat from rest).
        const first_comma = std.mem.indexOfScalar(u8, inner, ',') orelse return GeoError.InvalidFormat;

        // Find second comma (separates lon from alt).
        const rest = inner[first_comma + 1 ..];
        const second_comma_rel = std.mem.indexOfScalar(u8, rest, ',') orelse return GeoError.InvalidFormat;
        const second_comma = first_comma + 1 + second_comma_rel;

        const lat_str = std.mem.trim(u8, inner[0..first_comma], &std.ascii.whitespace);
        const lon_str = std.mem.trim(u8, inner[first_comma + 1 .. second_comma], &std.ascii.whitespace);
        const alt_str = std.mem.trim(u8, inner[second_comma + 1 ..], &std.ascii.whitespace);

        if (lat_str.len == 0 or lon_str.len == 0 or alt_str.len == 0) {
            return GeoError.InvalidFormat;
        }

        const lat_val = std.fmt.parseFloat(f64, lat_str) catch return GeoError.InvalidCharacter;
        const lon_val = std.fmt.parseFloat(f64, lon_str) catch return GeoError.InvalidCharacter;
        const alt_val = std.fmt.parseFloat(f64, alt_str) catch return GeoError.InvalidCharacter;

        return init(lat_val, lon_val, alt_val);
    }
};

// ============================================================================
// GeoPoint
// ============================================================================

/// A tagged union representing either a 2D or 3D geographic coordinate.
///
/// Useful when a function may accept positions with or without altitude.
pub const GeoPoint = union(enum) {
    point_2d: LatLon,
    point_3d: LatLonAlt,

    /// Return the latitude in decimal degrees.
    pub fn lat(self: GeoPoint) f64 {
        return switch (self) {
            .point_2d => |p| p.lat,
            .point_3d => |p| p.lat,
        };
    }

    /// Return the longitude in decimal degrees.
    pub fn lon(self: GeoPoint) f64 {
        return switch (self) {
            .point_2d => |p| p.lon,
            .point_3d => |p| p.lon,
        };
    }

    /// Return the altitude if available, or `null` for 2D points.
    pub fn alt(self: GeoPoint) ?f64 {
        return switch (self) {
            .point_2d => null,
            .point_3d => |p| p.alt,
        };
    }

    /// Convert to a `LatLon`, discarding altitude if present.
    pub fn toLatLon(self: GeoPoint) LatLon {
        return switch (self) {
            .point_2d => |p| p,
            .point_3d => |p| p.toLatLon(),
        };
    }

    /// Compute haversine great-circle distance to another `GeoPoint` in meters.
    /// Altitude is ignored — this is a surface-distance calculation.
    pub fn haversineDistance(self: GeoPoint, other: GeoPoint) f64 {
        return self.toLatLon().haversineDistance(other.toLatLon());
    }

    /// Test equality. Two `GeoPoint` values are equal only if they share the
    /// same variant and all fields match.
    pub fn eql(self: GeoPoint, other: GeoPoint) bool {
        return switch (self) {
            .point_2d => |a| switch (other) {
                .point_2d => |b| a.eql(b),
                .point_3d => false,
            },
            .point_3d => |a| switch (other) {
                .point_2d => false,
                .point_3d => |b| a.eql(b),
            },
        };
    }

    /// Format as the underlying type's format — `(lat, lon)` or `(lat, lon, alt)`.
    pub fn format(self: GeoPoint, writer: anytype) !void {
        switch (self) {
            .point_2d => |p| try p.format(writer),
            .point_3d => |p| try p.format(writer),
        }
    }

    /// Parse a `GeoPoint` from either `(lat, lon)` or `(lat, lon, alt)` format.
    ///
    /// Determines dimensionality by counting commas inside the parentheses:
    /// one comma = 2D, two commas = 3D.
    pub fn parse(input: []const u8) GeoError!GeoPoint {
        const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);

        if (trimmed.len < 3 or trimmed[0] != '(' or trimmed[trimmed.len - 1] != ')') {
            return GeoError.InvalidFormat;
        }

        const inner = trimmed[1 .. trimmed.len - 1];
        const comma_count = std.mem.count(u8, inner, ",");

        return switch (comma_count) {
            1 => .{ .point_2d = try LatLon.parse(input) },
            2 => .{ .point_3d = try LatLonAlt.parse(input) },
            else => GeoError.InvalidFormat,
        };
    }
};

// ============================================================================
// Tests — LatLon
// ============================================================================

test "LatLon: valid creation" {
    const ll = try LatLon.init(37.7749, -122.4194);
    try testing.expectApproxEqAbs(@as(f64, 37.7749), ll.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), ll.lon, 1e-10);
}

test "LatLon: boundary values" {
    _ = try LatLon.init(90.0, 180.0);
    _ = try LatLon.init(-90.0, -180.0);
    _ = try LatLon.init(0.0, 0.0);
}

test "LatLon: invalid latitude" {
    try testing.expectError(GeoError.LatitudeOutOfRange, LatLon.init(90.1, 0.0));
    try testing.expectError(GeoError.LatitudeOutOfRange, LatLon.init(-90.1, 0.0));
    try testing.expectError(GeoError.LatitudeOutOfRange, LatLon.init(math.nan(f64), 0.0));
}

test "LatLon: invalid longitude" {
    try testing.expectError(GeoError.LongitudeOutOfRange, LatLon.init(0.0, 180.1));
    try testing.expectError(GeoError.LongitudeOutOfRange, LatLon.init(0.0, -180.1));
    try testing.expectError(GeoError.LongitudeOutOfRange, LatLon.init(0.0, math.nan(f64)));
}

test "LatLon: equality" {
    const a = LatLon.initUnchecked(51.5074, -0.1278);
    const b = LatLon.initUnchecked(51.5074, -0.1278);
    const c = LatLon.initUnchecked(51.5074, 0.0);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "LatLon: haversine NYC to London ~5570 km" {
    // NYC: 40.7128 N, 74.0060 W — London: 51.5074 N, 0.1278 W
    const nyc = try LatLon.init(40.7128, -74.0060);
    const london = try LatLon.init(51.5074, -0.1278);
    const distance = nyc.haversineDistance(london);

    // Known reference ~5570 km; accept 20 km tolerance for spherical model.
    try testing.expectApproxEqAbs(@as(f64, 5_570_000.0), distance, 20_000.0);
}

test "LatLon: haversine zero distance (same point)" {
    const p = try LatLon.init(45.0, 90.0);
    try testing.expectApproxEqAbs(@as(f64, 0.0), p.haversineDistance(p), 1e-6);
}

test "LatLon: haversine poles" {
    const north = try LatLon.init(90.0, 0.0);
    const south = try LatLon.init(-90.0, 0.0);
    // Half circumference = π * R ≈ 20_015_087 m
    const expected = math.pi * earth_radius_m;
    try testing.expectApproxEqAbs(expected, north.haversineDistance(south), 1.0);
}

test "LatLon: haversine antimeridian" {
    const a = try LatLon.init(0.0, 179.0);
    const b = try LatLon.init(0.0, -179.0);
    // 2 degrees of longitude at the equator ≈ 222.4 km
    const expected: f64 = 2.0 * (math.pi / 180.0) * earth_radius_m;
    try testing.expectApproxEqAbs(expected, a.haversineDistance(b), 100.0);
}

test "LatLon: format" {
    const ll = LatLon.initUnchecked(37.7749, -122.4194);
    var buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{ll}) catch unreachable;
    try testing.expectEqualStrings("(37.7749, -122.4194)", result);
}

test "LatLon: format and parse roundtrip" {
    const original = try LatLon.init(37.7749, -122.4194);
    var buf: [128]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try LatLon.parse(formatted);
    try testing.expectApproxEqAbs(original.lat, parsed.lat, 1e-10);
    try testing.expectApproxEqAbs(original.lon, parsed.lon, 1e-10);
}

test "LatLon: parse valid" {
    const ll = try LatLon.parse("(37.7749, -122.4194)");
    try testing.expectApproxEqAbs(@as(f64, 37.7749), ll.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), ll.lon, 1e-10);
}

test "LatLon: parse with extra whitespace" {
    const ll = try LatLon.parse("  ( 37.7749 , -122.4194 )  ");
    try testing.expectApproxEqAbs(@as(f64, 37.7749), ll.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), ll.lon, 1e-10);
}

test "LatLon: parse invalid format" {
    try testing.expectError(GeoError.InvalidFormat, LatLon.parse("37.7749, -122.4194"));
    try testing.expectError(GeoError.InvalidFormat, LatLon.parse("()"));
    try testing.expectError(GeoError.InvalidFormat, LatLon.parse("(37.7749)"));
    try testing.expectError(GeoError.InvalidFormat, LatLon.parse(""));
}

test "LatLon: parse invalid character" {
    try testing.expectError(GeoError.InvalidCharacter, LatLon.parse("(abc, 0.0)"));
}

test "LatLon: parse out of range" {
    try testing.expectError(GeoError.LatitudeOutOfRange, LatLon.parse("(91.0, 0.0)"));
    try testing.expectError(GeoError.LongitudeOutOfRange, LatLon.parse("(0.0, 181.0)"));
}

// ============================================================================
// Tests — LatLonAlt
// ============================================================================

test "LatLonAlt: valid creation" {
    const lla = try LatLonAlt.init(37.7749, -122.4194, 10.5);
    try testing.expectApproxEqAbs(@as(f64, 37.7749), lla.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), lla.lon, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 10.5), lla.alt, 1e-10);
}

test "LatLonAlt: invalid lat/lon" {
    try testing.expectError(GeoError.LatitudeOutOfRange, LatLonAlt.init(91.0, 0.0, 0.0));
    try testing.expectError(GeoError.LongitudeOutOfRange, LatLonAlt.init(0.0, 181.0, 0.0));
}

test "LatLonAlt: negative altitude (below sea level)" {
    const dead_sea = try LatLonAlt.init(31.5, 35.5, -430.0);
    try testing.expectApproxEqAbs(@as(f64, -430.0), dead_sea.alt, 1e-10);
}

test "LatLonAlt: toLatLon drops altitude" {
    const lla = LatLonAlt.initUnchecked(37.7749, -122.4194, 100.0);
    const ll = lla.toLatLon();
    try testing.expectApproxEqAbs(lla.lat, ll.lat, 1e-10);
    try testing.expectApproxEqAbs(lla.lon, ll.lon, 1e-10);
}

test "LatLonAlt: equality" {
    const a = LatLonAlt.initUnchecked(37.7749, -122.4194, 10.0);
    const b = LatLonAlt.initUnchecked(37.7749, -122.4194, 10.0);
    const c = LatLonAlt.initUnchecked(37.7749, -122.4194, 20.0);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "LatLonAlt: format and parse roundtrip" {
    const original = try LatLonAlt.init(37.7749, -122.4194, 10.5);
    var buf: [192]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try LatLonAlt.parse(formatted);
    try testing.expectApproxEqAbs(original.lat, parsed.lat, 1e-10);
    try testing.expectApproxEqAbs(original.lon, parsed.lon, 1e-10);
    try testing.expectApproxEqAbs(original.alt, parsed.alt, 1e-10);
}

test "LatLonAlt: parse valid" {
    const lla = try LatLonAlt.parse("(37.7749, -122.4194, 10.5)");
    try testing.expectApproxEqAbs(@as(f64, 37.7749), lla.lat, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), lla.lon, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 10.5), lla.alt, 1e-10);
}

test "LatLonAlt: parse invalid format" {
    try testing.expectError(GeoError.InvalidFormat, LatLonAlt.parse("(37.7749, -122.4194)"));
    try testing.expectError(GeoError.InvalidFormat, LatLonAlt.parse(""));
}

test "LatLonAlt: nan altitude rejected" {
    try testing.expectError(GeoError.InvalidFormat, LatLonAlt.init(0.0, 0.0, math.nan(f64)));
}

test "LatLonAlt: inf altitude rejected" {
    try testing.expectError(GeoError.InvalidFormat, LatLonAlt.init(0.0, 0.0, math.inf(f64)));
}

test "LatLonAlt: parse nan altitude rejected" {
    try testing.expectError(GeoError.InvalidFormat, LatLonAlt.parse("(0, 0, nan)"));
}

// ============================================================================
// Tests — GeoPoint
// ============================================================================

test "GeoPoint: 2D variant" {
    const ll = try LatLon.init(37.7749, -122.4194);
    const gp = GeoPoint{ .point_2d = ll };
    try testing.expectApproxEqAbs(@as(f64, 37.7749), gp.lat(), 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), gp.lon(), 1e-10);
    try testing.expect(gp.alt() == null);
}

test "GeoPoint: 3D variant" {
    const lla = try LatLonAlt.init(37.7749, -122.4194, 100.0);
    const gp = GeoPoint{ .point_3d = lla };
    try testing.expectApproxEqAbs(@as(f64, 37.7749), gp.lat(), 1e-10);
    try testing.expectApproxEqAbs(@as(f64, -122.4194), gp.lon(), 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 100.0), gp.alt().?, 1e-10);
}

test "GeoPoint: toLatLon from both variants" {
    const ll = LatLon.initUnchecked(10.0, 20.0);
    const lla = LatLonAlt.initUnchecked(10.0, 20.0, 500.0);

    const gp2 = GeoPoint{ .point_2d = ll };
    const gp3 = GeoPoint{ .point_3d = lla };

    try testing.expect(gp2.toLatLon().eql(ll));
    try testing.expect(gp3.toLatLon().eql(ll));
}

test "GeoPoint: haversine distance across variants" {
    const nyc_2d = GeoPoint{ .point_2d = try LatLon.init(40.7128, -74.0060) };
    const london_3d = GeoPoint{ .point_3d = try LatLonAlt.init(51.5074, -0.1278, 11.0) };
    const distance = nyc_2d.haversineDistance(london_3d);
    try testing.expectApproxEqAbs(@as(f64, 5_570_000.0), distance, 20_000.0);
}

test "GeoPoint: equality same variant" {
    const a = GeoPoint{ .point_2d = LatLon.initUnchecked(1.0, 2.0) };
    const b = GeoPoint{ .point_2d = LatLon.initUnchecked(1.0, 2.0) };
    const c = GeoPoint{ .point_2d = LatLon.initUnchecked(1.0, 3.0) };
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "GeoPoint: equality different variants" {
    const a = GeoPoint{ .point_2d = LatLon.initUnchecked(1.0, 2.0) };
    const b = GeoPoint{ .point_3d = LatLonAlt.initUnchecked(1.0, 2.0, 0.0) };
    // Different variants are never equal, even with matching lat/lon.
    try testing.expect(!a.eql(b));
}

test "GeoPoint: format 2D" {
    const gp = GeoPoint{ .point_2d = LatLon.initUnchecked(1.0, 2.0) };
    var buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{gp}) catch unreachable;
    try testing.expectEqualStrings("(1, 2)", result);
}

test "GeoPoint: format 3D" {
    const gp = GeoPoint{ .point_3d = LatLonAlt.initUnchecked(1.0, 2.0, 3.0) };
    var buf: [128]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{gp}) catch unreachable;
    try testing.expectEqualStrings("(1, 2, 3)", result);
}

test "GeoPoint: parse 2D" {
    const gp = try GeoPoint.parse("(37.7749, -122.4194)");
    try testing.expect(gp.alt() == null);
    try testing.expectApproxEqAbs(@as(f64, 37.7749), gp.lat(), 1e-10);
}

test "GeoPoint: parse 3D" {
    const gp = try GeoPoint.parse("(37.7749, -122.4194, 10.0)");
    try testing.expectApproxEqAbs(@as(f64, 10.0), gp.alt().?, 1e-10);
}

test "GeoPoint: parse invalid" {
    try testing.expectError(GeoError.InvalidFormat, GeoPoint.parse("not a point"));
}
