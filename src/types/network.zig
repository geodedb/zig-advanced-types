// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Portable network value types for IPv4, IPv6, Subnet (CIDR), and MAC addresses.
//!
//! All types are plain value types that require no allocator for core operations
//! including parsing, formatting, equality comparison, and classification.

const std = @import("std");
const testing = std.testing;

// ============================================================================
// Shared Helpers
// ============================================================================

/// Convert an ASCII hex digit to its integer value (0-15), or null if invalid.
fn hexDigitToInt(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}

// ============================================================================
// Error Type
// ============================================================================

/// Errors that can occur when parsing network addresses and subnets.
pub const ParseError = error{
    InvalidCharacter,
    InvalidFormat,
    InvalidLength,
    Overflow,
};

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
};

// ============================================================================
// Ipv6Addr
// ============================================================================

/// An IPv6 address represented as 16 octets.
pub const Ipv6Addr = struct {
    octets: [16]u8,

    const Self = @This();

    /// The loopback address (::1).
    pub const localhost = blk: {
        var addr: [16]u8 = .{0} ** 16;
        addr[15] = 1;
        break :blk Self{ .octets = addr };
    };

    /// The unspecified address (::).
    pub const any = Self{ .octets = .{0} ** 16 };

    /// Create an IPv6 address from eight 16-bit segments.
    pub fn init(segs: [8]u16) Self {
        var octets: [16]u8 = undefined;
        for (segs, 0..) |seg, i| {
            octets[i * 2] = @intCast((seg >> 8) & 0xFF);
            octets[i * 2 + 1] = @intCast(seg & 0xFF);
        }
        return .{ .octets = octets };
    }

    /// Returns the eight 16-bit segments of the address.
    fn segments(self: Self) [8]u16 {
        var segs: [8]u16 = undefined;
        for (0..8) |i| {
            segs[i] = @as(u16, self.octets[i * 2]) << 8 | @as(u16, self.octets[i * 2 + 1]);
        }
        return segs;
    }

    /// Parse an IPv6 address from colon-hex notation (e.g., "2001:db8::1").
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;

        var octets: [16]u8 = .{0} ** 16;

        // Handle :: shorthand
        // Split on "::" first to find left and right parts
        const double_colon_pos = findDoubleColon(input);

        if (double_colon_pos) |dc_pos| {
            const left = input[0..dc_pos];
            const right_start = dc_pos + 2;
            const right = if (right_start <= input.len) input[right_start..] else "";

            var left_count: usize = 0;
            var right_count: usize = 0;

            // Parse left groups
            if (left.len > 0) {
                left_count = try parseGroups(left, octets[0..], 8);
            }

            // Parse right groups
            if (right.len > 0) {
                var right_octets: [16]u8 = .{0} ** 16;
                right_count = try parseGroups(right, right_octets[0..], 8);

                if (left_count + right_count > 8) return error.InvalidFormat;

                // Copy right groups to their position at the end
                const right_offset = (8 - right_count) * 2;
                for (0..right_count * 2) |i| {
                    octets[right_offset + i] = right_octets[i];
                }
            }

            if (left_count + right_count > 8) return error.InvalidFormat;
        } else {
            // No ::, must have exactly 8 groups
            const count = try parseGroups(input, octets[0..], 8);
            if (count != 8) return error.InvalidFormat;
        }

        return .{ .octets = octets };
    }

    fn findDoubleColon(input: []const u8) ?usize {
        if (input.len < 2) return null;
        for (0..input.len - 1) |i| {
            if (input[i] == ':' and input[i + 1] == ':') {
                return i;
            }
        }
        return null;
    }

    fn parseGroups(input: []const u8, octets: []u8, max_groups: usize) ParseError!usize {
        var group_count: usize = 0;
        var current_value: u32 = 0;
        var digit_count: u8 = 0;

        for (input) |ch| {
            if (ch == ':') {
                if (digit_count == 0) return error.InvalidFormat;
                if (group_count >= max_groups) return error.InvalidFormat;
                if (current_value > 0xFFFF) return error.Overflow;
                octets[group_count * 2] = @intCast((current_value >> 8) & 0xFF);
                octets[group_count * 2 + 1] = @intCast(current_value & 0xFF);
                group_count += 1;
                current_value = 0;
                digit_count = 0;
            } else if (hexDigitValue(ch)) |val| {
                digit_count += 1;
                if (digit_count > 4) return error.Overflow;
                current_value = current_value * 16 + val;
            } else {
                return error.InvalidCharacter;
            }
        }

        // Handle the last group
        if (digit_count == 0) return error.InvalidFormat;
        if (group_count >= max_groups) return error.InvalidFormat;
        if (current_value > 0xFFFF) return error.Overflow;
        octets[group_count * 2] = @intCast((current_value >> 8) & 0xFF);
        octets[group_count * 2 + 1] = @intCast(current_value & 0xFF);
        group_count += 1;

        return group_count;
    }

    fn hexDigitValue(ch: u8) ?u32 {
        const v: u32 = hexDigitToInt(ch) orelse return null;
        return v;
    }

    /// Write this address in RFC 5952 canonical notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        const segs = self.segments();

        // Find the longest run of zero segments for :: compression
        var best_start: usize = 8;
        var best_len: usize = 0;
        var run_start: usize = 0;
        var run_len: usize = 0;

        for (segs, 0..) |seg, i| {
            if (seg == 0) {
                if (run_len == 0) run_start = i;
                run_len += 1;
                if (run_len > best_len) {
                    best_start = run_start;
                    best_len = run_len;
                }
            } else {
                run_len = 0;
            }
        }

        // Only compress runs of 2 or more zeros
        if (best_len < 2) {
            best_start = 8;
            best_len = 0;
        }

        var i: usize = 0;
        var need_colon = false;
        while (i < 8) {
            if (i == best_start) {
                try writer.writeAll("::");
                i += best_len;
                need_colon = false;
                continue;
            }
            if (need_colon) {
                try writer.writeByte(':');
            }
            try writer.print("{x}", .{segs[i]});
            need_colon = true;
            i += 1;
        }
    }

    /// Returns true if both addresses have identical octets.
    pub fn eql(self: Self, other: Self) bool {
        return std.mem.eql(u8, &self.octets, &other.octets);
    }

    /// Returns true if this is the loopback address (::1).
    pub fn isLoopback(self: Self) bool {
        return self.eql(localhost);
    }

    /// Returns the mapped IPv4 address if this is an IPv4-mapped IPv6 address
    /// (::ffff:x.x.x.x), otherwise null.
    pub fn toIpv4(self: Self) ?Ipv4Addr {
        // Check for ::ffff:x.x.x.x pattern
        // First 10 bytes must be 0, bytes 10-11 must be 0xFF
        for (self.octets[0..10]) |b| {
            if (b != 0) return null;
        }
        if (self.octets[10] != 0xFF or self.octets[11] != 0xFF) return null;

        return Ipv4Addr{
            .octets = .{
                self.octets[12],
                self.octets[13],
                self.octets[14],
                self.octets[15],
            },
        };
    }
};

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
// Subnet
// ============================================================================

