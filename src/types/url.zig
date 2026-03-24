// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Url and Domain value types for simplified URL/domain handling.
//!
//! These are standalone value types that store slices into the original input
//! (no allocation for parsing). They provide parsing, normalization,
//! comparison, and formatting for URLs and domain names.

const std = @import("std");

// ============================================================================
// Error Type
// ============================================================================

pub const ParseError = error{
    InvalidCharacter,
    InvalidFormat,
    EmptyInput,
    InvalidScheme,
    InvalidPort,
    InvalidDomain,
    MissingHost,
};

// ============================================================================
// Domain
// ============================================================================

/// A validated domain name stored as a slice into the original input.
///
/// Domain names are validated per RFC 952 / RFC 1123 rules:
/// - Labels separated by dots, each 1-63 characters
/// - Total length <= 253 characters
/// - Valid characters: alphanumeric + hyphen
/// - No leading/trailing hyphens per label
pub const Domain = struct {
    raw: []const u8,

    /// Parse and validate a domain name from the input string.
    pub fn parse(input: []const u8) ParseError!Domain {
        if (input.len == 0) return ParseError.EmptyInput;
        if (input.len > 253) return ParseError.InvalidDomain;

        var label_start: usize = 0;

        for (input, 0..) |c, i| {
            if (c == '.') {
                const label = input[label_start..i];
                try validateLabel(label);
                label_start = i + 1;
            } else if (!isValidDomainChar(c)) {
                return ParseError.InvalidCharacter;
            }
        }

        // Validate the last label (or only label if no dots)
        const last_label = input[label_start..];
        try validateLabel(last_label);

        return Domain{ .raw = input };
    }

    /// Iterate over the labels of the domain (e.g., "www", "example", "com").
    pub fn labels(self: Domain) DomainLabelIterator {
        return DomainLabelIterator{ .raw = self.raw, .pos = 0 };
    }

    /// Return the top-level domain (e.g., "com" from "www.example.com").
    /// Returns null if the domain has no dots (single-label domain).
    pub fn tld(self: Domain) ?[]const u8 {
        const last_dot = std.mem.lastIndexOfScalar(u8, self.raw, '.') orelse return null;
        return self.raw[last_dot + 1 ..];
    }

    /// Return the registered domain (e.g., "example.com" from "www.example.com").
    /// This is the last two labels joined by a dot.
    /// Returns null if the domain has fewer than two labels.
    pub fn registeredDomain(self: Domain) ?[]const u8 {
        // Find the last dot
        const last_dot = std.mem.lastIndexOfScalar(u8, self.raw, '.') orelse return null;
        // Find the second-to-last dot (or start of string)
        const before_last = self.raw[0..last_dot];
        const second_last_dot = std.mem.lastIndexOfScalar(u8, before_last, '.');
        if (second_last_dot) |pos| {
            return self.raw[pos + 1 ..];
        }
        // Only two labels total — the whole domain is the registered domain
        return self.raw;
    }

    /// Case-insensitive comparison of two domains.
    pub fn eql(self: Domain, other: Domain) bool {
        return std.ascii.eqlIgnoreCase(self.raw, other.raw);
    }

    /// Format the domain for use with `std.fmt`.
    pub fn format(self: Domain, writer: anytype) !void {
        try writer.writeAll(self.raw);
    }

    fn validateLabel(label: []const u8) ParseError!void {
        if (label.len == 0) return ParseError.InvalidDomain;
        if (label.len > 63) return ParseError.InvalidDomain;
        if (label[0] == '-') return ParseError.InvalidDomain;
        if (label[label.len - 1] == '-') return ParseError.InvalidDomain;
        for (label) |c| {
            if (!isValidDomainChar(c)) return ParseError.InvalidCharacter;
        }
    }

    fn isValidDomainChar(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '-';
    }
};

// ============================================================================
// DomainLabelIterator
// ============================================================================

/// Iterator over the labels of a domain name.
pub const DomainLabelIterator = struct {
    raw: []const u8,
    pos: usize,

    /// Return the next label, or null when exhausted.
    pub fn next(self: *DomainLabelIterator) ?[]const u8 {
        if (self.pos >= self.raw.len) return null;

        const remaining = self.raw[self.pos..];
        const dot_pos = std.mem.indexOfScalar(u8, remaining, '.');
        if (dot_pos) |dp| {
            const label = remaining[0..dp];
            self.pos += dp + 1;
            return label;
        }
        // Last label
        self.pos = self.raw.len;
        return remaining;
    }
};

