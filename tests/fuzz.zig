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
//! Q43: the 12 per-parser fuzz wrappers are now generated from a single
//! `parserFuzzer` comptime helper, collapsing ~70 LOC of boilerplate
//! while keeping every test name identical to pre-Q43 output.
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

/// Build a `std.testing.fuzz`-compatible target that pulls an arbitrary
/// byte slice from `Smith` and feeds it into `T.parse`, swallowing every
/// parse error. `T` is required to expose `pub fn parse([]const u8) !...`.
fn parserFuzzer(comptime T: type) fn (void, *std.testing.Smith) anyerror!void {
    return struct {
        fn run(_: void, smith: *std.testing.Smith) anyerror!void {
            var buf: [max_input_len]u8 = undefined;
            const n = smith.slice(&buf);
            const input = buf[0..n];
            _ = T.parse(input) catch return;
        }
    }.run;
}

// ============================================================================
// Network parsers
// ============================================================================

test "fuzz Ipv4Addr.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Ipv4Addr), .{});
}

test "fuzz Ipv6Addr.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Ipv6Addr), .{});
}

test "fuzz IpAddr.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.IpAddr), .{});
}

test "fuzz Subnet.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Subnet), .{});
}

test "fuzz Mac.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Mac), .{});
}

// ============================================================================
// URL / domain parsers
// ============================================================================

test "fuzz Url.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Url), .{});
}

test "fuzz Domain.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.Domain), .{});
}

// ============================================================================
// Geographic parsers
// ============================================================================

test "fuzz LatLon.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.LatLon), .{});
}

test "fuzz LatLonAlt.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.LatLonAlt), .{});
}

// ============================================================================
// Vector parser
// ============================================================================

test "fuzz VectorF32.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.VectorF32), .{});
}

// ============================================================================
// Range parsers
// ============================================================================
// ATX-06: `Range(T).parse` is integer-only (`@compileError` for floats),
// so FloatRange cannot be fuzzed -- cover both signed and unsigned aliases.

test "fuzz IntRange.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.IntRange), .{});
}

test "fuzz UintRange.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.UintRange), .{});
}
