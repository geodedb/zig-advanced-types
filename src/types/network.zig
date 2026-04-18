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
    InvalidPrefix,
    InputTooLong,
    Overflow,
};

// SAST-DOS-01: per-parser input length caps. Returning `error.InputTooLong`
// before scanning bounds the per-call work the library can be forced to do
// by an attacker-controlled input. Caps are generous enough to accept every
// syntactically valid input and still reject arbitrarily padded blobs.
const MAX_IPV4_INPUT: usize = 45;
const MAX_IPV6_INPUT: usize = 45;
const MAX_IP_INPUT: usize = MAX_IPV6_INPUT;
const MAX_SUBNET_INPUT: usize = MAX_IPV6_INPUT + 4; // "/128"
const MAX_MAC_INPUT: usize = 17;

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

    /// Q19: sides of a `::` split. `left_count` + `right_count` <= 8.
    const Sides = struct { left_count: usize, right_count: usize, right_octets: [16]u8 };

    /// Parse the two sides of a `::`-compressed IPv6 literal into
    /// left-anchored `octets` and a scratch right buffer. Caller is
    /// responsible for placing the right side via `placeRight`.
    fn parseSides(input: []const u8, dc_pos: usize, octets: *[16]u8) ParseError!Sides {
        const left = input[0..dc_pos];
        const right_start = dc_pos + 2;
        const right = if (right_start <= input.len) input[right_start..] else "";

        var left_count: usize = 0;
        if (left.len > 0) left_count = try parseGroups(left, octets[0..], 8);

        var right_octets: [16]u8 = .{0} ** 16;
        var right_count: usize = 0;
        if (right.len > 0) {
            right_count = try parseGroups(right, right_octets[0..], 8);
            if (left_count + right_count > 8) return error.InvalidFormat;
        }
        return .{ .left_count = left_count, .right_count = right_count, .right_octets = right_octets };
    }

    /// Copy `right_count` already-parsed groups from `right_octets` into the
    /// tail of `octets` so the `::` compression expands to zeros in between.
    fn placeRight(octets: *[16]u8, sides: Sides) void {
        const right_offset = (8 - sides.right_count) * 2;
        for (0..sides.right_count * 2) |i| {
            octets[right_offset + i] = sides.right_octets[i];
        }
    }

    /// Parse an IPv6 address from colon-hex notation (e.g., "2001:db8::1").
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;
        if (input.len > MAX_IPV6_INPUT) return error.InputTooLong;

        var octets: [16]u8 = .{0} ** 16;

        if (findDoubleColon(input)) |dc_pos| {
            const sides = try parseSides(input, dc_pos, &octets);
            placeRight(&octets, sides);
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
            } else if (hexDigitToInt(ch)) |val| {
                digit_count += 1;
                if (digit_count > 4) return error.Overflow;
                current_value = current_value * 16 + @as(u32, val);
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

    /// Find the longest run of consecutive zero segments in an 8-segment IPv6
    /// address. Returns `{ .start, .len }` where `len >= 2` is the RFC 5952
    /// compression threshold; returns `len == 0` (and `start = 8`) when no
    /// such run exists. Q18: extracted from `Ipv6Addr.format` to keep that
    /// method flat (was 5-deep nested).
    const ZeroRun = struct { start: usize, len: usize };
    fn longestZeroRun(segs: [8]u16) ZeroRun {
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
        if (best_len < 2) return .{ .start = 8, .len = 0 };
        return .{ .start = best_start, .len = best_len };
    }

    /// Write this address in RFC 5952 canonical notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        const segs = self.segments();
        const run = longestZeroRun(segs);

        var i: usize = 0;
        var need_colon = false;
        while (i < 8) {
            if (i == run.start) {
                try writer.writeAll("::");
                i += run.len;
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

    /// Returns true if this is the unspecified address (::).
    pub fn isUnspecified(self: Self) bool {
        return self.eql(any);
    }

    /// Returns true if this is a link-local unicast address (fe80::/10).
    pub fn isLinkLocal(self: Self) bool {
        return self.octets[0] == 0xFE and (self.octets[1] & 0xC0) == 0x80;
    }

    /// Returns true if this is a unique-local address (fc00::/7).
    pub fn isUniqueLocal(self: Self) bool {
        return (self.octets[0] & 0xFE) == 0xFC;
    }

    /// Returns true if this is a multicast address (ff00::/8).
    pub fn isMulticast(self: Self) bool {
        return self.octets[0] == 0xFF;
    }

    /// Returns true if this IPv6 address is safe to use as the target of an
    /// outbound HTTP/network fetch (SSRF defense). Rejects loopback (::1),
    /// unspecified (::), link-local (fe80::/10), unique-local (fc00::/7),
    /// multicast (ff00::/8). IPv4-mapped addresses (::ffff:0:0/96) are
    /// downcast to IPv4 and re-checked via `Ipv4Addr.isSafeForOutboundFetch`
    /// so attackers cannot smuggle a link-local IPv4 target behind an IPv6
    /// facade.
    pub fn isSafeForOutboundFetch(self: Self) bool {
        if (self.isUnspecified()) return false;
        if (self.isLoopback()) return false;
        if (self.isLinkLocal()) return false;
        if (self.isUniqueLocal()) return false;
        if (self.isMulticast()) return false;
        // IPv4-mapped: re-run the v4 predicate on the embedded v4 address.
        if (self.toIpv4()) |v4| return v4.isSafeForOutboundFetch();
        return true;
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
// Subnet
// ============================================================================

/// A subnet in CIDR notation, combining a network address with a prefix length.
pub const Subnet = struct {
    network: IpAddr,
    prefix_len: u8,

    const Self = @This();

    /// Create a Subnet from an address and prefix length, validating the prefix
    /// against the address family (0..=32 for IPv4, 0..=128 for IPv6).
    /// Returns `error.InvalidPrefix` when out of range. This is the safe
    /// constructor -- struct-literal construction (`Subnet{ ... }`) remains
    /// legal Zig but bypasses validation; `contains` defensively returns
    /// `false` if `prefix_len` is out of range for the family.
    pub fn init(address: IpAddr, prefix_len: u8) ParseError!Self {
        const max_prefix: u8 = switch (address) {
            .v4 => 32,
            .v6 => 128,
        };
        if (prefix_len > max_prefix) return error.InvalidPrefix;
        return .{ .network = address, .prefix_len = prefix_len };
    }

    /// Parse a CIDR subnet string (e.g., "192.168.1.0/24" or "2001:db8::/32").
    pub fn parse(input: []const u8) ParseError!Self {
        if (input.len == 0) return error.InvalidFormat;
        if (input.len > MAX_SUBNET_INPUT) return error.InputTooLong;

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

    /// Returns true if the given address falls within this subnet. Defensive:
    /// if `self.prefix_len` is out of range for the family (e.g., a literal-
    /// constructed `Subnet` with a bad prefix), returns `false` rather than
    /// panicking.
    pub fn contains(self: Self, addr: IpAddr) bool {
        return switch (self.network) {
            .v4 => |net4| switch (addr) {
                .v4 => |addr4| containsV4(net4, self.prefix_len, addr4),
                .v6 => false,
            },
            .v6 => |net6| switch (addr) {
                .v4 => false,
                .v6 => |addr6| containsV6(net6, self.prefix_len, addr6),
            },
        };
    }

    fn containsV4(net: Ipv4Addr, prefix_len: u8, addr: Ipv4Addr) bool {
        if (prefix_len > 32) return false;
        if (prefix_len == 0) return true;
        if (prefix_len == 32) return net.eql(addr);

        // At this point prefix_len is in 1..=31, so (32 - prefix_len) fits in u5.
        // `Subnet.init` enforces this on construction; the defensive branches
        // above cover struct-literal bypass. Assert documents the invariant
        // for ReleaseSafe/Debug and is elided in ReleaseFast.
        std.debug.assert(prefix_len > 0 and prefix_len < 32);
        const shift: u5 = @intCast(@as(u8, 32) - prefix_len);
        const mask: u32 = @as(u32, 0xFFFFFFFF) << shift;
        return (net.toU32() & mask) == (addr.toU32() & mask);
    }

    fn containsV6(net: Ipv6Addr, prefix_len: u8, addr: Ipv6Addr) bool {
        if (prefix_len > 128) return false;
        if (prefix_len == 0) return true;

        const full_bytes: u8 = prefix_len / 8;
        const remaining_bits: u3 = @intCast(prefix_len % 8);

        if (full_bytes > 0 and !std.mem.eql(u8, net.octets[0..full_bytes], addr.octets[0..full_bytes])) {
            return false;
        }

        if (remaining_bits > 0 and full_bytes < 16) {
            const shift: u3 = @intCast(@as(u4, 8) - @as(u4, remaining_bits));
            const mask: u8 = @as(u8, 0xFF) << shift;
            if ((net.octets[full_bytes] & mask) != (addr.octets[full_bytes] & mask)) {
                return false;
            }
        }

        return true;
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

            const hi = hexDigitToInt(input[offset]) orelse return error.InvalidCharacter;
            const lo = hexDigitToInt(input[offset + 1]) orelse return error.InvalidCharacter;
            octets[i] = hi << 4 | lo;
        }

        return .{ .octets = octets };
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

test "Ipv6Addr.isSafeForOutboundFetch rejects SSRF-dangerous ranges" {
    try testing.expect(!Ipv6Addr.localhost.isSafeForOutboundFetch()); // ::1
    try testing.expect(!Ipv6Addr.any.isSafeForOutboundFetch()); // ::
    // Link-local fe80::/10
    try testing.expect(!(try Ipv6Addr.parse("fe80::1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv6Addr.parse("febf::1")).isSafeForOutboundFetch());
    // Unique-local fc00::/7
    try testing.expect(!(try Ipv6Addr.parse("fc00::1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv6Addr.parse("fd00::1")).isSafeForOutboundFetch());
    // Multicast ff00::/8
    try testing.expect(!(try Ipv6Addr.parse("ff00::1")).isSafeForOutboundFetch());
    try testing.expect(!(try Ipv6Addr.parse("ff02::1")).isSafeForOutboundFetch());

    // IPv4-mapped smuggling attempts must be rejected via v4 predicate.
    // (Parser does not yet accept dotted-v4 form inside v6 literals, so we
    // construct the mapped addresses from the hex form: ::ffff:<hi>:<lo>.)
    // 169.254.169.254 -> a9fe:a9fe
    try testing.expect(!(try Ipv6Addr.parse("::ffff:a9fe:a9fe")).isSafeForOutboundFetch());
    // 127.0.0.1 -> 7f00:0001
    try testing.expect(!(try Ipv6Addr.parse("::ffff:7f00:1")).isSafeForOutboundFetch());
    // 10.0.0.1 -> 0a00:0001
    try testing.expect(!(try Ipv6Addr.parse("::ffff:a00:1")).isSafeForOutboundFetch());
    // 0.0.0.0
    try testing.expect(!(try Ipv6Addr.parse("::ffff:0:0")).isSafeForOutboundFetch());
    // 100.64.0.1 -> 6440:0001 (CGNAT smuggled)
    try testing.expect(!(try Ipv6Addr.parse("::ffff:6440:1")).isSafeForOutboundFetch());

    // Safe public v6
    try testing.expect((try Ipv6Addr.parse("2001:db8::1")).isSafeForOutboundFetch());
    try testing.expect((try Ipv6Addr.parse("2606:4700:4700::1111")).isSafeForOutboundFetch());
    // Safe public v4 (8.8.8.8 -> 0808:0808) smuggled through mapped form
    try testing.expect((try Ipv6Addr.parse("::ffff:808:808")).isSafeForOutboundFetch());
}

test "Ipv6Addr classification predicates" {
    try testing.expect(Ipv6Addr.any.isUnspecified());
    try testing.expect(!Ipv6Addr.localhost.isUnspecified());
    try testing.expect((try Ipv6Addr.parse("fe80::1")).isLinkLocal());
    try testing.expect((try Ipv6Addr.parse("febf::1")).isLinkLocal());
    try testing.expect(!(try Ipv6Addr.parse("fec0::1")).isLinkLocal()); // deprecated site-local not link-local
    try testing.expect((try Ipv6Addr.parse("fc00::1")).isUniqueLocal());
    try testing.expect((try Ipv6Addr.parse("fd00::1")).isUniqueLocal());
    try testing.expect(!(try Ipv6Addr.parse("fe00::1")).isUniqueLocal());
    try testing.expect((try Ipv6Addr.parse("ff00::1")).isMulticast());
    try testing.expect(!(try Ipv6Addr.parse("fe80::1")).isMulticast());
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

test "Subnet.init validates prefix for family" {
    // Valid v4 prefixes
    const v4 = IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 0) };
    _ = try Subnet.init(v4, 0);
    _ = try Subnet.init(v4, 24);
    _ = try Subnet.init(v4, 32);
    // Invalid v4 prefix
    try testing.expectError(error.InvalidPrefix, Subnet.init(v4, 33));
    try testing.expectError(error.InvalidPrefix, Subnet.init(v4, 128));
    try testing.expectError(error.InvalidPrefix, Subnet.init(v4, 255));

    // Valid v6 prefixes
    const v6 = IpAddr{ .v6 = Ipv6Addr.localhost };
    _ = try Subnet.init(v6, 0);
    _ = try Subnet.init(v6, 64);
    _ = try Subnet.init(v6, 128);
    // Invalid v6 prefix
    try testing.expectError(error.InvalidPrefix, Subnet.init(v6, 129));
    try testing.expectError(error.InvalidPrefix, Subnet.init(v6, 255));
}

test "Subnet.contains defends against out-of-range prefix_len" {
    // Struct-literal construction bypasses init's validation.
    // contains must return false rather than panicking.
    const bad_v4 = Subnet{
        .network = IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 0) },
        .prefix_len = 33,
    };
    try testing.expect(!bad_v4.contains(IpAddr{ .v4 = Ipv4Addr.init(10, 0, 0, 1) }));

    const bad_v6 = Subnet{
        .network = IpAddr{ .v6 = Ipv6Addr.localhost },
        .prefix_len = 200,
    };
    try testing.expect(!bad_v6.contains(IpAddr{ .v6 = Ipv6Addr.localhost }));
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

// SAST-DOS-01: per-parser MAX_INPUT caps. Each parser must reject oversized
// input with `error.InputTooLong` before scanning, bounding attacker-
// controlled per-call CPU.

test "Ipv4Addr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "1" ** (MAX_IPV4_INPUT + 1);
    try testing.expectError(error.InputTooLong, Ipv4Addr.parse(big));
    // cap boundary still accepted if syntactically valid
    _ = try Ipv4Addr.parse("255.255.255.255");
}

test "Ipv6Addr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "a" ** (MAX_IPV6_INPUT + 1);
    try testing.expectError(error.InputTooLong, Ipv6Addr.parse(big));
    _ = try Ipv6Addr.parse("2001:db8::1");
}

test "IpAddr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "9" ** (MAX_IP_INPUT + 1);
    try testing.expectError(error.InputTooLong, IpAddr.parse(big));
    _ = try IpAddr.parse("10.0.0.1");
    _ = try IpAddr.parse("::1");
}

test "Subnet.parse rejects oversized input (SAST-DOS-01)" {
    const big = "0" ** (MAX_SUBNET_INPUT + 1);
    try testing.expectError(error.InputTooLong, Subnet.parse(big));
    _ = try Subnet.parse("192.168.0.0/16");
}
