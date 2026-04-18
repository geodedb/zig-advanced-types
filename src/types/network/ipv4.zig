// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! IPv4 address value type.
//!
//! Q45: extracted from the monolithic `src/types/network.zig` into its
//! own file under `types/network/`. Public API (`Ipv4Addr`, its
//! constants, methods, and tests) is byte-for-byte unchanged.

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const ParseError = common.ParseError;
const MAX_IPV4_INPUT = common.MAX_IPV4_INPUT;

// ============================================================================
// Ipv4Addr
// ============================================================================

/// An IPv4 address represented as 4 octets.
pub const Ipv4Addr = struct {
    octets: [4]u8,

    const Self = @This();

    /// The loopback address (127.0.0.1).
    pub const localhost = Self{ .octets = .{ 127, 0, 0, 1 } };
    /// The unspecified address (0.0.0.0), used to bind to all interfaces.
    pub const any = Self{ .octets = .{ 0, 0, 0, 0 } };
    /// The broadcast address (255.255.255.255).
    pub const broadcast = Self{ .octets = .{ 255, 255, 255, 255 } };

    /// Create an IPv4 address from four individual octets.
    pub fn init(a: u8, b: u8, c: u8, d: u8) Self {
        return .{ .octets = .{ a, b, c, d } };
    }

    /// Create an IPv4 address from a 32-bit integer in network (big-endian) byte order.
    pub fn fromU32(value: u32) Self {
        return .{ .octets = .{
            @intCast((value >> 24) & 0xFF),
            @intCast((value >> 16) & 0xFF),
            @intCast((value >> 8) & 0xFF),
            @intCast(value & 0xFF),
        } };
    }

    /// Convert this address to a 32-bit integer in network (big-endian) byte order.
    pub fn toU32(self: Self) u32 {
        return @as(u32, self.octets[0]) << 24 |
            @as(u32, self.octets[1]) << 16 |
            @as(u32, self.octets[2]) << 8 |
            @as(u32, self.octets[3]);
    }

    /// Parse an IPv4 address from dotted-decimal notation (e.g., "192.168.1.1").
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;
        if (input.len > MAX_IPV4_INPUT) return error.InputTooLong;

        var octets: [4]u8 = undefined;
        var octet_index: u8 = 0;
        var current_value: u16 = 0;
        var digit_count: u8 = 0;

        for (input) |ch| {
            if (ch == '.') {
                if (digit_count == 0) return error.InvalidFormat;
                if (octet_index >= 3) return error.InvalidFormat;
                if (current_value > 255) return error.Overflow;
                octets[octet_index] = @intCast(current_value);
                octet_index += 1;
                current_value = 0;
                digit_count = 0;
            } else if (ch >= '0' and ch <= '9') {
                digit_count += 1;
                if (digit_count > 3) return error.Overflow;
                current_value = current_value * 10 + (ch - '0');
            } else {
                return error.InvalidCharacter;
            }
        }

        // Handle the last octet
        if (digit_count == 0) return error.InvalidFormat;
        if (octet_index != 3) return error.InvalidFormat;
        if (current_value > 255) return error.Overflow;
        octets[octet_index] = @intCast(current_value);

        return .{ .octets = octets };
    }

    /// Write this address in dotted-decimal notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        try writer.print("{}.{}.{}.{}", .{
            self.octets[0],
            self.octets[1],
            self.octets[2],
            self.octets[3],
        });
    }

    /// Returns true if both addresses have identical octets.
    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.octets, &other.octets);
    }

    /// Returns true if this is a loopback address (127.0.0.0/8).
    pub fn isLoopback(self: Self) bool {
        return self.octets[0] == 127;
    }

    /// Returns true if this is a private address (10/8, 172.16/12, or 192.168/16).
    pub fn isPrivate(self: Self) bool {
        // 10.0.0.0/8
        if (self.octets[0] == 10) return true;
        // 172.16.0.0/12
        if (self.octets[0] == 172 and (self.octets[1] >= 16 and self.octets[1] <= 31)) return true;
        // 192.168.0.0/16
        if (self.octets[0] == 192 and self.octets[1] == 168) return true;
        return false;
    }

    /// Returns true if this is a multicast address (224.0.0.0/4).
    pub fn isMulticast(self: Self) bool {
        // 224.0.0.0 - 239.255.255.255
        return self.octets[0] >= 224 and self.octets[0] <= 239;
    }

    /// Returns true if this IPv4 address is safe to use as the target of an
    /// outbound HTTP/network fetch (SSRF defense). Rejects loopback, private
    /// (RFC 1918), link-local (169.254/16), CGNAT (100.64/10), multicast
    /// (224/4), broadcast / unspecified (255.255.255.255 / 0.0.0.0), and
    /// reserved (240/4) ranges.
    pub fn isSafeForOutboundFetch(self: Self) bool {
        // 0.0.0.0/8 — "this network"; callers must not dial 0.0.0.0
        if (self.octets[0] == 0) return false;
        // 127.0.0.0/8 — loopback
        if (self.isLoopback()) return false;
        // 10/8, 172.16/12, 192.168/16 — RFC 1918 private
        if (self.isPrivate()) return false;
        // 169.254.0.0/16 — link-local (AWS/GCP metadata lives at 169.254.169.254)
        if (self.octets[0] == 169 and self.octets[1] == 254) return false;
        // 100.64.0.0/10 — Carrier-Grade NAT (RFC 6598)
        if (self.octets[0] == 100 and (self.octets[1] >= 64 and self.octets[1] <= 127)) return false;
        // 224/4 — multicast
        if (self.isMulticast()) return false;
        // 240/4 — reserved (includes 255.255.255.255 broadcast)
        if (self.octets[0] >= 240) return false;
        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Ipv4Addr.parse valid addresses" {
    const addr = try Ipv4Addr.parse("192.168.1.1");
    try testing.expectEqual(@as(u8, 192), addr.octets[0]);
    try testing.expectEqual(@as(u8, 168), addr.octets[1]);
    try testing.expectEqual(@as(u8, 1), addr.octets[2]);
    try testing.expectEqual(@as(u8, 1), addr.octets[3]);

    const loopback = try Ipv4Addr.parse("127.0.0.1");
    try testing.expect(loopback.eql(Ipv4Addr.localhost));

    const zeros = try Ipv4Addr.parse("0.0.0.0");
    try testing.expect(zeros.eql(Ipv4Addr.any));

    const max = try Ipv4Addr.parse("255.255.255.255");
    try testing.expect(max.eql(Ipv4Addr.broadcast));
}

