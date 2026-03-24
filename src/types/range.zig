// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Generic Range type representing an inclusive interval `[lower, upper]`.
//!
//! Supports containment checks, overlap detection, intersection, union,
//! formatting, and parsing. Works with any numeric or comparable type.

const std = @import("std");
const math = std.math;
const testing = std.testing;

/// Errors returned by Range operations.
pub const RangeError = error{ InvalidBounds, InvalidFormat, InvalidCharacter, Overflow };

/// A generic inclusive range `[lower, upper]`.
///
/// `T` must support `==` and ordering operators (`<`, `<=`, `>=`, `>`).
/// Numeric operations like `span()` additionally require subtraction and addition.
pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        lower: T,
        upper: T,

        /// Create a range, returning `InvalidBounds` when `lower > upper`.
        pub fn init(lower: T, upper: T) RangeError!Self {
            if (comptime isFloat()) {
                const m = std.math;
                if (m.isNan(lower) or m.isNan(upper) or m.isInf(lower) or m.isInf(upper)) {
                    return RangeError.InvalidBounds;
                }
            }
            if (greaterThan(lower, upper)) return error.InvalidBounds;
            return .{ .lower = lower, .upper = upper };
        }

        /// Create a range without validating bounds ordering.
        pub fn initUnchecked(lower: T, upper: T) Self {
            return .{ .lower = lower, .upper = upper };
        }

        /// True if `lower <= value <= upper`.
        pub fn contains(self: Self, value: T) bool {
            return !greaterThan(value, self.upper) and !lessThan(value, self.lower);
        }

        /// True if `other` is fully contained within `self`.
        pub fn containsRange(self: Self, other: Self) bool {
            return !lessThan(other.lower, self.lower) and !greaterThan(other.upper, self.upper);
        }

        /// True if the two ranges share at least one value.
        pub fn overlaps(self: Self, other: Self) bool {
            return !greaterThan(self.lower, other.upper) and !greaterThan(other.lower, self.upper);
        }

        /// Returns the overlapping portion of two ranges, or `null` if they
        /// do not overlap.
        pub fn intersection(self: Self, other: Self) ?Self {
            const lo = max(self.lower, other.lower);
            const hi = min(self.upper, other.upper);
            if (greaterThan(lo, hi)) return null;
            return .{ .lower = lo, .upper = hi };
        }

        /// Returns the combined range if `self` and `other` overlap or are
        /// adjacent (differ by at most one unit for integer types, or touch
        /// for floats). Returns `null` otherwise.
        pub fn union_(self: Self, other: Self) ?Self {
            if (adjacent(self, other) or self.overlaps(other)) {
                return .{
                    .lower = min(self.lower, other.lower),
                    .upper = max(self.upper, other.upper),
                };
            }
            return null;
        }

        /// Returns the width of the range (upper - lower).
        /// Warning: For integer types, this can overflow if the range spans more than
        /// half the type's representable values (e.g., IntRange from minInt to maxInt).
        /// In Debug/ReleaseSafe modes this triggers a safety panic; in ReleaseFast it wraps.
        pub fn span(self: Self) T {
            return self.upper - self.lower;
        }

        /// Returns true if the range contains exactly one point (lower == upper).
        pub fn isPoint(self: Self) bool {
            return equal(self.lower, self.upper);
        }

        /// True if both bounds are equal.
        pub fn eql(self: Self, other: Self) bool {
            return equal(self.lower, other.lower) and equal(self.upper, other.upper);
        }

        /// Formats the range as `[lower, upper]`.
        /// Use `{f}` format specifier: `std.fmt.bufPrint(&buf, "{f}", .{range})`.
        pub fn format(self: Self, writer: anytype) !void {
            try writer.print("[{d}, {d}]", .{ self.lower, self.upper });
        }

        /// Parse a range from the string format `[lower, upper]`.
        /// Supported for integer types only.
        pub fn parse(input: []const u8) RangeError!Self {
            const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
            if (trimmed.len < 2) return error.InvalidFormat;
            if (trimmed[0] != '[') return error.InvalidFormat;
            if (trimmed[trimmed.len - 1] != ']') return error.InvalidFormat;

            const inner = trimmed[1 .. trimmed.len - 1];
            const comma_idx = std.mem.indexOf(u8, inner, ",") orelse return error.InvalidFormat;

            const lower_str = std.mem.trim(u8, inner[0..comma_idx], &std.ascii.whitespace);
            const upper_str = std.mem.trim(u8, inner[comma_idx + 1 ..], &std.ascii.whitespace);

            if (lower_str.len == 0 or upper_str.len == 0) return error.InvalidFormat;

            const lower = parseValue(lower_str) catch |err| return mapParseError(err);
            const upper = parseValue(upper_str) catch |err| return mapParseError(err);

            return init(lower, upper);
        }

        // ----------------------------------------------------------------
        // Private helpers
        // ----------------------------------------------------------------

        fn parseValue(s: []const u8) std.fmt.ParseIntError!T {
            const type_info = @typeInfo(T);
            switch (type_info) {
                .int => return std.fmt.parseInt(T, s, 10),
                .comptime_int => return std.fmt.parseInt(T, s, 10),
                else => @compileError("parse is only supported for integer types"),
            }
        }

        fn mapParseError(err: std.fmt.ParseIntError) RangeError {
            return switch (err) {
                error.InvalidCharacter => error.InvalidCharacter,
                error.Overflow => error.Overflow,
            };
        }

        fn isFloat() bool {
            return @typeInfo(T) == .float;
        }

        fn equal(a: T, b: T) bool {
            return a == b;
        }

        fn lessThan(a: T, b: T) bool {
            return a < b;
        }

        fn greaterThan(a: T, b: T) bool {
            return a > b;
        }

        fn max(a: T, b: T) T {
            return if (greaterThan(a, b)) a else b;
        }

        fn min(a: T, b: T) T {
            return if (lessThan(a, b)) a else b;
        }

        /// Two ranges are adjacent if one's upper + 1 == the other's lower
        /// (integer types) or if they share a boundary (floats).
        fn adjacent(a: Self, b: Self) bool {
            if (isFloat()) {
                return equal(a.upper, b.lower) or equal(b.upper, a.lower);
            }
            const type_info = @typeInfo(T);
            switch (type_info) {
                .int => {
                    // Guard against overflow at type boundaries.
                    const a_adj = if (a.upper < math.maxInt(T)) a.upper + 1 == b.lower else false;
                    const b_adj = if (b.upper < math.maxInt(T)) b.upper + 1 == a.lower else false;
                    return a_adj or b_adj;
                },
                else => return false,
            }
        }
    };
}

