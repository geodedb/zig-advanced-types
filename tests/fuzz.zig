// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Fuzz test targets for advanced-types parsers.
//!
//! Each test feeds arbitrary `[]const u8` input into a parser and discards the
//! result.  The key invariant: **no parser may panic or trigger undefined
//! behaviour on any input** — returning an error is perfectly fine.
//!
//! Run the initial compilation check with:
//!
//!     zig build test-fuzz --summary all
//!
//! For continuous fuzzing pass `--fuzz` to the test runner:
//!
//!     zig build test-fuzz -- --fuzz

const std = @import("std");
const types = @import("advanced_types");

// ============================================================================
// Network parsers
// ============================================================================

test "fuzz Ipv4Addr.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Ipv4Addr.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz Ipv6Addr.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Ipv6Addr.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz IpAddr.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.IpAddr.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz Subnet.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Subnet.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz Mac.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Mac.parse(input) catch return;
        }
    }.run, .{});
}

// ============================================================================
// URL / domain parsers
// ============================================================================

test "fuzz Url.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Url.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz Domain.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.Domain.parse(input) catch return;
        }
    }.run, .{});
}

// ============================================================================
// Geographic parsers
// ============================================================================

test "fuzz LatLon.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.LatLon.parse(input) catch return;
        }
    }.run, .{});
}

test "fuzz LatLonAlt.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.LatLonAlt.parse(input) catch return;
        }
    }.run, .{});
}

// ============================================================================
// Vector parser
// ============================================================================

test "fuzz VectorF32.parse" {
    try std.testing.fuzz({}, struct {
        fn run(_: void, input: []const u8) anyerror!void {
            _ = types.VectorF32.parse(input) catch return;
        }
    }.run, .{});
}
