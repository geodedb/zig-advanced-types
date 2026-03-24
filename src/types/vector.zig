// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Portable vector value types with compile-time known dimensions.
//!
//! Provides generic fixed-size vectors with element-wise math operations,
//! dot product, magnitude, normalization, and distance metrics. Float-only
//! operations (magnitude, normalize, distance, cosineDistance) are available
//! when the element type is a floating-point type.
//!
//! ## Quick Start
//!
//! ```zig
//! const VectorF32 = @import("types/vector.zig").VectorF32;
//!
//! const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
//! const b = VectorF32.init(.{ 4.0, 5.0, 6.0 });
//! const c = a.add(b);           // [5.0, 7.0, 9.0]
//! const d = a.dot(b);           // 32.0
//! const n = a.normalize();      // unit vector
//! ```

const std = @import("std");

/// Errors that can occur when parsing a vector from a string.
pub const ParseError = error{ InvalidCharacter, InvalidFormat, InvalidDimension, Overflow };

/// A generic fixed-size vector with compile-time known element type and
/// dimension count. All math operations return new vectors and never mutate.
pub fn Vector(comptime T: type, comptime N: usize) type {
    if (N == 0) @compileError("Vector dimension N must be at least 1");

    const is_float = switch (@typeInfo(T)) {
        .float => true,
        else => false,
    };

    const is_int = switch (@typeInfo(T)) {
        .int => true,
        else => false,
    };

    if (!is_float and !is_int) {
        @compileError("Vector element type must be an integer or float type");
    }

    return struct {
        const Self = @This();

        data: [N]T,

        // ====================================================================
        // Construction
        // ====================================================================

        /// Create a vector from an array of values.
        pub fn init(data: [N]T) Self {
            return .{ .data = data };
        }

        /// Return the zero vector (all elements are 0).
        pub fn zero() Self {
            return .{ .data = [_]T{0} ** N };
        }

        /// Return a vector with every element set to `val`.
        pub fn fill(val: T) Self {
            return .{ .data = [_]T{val} ** N };
        }

        // ====================================================================
        // Element access
        // ====================================================================

        /// Returns the element at the given index. Panics if index >= N.
        pub fn at(self: Self, index: usize) T {
            if (index >= N) {
                @panic("Vector index out of bounds");
            }
            return self.data[index];
        }

        /// Returns the element at the given index, or null if out of bounds.
        pub fn get(self: Self, index: usize) ?T {
            if (index >= N) return null;
            return self.data[index];
        }

        // ====================================================================
        // Equality
        // ====================================================================

        /// Element-wise equality comparison.
        pub fn eql(self: Self, other: Self) bool {
            for (self.data, other.data) |a, b| {
                if (a != b) return false;
            }
            return true;
        }

        // ====================================================================
        // Arithmetic (available for all numeric types)
        // ====================================================================

        /// Element-wise addition. Integer overflow is safety-checked in Debug/ReleaseSafe (panics) and wraps in ReleaseFast.
        pub fn add(self: Self, other: Self) Self {
            var result: [N]T = undefined;
            for (self.data, other.data, 0..) |a, b, i| {
                result[i] = a + b;
            }
            return .{ .data = result };
        }

        /// Element-wise subtraction. Integer overflow is safety-checked in Debug/ReleaseSafe (panics) and wraps in ReleaseFast.
        pub fn sub(self: Self, other: Self) Self {
            var result: [N]T = undefined;
            for (self.data, other.data, 0..) |a, b, i| {
                result[i] = a - b;
            }
            return .{ .data = result };
        }

        /// Scalar multiplication (scale every element by `scalar`). Integer overflow is safety-checked in Debug/ReleaseSafe (panics) and wraps in ReleaseFast.
        pub fn scale(self: Self, scalar: T) Self {
            var result: [N]T = undefined;
            for (self.data, 0..) |v, i| {
                result[i] = v * scalar;
            }
            return .{ .data = result };
        }

        /// Dot product (inner product) of two vectors. Integer overflow is safety-checked in Debug/ReleaseSafe (panics) and wraps in ReleaseFast.
        pub fn dot(self: Self, other: Self) T {
            var sum: T = 0;
            for (self.data, other.data) |a, b| {
                sum += a * b;
            }
            return sum;
        }

        /// Sum of squares of all elements. Works for both int and float types.
        pub fn magnitudeSquared(self: Self) T {
            return self.dot(self);
        }

        // ====================================================================
        // Float-only operations
        // ====================================================================

        /// Euclidean length (L2 norm). Only available for float element types.
        pub fn magnitude(self: Self) T {
            comptime if (!is_float) @compileError("magnitude() requires a float element type");
            return @sqrt(self.magnitudeSquared());
        }

        /// Return the unit vector (same direction, magnitude 1). Returns the
        /// zero vector when the input magnitude is 0.
        pub fn normalize(self: Self) Self {
            comptime if (!is_float) @compileError("normalize() requires a float element type");
            const mag = self.magnitude();
            if (mag == 0) return zero();
            return self.scale(1.0 / mag);
        }

        /// Euclidean distance between two vectors.
        pub fn distance(self: Self, other: Self) T {
            comptime if (!is_float) @compileError("distance() requires a float element type");
            return self.sub(other).magnitude();
        }

        /// Cosine distance: `1 - cosine_similarity`.
        ///
        /// Returns 0 for identical directions, 1 for orthogonal, 2 for opposite.
        /// Returns 0 when either vector is the zero vector (degenerate case).
        pub fn cosineDistance(self: Self, other: Self) T {
            comptime if (!is_float) @compileError("cosineDistance requires float element type");
            var sum_aa: T = 0;
            var sum_bb: T = 0;
            var sum_ab: T = 0;
            for (self.data, other.data) |a, b| {
                sum_aa += a * a;
                sum_bb += b * b;
                sum_ab += a * b;
            }
            const mag_self = @sqrt(sum_aa);
            const mag_other = @sqrt(sum_bb);
            if (mag_self == 0 or mag_other == 0) return 0;
            return 1.0 - sum_ab / (mag_self * mag_other);
        }

        // ====================================================================
        // Formatting
        // ====================================================================

        /// Format the vector as `[v0, v1, ..., vN-1]` for `std.fmt`.
        /// Use `{f}` as the format specifier in Zig 0.15.
        pub fn format(self: Self, writer: anytype) !void {
            try writer.writeByte('[');
            for (self.data, 0..) |v, i| {
                if (i > 0) try writer.writeAll(", ");
                try writer.print("{d}", .{v});
            }
            try writer.writeByte(']');
        }

        // ====================================================================
        // Parsing
        // ====================================================================

        /// Parse a vector from the string format `[v0, v1, ..., vN-1]`.
        pub fn parse(input: []const u8) ParseError!Self {
            const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
            if (trimmed.len < 2) return ParseError.InvalidFormat;
            if (trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']')
                return ParseError.InvalidFormat;

            const inner = trimmed[1 .. trimmed.len - 1];
            var result: [N]T = undefined;
            var count: usize = 0;

            var iter = std.mem.splitScalar(u8, inner, ',');
            while (iter.next()) |raw| {
                if (count >= N) return ParseError.InvalidDimension;
                const tok = std.mem.trim(u8, raw, &std.ascii.whitespace);
                if (tok.len == 0) return ParseError.InvalidFormat;

                result[count] = parseElement(tok) catch |err| switch (err) {
                    error.InvalidCharacter => return ParseError.InvalidCharacter,
                    error.Overflow => return ParseError.Overflow,
                };
                count += 1;
            }

            if (count != N) return ParseError.InvalidDimension;
            return .{ .data = result };
        }

        /// Parse a single element from its textual representation.
        fn parseElement(tok: []const u8) error{ InvalidCharacter, Overflow }!T {
            if (is_float) {
                const val = std.fmt.parseFloat(T, tok) catch {
                    return error.InvalidCharacter;
                };
                if (std.math.isNan(val) or std.math.isInf(val)) return error.InvalidCharacter;
                return val;
            } else {
                return std.fmt.parseInt(T, tok, 10) catch |err| switch (err) {
                    error.InvalidCharacter => return error.InvalidCharacter,
                    error.Overflow => return error.Overflow,
                };
            }
        }
    };
}