/// A subnet in CIDR notation, combining a network address with a prefix length.
pub const Subnet = struct {
    network: IpAddr,
    prefix_len: u8,

    const Self = @This();

    /// Parse a CIDR subnet string (e.g., "192.168.1.0/24" or "2001:db8::/32").
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;

        // Find the '/' separator
        const slash_pos = std.mem.indexOfScalar(u8, input, '/') orelse return error.InvalidFormat;

        const addr_part = input[0..slash_pos];
        const prefix_part = input[slash_pos + 1 ..];

        if (prefix_part.len == 0) return error.InvalidFormat;

        const network = try IpAddr.parse(addr_part);

        // Parse prefix length
        var prefix_len: u16 = 0;
        for (prefix_part) |ch| {
            if (ch < '0' or ch > '9') return error.InvalidCharacter;
            prefix_len = prefix_len * 10 + (ch - '0');
            if (prefix_len > 128) return error.Overflow;
        }

        // Validate prefix length based on address family
        const max_prefix: u16 = switch (network) {
            .v4 => 32,
            .v6 => 128,
        };
        if (prefix_len > max_prefix) return error.Overflow;

        return .{
            .network = network,
            .prefix_len = @intCast(prefix_len),
        };
    }

    /// Returns true if the given address falls within this subnet.
    pub fn contains(self: Self, addr: IpAddr) bool {
        switch (self.network) {
            .v4 => |net4| {
                switch (addr) {
                    .v4 => |addr4| {
                        if (self.prefix_len == 0) return true;
                        if (self.prefix_len >= 32) return net4.eql(addr4);

                        const shift: u5 = @intCast(@as(u8, 32) - self.prefix_len);
                        const mask: u32 = @as(u32, 0xFFFFFFFF) << shift;
                        return (net4.toU32() & mask) == (addr4.toU32() & mask);
                    },
                    .v6 => return false,
                }
            },
            .v6 => |net6| {
                switch (addr) {
                    .v4 => return false,
                    .v6 => |addr6| {
                        if (self.prefix_len == 0) return true;

                        const full_bytes: u8 = self.prefix_len / 8;
                        const remaining_bits: u3 = @intCast(self.prefix_len % 8);

                        // Compare full bytes
                        if (full_bytes > 0) {
                            if (!std.mem.eql(u8, net6.octets[0..full_bytes], addr6.octets[0..full_bytes])) {
                                return false;
                            }
                        }

                        // Compare remaining bits in the next byte
                        if (remaining_bits > 0 and full_bytes < 16) {
                            const shift: u3 = @intCast(@as(u4, 8) - @as(u4, remaining_bits));
                            const mask: u8 = @as(u8, 0xFF) << shift;
                            if ((net6.octets[full_bytes] & mask) != (addr6.octets[full_bytes] & mask)) {
                                return false;
                            }
                        }

                        return true;
                    },
                }
            },
        }
    }

    /// Write this subnet in CIDR notation (address/prefix) to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        try self.network.format(writer);
        try writer.print("/{}", .{self.prefix_len});
    }

    /// Returns true if both subnets have the same network address and prefix length.
    pub fn eql(self: Self, other: Self) bool {
        return self.network.eql(other.network) and self.prefix_len == other.prefix_len;
    }
};

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

            const hi = hexVal(input[offset]) orelse return error.InvalidCharacter;
            const lo = hexVal(input[offset + 1]) orelse return error.InvalidCharacter;
            octets[i] = hi << 4 | lo;
        }

        return .{ .octets = octets };
    }

    fn hexVal(ch: u8) ?u8 {
        return hexDigitToInt(ch);
    }

    /// Write this address in uppercase colon-separated hex notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        for (self.octets, 0..) |byte, i| {
            if (i > 0) try writer.writeByte(':');
            try writer.print("{X:0>2}", .{byte});
        }
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
// Unit Tests
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

