// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Micro-benchmark harness for advanced_types parsers and hot-path
//! numeric operations.
//!
//! Invocation:
//!   zig build bench
//!   zig build bench -Doptimize=ReleaseFast
//!
//! Output is a fixed-width table to stdout: one row per benchmark with
//! total iterations, total time, ns/op, and ops/sec. Non-zero exit
//! indicates a benchmark crashed (e.g. the library returned an
//! unexpected error on input that used to succeed). The intent is that
//! CI runs this harness in "does it finish?" mode while developers
//! inspect the numbers locally.
//!
//! Closes I1.

const std = @import("std");
const builtin = @import("builtin");
const lib = @import("advanced_types");

const iterations: usize = 100_000;

/// Monotonic nanosecond clock. Zig 0.16 removed `std.time.Timer`; this
/// wrapper keeps the harness portable across supported OSes by routing
/// to the native clock-gettime equivalent.
fn nowNs() u64 {
    switch (builtin.os.tag) {
        .linux => {
            const linux = std.os.linux;
            var ts: linux.timespec = undefined;
            _ = linux.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s +
                @as(u64, @intCast(ts.nsec));
        },
        .macos, .ios, .tvos, .watchos => {
            // macOS: mach_absolute_time() returns monotonic ticks.
            // Fallback approximation via clock_gettime on supported versions.
            var ts: std.c.timespec = undefined;
            _ = std.c.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s +
                @as(u64, @intCast(ts.nsec));
        },
        .windows => {
            // QueryPerformanceCounter gives ticks; scale by the frequency.
            const windows = std.os.windows;
            const freq = windows.QueryPerformanceFrequency();
            const counter = windows.QueryPerformanceCounter();
            return counter * std.time.ns_per_s / freq;
        },
        else => {
            // Best-effort portable fallback for other OSes.
            var ts: std.c.timespec = undefined;
            _ = std.c.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s +
                @as(u64, @intCast(ts.nsec));
        },
    }
}

const BenchResult = struct {
    name: []const u8,
    iterations: usize,
    total_ns: u64,

    fn nsPerOp(self: BenchResult) f64 {
        return @as(f64, @floatFromInt(self.total_ns)) /
            @as(f64, @floatFromInt(self.iterations));
    }

    fn opsPerSec(self: BenchResult) f64 {
        const ns = self.nsPerOp();
        if (ns <= 0.0) return 0.0;
        return 1.0e9 / ns;
    }
};

fn benchIpv4Parse() !BenchResult {
    const inputs = [_][]const u8{
        "127.0.0.1",
        "192.168.1.1",
        "8.8.8.8",
        "255.255.255.255",
        "1.2.3.4",
    };
    const t0 = nowNs();
    var sink: u32 = 0;
    for (0..iterations) |i| {
        const input = inputs[i % inputs.len];
        const addr = try lib.Ipv4Addr.parse(input);
        sink ^= addr.toU32();
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return .{ .name = "Ipv4Addr.parse", .iterations = iterations, .total_ns = elapsed };
}

fn benchIpv6Parse() !BenchResult {
    const inputs = [_][]const u8{
        "::1",
        "2001:db8::1",
        "fe80::1",
        "2001:db8:85a3::8a2e:370:7334",
        "ff02::1",
    };
    const t0 = nowNs();
    var sink: u8 = 0;
    for (0..iterations) |i| {
        const input = inputs[i % inputs.len];
        const addr = try lib.Ipv6Addr.parse(input);
        sink ^= addr.octets[0];
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return .{ .name = "Ipv6Addr.parse", .iterations = iterations, .total_ns = elapsed };
}

fn benchUrlParse() !BenchResult {
    const inputs = [_][]const u8{
        "https://www.example.com:8443/v1/data?k=v#top",
        "http://localhost:3000/api",
        "https://api.example.com/",
        "http://user:pass@host.example/x/y?q=1",
        "https://[::1]:8080/ipv6",
    };
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations) |i| {
        const input = inputs[i % inputs.len];
        const u = try lib.Url.parse(input);
        sink ^= u.host.len;
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return .{ .name = "Url.parse", .iterations = iterations, .total_ns = elapsed };
}

fn benchCosineDistance() !BenchResult {
    const a = lib.VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = lib.VectorF32.init(.{ 0.9, 0.1, 0.02 });
    const t0 = nowNs();
    var sink: f32 = 0.0;
    for (0..iterations) |_| {
        sink += a.cosineDistance(b);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return .{ .name = "VectorF32.cosineDistance", .iterations = iterations, .total_ns = elapsed };
}

fn benchHaversine() !BenchResult {
    const sf = try lib.LatLon.init(37.7749, -122.4194);
    const ny = try lib.LatLon.init(40.7128, -74.0060);
    const t0 = nowNs();
    var sink: f64 = 0.0;
    for (0..iterations) |_| {
        sink += sf.haversineDistance(ny);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return .{ .name = "LatLon.haversineDistance", .iterations = iterations, .total_ns = elapsed };
}

pub fn main() !void {
    const p = std.debug.print;
    p("advanced_types micro-benchmarks -- iterations={d}\n", .{iterations});
    p("{s: <32} {s: >12} {s: >14} {s: >16}\n", .{
        "benchmark",
        "iters",
        "ns/op",
        "ops/sec",
    });
    p("--------------------------------------------------------------------------------\n", .{});

    const results = [_]BenchResult{
        try benchIpv4Parse(),
        try benchIpv6Parse(),
        try benchUrlParse(),
        try benchCosineDistance(),
        try benchHaversine(),
    };

    for (results) |r| {
        p("{s: <32} {d: >12} {d: >14.2} {d: >16.0}\n", .{
            r.name,
            r.iterations,
            r.nsPerOp(),
            r.opsPerSec(),
        });
    }
}