// ============================================================================
// Convenience aliases
// ============================================================================

/// 3-dimensional vector with `f32` elements — the most common spatial vector.
pub const VectorF32 = Vector(f32, 3);

/// 3-dimensional vector with `i32` elements.
pub const VectorI32 = Vector(i32, 3);

// ============================================================================
// Unit Tests
// ============================================================================

const testing = std.testing;
const epsilon: f32 = 1e-6;

// --------------------------------------------------------------------------
// Construction
// --------------------------------------------------------------------------

test "VectorF32 init stores values" {
    const v = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    try testing.expectApproxEqAbs(@as(f32, 1.0), v.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 2.0), v.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 3.0), v.data[2], epsilon);
}

test "VectorF32 zero returns all zeros" {
    const v = VectorF32.zero();
    for (v.data) |val| {
        try testing.expectApproxEqAbs(@as(f32, 0.0), val, epsilon);
    }
}

test "VectorF32 fill returns uniform vector" {
    const v = VectorF32.fill(7.5);
    for (v.data) |val| {
        try testing.expectApproxEqAbs(@as(f32, 7.5), val, epsilon);
    }
}

test "VectorI32 init stores values" {
    const v = VectorI32.init(.{ 10, 20, 30 });
    try testing.expectEqual(@as(i32, 10), v.data[0]);
    try testing.expectEqual(@as(i32, 20), v.data[1]);
    try testing.expectEqual(@as(i32, 30), v.data[2]);
}