// ============================================================================
// Common Aliases
// ============================================================================

pub const IntRange = Range(i64);
pub const UintRange = Range(u64);
pub const FloatRange = Range(f64);

// ============================================================================
// Unit Tests
// ============================================================================

test "Range creation: valid bounds" {
    const r = try IntRange.init(1, 10);
    try testing.expectEqual(@as(i64, 1), r.lower);
    try testing.expectEqual(@as(i64, 10), r.upper);
}

test "Range creation: invalid bounds returns error" {
    const result = IntRange.init(10, 1);
    try testing.expectError(error.InvalidBounds, result);
}

test "Range creation: equal bounds (single-point range)" {
    const r = try IntRange.init(5, 5);
    try testing.expectEqual(@as(i64, 5), r.lower);
    try testing.expectEqual(@as(i64, 5), r.upper);
}

test "initUnchecked does not validate" {
    const r = IntRange.initUnchecked(10, 1);
    try testing.expectEqual(@as(i64, 10), r.lower);
    try testing.expectEqual(@as(i64, 1), r.upper);
}

// ── contains ──────────────────────────────────────────────────────────

test "contains: value inside range" {
    const r = try IntRange.init(1, 10);
    try testing.expect(r.contains(5));
}

test "contains: value at lower bound" {
    const r = try IntRange.init(1, 10);
    try testing.expect(r.contains(1));
}

test "contains: value at upper bound" {
    const r = try IntRange.init(1, 10);
    try testing.expect(r.contains(10));
}

test "contains: value below range" {
    const r = try IntRange.init(1, 10);
    try testing.expect(!r.contains(0));
}

test "contains: value above range" {
    const r = try IntRange.init(1, 10);
    try testing.expect(!r.contains(11));
}

test "contains: single-point range" {
    const r = try IntRange.init(5, 5);
    try testing.expect(r.contains(5));
    try testing.expect(!r.contains(4));
    try testing.expect(!r.contains(6));
}

// ── containsRange ─────────────────────────────────────────────────────

test "containsRange: other fully inside" {
    const outer = try IntRange.init(1, 10);
    const inner = try IntRange.init(3, 7);
    try testing.expect(outer.containsRange(inner));
}

test "containsRange: other partially outside" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(5, 15);
    try testing.expect(!a.containsRange(b));
}

test "containsRange: other completely outside" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(6, 10);
    try testing.expect(!a.containsRange(b));
}

test "containsRange: identical ranges" {
    const r = try IntRange.init(1, 10);
    try testing.expect(r.containsRange(r));
}

