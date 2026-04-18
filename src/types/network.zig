// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Portable network value types for IPv4, IPv6, Subnet (CIDR), and MAC
//! addresses.
//!
//! All types are plain value types that require no allocator for core
//! operations (parsing, formatting, equality, classification).
//!
//! ## Layout (Q45)
//!
//! As of Q45 this file is a thin facade over `src/types/network/`:
//!
//! * `network/common.zig` -- shared `ParseError` error set and
//!   per-parser `MAX_*_INPUT` caps (SAST-DOS-01).
//! * `network/hex.zig`    -- shared `hexDigitToInt` helper.
//! * `network/ipv4.zig`   -- `Ipv4Addr`.
//! * `network/ipv6.zig`   -- `Ipv6Addr`.
//! * `network/ip.zig`     -- `IpAddr` (v4/v6 tagged union).
//! * `network/subnet.zig` -- `Subnet` (CIDR).
//! * `network/mac.zig`    -- `Mac` (IEEE 802).
//!
//! The facade re-exports every public type so `network.Ipv4Addr`,
//! `network.Subnet`, and all `root.*` re-exports resolve exactly as
//! they did before the split. Callers never need to import the
//! per-type files directly.

const std = @import("std");
const testing = std.testing;

// ============================================================================
// Per-type modules (Q45)
// ============================================================================

const common = @import("network/common.zig");
const ipv4 = @import("network/ipv4.zig");
const ipv6 = @import("network/ipv6.zig");
const ip = @import("network/ip.zig");
const subnet = @import("network/subnet.zig");
const mac = @import("network/mac.zig");

// ============================================================================
// Public re-exports
// ============================================================================

/// Errors that can occur when parsing network addresses and subnets.
pub const ParseError = common.ParseError;

pub const Ipv4Addr = ipv4.Ipv4Addr;
pub const Ipv6Addr = ipv6.Ipv6Addr;
pub const IpAddr = ip.IpAddr;
pub const Subnet = subnet.Subnet;
pub const Mac = mac.Mac;

// ============================================================================
// Test aggregation
// ============================================================================

// Q45: ensure tests in the per-type submodules are discovered from the
// facade's test run. `refAllDecls` on each submodule forces the test
// harness to compile and enumerate every `test` block in them.
test {
    testing.refAllDecls(ipv4);
    testing.refAllDecls(ipv6);
    testing.refAllDecls(ip);
    testing.refAllDecls(subnet);
    testing.refAllDecls(mac);
}