test "VectorI32 zero returns all zeros" {
    const v = VectorI32.zero();
    for (v.data) |val| {
        try testing.expectEqual(@as(i32, 0), val);
    }
}

test "VectorI32 fill returns uniform vector" {
    const v = VectorI32.fill(42);
    for (v.data) |val| {
        try testing.expectEqual(@as(i32, 42), val);
    }
}

// --------------------------------------------------------------------------
// Element access and equality
// --------------------------------------------------------------------------

test "VectorF32 at returns correct element" {
    const v = VectorF32.init(.{ 10.0, 20.0, 30.0 });
    try testing.expectApproxEqAbs(@as(f32, 10.0), v.at(0), epsilon);
    try testing.expectApproxEqAbs(@as(f32, 20.0), v.at(1), epsilon);
    try testing.expectApproxEqAbs(@as(f32, 30.0), v.at(2), epsilon);
}

test "VectorF32 eql returns true for equal vectors" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    try testing.expect(a.eql(b));
}

test "VectorF32 eql returns false for unequal vectors" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = VectorF32.init(.{ 1.0, 2.0, 4.0 });
    try testing.expect(!a.eql(b));
}

test "VectorI32 at returns correct element" {
    const v = VectorI32.init(.{ 5, 10, 15 });
    try testing.expectEqual(@as(i32, 5), v.at(0));
    try testing.expectEqual(@as(i32, 10), v.at(1));
    try testing.expectEqual(@as(i32, 15), v.at(2));
}

test "VectorI32 eql works" {
    const a = VectorI32.init(.{ 1, 2, 3 });
    const b = VectorI32.init(.{ 1, 2, 3 });
    const c = VectorI32.init(.{ 1, 2, 4 });
    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

// --------------------------------------------------------------------------
// Math: add, sub, scale, dot
// --------------------------------------------------------------------------

test "VectorF32 add" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = VectorF32.init(.{ 4.0, 5.0, 6.0 });
    const c = a.add(b);
    try testing.expectApproxEqAbs(@as(f32, 5.0), c.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 7.0), c.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 9.0), c.data[2], epsilon);
}

test "VectorF32 sub" {
    const a = VectorF32.init(.{ 5.0, 7.0, 9.0 });
    const b = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const c = a.sub(b);
    try testing.expectApproxEqAbs(@as(f32, 4.0), c.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 5.0), c.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 6.0), c.data[2], epsilon);
}

test "VectorF32 scale" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = a.scale(2.0);
    try testing.expectApproxEqAbs(@as(f32, 2.0), b.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 4.0), b.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 6.0), b.data[2], epsilon);
}

test "VectorF32 dot product" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = VectorF32.init(.{ 4.0, 5.0, 6.0 });
    // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    try testing.expectApproxEqAbs(@as(f32, 32.0), a.dot(b), epsilon);
}

test "VectorI32 add" {
    const a = VectorI32.init(.{ 1, 2, 3 });
    const b = VectorI32.init(.{ 10, 20, 30 });
    const c = a.add(b);
    try testing.expectEqual(@as(i32, 11), c.data[0]);
    try testing.expectEqual(@as(i32, 22), c.data[1]);
    try testing.expectEqual(@as(i32, 33), c.data[2]);
}

test "VectorI32 sub" {
    const a = VectorI32.init(.{ 10, 20, 30 });
    const b = VectorI32.init(.{ 1, 2, 3 });
    const c = a.sub(b);
    try testing.expectEqual(@as(i32, 9), c.data[0]);
    try testing.expectEqual(@as(i32, 18), c.data[1]);
    try testing.expectEqual(@as(i32, 27), c.data[2]);
}

