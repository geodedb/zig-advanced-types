// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Shared error set and input-length caps for the network parsers.
//!
//! Q45: extracted from `src/types/network.zig` so the per-type files
//! in this directory can import them without going through the facade
//! (which would create a circular import).

/// Errors that can occur when parsing network addresses and subnets.
pub const ParseError = error{
    InvalidCharacter,
    InvalidFormat,
    InvalidLength,
    InvalidPrefix,
    InputTooLong,
    Overflow,
};

// SAST-DOS-01: per-parser input length caps. Returning `error.InputTooLong`
// before scanning bounds the per-call work the library can be forced to do
// by an attacker-controlled input. Caps are generous enough to accept every
// syntactically valid input and still reject arbitrarily padded blobs.
pub const MAX_IPV4_INPUT: usize = 45;
pub const MAX_IPV6_INPUT: usize = 45;
pub const MAX_IP_INPUT: usize = MAX_IPV6_INPUT;
pub const MAX_SUBNET_INPUT: usize = MAX_IPV6_INPUT + 4; // "/128"
pub const MAX_MAC_INPUT: usize = 17;
