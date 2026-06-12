// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! IPv6 address value type.
//!
//! Q45: extracted from the monolithic `src/types/network.zig` into its
//! own file under `types/network/`. Public API (`Ipv6Addr`, its
//! constants, methods, and tests) is byte-for-byte unchanged.

const std = @import("std");
const testing = std.testing;

const common = @import("common.zig");
const ParseError = common.ParseError;
const MAX_IPV6_INPUT = common.MAX_IPV6_INPUT;

const hex = @import("hex.zig");
const hexDigitToInt = hex.hexDigitToInt;

const ipv4 = @import("ipv4.zig");
const Ipv4Addr = ipv4.Ipv4Addr;

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
    /// SSRF-safety gate, not a routability check -- see Ipv4Addr.isSafeForOutboundFetch.
    pub fn isSafeForOutboundFetch(self: Self) bool {
        if (self.isUnspecified()) return false;
        if (self.isLoopback()) return false;
        if (self.isLinkLocal()) return false;
        if (self.isUniqueLocal()) return false;
        if (self.isMulticast()) return false;
        // Re-check mapped addresses as IPv4 so ::ffff:<v4> forms (e.g. mapped
        // 169.254.169.254) cannot bypass the v4 blocklist.
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
// Tests
// ============================================================================

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

test "Ipv6Addr.parse rejects oversized input (SAST-DOS-01)" {
    const big = "a" ** (MAX_IPV6_INPUT + 1);
    try testing.expectError(error.InputTooLong, Ipv6Addr.parse(big));
    _ = try Ipv6Addr.parse("2001:db8::1");
}