test "Ipv6Addr.parse valid addresses" {
    // Full address
    const full = try Ipv6Addr.parse("2001:0db8:0000:0000:0000:0000:0000:0001");
    try testing.expectEqual(@as(u8, 0x20), full.octets[0]);
    try testing.expectEqual(@as(u8, 0x01), full.octets[1]);
    try testing.expectEqual(@as(u8, 0x01), full.octets[15]);

    // Loopback
    const loopback = try Ipv6Addr.parse("::1");
    try testing.expect(loopback.isLoopback());

    // All zeros
    const any = try Ipv6Addr.parse("::");
    try testing.expect(any.eql(Ipv6Addr.any));

    // Shortened
    const short = try Ipv6Addr.parse("2001:db8::1");
    try testing.expectEqual(@as(u8, 0x20), short.octets[0]);
    try testing.expectEqual(@as(u8, 0x01), short.octets[1]);
    try testing.expectEqual(@as(u8, 0x0d), short.octets[2]);
    try testing.expectEqual(@as(u8, 0xb8), short.octets[3]);
    try testing.expectEqual(@as(u8, 0x01), short.octets[15]);

    // :: in the middle
    const mid = try Ipv6Addr.parse("fe80::1:2");
    try testing.expectEqual(@as(u8, 0xfe), mid.octets[0]);
    try testing.expectEqual(@as(u8, 0x80), mid.octets[1]);
    try testing.expectEqual(@as(u8, 0x00), mid.octets[12]);
    try testing.expectEqual(@as(u8, 0x01), mid.octets[13]);
    try testing.expectEqual(@as(u8, 0x00), mid.octets[14]);
    try testing.expectEqual(@as(u8, 0x02), mid.octets[15]);
}

