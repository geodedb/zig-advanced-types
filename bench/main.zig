// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Micro-benchmark harness for advanced_types parsers and hot-path
//! numeric operations.
//!
//! Invocation:
//!   zig build bench
//!   zig build bench -Doptimize=ReleaseFast
//!
//! Each benchmark runs `warmup_rounds` discarded iterations to settle
//! CPU state, then `sample_rounds` measured rounds. Each round performs
//! `iterations_per_round` inner iterations and reports wall time via a
//! monotonic clock. From the per-round ns/op values we emit the minimum,
//! median, and p95, plus a jitter figure (`(p95-min)/min`) so BENCH-02
//! can gate on stable runs. BENCH-01 (#57).
//!
//! Pin to a single core for best stability:
//!   taskset -c 0 zig build bench -Doptimize=ReleaseFast
//!
//! Output is a fixed-width table to stdout. Non-zero exit indicates a
//! benchmark crashed; CI runs this harness in "does it finish?" mode
//! while developers inspect the numbers locally.

const std = @import("std");
const builtin = @import("builtin");
const lib = @import("advanced_types");

/// Per-round inner iterations -- amortises clock granularity.
const iterations_per_round: usize = 100_000;
/// Measured rounds fed into min/median/p95 aggregation.
const sample_rounds: usize = 9;
/// Discarded warm-up rounds before sampling.
const warmup_rounds: usize = 3;

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
            var ts: std.c.timespec = undefined;
            _ = std.c.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s +
                @as(u64, @intCast(ts.nsec));
        },
        .windows => {
            const windows = std.os.windows;
            const freq = windows.QueryPerformanceFrequency();
            const counter = windows.QueryPerformanceCounter();
            return counter * std.time.ns_per_s / freq;
        },
        else => {
            var ts: std.c.timespec = undefined;
            _ = std.c.clock_gettime(.MONOTONIC, &ts);
            return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s +
                @as(u64, @intCast(ts.nsec));
        },
    }
}

/// Aggregated result of `sample_rounds` rounds of a benchmark.
const BenchResult = struct {
    name: []const u8,
    iterations_per_round: usize,
    rounds: usize,
    min_ns_per_op: f64,
    median_ns_per_op: f64,
    p95_ns_per_op: f64,

    fn opsPerSec(self: BenchResult) f64 {
        if (self.min_ns_per_op <= 0.0) return 0.0;
        return 1.0e9 / self.min_ns_per_op;
    }

    fn jitter(self: BenchResult) f64 {
        if (self.min_ns_per_op <= 0.0) return 0.0;
        return (self.p95_ns_per_op - self.min_ns_per_op) / self.min_ns_per_op;
    }
};

fn ascF64(_: void, a: f64, b: f64) bool {
    return a < b;
}

/// Run a benchmark closure `rounds` times (after `warmup_rounds` discarded
/// rounds) and aggregate the per-round ns/op into min/median/p95.
fn runRounds(
    name: []const u8,
    round_fn: *const fn () anyerror!u64,
) !BenchResult {
    // Warm-up -- discarded.
    for (0..warmup_rounds) |_| {
        _ = try round_fn();
    }

    var samples: [sample_rounds]f64 = undefined;
    for (&samples) |*s| {
        const ns = try round_fn();
        s.* = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(iterations_per_round));
    }
    std.mem.sort(f64, &samples, {}, ascF64);

    const min = samples[0];
    const median = samples[sample_rounds / 2];
    // p95 index for 9 samples = ceil(0.95 * 9) - 1 = 8 (take max of sorted).
    const p95 = samples[sample_rounds - 1];

    return .{
        .name = name,
        .iterations_per_round = iterations_per_round,
        .rounds = sample_rounds,
        .min_ns_per_op = min,
        .median_ns_per_op = median,
        .p95_ns_per_op = p95,
    };
}

// ============================================================================
// Per-benchmark round closures
// ============================================================================

