// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Parser edge-case regression suite.
//!
//! Boundary, ambiguity, and hardening tests spanning:
//!   - IPv4: leading-zero octets (documents decimal-only semantics per
//!     CVE-2021-29921 / CVE-2021-29923 discussion)
//!   - IPv6: `::` repetition, boundary prefix lengths
//!   - Url: userinfo stripping (SAST-05) with edge ordering
//!   - Subnet: prefix-length boundaries (0, family-max, family-max+1)
//!
//! Closes Q33. Exercises constructors and predicates landed earlier
//! in this series (Subnet.init, isSafeForOutboundFetch, userinfo strip).

const std = @import("std");
const lib = @import("advanced_types");

// ============================================================================
// IPv4 -- leading-zero octets
// ============================================================================

test "Ipv4Addr: leading-zero octet is accepted as decimal (documents current behavior)" {
    // CVE-2021-29921 (Python inet) and CVE-2021-29923 (Go) rejected leading
    // zeros specifically because libc-style parsers interpret them as octal.
    // advanced_types' parser is explicitly base-10; "010" is decimal 10.
    // This test locks in the decimal interpretation so any future refactor
    // that accidentally enables octal will fail here.
    const a = try lib.Ipv4Addr.parse("010.0.0.1");
    try std.testing.expectEqual(@as(u8, 10), a.octets[0]);
    try std.testing.expectEqual(@as(u8, 0), a.octets[1]);
    try std.testing.expectEqual(@as(u8, 0), a.octets[2]);
    try std.testing.expectEqual(@as(u8, 1), a.octets[3]);

    // All-leading-zero octets.
    const b = try lib.Ipv4Addr.parse("001.002.003.004");
    try std.testing.expectEqual(@as(u8, 1), b.octets[0]);
    try std.testing.expectEqual(@as(u8, 2), b.octets[1]);
    try std.testing.expectEqual(@as(u8, 3), b.octets[2]);
    try std.testing.expectEqual(@as(u8, 4), b.octets[3]);
}

test "Ipv4Addr: 4-digit octet overflows" {
    try std.testing.expectError(error.Overflow, lib.Ipv4Addr.parse("1234.0.0.1"));
}

test "Ipv4Addr: octet value 256 overflows" {
    try std.testing.expectError(error.Overflow, lib.Ipv4Addr.parse("256.0.0.1"));
    try std.testing.expectError(error.Overflow, lib.Ipv4Addr.parse("192.168.1.256"));
}

// ============================================================================
// IPv6 -- `::` doubled and boundary prefixes
// ============================================================================

test "Ipv6Addr: double :: rejected (1::2::3)" {
    try std.testing.expectError(error.InvalidFormat, lib.Ipv6Addr.parse("1::2::3"));
    try std.testing.expectError(error.InvalidFormat, lib.Ipv6Addr.parse("::1::"));
    try std.testing.expectError(error.InvalidFormat, lib.Ipv6Addr.parse("a::b::c::d"));
}

test "Ipv6Addr: `::` alone is the unspecified address" {
    const a = try lib.Ipv6Addr.parse("::");
    try std.testing.expect(a.isUnspecified());
}

test "Ipv6Addr: triple-colon is malformed" {
    try std.testing.expectError(error.InvalidFormat, lib.Ipv6Addr.parse(":::"));
}

// ============================================================================
// Subnet -- boundary prefix lengths via init
// ============================================================================

test "Subnet.init: v4 boundary prefixes /0 /32" {
    const v4 = lib.IpAddr{ .v4 = lib.Ipv4Addr.init(10, 0, 0, 0) };
    const s0 = try lib.Subnet.init(v4, 0);
    try std.testing.expectEqual(@as(u8, 0), s0.prefix_len);
    const s32 = try lib.Subnet.init(v4, 32);
    try std.testing.expectEqual(@as(u8, 32), s32.prefix_len);
    // One past the max for v4.
    try std.testing.expectError(error.InvalidPrefix, lib.Subnet.init(v4, 33));
}