test "VectorI32 scale" {
    const a = VectorI32.init(.{ 2, 3, 4 });
    const b = a.scale(5);
    try testing.expectEqual(@as(i32, 10), b.data[0]);
    try testing.expectEqual(@as(i32, 15), b.data[1]);
    try testing.expectEqual(@as(i32, 20), b.data[2]);
}

test "VectorI32 dot product" {
    const a = VectorI32.init(.{ 1, 2, 3 });
    const b = VectorI32.init(.{ 4, 5, 6 });
    try testing.expectEqual(@as(i32, 32), a.dot(b));
}

test "VectorI32 magnitudeSquared" {
    const v = VectorI32.init(.{ 3, 4, 0 });
    try testing.expectEqual(@as(i32, 25), v.magnitudeSquared());
}

// --------------------------------------------------------------------------
// Float-only: magnitude, normalize, distance, cosineDistance
// --------------------------------------------------------------------------

test "VectorF32 magnitude" {
    const v = VectorF32.init(.{ 3.0, 4.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 5.0), v.magnitude(), epsilon);
}

test "VectorF32 magnitudeSquared" {
    const v = VectorF32.init(.{ 3.0, 4.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 25.0), v.magnitudeSquared(), epsilon);
}

test "VectorF32 normalize" {
    const v = VectorF32.init(.{ 3.0, 0.0, 0.0 });
    const n = v.normalize();
    try testing.expectApproxEqAbs(@as(f32, 1.0), n.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), n.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), n.data[2], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 1.0), n.magnitude(), epsilon);
}

test "VectorF32 normalize of zero vector returns zero" {
    const v = VectorF32.zero();
    const n = v.normalize();
    try testing.expect(n.eql(VectorF32.zero()));
}

test "VectorF32 distance" {
    const a = VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = VectorF32.init(.{ 4.0, 0.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 3.0), a.distance(b), epsilon);
}

test "VectorF32 distance between equal vectors is zero" {
    const a = VectorF32.init(.{ 2.0, 3.0, 4.0 });
    try testing.expectApproxEqAbs(@as(f32, 0.0), a.distance(a), epsilon);
}

test "VectorF32 cosineDistance of identical directions is zero" {
    const a = VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = VectorF32.init(.{ 5.0, 0.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 0.0), a.cosineDistance(b), epsilon);
}

test "VectorF32 cosineDistance of opposite directions is two" {
    const a = VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = VectorF32.init(.{ -1.0, 0.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 2.0), a.cosineDistance(b), epsilon);
}

test "VectorF32 cosineDistance of orthogonal vectors is one" {
    const a = VectorF32.init(.{ 1.0, 0.0, 0.0 });
    const b = VectorF32.init(.{ 0.0, 1.0, 0.0 });
    try testing.expectApproxEqAbs(@as(f32, 1.0), a.cosineDistance(b), epsilon);
}

test "VectorF32 cosineDistance of zero vector returns zero" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const z = VectorF32.zero();
    try testing.expectApproxEqAbs(@as(f32, 0.0), a.cosineDistance(z), epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), z.cosineDistance(a), epsilon);
    try testing.expectApproxEqAbs(@as(f32, 0.0), z.cosineDistance(z), epsilon);
}

// --------------------------------------------------------------------------
// Formatting and parsing
// --------------------------------------------------------------------------

test "VectorF32 format produces bracketed output" {
    const v = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    var buf: [256]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{f}", .{v}) catch unreachable;
    try testing.expectEqualStrings("[1, 2, 3]", slice);
}

test "VectorI32 format produces bracketed output" {
    const v = VectorI32.init(.{ 10, -20, 30 });
    var buf: [256]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{f}", .{v}) catch unreachable;
    try testing.expectEqualStrings("[10, -20, 30]", slice);
}

test "VectorF32 parse valid input" {
    const v = try VectorF32.parse("[1.5, 2.5, 3.5]");
    try testing.expectApproxEqAbs(@as(f32, 1.5), v.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 2.5), v.data[1], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 3.5), v.data[2], epsilon);
}

test "VectorI32 parse valid input" {
    const v = try VectorI32.parse("[10, -20, 30]");
    try testing.expectEqual(@as(i32, 10), v.data[0]);
    try testing.expectEqual(@as(i32, -20), v.data[1]);
    try testing.expectEqual(@as(i32, 30), v.data[2]);
}