// ============================================================================
// Url
// ============================================================================

/// A parsed URL stored as slices into the original input string.
///
/// Provides zero-allocation parsing of URLs into their component parts:
/// scheme, host, port, path, query, and fragment.
pub const Url = struct {
    raw: []const u8,
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,

    /// Parse a URL string into its components.
    pub fn parse(input: []const u8) ParseError!Url {
        if (input.len == 0) return ParseError.EmptyInput;

        // Parse scheme: find "://"
        const scheme_end = std.mem.indexOf(u8, input, "://") orelse
            return ParseError.InvalidScheme;
        const scheme = input[0..scheme_end];
        if (scheme.len == 0) return ParseError.InvalidScheme;
        for (scheme) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '+' and c != '-' and c != '.') {
                return ParseError.InvalidScheme;
            }
        }

        // After "://" is the authority + path + query + fragment
        var rest = input[scheme_end + 3 ..];
        if (rest.len == 0) return ParseError.MissingHost;

        // Split off fragment first (rightmost '#')
        var fragment: ?[]const u8 = null;
        if (std.mem.indexOfScalar(u8, rest, '#')) |frag_pos| {
            fragment = rest[frag_pos + 1 ..];
            rest = rest[0..frag_pos];
        }

        // Split off query (first '?' in what remains)
        var query: ?[]const u8 = null;
        if (std.mem.indexOfScalar(u8, rest, '?')) |q_pos| {
            query = rest[q_pos + 1 ..];
            rest = rest[0..q_pos];
        }

        // Now rest is authority + path
        // Find the first '/' to split authority from path
        var authority: []const u8 = undefined;
        var path: []const u8 = undefined;
        if (std.mem.indexOfScalar(u8, rest, '/')) |slash_pos| {
            authority = rest[0..slash_pos];
            path = rest[slash_pos..];
        } else {
            authority = rest;
            path = input[scheme_end + 3 + rest.len .. scheme_end + 3 + rest.len]; // empty slice at correct position
        }

        if (authority.len == 0) return ParseError.MissingHost;

        // Parse host and port from authority
        // Handle IPv6 literals: [::1]:port
        var host: []const u8 = undefined;
        var port_val: ?u16 = null;

        if (authority[0] == '[') {
            // IPv6 literal
            const bracket_end = std.mem.indexOfScalar(u8, authority, ']') orelse
                return ParseError.InvalidFormat;
            host = authority[0 .. bracket_end + 1];
            const after_bracket = authority[bracket_end + 1 ..];
            if (after_bracket.len > 0) {
                if (after_bracket[0] != ':') return ParseError.InvalidFormat;
                port_val = parsePort(after_bracket[1..]) orelse return ParseError.InvalidPort;
            }
        } else {
            // Regular host or IPv4
            if (std.mem.lastIndexOfScalar(u8, authority, ':')) |colon_pos| {
                host = authority[0..colon_pos];
                port_val = parsePort(authority[colon_pos + 1 ..]) orelse return ParseError.InvalidPort;
            } else {
                host = authority;
            }
        }

        if (host.len == 0) return ParseError.MissingHost;

        // If path is empty, default to "/"
        const final_path = if (path.len == 0) "/" else path;

        return Url{
            .raw = input,
            .scheme = scheme,
            .host = host,
            .port = port_val,
            .path = final_path,
            .query = query,
            .fragment = fragment,
        };
    }

    /// Return the effective port: the explicit port if present, otherwise the
    /// default port for the scheme (80 for http, 443 for https).
    pub fn effectivePort(self: Url) u16 {
        if (self.port) |p| return p;
        if (std.ascii.eqlIgnoreCase(self.scheme, "https")) return 443;
        if (std.ascii.eqlIgnoreCase(self.scheme, "http")) return 80;
        return 0;
    }

    /// Attempt to parse the host as a Domain.
    /// Returns null if the host is not a valid domain (e.g., IP literal).
    pub fn domain(self: Url) ?Domain {
        // Skip IPv6 literals
        if (self.host.len > 0 and self.host[0] == '[') return null;
        // Skip if it looks like an IPv4 address (all digits and dots)
        if (looksLikeIpv4(self.host)) return null;
        return Domain.parse(self.host) catch null;
    }

    /// Compare two URLs for equality (case-insensitive scheme and host).
    pub fn eql(self: Url, other: Url) bool {
        if (!std.ascii.eqlIgnoreCase(self.scheme, other.scheme)) return false;
        if (!std.ascii.eqlIgnoreCase(self.host, other.host)) return false;
        if (self.effectivePort() != other.effectivePort()) return false;
        if (!std.mem.eql(u8, self.path, other.path)) return false;
        if (!optionalEql(self.query, other.query)) return false;
        if (!optionalEql(self.fragment, other.fragment)) return false;
        return true;
    }

    /// Format the URL for use with `std.fmt`. Reconstructs the URL from components.
    pub fn format(self: Url, writer: anytype) !void {
        try writer.writeAll(self.scheme);
        try writer.writeAll("://");
        try writer.writeAll(self.host);
        if (self.port) |p| {
            try writer.print(":{d}", .{p});
        }
        try writer.writeAll(self.path);
        if (self.query) |q| {
            try writer.writeByte('?');
            try writer.writeAll(q);
        }
        if (self.fragment) |f| {
            try writer.writeByte('#');
            try writer.writeAll(f);
        }
    }

    fn parsePort(s: []const u8) ?u16 {
        if (s.len == 0) return null;
        return std.fmt.parseInt(u16, s, 10) catch null;
    }

    fn looksLikeIpv4(host: []const u8) bool {
        if (host.len == 0) return false;
        for (host) |c| {
            if (c != '.' and !std.ascii.isDigit(c)) return false;
        }
        return true;
    }

    fn optionalEql(a: ?[]const u8, b: ?[]const u8) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        return std.mem.eql(u8, a.?, b.?);
    }
};