test "Ipv6Addr.parse invalid addresses" {
    try testing.expectError(error.InvalidFormat, Ipv6Addr.parse(""));
    try testing.expectError(error.InvalidCharacter, Ipv6Addr.parse("gggg::1"));
    try testing.expectError(error.Overflow, Ipv6Addr.parse("10000::1"));
    // Too many groups
    try testing.expectError(error.InvalidFormat, Ipv6Addr.parse("1:2:3:4:5:6:7:8:9"));
}

test "Ipv6Addr.format" {
    const loopback = Ipv6Addr.localhost;
    var buf: [39]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{loopback}) catch unreachable;
    try testing.expectEqualStrings("::1", result);

    const full = Ipv6Addr.init(.{ 0x2001, 0x0db8, 0, 0, 0, 0, 0, 1 });
    const result2 = std.fmt.bufPrint(&buf, "{f}", .{full}) catch unreachable;
    try testing.expectEqualStrings("2001:db8::1", result2);

    // No compression for single zero
    const no_compress = Ipv6Addr.init(.{ 0x2001, 0x0db8, 0, 1, 0, 0, 0, 1 });
    var big_buf: [45]u8 = undefined;
    const result3 = std.fmt.bufPrint(&big_buf, "{f}", .{no_compress}) catch unreachable;
    try testing.expectEqualStrings("2001:db8:0:1::1", result3);
}

test "Ipv6Addr.isLoopback" {
    try testing.expect(Ipv6Addr.localhost.isLoopback());
    try testing.expect(!Ipv6Addr.any.isLoopback());
    try testing.expect(!(try Ipv6Addr.parse("2001:db8::1")).isLoopback());
}

test "Ipv6Addr.toIpv4 for mapped addresses" {
    // ::ffff:192.168.1.1 = ::ffff:c0a8:0101
    const mapped = Ipv6Addr.init(.{ 0, 0, 0, 0, 0, 0xFFFF, 0xC0A8, 0x0101 });
    const v4 = mapped.toIpv4();
    try testing.expect(v4 != null);
    try testing.expect(v4.?.eql(Ipv4Addr.init(192, 168, 1, 1)));

    // Not a mapped address
    const not_mapped = Ipv6Addr.localhost;
    try testing.expect(not_mapped.toIpv4() == null);

    // Almost mapped (wrong prefix)
    const almost = Ipv6Addr.init(.{ 0, 0, 0, 0, 0, 0xFFFE, 0xC0A8, 0x0101 });
    try testing.expect(almost.toIpv4() == null);
}