test "Ipv4Addr.parse invalid addresses" {
    try testing.expectError(error.InvalidFormat, Ipv4Addr.parse(""));
    try testing.expectError(error.InvalidFormat, Ipv4Addr.parse("1.2.3"));
    try testing.expectError(error.InvalidFormat, Ipv4Addr.parse("1.2.3.4.5"));
    try testing.expectError(error.Overflow, Ipv4Addr.parse("256.0.0.1"));
    try testing.expectError(error.InvalidCharacter, Ipv4Addr.parse("1.2.3.x"));
    try testing.expectError(error.InvalidFormat, Ipv4Addr.parse(".1.2.3"));
    try testing.expectError(error.InvalidFormat, Ipv4Addr.parse("1.2.3."));
}

test "Ipv4Addr.format" {
    const addr = Ipv4Addr.init(10, 0, 0, 1);
    var buf: [15]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{addr}) catch unreachable;
    try testing.expectEqualStrings("10.0.0.1", result);
}

test "Ipv4Addr.isLoopback" {
    try testing.expect(Ipv4Addr.localhost.isLoopback());
    try testing.expect((try Ipv4Addr.parse("127.255.0.1")).isLoopback());
    try testing.expect(!(try Ipv4Addr.parse("10.0.0.1")).isLoopback());
}

test "Ipv4Addr.isPrivate" {
    try testing.expect((try Ipv4Addr.parse("10.0.0.1")).isPrivate());
    try testing.expect((try Ipv4Addr.parse("10.255.255.255")).isPrivate());
    try testing.expect((try Ipv4Addr.parse("172.16.0.1")).isPrivate());
    try testing.expect((try Ipv4Addr.parse("172.31.255.255")).isPrivate());
    try testing.expect((try Ipv4Addr.parse("192.168.0.1")).isPrivate());
    try testing.expect((try Ipv4Addr.parse("192.168.255.255")).isPrivate());
    try testing.expect(!(try Ipv4Addr.parse("8.8.8.8")).isPrivate());
    try testing.expect(!(try Ipv4Addr.parse("172.32.0.1")).isPrivate());
}