// ============================================================================
// Unit Tests — Domain
// ============================================================================

test "Domain: parse valid simple domain" {
    const d = try Domain.parse("example.com");
    try std.testing.expectEqualStrings("example.com", d.raw);
}

test "Domain: parse valid subdomain" {
    const d = try Domain.parse("www.example.com");
    try std.testing.expectEqualStrings("www.example.com", d.raw);
}

test "Domain: parse single-label domain" {
    const d = try Domain.parse("localhost");
    try std.testing.expectEqualStrings("localhost", d.raw);
}

test "Domain: parse domain with hyphens" {
    const d = try Domain.parse("my-site.example.co");
    try std.testing.expectEqualStrings("my-site.example.co", d.raw);
}

test "Domain: parse deeply nested subdomain" {
    const d = try Domain.parse("a.b.c.d.example.com");
    try std.testing.expectEqualStrings("a.b.c.d.example.com", d.raw);
}

test "Domain: reject empty input" {
    try std.testing.expectError(ParseError.EmptyInput, Domain.parse(""));
}

test "Domain: reject empty label (leading dot)" {
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse(".example.com"));
}

test "Domain: reject empty label (trailing dot)" {
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse("example.com."));
}

test "Domain: reject empty label (consecutive dots)" {
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse("example..com"));
}

test "Domain: reject label too long (>63 chars)" {
    const long_label = "a" ** 64 ++ ".com";
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse(long_label));
}

test "Domain: reject total length >253 chars" {
    // Build a domain that exceeds 253 characters
    const long_domain = "a." ** 127 ++ "b";
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse(long_domain));
}

test "Domain: reject invalid character (underscore)" {
    try std.testing.expectError(ParseError.InvalidCharacter, Domain.parse("ex_ample.com"));
}

test "Domain: reject invalid character (space)" {
    try std.testing.expectError(ParseError.InvalidCharacter, Domain.parse("exam ple.com"));
}

test "Domain: reject leading hyphen in label" {
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse("-example.com"));
}

test "Domain: reject trailing hyphen in label" {
    try std.testing.expectError(ParseError.InvalidDomain, Domain.parse("example-.com"));
}

test "Domain: labels iterator" {
    const d = try Domain.parse("www.example.com");
    var iter = d.labels();
    try std.testing.expectEqualStrings("www", iter.next().?);
    try std.testing.expectEqualStrings("example", iter.next().?);
    try std.testing.expectEqualStrings("com", iter.next().?);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());
}