test "Subnet.init: v6 boundary prefixes /0 /128" {
    const v6 = lib.IpAddr{ .v6 = lib.Ipv6Addr.localhost };
    const s0 = try lib.Subnet.init(v6, 0);
    try std.testing.expectEqual(@as(u8, 0), s0.prefix_len);
    const s128 = try lib.Subnet.init(v6, 128);
    try std.testing.expectEqual(@as(u8, 128), s128.prefix_len);
    try std.testing.expectError(error.InvalidPrefix, lib.Subnet.init(v6, 129));
}

test "Subnet.parse: prefix boundary cases" {
    _ = try lib.Subnet.parse("0.0.0.0/0");
    _ = try lib.Subnet.parse("10.0.0.1/32");
    _ = try lib.Subnet.parse("::/0");
    _ = try lib.Subnet.parse("::1/128");
    try std.testing.expectError(error.InvalidPrefix, lib.Subnet.parse("10.0.0.0/33"));
    try std.testing.expectError(error.InvalidPrefix, lib.Subnet.parse("::/129"));
}

test "Subnet.contains: /0 v4 contains any v4 but not v6" {
    const all_v4 = try lib.Subnet.parse("0.0.0.0/0");
    try std.testing.expect(all_v4.contains(lib.IpAddr{ .v4 = lib.Ipv4Addr.init(1, 2, 3, 4) }));
    try std.testing.expect(all_v4.contains(lib.IpAddr{ .v4 = lib.Ipv4Addr.broadcast }));
    try std.testing.expect(!all_v4.contains(lib.IpAddr{ .v6 = lib.Ipv6Addr.localhost }));
}

test "Subnet.contains: /128 v6 is single host" {
    const one = try lib.Subnet.parse("2001:db8::1/128");
    try std.testing.expect(one.contains(try lib.IpAddr.parse("2001:db8::1")));
    try std.testing.expect(!one.contains(try lib.IpAddr.parse("2001:db8::2")));
}

// ============================================================================
// Url -- userinfo stripping + SSRF-safe compositions
// ============================================================================

test "Url: userinfo with trailing host matches trusted" {
    // Canonical SSRF-laundering case.
    const u = try lib.Url.parse("http://evil.com@trusted.com/path");
    try std.testing.expectEqualStrings("trusted.com", u.host);
    try std.testing.expectEqualStrings("evil.com", u.userinfo.?);
}

test "Url: userinfo containing percent-encoded @ still last-@-wins" {
    // Single raw '@' in authority; everything left of the rightmost '@'
    // goes to userinfo even if it *looks* encoded.
    const u = try lib.Url.parse("http://foo%40bar@host.example/");
    try std.testing.expectEqualStrings("host.example", u.host);
    try std.testing.expectEqualStrings("foo%40bar", u.userinfo.?);
}

test "Url: empty userinfo ('@') means empty userinfo + valid host" {
    const u = try lib.Url.parse("http://@example.com/");
    try std.testing.expectEqualStrings("example.com", u.host);
    try std.testing.expectEqualStrings("", u.userinfo.?);
}

test "Url: userinfo plus leading-zero port still rejects port" {
    try std.testing.expectError(
        lib.url.ParseError.InvalidPort,
        lib.Url.parse("http://u@host.com:01/"),
    );
}

test "Url + Ipv4.isSafeForOutboundFetch metadata gateway rejected" {
    // If a caller resolved the host to this v4, it must be rejected.
    const metadata = try lib.Ipv4Addr.parse("169.254.169.254");
    try std.testing.expect(!metadata.isSafeForOutboundFetch());

    // And a public host is fine.
    const public = try lib.Ipv4Addr.parse("1.1.1.1");
    try std.testing.expect(public.isSafeForOutboundFetch());
}