test "Ipv6Addr.eql" {
    const a = try Ipv6Addr.parse("::1");
    const b = try Ipv6Addr.parse("::1");
    const c = try Ipv6Addr.parse("::2");
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

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

test "Subnet.parse valid CIDR" {
    const v4_sub = try Subnet.parse("192.168.1.0/24");
    switch (v4_sub.network) {
        .v4 => |addr| try testing.expect(addr.eql(Ipv4Addr.init(192, 168, 1, 0))),
        .v6 => return error.InvalidFormat,
    }
    try testing.expectEqual(@as(u8, 24), v4_sub.prefix_len);

    const v6_sub = try Subnet.parse("::1/128");
    switch (v6_sub.network) {
        .v4 => return error.InvalidFormat,
        .v6 => |addr| try testing.expect(addr.isLoopback()),
    }
    try testing.expectEqual(@as(u8, 128), v6_sub.prefix_len);

    const zero_prefix = try Subnet.parse("0.0.0.0/0");
    try testing.expectEqual(@as(u8, 0), zero_prefix.prefix_len);
}

test "Subnet.parse invalid" {
    try testing.expectError(error.InvalidFormat, Subnet.parse(""));
    try testing.expectError(error.InvalidFormat, Subnet.parse("192.168.1.0"));
    try testing.expectError(error.InvalidFormat, Subnet.parse("192.168.1.0/"));
    try testing.expectError(error.Overflow, Subnet.parse("192.168.1.0/33"));
    try testing.expectError(error.Overflow, Subnet.parse("::1/129"));
    try testing.expectError(error.InvalidCharacter, Subnet.parse("192.168.1.0/abc"));
}

test "Subnet.contains" {
    const subnet = try Subnet.parse("192.168.1.0/24");
    try testing.expect(subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(192, 168, 1, 0) }));
    try testing.expect(subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(192, 168, 1, 255) }));
    try testing.expect(subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(192, 168, 1, 100) }));
    try testing.expect(!subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(192, 168, 2, 1) }));
    try testing.expect(!subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) }));

    // v4 subnet does not contain v6 address
    try testing.expect(!subnet.contains(IpAddr{ .v6 = Ipv6Addr.localhost }));

    // /32 is a single host
    const host = try Subnet.parse("10.0.0.1/32");
    try testing.expect(host.contains(IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) }));
    try testing.expect(!host.contains(IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 2) }));

    // /0 matches everything
    const all = try Subnet.parse("0.0.0.0/0");
    try testing.expect(all.contains(IpAddr{ .v4 = Ipv4Addr.init(1, 2, 3, 4) }));
    try testing.expect(all.contains(IpAddr{ .v4 = Ipv4Addr.init(255, 255, 255, 255) }));
}

test "Subnet.contains IPv6" {
    const subnet = try Subnet.parse("2001:db8::/32");
    try testing.expect(subnet.contains(try IpAddr.parse("2001:db8::1")));
    try testing.expect(subnet.contains(try IpAddr.parse("2001:db8:ffff:ffff:ffff:ffff:ffff:ffff")));
    try testing.expect(!subnet.contains(try IpAddr.parse("2001:db9::1")));

    // v6 subnet does not contain v4 address
    try testing.expect(!subnet.contains(IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) }));
}

test "Subnet.format" {
    const subnet = try Subnet.parse("192.168.1.0/24");
    var buf: [50]u8 = undefined;
    const result = std.fmt.bufPrint(&buf, "{f}", .{subnet}) catch unreachable;
    try testing.expectEqualStrings("192.168.1.0/24", result);

    const v6_sub = try Subnet.parse("2001:db8::/32");
    const result2 = std.fmt.bufPrint(&buf, "{f}", .{v6_sub}) catch unreachable;
    try testing.expectEqualStrings("2001:db8::/32", result2);
}

test "Subnet.eql" {
    const a = try Subnet.parse("192.168.1.0/24");
    const b = try Subnet.parse("192.168.1.0/24");
    const c = try Subnet.parse("192.168.1.0/25");
    const d = try Subnet.parse("10.0.0.0/24");
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
    try testing.expect(!a.eql(d));
}

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