test "Domain: labels iterator single label" {
    const d = try Domain.parse("localhost");
    var iter = d.labels();
    try std.testing.expectEqualStrings("localhost", iter.next().?);
    try std.testing.expectEqual(@as(?[]const u8, null), iter.next());
}

test "Domain: tld" {
    const d = try Domain.parse("www.example.com");
    try std.testing.expectEqualStrings("com", d.tld().?);
}

test "Domain: tld returns null for single label" {
    const d = try Domain.parse("localhost");
    try std.testing.expectEqual(@as(?[]const u8, null), d.tld());
}

test "Domain: registeredDomain" {
    const d = try Domain.parse("www.example.com");
    try std.testing.expectEqualStrings("example.com", d.registeredDomain().?);
}

test "Domain: registeredDomain for two-label domain" {
    const d = try Domain.parse("example.com");
    try std.testing.expectEqualStrings("example.com", d.registeredDomain().?);
}

test "Domain: registeredDomain returns null for single label" {
    const d = try Domain.parse("localhost");
    try std.testing.expectEqual(@as(?[]const u8, null), d.registeredDomain());
}

test "Domain: case-insensitive eql" {
    const a = try Domain.parse("Example.COM");
    const b = try Domain.parse("example.com");
    try std.testing.expect(a.eql(b));
}

test "Domain: eql returns false for different domains" {
    const a = try Domain.parse("example.com");
    const b = try Domain.parse("example.org");
    try std.testing.expect(!a.eql(b));
}

test "Domain: format output" {
    const d = try Domain.parse("www.example.com");
    var buf: [256]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{d});
    try std.testing.expectEqualStrings("www.example.com", result);
}

// ============================================================================
// Unit Tests — Url
// ============================================================================

test "Url: parse full URL with all components" {
    const u = try Url.parse("https://www.example.com:8443/path/to/resource?key=value&a=b#section");
    try std.testing.expectEqualStrings("https", u.scheme);
    try std.testing.expectEqualStrings("www.example.com", u.host);
    try std.testing.expectEqual(@as(?u16, 8443), u.port);
    try std.testing.expectEqualStrings("/path/to/resource", u.path);
    try std.testing.expectEqualStrings("key=value&a=b", u.query.?);
    try std.testing.expectEqualStrings("section", u.fragment.?);
}

test "Url: parse minimal URL (scheme + host)" {
    const u = try Url.parse("http://example.com");
    try std.testing.expectEqualStrings("http", u.scheme);
    try std.testing.expectEqualStrings("example.com", u.host);
    try std.testing.expectEqual(@as(?u16, null), u.port);
    try std.testing.expectEqualStrings("/", u.path);
    try std.testing.expectEqual(@as(?[]const u8, null), u.query);
    try std.testing.expectEqual(@as(?[]const u8, null), u.fragment);
}

test "Url: parse URL with trailing slash" {
    const u = try Url.parse("https://example.com/");
    try std.testing.expectEqualStrings("/", u.path);
}

test "Url: parse URL with path only" {
    const u = try Url.parse("https://example.com/path");
    try std.testing.expectEqualStrings("/path", u.path);
}

test "Url: parse URL with query but no fragment" {
    const u = try Url.parse("http://example.com/search?q=zig");
    try std.testing.expectEqualStrings("q=zig", u.query.?);
    try std.testing.expectEqual(@as(?[]const u8, null), u.fragment);
}

test "Url: parse URL with fragment but no query" {
    const u = try Url.parse("http://example.com/page#top");
    try std.testing.expectEqual(@as(?[]const u8, null), u.query);
    try std.testing.expectEqualStrings("top", u.fragment.?);
}

test "Url: parse URL with empty query and fragment" {
    const u = try Url.parse("http://example.com/path?#");
    try std.testing.expectEqualStrings("", u.query.?);
    try std.testing.expectEqualStrings("", u.fragment.?);
}

test "Url: parse URL with port" {
    const u = try Url.parse("http://localhost:3000/api");
    try std.testing.expectEqualStrings("localhost", u.host);
    try std.testing.expectEqual(@as(?u16, 3000), u.port);
    try std.testing.expectEqualStrings("/api", u.path);
}

test "Url: reject empty input" {
    try std.testing.expectError(ParseError.EmptyInput, Url.parse(""));
}

test "Url: reject missing scheme" {
    try std.testing.expectError(ParseError.InvalidScheme, Url.parse("example.com"));
}

