// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Generic `IpAddr` tagged-union over `Ipv4Addr` and `Ipv6Addr`.
//!
//! Q45: extracted from the monolithic `src/types/network.zig` so the
//! `Subnet` submodule that follows can depend on `IpAddr` without
//! importing the facade (which would cycle). Public API is byte-for-byte
//! unchanged.

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const ParseError = common.ParseError;
const MAX_IP_INPUT = common.MAX_IP_INPUT;

const ipv4 = @import("ipv4.zig");
const Ipv4Addr = ipv4.Ipv4Addr;
const ipv6 = @import("ipv6.zig");
const Ipv6Addr = ipv6.Ipv6Addr;

// ============================================================================
// IpAddr
// ============================================================================

/// A generic IP address, either IPv4 or IPv6.
pub const IpAddr = union(enum) {
    v4: Ipv4Addr,
    v6: Ipv6Addr,

    const Self = @This();

    /// Parse an IP address, auto-detecting IPv4 vs IPv6 by the presence of colons.
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;
        if (input.len > MAX_IP_INPUT) return error.InputTooLong;

        // If input contains a colon, try IPv6; otherwise try IPv4.
        for (input) |ch| {
            if (ch == ':') {
                const v6 = try Ipv6Addr.parse(input);
                return Self{ .v6 = v6 };
            }
        }

        const v4 = try Ipv4Addr.parse(input);
        return Self{ .v4 = v4 };
    }

    /// Write this address to the given writer, delegating to the inner type's format.
    pub fn format(self: Self, writer: anytype) !void {
        switch (self) {
            .v4 => |v4| try v4.format(writer),
            .v6 => |v6| try v6.format(writer),
        }
    }

    /// Returns true if both addresses are the same family and have equal values.
    pub fn eql(self: Self, other: Self) bool {
        switch (self) {
            .v4 => |s4| switch (other) {
                .v4 => |o4| return s4.eql(o4),
                .v6 => return false,
            },
            .v6 => |s6| switch (other) {
                .v4 => return false,
                .v6 => |o6| return s6.eql(o6),
            },
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IpAddr.parse auto-detects v4 vs v6" {
    const v4 = try IpAddr.parse("192.168.1.1");
    switch (v4) {
        .v4 => |addr| try testing.expect(addr.eql(Ipv4Addr.init(192, 168, 1, 1))),
        .v6 => return error.InvalidFormat,
    }

    const v6 = try IpAddr.parse("::1");
    switch (v6) {
        .v4 => return error.InvalidFormat,
        .v6 => |addr| try testing.expect(addr.isLoopback()),
    }

    const v6_full = try IpAddr.parse("2001:db8::1");
    switch (v6_full) {
        .v4 => return error.InvalidFormat,
        .v6 => {},
    }
}

test "IpAddr.parse invalid" {
    try testing.expectError(error.InvalidFormat, IpAddr.parse(""));
}

test "IpAddr.format" {
    const v4 = IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) };
    var buf: [45]u8 = undefined;
    const r1 = std.fmt.bufPrint(&buf, "{f}", .{v4}) catch unreachable;
    try testing.expectEqualStrings("10.0.0.1", r1);

    const v6 = IpAddr{ .v6 = Ipv6Addr.localhost };
    const r2 = std.fmt.bufPrint(&buf, "{f}", .{v6}) catch unreachable;
    try testing.expectEqualStrings("::1", r2);
}

test "IpAddr.eql" {
    const a = IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) };
    const b = IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) };
    const c = IpAddr{ .v6 = Ipv6Addr.localhost };
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
    try testing.expect(!c.eql(a));
}

test "IpAddr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "9" ** (MAX_IP_INPUT + 1);
    try testing.expectError(error.InputTooLong, IpAddr.parse(big));
    _ = try IpAddr.parse("10.0.0.1");
    _ = try IpAddr.parse("::1");
}