// ── overlaps ──────────────────────────────────────────────────────────

test "overlaps: ranges overlap" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(5, 15);
    try testing.expect(a.overlaps(b));
    try testing.expect(b.overlaps(a));
}

test "overlaps: adjacent ranges (touching at one point)" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(5, 10);
    try testing.expect(a.overlaps(b));
    try testing.expect(b.overlaps(a));
}

test "overlaps: separate ranges" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(7, 10);
    try testing.expect(!a.overlaps(b));
    try testing.expect(!b.overlaps(a));
}

// ── intersection ──────────────────────────────────────────────────────

test "intersection: overlapping ranges" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(5, 15);
    const result = a.intersection(b).?;
    try testing.expectEqual(@as(i64, 5), result.lower);
    try testing.expectEqual(@as(i64, 10), result.upper);
}

test "intersection: one range inside another" {
    const a = try IntRange.init(1, 20);
    const b = try IntRange.init(5, 10);
    const result = a.intersection(b).?;
    try testing.expect(result.eql(b));
}

test "intersection: non-overlapping returns null" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(7, 10);
    try testing.expect(a.intersection(b) == null);
}

test "intersection: touching at single point" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(5, 10);
    const result = a.intersection(b).?;
    try testing.expectEqual(@as(i64, 5), result.lower);
    try testing.expectEqual(@as(i64, 5), result.upper);
}

// ── union_ ────────────────────────────────────────────────────────────

test "union_: overlapping ranges" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(5, 15);
    const result = a.union_(b).?;
    try testing.expectEqual(@as(i64, 1), result.lower);
    try testing.expectEqual(@as(i64, 15), result.upper);
}

test "union_: adjacent ranges (gap of 1)" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(6, 10);
    const result = a.union_(b).?;
    try testing.expectEqual(@as(i64, 1), result.lower);
    try testing.expectEqual(@as(i64, 10), result.upper);
}

test "union_: separate ranges returns null" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(8, 10);
    try testing.expect(a.union_(b) == null);
}

test "union_: touching at single point" {
    const a = try IntRange.init(1, 5);
    const b = try IntRange.init(5, 10);
    const result = a.union_(b).?;
    try testing.expectEqual(@as(i64, 1), result.lower);
    try testing.expectEqual(@as(i64, 10), result.upper);
}

// ── span / isPoint ────────────────────────────────────────────────────

test "span: normal range" {
    const r = try IntRange.init(3, 10);
    try testing.expectEqual(@as(i64, 7), r.span());
}

test "span: single-point range" {
    const r = try IntRange.init(5, 5);
    try testing.expectEqual(@as(i64, 0), r.span());
}

test "isPoint: single-point range is a point" {
    const r = try IntRange.init(5, 5);
    try testing.expect(r.isPoint());
}

test "isPoint: normal range is not a point" {
    const r = try IntRange.init(1, 10);
    try testing.expect(!r.isPoint());
}

// ── eql ───────────────────────────────────────────────────────────────

test "eql: identical ranges" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(1, 10);
    try testing.expect(a.eql(b));
}

test "eql: different ranges" {
    const a = try IntRange.init(1, 10);
    const b = try IntRange.init(1, 11);
    try testing.expect(!a.eql(b));
}

// ── FloatRange alias ──────────────────────────────────────────────────

test "FloatRange: creation and span" {
    const r = try FloatRange.init(1.5, 4.5);
    try testing.expectApproxEqAbs(@as(f64, 3.0), r.span(), 1e-10);
}

test "FloatRange: contains" {
    const r = try FloatRange.init(0.0, 1.0);
    try testing.expect(r.contains(0.5));
    try testing.expect(r.contains(0.0));
    try testing.expect(r.contains(1.0));
    try testing.expect(!r.contains(1.1));
}

test "FloatRange: intersection" {
    const a = try FloatRange.init(0.0, 2.0);
    const b = try FloatRange.init(1.0, 3.0);
    const result = a.intersection(b).?;
    try testing.expectApproxEqAbs(@as(f64, 1.0), result.lower, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 2.0), result.upper, 1e-10);
}

test "FloatRange: union_ of adjacent (touching) ranges" {
    const a = try FloatRange.init(0.0, 1.0);
    const b = try FloatRange.init(1.0, 2.0);
    const result = a.union_(b).?;
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.lower, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 2.0), result.upper, 1e-10);
}

// ── UintRange alias ───────────────────────────────────────────────────

test "UintRange: creation and contains" {
    const r = try UintRange.init(0, 100);
    try testing.expect(r.contains(50));
    try testing.expect(r.contains(0));
    try testing.expect(r.contains(100));
}