test "Url: reject empty scheme" {
    try std.testing.expectError(ParseError.InvalidScheme, Url.parse("://example.com"));
}

test "Url: reject missing host" {
    try std.testing.expectError(ParseError.MissingHost, Url.parse("http:///path"));
}

test "Url: reject invalid port" {
    try std.testing.expectError(ParseError.InvalidPort, Url.parse("http://example.com:notaport/"));
}

test "Url: reject port out of range" {
    try std.testing.expectError(ParseError.InvalidPort, Url.parse("http://example.com:99999/"));
}

test "Url: effectivePort returns explicit port" {
    const u = try Url.parse("http://example.com:9090");
    try std.testing.expectEqual(@as(u16, 9090), u.effectivePort());
}

test "Url: effectivePort returns 80 for http" {
    const u = try Url.parse("http://example.com");
    try std.testing.expectEqual(@as(u16, 80), u.effectivePort());
}

test "Url: effectivePort returns 443 for https" {
    const u = try Url.parse("https://example.com");
    try std.testing.expectEqual(@as(u16, 443), u.effectivePort());
}

test "Url: effectivePort returns 0 for unknown scheme" {
    const u = try Url.parse("ftp://files.example.com");
    try std.testing.expectEqual(@as(u16, 0), u.effectivePort());
}

test "Url: domain extraction" {
    const u = try Url.parse("https://www.example.com/path");
    const d = u.domain().?;
    try std.testing.expectEqualStrings("www.example.com", d.raw);
}

test "Url: domain returns null for IPv4 host" {
    const u = try Url.parse("http://192.168.1.1/path");
    try std.testing.expectEqual(@as(?Domain, null), u.domain());
}

test "Url: domain returns null for IPv6 host" {
    const u = try Url.parse("http://[::1]:8080/path");
    try std.testing.expectEqual(@as(?Domain, null), u.domain());
}

test "Url: eql with same URLs" {
    const a = try Url.parse("https://example.com/path?q=1#frag");
    const b = try Url.parse("https://example.com/path?q=1#frag");
    try std.testing.expect(a.eql(b));
}

test "Url: eql is case-insensitive for scheme and host" {
    const a = try Url.parse("HTTPS://EXAMPLE.COM/path");
    const b = try Url.parse("https://example.com/path");
    try std.testing.expect(a.eql(b));
}

test "Url: eql considers effective port" {
    const a = try Url.parse("https://example.com:443/path");
    const b = try Url.parse("https://example.com/path");
    try std.testing.expect(a.eql(b));
}

test "Url: eql returns false for different paths" {
    const a = try Url.parse("https://example.com/a");
    const b = try Url.parse("https://example.com/b");
    try std.testing.expect(!a.eql(b));
}

test "Url: format roundtrip" {
    const input = "https://example.com:8080/path?query=1#frag";
    const u = try Url.parse(input);
    var buf: [512]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{u});
    try std.testing.expectEqualStrings(input, result);
}

test "Url: format minimal URL" {
    const u = try Url.parse("http://example.com");
    var buf: [512]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{u});
    try std.testing.expectEqualStrings("http://example.com/", result);
}

test "Url: format URL with query only" {
    const u = try Url.parse("http://example.com/search?q=test");
    var buf: [512]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{u});
    try std.testing.expectEqualStrings("http://example.com/search?q=test", result);
}

test "Url: format URL with fragment only" {
    const u = try Url.parse("http://example.com/page#section");
    var buf: [512]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{u});
    try std.testing.expectEqualStrings("http://example.com/page#section", result);
}

test "Url: parse URL with IPv6 host and port" {
    const u = try Url.parse("http://[::1]:8080/path");
    try std.testing.expectEqualStrings("[::1]", u.host);
    try std.testing.expectEqual(@as(?u16, 8080), u.port);
    try std.testing.expectEqualStrings("/path", u.path);
}

test "Url: parse URL with IPv6 host without port" {
    const u = try Url.parse("http://[::1]/path");
    try std.testing.expectEqualStrings("[::1]", u.host);
    try std.testing.expectEqual(@as(?u16, null), u.port);
}

test "Url: raw preserves original input" {
    const input = "https://Example.COM:443/Path?Q=1#F";
    const u = try Url.parse(input);
    try std.testing.expectEqualStrings(input, u.raw);
}
