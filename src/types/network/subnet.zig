// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! CIDR subnet value type.
//!
//! Q45: extracted from the monolithic `src/types/network.zig`. Depends on
//! the `IpAddr` union in `network/ip.zig`; public API is byte-for-byte
//! unchanged.

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const ParseError = common.ParseError;
const MAX_SUBNET_INPUT = common.MAX_SUBNET_INPUT;

const ipv4 = @import("ipv4.zig");
const Ipv4Addr = ipv4.Ipv4Addr;
const ipv6 = @import("ipv6.zig");
const Ipv6Addr = ipv6.Ipv6Addr;
const ip = @import("ip.zig");
const IpAddr = ip.IpAddr;

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
    /// Returns `error.InvalidPrefix` for an out-of-range prefix length,
    /// matching `init`.
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
            if (prefix_len > 128) return error.InvalidPrefix;
        }

        // Validate prefix length based on address family
        const max_prefix: u16 = switch (network) {
            .v4 => 32,
            .v6 => 128,
        };
        if (prefix_len > max_prefix) return error.InvalidPrefix;

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
// Tests
// ============================================================================

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
    try testing.expectError(error.InvalidPrefix, Subnet.parse("192.168.1.0/33"));
    try testing.expectError(error.InvalidPrefix, Subnet.parse("::1/129"));
    try testing.expectError(error.InvalidPrefix, Subnet.parse("192.168.1.0/999"));
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

test "Subnet.parse rejects oversized input (SAST-DOS-01)" {
    const big = "0" ** (MAX_SUBNET_INPUT + 1);
    try testing.expectError(error.InputTooLong, Subnet.parse(big));
    _ = try Subnet.parse("192.168.0.0/16");
}