test "VectorF32 parse/format roundtrip" {
    const original = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    var buf: [256]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try VectorF32.parse(formatted);
    for (original.data, parsed.data) |a, b| {
        try testing.expectApproxEqAbs(a, b, epsilon);
    }
}

test "VectorI32 parse/format roundtrip" {
    const original = VectorI32.init(.{ 7, -3, 42 });
    var buf: [256]u8 = undefined;
    const formatted = std.fmt.bufPrint(&buf, "{f}", .{original}) catch unreachable;
    const parsed = try VectorI32.parse(formatted);
    try testing.expect(original.eql(parsed));
}

test "VectorF32 parse rejects wrong dimension" {
    const result = VectorF32.parse("[1.0, 2.0]");
    try testing.expectError(ParseError.InvalidDimension, result);
}

test "VectorF32 parse rejects too many dimensions" {
    const result = VectorF32.parse("[1.0, 2.0, 3.0, 4.0]");
    try testing.expectError(ParseError.InvalidDimension, result);
}

test "VectorF32 parse rejects missing brackets" {
    try testing.expectError(ParseError.InvalidFormat, VectorF32.parse("1.0, 2.0, 3.0"));
    try testing.expectError(ParseError.InvalidFormat, VectorF32.parse("[1.0, 2.0, 3.0"));
    try testing.expectError(ParseError.InvalidFormat, VectorF32.parse("1.0, 2.0, 3.0]"));
}

test "VectorF32 parse rejects invalid characters" {
    const result = VectorF32.parse("[abc, 2.0, 3.0]");
    try testing.expectError(ParseError.InvalidCharacter, result);
}

test "VectorF32 parse rejects empty input" {
    try testing.expectError(ParseError.InvalidFormat, VectorF32.parse(""));
    try testing.expectError(ParseError.InvalidFormat, VectorF32.parse("x"));
}

// --------------------------------------------------------------------------
// Immutability check: operations do not mutate the original
// --------------------------------------------------------------------------

test "VectorF32 add does not mutate operands" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    const b = VectorF32.init(.{ 4.0, 5.0, 6.0 });
    _ = a.add(b);
    // originals unchanged
    try testing.expectApproxEqAbs(@as(f32, 1.0), a.data[0], epsilon);
    try testing.expectApproxEqAbs(@as(f32, 4.0), b.data[0], epsilon);
}

test "VectorF32 scale does not mutate operand" {
    const a = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    _ = a.scale(10.0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), a.data[0], epsilon);
}

// --------------------------------------------------------------------------
// Inf/NaN rejection
// --------------------------------------------------------------------------

test "VectorF32 parse rejects inf" {
    const result = VectorF32.parse("[inf, 0, 0]");
    try testing.expectError(ParseError.InvalidCharacter, result);
}

test "VectorF32 parse rejects nan" {
    const result = VectorF32.parse("[nan, 0, 0]");
    try testing.expectError(ParseError.InvalidCharacter, result);
}

// --------------------------------------------------------------------------
// get() method
// --------------------------------------------------------------------------

test "VectorF32 get returns value for valid index" {
    const v = VectorF32.init(.{ 10.0, 20.0, 30.0 });
    try testing.expectApproxEqAbs(@as(f32, 10.0), v.get(0).?, epsilon);
    try testing.expectApproxEqAbs(@as(f32, 20.0), v.get(1).?, epsilon);
    try testing.expectApproxEqAbs(@as(f32, 30.0), v.get(2).?, epsilon);
}

test "VectorF32 get returns null for out-of-bounds index" {
    const v = VectorF32.init(.{ 1.0, 2.0, 3.0 });
    try testing.expectEqual(@as(?f32, null), v.get(3));
    try testing.expectEqual(@as(?f32, null), v.get(100));
}

test "VectorI32 get returns value for valid index" {
    const v = VectorI32.init(.{ 5, 10, 15 });
    try testing.expectEqual(@as(i32, 5), v.get(0).?);
    try testing.expectEqual(@as(i32, 10), v.get(1).?);
    try testing.expectEqual(@as(i32, 15), v.get(2).?);
}

test "VectorI32 get returns null for out-of-bounds index" {
    const v = VectorI32.init(.{ 1, 2, 3 });
    try testing.expectEqual(@as(?i32, null), v.get(3));
    try testing.expectEqual(@as(?i32, null), v.get(100));
}
