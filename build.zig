// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

const std = @import("std");

pub fn build(b: *std.Build) void {
    // ATX-04 guard: fail the build if src/root.zig's `version` constant
    // drifts from build.zig.zon's `.version`.
    checkVersionSync(b) catch |err| std.debug.panic("version sync check: I/O or parse failure: {s}", .{@errorName(err)});

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Q34: `-Dtest-filter="name substring"` narrows every test suite to
    // tests whose names contain the string. Repeatable; empty = run all.
    const test_filters = b.option([]const []const u8, "test-filter", "Only run tests whose names contain this string (repeatable)") orelse &.{};

    // Main library module
    const module = b.addModule("advanced_types", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Unit tests (run tests defined in the module itself)
    const test_step = b.step("test", "Run unit tests");
    const unit_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);

    // Integration tests (separate test file with module import)
    const integration_step = b.step("test-integration", "Run integration tests");
    const integration_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    integration_step.dependOn(&run_integration_tests.step);

    // Type-extension tests (cross-feature type-extension coverage)
    const extensions_step = b.step("test-extensions", "Run type-extension tests");
    const extensions_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/type_extensions.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_extensions_tests = b.addRunArtifact(extensions_tests);
    extensions_step.dependOn(&run_extensions_tests.step);

    // Fuzz tests (exercise parsers with arbitrary input)
    const fuzz_step = b.step("test-fuzz", "Run fuzz tests");
    const fuzz_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_fuzz_tests = b.addRunArtifact(fuzz_tests);
    fuzz_step.dependOn(&run_fuzz_tests.step);

    // Parser edge-case regression tests (Q33: IPv4 leading-zero, IPv6 ::
    // duplication, URL userinfo, Subnet prefix boundaries).
    const parser_edges_step = b.step("test-parser-edges", "Run parser edge-case regression tests");
    const parser_edges_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/parser_edge_cases.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_parser_edges_tests = b.addRunArtifact(parser_edges_tests);
    parser_edges_step.dependOn(&run_parser_edges_tests.step);

    // Performance tests (dataset-level workflows and bulk operations)
    const performance_step = b.step("test-performance", "Run performance tests");
    const performance_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/performance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_performance_tests = b.addRunArtifact(performance_tests);
    performance_step.dependOn(&run_performance_tests.step);

    // Example build step (validates examples compile against the library)
    const example_step = b.step("example", "Build and run the basic example");
    const example = b.addExecutable(.{
        .name = "basic-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_example = b.addRunArtifact(example);
    example_step.dependOn(&run_example.step);

    // Benchmark harness (I1). Not a test -- this is an executable that
    // prints ns/op timings. CI runs it to verify the harness compiles and
    // exits 0; numeric thresholds are explicitly NOT gated on.
    const bench_step = b.step("bench", "Run micro-benchmarks");
    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "advanced_types", .module = module },
            },
        }),
    });
    const run_bench = b.addRunArtifact(bench_exe);
    bench_step.dependOn(&run_bench.step);

    // Check step for IDE integration (fast syntax validation)
    const check_step = b.step("check", "Check for compilation errors");
    // No .filters here: check is compile-only (no addRunArtifact), so test
    // filters would be silently ignored anyway.
    const check = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    check_step.dependOn(&check.step);
}

/// ATX-04: verify that the `version` constant in src/root.zig matches the
/// `.version` field in build.zig.zon. Panics with a drift message on
/// mismatch so the build cannot proceed with inconsistent versions.
fn checkVersionSync(b: *std.Build) !void {
    const io = b.graph.io;
    const cwd = std.Io.Dir.cwd();
    const zon = try cwd.readFileAlloc(io, b.pathFromRoot("build.zig.zon"), b.allocator, .limited(1 << 16));
    const root = try cwd.readFileAlloc(io, b.pathFromRoot("src/root.zig"), b.allocator, .limited(1 << 20));
    const zon_ver = extractBetween(zon, ".version = \"", "\"") orelse return error.ZonVersionNotFound;
    const root_ver = extractBetween(root, "pub const version = \"", "\"") orelse return error.RootVersionNotFound;
    if (!std.mem.eql(u8, zon_ver, root_ver)) {
        std.debug.panic("version drift: build.zig.zon has \"{s}\" but src/root.zig has \"{s}\"", .{ zon_ver, root_ver });
    }
}

/// Return the slice of `haystack` between the first occurrence of `prefix`
/// and the next occurrence of `suffix`, or null if either is absent.
/// Limitation: matches the FIRST occurrence, so a commented-out
/// `pub const version = "..."` line above the real declaration would be
/// picked up instead — keep the version declarations unique in both files.
fn extractBetween(haystack: []const u8, prefix: []const u8, suffix: []const u8) ?[]const u8 {
    const start = (std.mem.indexOf(u8, haystack, prefix) orelse return null) + prefix.len;
    const end = std.mem.indexOfPos(u8, haystack, start, suffix) orelse return null;
    return haystack[start..end];
}
