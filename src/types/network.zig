// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Portable network value types for IPv4, IPv6, Subnet (CIDR), and MAC addresses.
//!
//! All types are plain value types that require no allocator for core operations
//! including parsing, formatting, equality comparison, and classification.

const std = @import("std");
const testing = std.testing;

// ============================================================================
// Shared helpers / common types (Q45)
// ============================================================================

// Q45: shared error set, input caps, and hex helpers live in per-concern
// files under `types/network/`. The facade re-exports the error set (public
// API stays stable) and aliases the caps/hex helper for in-file use by the
// types that have not yet been extracted.
const hex = @import("network/hex.zig");
const hexDigitToInt = hex.hexDigitToInt;

const common = @import("network/common.zig");
pub const ParseError = common.ParseError;
const MAX_IPV4_INPUT = common.MAX_IPV4_INPUT;
const MAX_IPV6_INPUT = common.MAX_IPV6_INPUT;
const MAX_IP_INPUT = common.MAX_IP_INPUT;
const MAX_SUBNET_INPUT = common.MAX_SUBNET_INPUT;
const MAX_MAC_INPUT = common.MAX_MAC_INPUT;

// ============================================================================
// Ipv4Addr (Q45: moved to network/ipv4.zig)
// ============================================================================

const ipv4 = @import("network/ipv4.zig");
pub const Ipv4Addr = ipv4.Ipv4Addr;

// ============================================================================
// Ipv6Addr (Q45: moved to network/ipv6.zig)
// ============================================================================

const ipv6 = @import("network/ipv6.zig");
pub const Ipv6Addr = ipv6.Ipv6Addr;

// ============================================================================
// IpAddr (Q45: moved to network/ip.zig)
// ============================================================================

const ip = @import("network/ip.zig");
pub const IpAddr = ip.IpAddr;

// ============================================================================
// Subnet (Q45: moved to network/subnet.zig)
// ============================================================================

const subnet = @import("network/subnet.zig");
pub const Subnet = subnet.Subnet;

// ============================================================================
// Mac (Q45: moved to network/mac.zig)
// ============================================================================

const mac = @import("network/mac.zig");
pub const Mac = mac.Mac;

// ============================================================================
// Unit Tests
// ============================================================================

// SAST-DOS-01: per-parser MAX_INPUT caps. Each parser must reject oversized
// input with `error.InputTooLong` before scanning, bounding attacker-
// controlled per-call CPU.

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
