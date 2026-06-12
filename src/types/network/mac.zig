// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! MAC (IEEE 802) hardware address value type.
//!
//! Q45: extracted from the monolithic `src/types/network.zig`. Public
//! API is byte-for-byte unchanged.

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const ParseError = common.ParseError;

const hex = @import("hex.zig");
const hexDigitToInt = hex.hexDigitToInt;

// ============================================================================
// Mac
// ============================================================================

/// A MAC (IEEE 802) hardware address represented as 6 octets.
pub const Mac = struct {
    octets: [6]u8,

    const Self = @This();

    /// The broadcast MAC address (FF:FF:FF:FF:FF:FF).
    pub const broadcast = Self{ .octets = .{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF } };

    /// Parse a MAC address from colon- or hyphen-separated hex notation (e.g., "AA:BB:CC:DD:EE:FF").
    pub fn parse(input: []const u8) ParseError!Self {
        // Expect "AA:BB:CC:DD:EE:FF" or "AA-BB-CC-DD-EE-FF" (17 characters)
        if (input.len != 17) return error.InvalidLength;

        // Determine and validate separator (must be ':' or '-')
        const sep = input[2];
        if (sep != ':' and sep != '-') return error.InvalidFormat;

        var octets: [6]u8 = undefined;

        for (0..6) |i| {
            const offset = i * 3;

            // Validate separator between octets
            if (i > 0) {
                if (input[offset - 1] != sep) return error.InvalidFormat;
            }

            const hi = hexDigitToInt(input[offset]) orelse return error.InvalidCharacter;
            const lo = hexDigitToInt(input[offset + 1]) orelse return error.InvalidCharacter;
            octets[i] = hi << 4 | lo;
        }

        return .{ .octets = octets };
    }

    /// Write this address in uppercase colon-separated hex notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        const hex_digits = "0123456789ABCDEF";
        var buf: [17]u8 = undefined;
        inline for (0..6) |i| {
            if (i > 0) buf[i * 3 - 1] = ':';
            buf[i * 3] = hex_digits[self.octets[i] >> 4];
            buf[i * 3 + 1] = hex_digits[self.octets[i] & 0x0F];
        }
        try writer.writeAll(&buf);
    }

    /// Returns true if both MAC addresses have identical octets.
    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.octets, &other.octets);
    }

    /// Returns true if this is the broadcast address (FF:FF:FF:FF:FF:FF).
    pub fn isBroadcast(self: Self) bool {
        return std.mem.eql(u8, &self.octets, &broadcast.octets);
    }

    /// Returns true if this is a multicast address (LSB of first octet is set).
    pub fn isMulticast(self: Self) bool {
        // Least significant bit of the first octet is 1
        return (self.octets[0] & 0x01) == 0x01;
    }

    /// Returns true if this is a locally administered address (second LSB of first octet is set).
    pub fn isLocallyAdministered(self: Self) bool {
        // Second least significant bit of the first octet is 1
        return (self.octets[0] & 0x02) == 0x02;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Mac.parse colon-separated" {
    const mac = try Mac.parse("AA:BB:CC:DD:EE:FF");
    try testing.expectEqual(@as(u8, 0xAA), mac.octets[0]);
    try testing.expectEqual(@as(u8, 0xBB), mac.octets[1]);
    try testing.expectEqual(@as(u8, 0xCC), mac.octets[2]);
    try testing.expectEqual(@as(u8, 0xDD), mac.octets[3]);
    try testing.expectEqual(@as(u8, 0xEE), mac.octets[4]);
    try testing.expectEqual(@as(u8, 0xFF), mac.octets[5]);
}

test "Mac.parse hyphen-separated" {
    const mac = try Mac.parse("01-23-45-67-89-AB");
    try testing.expectEqual(@as(u8, 0x01), mac.octets[0]);
    try testing.expectEqual(@as(u8, 0x23), mac.octets[1]);
    try testing.expectEqual(@as(u8, 0x45), mac.octets[2]);
    try testing.expectEqual(@as(u8, 0x67), mac.octets[3]);
    try testing.expectEqual(@as(u8, 0x89), mac.octets[4]);
    try testing.expectEqual(@as(u8, 0xAB), mac.octets[5]);
}

test "Mac.parse lowercase" {
    const mac = try Mac.parse("aa:bb:cc:dd:ee:ff");
    try testing.expectEqual(@as(u8, 0xAA), mac.octets[0]);
    try testing.expectEqual(@as(u8, 0xFF), mac.octets[5]);
}

test "Mac.parse invalid" {
    try testing.expectError(error.InvalidLength, Mac.parse(""));
    try testing.expectError(error.InvalidLength, Mac.parse("AA:BB:CC:DD:EE"));
    try testing.expectError(error.InvalidLength, Mac.parse("AA:BB:CC:DD:EE:FF:00"));
    try testing.expectError(error.InvalidCharacter, Mac.parse("GG:BB:CC:DD:EE:FF"));
    try testing.expectError(error.InvalidFormat, Mac.parse("AA:BB-CC:DD:EE:FF"));
    try testing.expectError(error.InvalidFormat, Mac.parse("AA.BB.CC.DD.EE.FF"));
}

test "Mac.format" {
    const mac = try Mac.parse("aa:bb:cc:dd:ee:ff");
    var buf: [17]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{mac}) catch unreachable;
    try testing.expectEqualStrings("AA:BB:CC:DD:EE:FF", result);
}

test "Mac.isBroadcast" {
    try testing.expect(Mac.broadcast.isBroadcast());
    try testing.expect((try Mac.parse("FF:FF:FF:FF:FF:FF")).isBroadcast());
    try testing.expect(!(try Mac.parse("00:00:00:00:00:00")).isBroadcast());
}

test "Mac.isMulticast" {
    // Broadcast is also multicast (LSB of first octet is set)
    try testing.expect(Mac.broadcast.isMulticast());
    try testing.expect((try Mac.parse("01:00:00:00:00:00")).isMulticast());
    try testing.expect(!(try Mac.parse("00:00:00:00:00:00")).isMulticast());
    try testing.expect(!(try Mac.parse("02:00:00:00:00:00")).isMulticast());
}

test "Mac.isLocallyAdministered" {
    try testing.expect((try Mac.parse("02:00:00:00:00:00")).isLocallyAdministered());
    try testing.expect((try Mac.parse("06:00:00:00:00:00")).isLocallyAdministered());
    try testing.expect(!(try Mac.parse("00:00:00:00:00:00")).isLocallyAdministered());
    try testing.expect(!(try Mac.parse("01:00:00:00:00:00")).isLocallyAdministered());
}

test "Mac.eql" {
    const a = try Mac.parse("AA:BB:CC:DD:EE:FF");
    const b = try Mac.parse("aa:bb:cc:dd:ee:ff");
    const c = try Mac.parse("00:00:00:00:00:00");
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}
