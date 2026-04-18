// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Fuzz test targets for advanced-types parsers.
//!
//! Each test obtains an arbitrary byte slice from `std.testing.Smith`
//! and feeds it into a parser, discarding the result. The key invariant:
//! **no parser may panic or trigger undefined behaviour on any input** --
//! returning an error is fine.
//!
//! Ported to the Zig 0.16 `std.testing.fuzz` + `Smith` API
//! (GAP-0020 / Q30). The pre-0.16 anonymous-struct `run` callback was
//! replaced by top-level fuzz-target functions that take
//! `*std.testing.Smith`. `Smith.slice(buf)` fills a caller-provided
//! byte buffer and returns the used length.
//!
//! Run the initial compilation check with:
//!
//!     zig build test-fuzz --summary all
//!
//! For continuous fuzzing:
//!
//!     zig build test-fuzz -- --fuzz

const std = @import("std");
const types = @import("advanced_types");

/// Maximum fuzz-input length. Large enough to exercise long malformed
/// URLs, IPv6 literals, and CIDR strings; small enough that the bytes
/// buffer stays on the stack.
const max_input_len: u32 = 256;

/// Pull an arbitrary byte slice from `Smith` into a stack buffer and
/// return the filled prefix.
fn takeSlice(smith: *std.testing.Smith, buf: *[max_input_len]u8) []const u8 {
    const n = smith.slice(buf);
    return buf[0..n];
}

// ============================================================================
// Network parsers
// ============================================================================

fn fuzzIpv4Parse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Ipv4Addr.parse(input) catch return;
}

test "fuzz Ipv4Addr.parse" {
    try std.testing.fuzz({}, fuzzIpv4Parse, .{});
}

fn fuzzIpv6Parse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Ipv6Addr.parse(input) catch return;
}

test "fuzz Ipv6Addr.parse" {
    try std.testing.fuzz({}, fuzzIpv6Parse, .{});
}

fn fuzzIpAddrParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.IpAddr.parse(input) catch return;
}

test "fuzz IpAddr.parse" {
    try std.testing.fuzz({}, fuzzIpAddrParse, .{});
}

fn fuzzSubnetParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Subnet.parse(input) catch return;
}

test "fuzz Subnet.parse" {
    try std.testing.fuzz({}, fuzzSubnetParse, .{});
}

fn fuzzMacParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Mac.parse(input) catch return;
}

test "fuzz Mac.parse" {
    try std.testing.fuzz({}, fuzzMacParse, .{});
}

// ============================================================================
// URL / domain parsers
// ============================================================================

fn fuzzUrlParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Url.parse(input) catch return;
}

test "fuzz Url.parse" {
    try std.testing.fuzz({}, fuzzUrlParse, .{});
}

fn fuzzDomainParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.Domain.parse(input) catch return;
}

test "fuzz Domain.parse" {
    try std.testing.fuzz({}, fuzzDomainParse, .{});
}

// ============================================================================
// Geographic parsers
// ============================================================================

fn fuzzLatLonParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.LatLon.parse(input) catch return;
}

test "fuzz LatLon.parse" {
    try std.testing.fuzz({}, fuzzLatLonParse, .{});
}

fn fuzzLatLonAltParse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.LatLonAlt.parse(input) catch return;
}

test "fuzz LatLonAlt.parse" {
    try std.testing.fuzz({}, fuzzLatLonAltParse, .{});
}

// ============================================================================
// Vector parser
// ============================================================================

fn fuzzVectorF32Parse(_: void, smith: *std.testing.Smith) !void {
    var buf: [max_input_len]u8 = undefined;
    const input = takeSlice(smith, &buf);
    _ = types.VectorF32.parse(input) catch return;
}

test "fuzz VectorF32.parse" {
    try std.testing.fuzz({}, fuzzVectorF32Parse, .{});
}