// ── format ────────────────────────────────────────────────────────────

test "format: integer range" {
    const r = try IntRange.init(1, 10);
    var buf: [64]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{f}", .{r}) catch unreachable;
    try testing.expectEqualStrings("[1, 10]", slice);
}

test "format: single-point range" {
    const r = try IntRange.init(42, 42);
    var buf: [64]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{f}", .{r}) catch unreachable;
    try testing.expectEqualStrings("[42, 42]", slice);
}

test "format: negative bounds" {
    const r = try IntRange.init(-10, -1);
    var buf: [64]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{f}", .{r}) catch unreachable;
    try testing.expectEqualStrings("[-10, -1]", slice);
}

// ── parse ─────────────────────────────────────────────────────────────

test "parse: valid integer range" {
    const r = try IntRange.parse("[1, 10]");
    try testing.expectEqual(@as(i64, 1), r.lower);
    try testing.expectEqual(@as(i64, 10), r.upper);
}

test "parse: extra whitespace" {
    const r = try IntRange.parse("  [ 3 ,  7 ]  ");
    try testing.expectEqual(@as(i64, 3), r.lower);
    try testing.expectEqual(@as(i64, 7), r.upper);
}

test "parse: negative values" {
    const r = try IntRange.parse("[-5, -1]");
    try testing.expectEqual(@as(i64, -5), r.lower);
    try testing.expectEqual(@as(i64, -1), r.upper);
}

test "parse: invalid bounds order" {
    const result = IntRange.parse("[10, 1]");
    try testing.expectError(error.InvalidBounds, result);
}

test "parse: missing bracket" {
    try testing.expectError(error.InvalidFormat, IntRange.parse("1, 10]"));
    try testing.expectError(error.InvalidFormat, IntRange.parse("[1, 10"));
}

test "parse: empty string" {
    try testing.expectError(error.InvalidFormat, IntRange.parse(""));
}

test "parse: non-numeric content" {
    try testing.expectError(error.InvalidCharacter, IntRange.parse("[abc, 10]"));
}

// ── parse/format roundtrip ────────────────────────────────────────────

test "parse/format roundtrip" {
    const original = try IntRange.init(-42, 99);
    var buf: [64]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try IntRange.parse(formatted);
    try testing.expect(original.eql(parsed));
}

// ── edge cases ────────────────────────────────────────────────────────

test "edge case: UintRange at maximum values" {
    const r = try UintRange.init(0, math.maxInt(u64));
    try testing.expect(r.contains(0));
    try testing.expect(r.contains(math.maxInt(u64)));
    try testing.expect(!r.isPoint());
}

test "edge case: IntRange spanning negative to positive" {
    const r = try IntRange.init(-100, 100);
    try testing.expect(r.contains(0));
    try testing.expectEqual(@as(i64, 200), r.span());
}

test "edge case: union_ not possible at max int boundary" {
    // Ranges [0, 5] and [7, 10] have a gap of more than 1, so no union.
    const a = try IntRange.init(0, 5);
    const b = try IntRange.init(7, 10);
    try testing.expect(a.union_(b) == null);
}

test "edge case: UintRange max value adjacency guard" {
    // upper is maxInt, so upper+1 would overflow. Adjacency check must not panic.
    const a = try UintRange.init(0, math.maxInt(u64));
    const b = try UintRange.init(0, 10);
    // They overlap, so union_ should work via overlap path, not adjacency.
    const result = a.union_(b).?;
    try testing.expectEqual(@as(u64, 0), result.lower);
    try testing.expectEqual(math.maxInt(u64), result.upper);
}

test "edge case: u8 Range" {
    const R = Range(u8);
    const r = try R.init(0, 255);
    try testing.expect(r.contains(128));
    try testing.expectEqual(@as(u8, 255), r.span());
}

// ── FloatRange NaN/Inf rejection ──────────────────────────────────────

test "FloatRange: NaN lower bound returns InvalidBounds" {
    const result = Range(f64).init(math.nan(f64), 5.0);
    try testing.expectError(error.InvalidBounds, result);
}

test "FloatRange: Inf upper bound returns InvalidBounds" {
    const result = Range(f64).init(5.0, math.inf(f64));
    try testing.expectError(error.InvalidBounds, result);
}

test "FloatRange: valid float range still works" {
    const r = try Range(f64).init(1.0, 2.0);
    try testing.expectEqual(@as(f64, 1.0), r.lower);
    try testing.expectEqual(@as(f64, 2.0), r.upper);
}