test "Ipv4Addr.isMulticast" {
    try testing.expect((try Ipv4Addr.parse("224.0.0.1")).isMulticast());
    try testing.expect((try Ipv4Addr.parse("239.255.255.255")).isMulticast());
    try testing.expect(!(try Ipv4Addr.parse("223.255.255.255")).isMulticast());
    try testing.expect(!(try Ipv4Addr.parse("240.0.0.0")).isMulticast());
}

test "Ipv4Addr.toU32 and fromU32 roundtrip" {
    const addr = Ipv4Addr.init(192, 168, 1, 1);
    const as_u32 = addr.toU32();
    try testing.expectEqual(@as(u32, 0xC0A80101), as_u32);

    const back = Ipv4Addr.fromU32(as_u32);
    try testing.expect(addr.eql(back));

    // Edge cases
    const zero = Ipv4Addr.any;
    try testing.expectEqual(@as(u32, 0), zero.toU32());
    try testing.expect(zero.eql(Ipv4Addr.fromU32(0)));

    const max = Ipv4Addr.broadcast;
    try testing.expectEqual(@as(u32, 0xFFFFFFFF), max.toU32());
    try testing.expect(max.eql(Ipv4Addr.fromU32(0xFFFFFFFF)));
}

test "Ipv4Addr.eql" {
    const a = Ipv4Addr.init(10, 0, 0, 1);
    const b = Ipv4Addr.init(10, 0, 0, 1);
    const c = Ipv4Addr.init(10, 0, 0, 2);
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "Ipv4Addr.isSafeForOutboundFetch rejects SSRF-dangerous ranges" {
    // Loopback
    try testing.expect(!Ipv4Addr.localhost.isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("127.0.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("127.255.255.255")).isSafeForOutboundFetch());
    // Private RFC 1918
    try testing.expect(!(try Ipv4Addr.parse("10.0.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("172.16.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("172.31.255.255")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("192.168.1.1")).isSafeForOutboundFetch());
    // Link-local (AWS metadata)
    try testing.expect(!(try Ipv4Addr.parse("169.254.169.254")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("169.254.0.1")).isSafeForOutboundFetch());
    // CGNAT 100.64/10
    try testing.expect(!(try Ipv4Addr.parse("100.64.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("100.127.255.255")).isSafeForOutboundFetch());
    // Multicast 224/4
    try testing.expect(!(try Ipv4Addr.parse("224.0.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("239.255.255.255")).isSafeForOutboundFetch());
    // Broadcast / unspecified / reserved
    try testing.expect(!Ipv4Addr.any.isSafeForOutboundFetch()); // 0.0.0.0
    try testing.expect(!(try Ipv4Addr.parse("0.1.2.3")).isSafeForOutboundFetch());
    try testing.expect(!Ipv4Addr.broadcast.isSafeForOutboundFetch()); // 255.255.255.255
    try testing.expect(!(try Ipv4Addr.parse("240.0.0.1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv4Addr.parse("255.0.0.1")).isSafeForOutboundFetch());

    // Safe public addresses
    try testing.expect((try Ipv4Addr.parse("8.8.8.8")).isSafeForOutboundFetch());
    try testing.expect((try Ipv4Addr.parse("1.1.1.1")).isSafeForOutboundFetch());
    try testing.expect((try Ipv4Addr.parse("100.63.255.255")).isSafeForOutboundFetch()); // just below CGNAT
    try testing.expect((try Ipv4Addr.parse("100.128.0.1")).isSafeForOutboundFetch()); // just above CGNAT
    try testing.expect((try Ipv4Addr.parse("169.253.0.1")).isSafeForOutboundFetch()); // just below link-local
}

test "Ipv4Addr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "1" ** (MAX_IPV4_INPUT + 1);
    try testing.expectError(error.InputTooLong, Ipv4Addr.parse(big));
    // cap boundary still accepted if syntactically valid
    _ = try Ipv4Addr.parse("255.255.255.255");
}