fn roundIpv4Parse() !u64 {
    const inputs = [_][]const u8{
        "127.0.0.1",
        "192.168.1.1",
        "8.8.8.8",
        "255.255.255.255",
        "1.2.3.4",
    };
    const t0 = nowNs();
    var sink: u32 = 0;
    for (0..iterations_per_round) |i| {
        const input = inputs[i % inputs.len];
        const addr = try lib.Ipv4Addr.parse(input);
        sink ^= addr.toU32();
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundIpv6Parse() !u64 {
    const inputs = [_][]const u8{
        "::1",
        "2001:db8::1",
        "fe80::1",
        "2001:db8:85a3::8a2e:370:7334",
        "ff02::1",
    };
    const t0 = nowNs();
    var sink: u8 = 0;
    for (0..iterations_per_round) |i| {
        const input = inputs[i % inputs.len];
        const addr = try lib.Ipv6Addr.parse(input);
        sink ^= addr.octets[0];
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundUrlParse() !u64 {
    const inputs = [_][]const u8{
        "https://www.example.com:8443/v1/data?k=v#top",
        "http://localhost:3000/api",
        "https://api.example.com/",
        "http://user:pass@host.example/x/y?q=1",
        "https://[::1]:8080/ipv6",
    };
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations_per_round) |i| {
        const input = inputs[i % inputs.len];
        const u = try lib.Url.parse(input);
        sink ^= u.host.len;
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundCosineDistance() !u64 {
    const a = lib.VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = lib.VectorF32.init(.{ 0.9, 0.1, 0.02 });
    const t0 = nowNs();
    var sink: f32 = 0.0;
    for (0..iterations_per_round) |_| {
        sink += a.cosineDistance(b);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundHaversine() !u64 {
    const sf = try lib.LatLon.init(37.7749, -122.4194);
    const ny = try lib.LatLon.init(40.7128, -74.0060);
    const t0 = nowNs();
    var sink: f64 = 0.0;
    for (0..iterations_per_round) |_| {
        sink += sf.haversineDistance(ny);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

// ----------------------------------------------------------------------------
// BENCH-03 (#59): expanded corpus — format paths, Subnet.contains, IpAddr.parse,
// and the 1-to-N haversine broadcast helper (S1 / PRECOMP-01).
// ----------------------------------------------------------------------------

fn roundIpv4Format() !u64 {
    const addrs = [_]lib.Ipv4Addr{
        .{ .octets = .{ 127, 0, 0, 1 } },
        .{ .octets = .{ 192, 168, 1, 1 } },
        .{ .octets = .{ 8, 8, 8, 8 } },
        .{ .octets = .{ 255, 255, 255, 255 } },
        .{ .octets = .{ 10, 0, 0, 42 } },
    };
    var buf: [32]u8 = undefined;
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations_per_round) |i| {
        const out = try std.fmt.bufPrint(&buf, "{f}", .{addrs[i % addrs.len]});
        sink ^= out.len;
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundMacFormat() !u64 {
    const macs = [_]lib.Mac{
        .{ .octets = .{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF } },
        .{ .octets = .{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55 } },
        lib.Mac.broadcast,
        .{ .octets = .{ 0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01 } },
        .{ .octets = .{ 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB } },
    };
    var buf: [32]u8 = undefined;
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations_per_round) |i| {
        const out = try std.fmt.bufPrint(&buf, "{f}", .{macs[i % macs.len]});
        sink ^= out.len;
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundSubnetContains() !u64 {
    const net = try lib.Subnet.parse("192.168.1.0/24");
    const addrs = [_]lib.IpAddr{
        try lib.IpAddr.parse("192.168.1.1"),
        try lib.IpAddr.parse("192.168.1.200"),
        try lib.IpAddr.parse("192.168.2.1"), // outside
        try lib.IpAddr.parse("10.0.0.1"), // outside
        try lib.IpAddr.parse("192.168.1.42"),
    };
    const t0 = nowNs();
    var sink: u32 = 0;
    for (0..iterations_per_round) |i| {
        sink +%= if (net.contains(addrs[i % addrs.len])) 1 else 0;
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundIpAddrParse() !u64 {
    // Mixed v4/v6 inputs so the detect-by-colon branch is exercised evenly.
    const inputs = [_][]const u8{
        "127.0.0.1",
        "::1",
        "192.168.1.1",
        "2001:db8::1",
        "8.8.8.8",
        "fe80::1",
    };
    const t0 = nowNs();
    var sink: u8 = 0;
    for (0..iterations_per_round) |i| {
        const addr = try lib.IpAddr.parse(inputs[i % inputs.len]);
        sink ^= switch (addr) {
            .v4 => |v| v.octets[0],
            .v6 => |v| v.octets[0],
        };
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundHaversineBroadcast() !u64 {
    // 1-to-N sweep using the precomputed-origin helper. Mirrors the real
    // "distance from user to each POI" hot path this helper targets.
    const origin = try lib.LatLon.init(37.7749, -122.4194);
    const dests = [_]lib.LatLon{
        try lib.LatLon.init(40.7128, -74.0060),
        try lib.LatLon.init(51.5074, -0.1278),
        try lib.LatLon.init(-33.8688, 151.2093),
        try lib.LatLon.init(35.6762, 139.6503),
        try lib.LatLon.init(-23.5505, -46.6333),
        try lib.LatLon.init(55.7558, 37.6173),
        try lib.LatLon.init(-34.6037, -58.3816),
        try lib.LatLon.init(1.3521, 103.8198),
    };
    const broadcast = origin.haversineBroadcast();
    const t0 = nowNs();
    var sink: f64 = 0.0;
    for (0..iterations_per_round) |i| {
        sink += broadcast.distanceTo(dests[i % dests.len]);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

pub fn main() !void {
    const p = std.debug.print;
    p(
        "advanced_types micro-benchmarks -- iters/round={d}, rounds={d}, warmup={d}\n",
        .{ iterations_per_round, sample_rounds, warmup_rounds },
    );
    p("{s: <32} {s: >12} {s: >12} {s: >12} {s: >10} {s: >14}\n", .{
        "benchmark",
        "min ns/op",
        "median",
        "p95",
        "jitter%",
        "ops/sec (min)",
    });
    p("------------------------------------------------------------------------------------------------\n", .{});

    const results = [_]BenchResult{
        try runRounds("Ipv4Addr.parse", roundIpv4Parse),
        try runRounds("Ipv6Addr.parse", roundIpv6Parse),
        try runRounds("IpAddr.parse", roundIpAddrParse),
        try runRounds("Url.parse", roundUrlParse),
        try runRounds("Ipv4Addr.format", roundIpv4Format),
        try runRounds("Mac.format", roundMacFormat),
        try runRounds("Subnet.contains", roundSubnetContains),
        try runRounds("VectorF32.cosineDistance", roundCosineDistance),
        try runRounds("LatLon.haversineDistance", roundHaversine),
        try runRounds("LatLon.haversineBroadcast", roundHaversineBroadcast),
    };

    for (results) |r| {
        p("{s: <32} {d: >12.2} {d: >12.2} {d: >12.2} {d: >10.1} {d: >14.0}\n", .{
            r.name,
            r.min_ns_per_op,
            r.median_ns_per_op,
            r.p95_ns_per_op,
            r.jitter() * 100.0,
            r.opsPerSec(),
        });
    }
}
