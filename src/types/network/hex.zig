// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Shared hex-digit helpers for the network parsers.
//!
//! Q45: extracted from `src/types/network.zig` as part of the
//! monolithic-module split. Lives in `types/network/` so the IPv6 and
//! MAC parsers can share one implementation without the whole network
//! module having to co-locate them.

/// Convert an ASCII hex digit to its integer value (0-15), or null if
/// invalid. Accepts upper- and lowercase `a-f`.
pub fn hexDigitToInt(c: u8) ?u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return null;
}
