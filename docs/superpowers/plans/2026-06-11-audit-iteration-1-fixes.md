# Audit Iteration-1 Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every actionable finding from the 2026-06-11 appsec review (ATX-01..08) and codepros audit (quality N1–N5, fix-now ledger Q27/Q29/Q34/Q35/Q37/Q41, perf P1–P6, doc-drift items) in the `advanced-types` Zig library.

**Architecture:** Pure Zig 0.16 zero-alloc value-type library (`src/types/*`), Python CI helpers, GitLab CI. Fixes are independent small changes: parser error alignment, API forwarding, bench harness de-hoisting + re-baseline, CI release/job hardening, and documentation/ledger sync. No new dependencies. TDD where behavior changes; doc/CI tasks verified by running the relevant tool.

**Tech Stack:** Zig 0.16.0 (`zig build test`, `zig fmt`), Python 3 (`ruff`), GitLab CI YAML, pre-commit, markdownlint-cli2.

**Canonical commands:**

- All Zig tests: `zig build test test-integration test-extensions test-fuzz test-parser-edges test-performance --summary all` (currently 318/318 pass)
- Format check: `zig fmt --check src/ tests/ examples/ build.zig`
- Bench: `zig build bench -Doptimize=ReleaseFast` then `python3 ci/bench_gate.py`
- Pre-commit: `pre-commit run --all-files`

**Commit convention:** conventional commits (commitizen enforced), e.g. `fix(subnet): ...`, `feat(ip): ...`, `perf(bench): ...`, `docs: ...`, `ci: ...`. End every commit message with the trailer:
`Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

## Task 1: Version constant sync + build-time guard (ATX-04 / VER-01)

**Files:**

- Modify: `src/root.zig:34`
- Modify: `tests/integration.zig:16-18`
- Modify: `build.zig` (top of `pub fn build`)

- [ ] **Step 1: Update the integration test to expect the real version (failing test first)**

In `tests/integration.zig`, change:

```zig
test "integration: version is defined" {
    try std.testing.expectEqualStrings("0.1.0", lib.version);
}
```

to:

```zig
test "integration: version is defined" {
    try std.testing.expectEqualStrings("0.1.2", lib.version);
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `zig build test-integration --summary all`
Expected: FAIL — expected "0.1.2", found "0.1.0".

- [ ] **Step 3: Fix the constant**

In `src/root.zig:34`, change `pub const version = "0.1.0";` to `pub const version = "0.1.2";`

- [ ] **Step 4: Add a build-time guard so this can never drift again**

In `build.zig`, at the very top of `pub fn build(b: *std.Build) void {` (after any existing option declarations), add:

```zig
    // ATX-04 guard: fail the build if src/root.zig's `version` constant
    // drifts from build.zig.zon's `.version`.
    checkVersionSync(b) catch |err| std.debug.panic("version sync check failed: {}", .{err});
```

and at file scope (bottom of build.zig):

```zig
fn checkVersionSync(b: *std.Build) !void {
    const zon = try std.fs.cwd().readFileAlloc(b.allocator, b.pathFromRoot("build.zig.zon"), 1 << 16);
    const root = try std.fs.cwd().readFileAlloc(b.allocator, b.pathFromRoot("src/root.zig"), 1 << 20);
    const zon_ver = extractBetween(zon, ".version = \"", "\"") orelse return error.ZonVersionNotFound;
    const root_ver = extractBetween(root, "pub const version = \"", "\"") orelse return error.RootVersionNotFound;
    if (!std.mem.eql(u8, zon_ver, root_ver)) {
        std.debug.panic("version drift: build.zig.zon has \"{s}\" but src/root.zig has \"{s}\"", .{ zon_ver, root_ver });
    }
}

fn extractBetween(haystack: []const u8, prefix: []const u8, suffix: []const u8) ?[]const u8 {
    const start = (std.mem.indexOf(u8, haystack, prefix) orelse return null) + prefix.len;
    const end = std.mem.indexOfPos(u8, haystack, start, suffix) orelse return null;
    return haystack[start..end];
}
```

Note: if `readFileAlloc` has a different signature in Zig 0.16 (it takes `(allocator, path, max_bytes)` on `std.fs.Dir`), adapt to the actual stdlib API — the intent is: read both files, extract the two version strings, panic on mismatch.

- [ ] **Step 5: Verify the guard works both ways**

Run: `zig build test-integration --summary all` → Expected: PASS (1/1... all 9 pass).
Then temporarily set root.zig version to `"9.9.9"`, run `zig build check`, expect a panic with the drift message. Revert to `"0.1.2"`, re-run `zig build check` → clean.

- [ ] **Step 6: Commit**

```bash
git add src/root.zig tests/integration.zig build.zig
git commit -m "fix(version): sync root.zig version to 0.1.2 and add build-time drift guard (ATX-04)"
```

---

## Task 2: Align Subnet.parse prefix error with Subnet.init (N1)

**Files:**

- Modify: `src/types/network/subnet.zig:70,78` and its tests around `:179-180`

- [ ] **Step 1: Update tests to expect `error.InvalidPrefix` (failing first)**

In `src/types/network/subnet.zig`, find the test(s) asserting `error.Overflow` for out-of-range prefixes (around lines 179-180, e.g. `Subnet.parse("192.168.1.0/33")` and any `/129` or `/999` case) and change the expected error to `error.InvalidPrefix`.

- [ ] **Step 2: Run to verify failure**

Run: `zig build test --summary all`
Expected: FAIL on the changed subnet tests (still returning `error.Overflow`).

- [ ] **Step 3: Change the two parse-path returns**

In `Subnet.parse`:

- Line ~70: `if (prefix_len > 128) return error.Overflow;` → `if (prefix_len > 128) return error.InvalidPrefix;`
- Line ~78: `if (prefix_len > max_prefix) return error.Overflow;` → `if (prefix_len > max_prefix) return error.InvalidPrefix;`

`error.InvalidPrefix` is already in `common.ParseError` (used by `Subnet.init`), so the error set is unchanged.

- [ ] **Step 4: Run full unit suite**

Run: `zig build test --summary all` → Expected: 263/263 PASS.
Also run: `zig build test-parser-edges --summary all` — if any edge-case test asserted `Overflow` for subnet prefixes, update it to `InvalidPrefix` and re-run.

- [ ] **Step 5: Commit**

```bash
git add src/types/network/subnet.zig tests/
git commit -m "fix(subnet): return InvalidPrefix from parse for out-of-range prefix, matching init (N1)"
```

---

## Task 3: Forward classification predicates through IpAddr (N2) + parse doc (N5)

**Files:**

- Modify: `src/types/network/ip.zig`

- [ ] **Step 1: Write failing tests**

Append to the Tests section of `src/types/network/ip.zig`:

```zig
test "IpAddr forwards classification predicates (N2)" {
    const lo4 = try IpAddr.parse("127.0.0.1");
    const lo6 = try IpAddr.parse("::1");
    try testing.expect(lo4.isLoopback());
    try testing.expect(lo6.isLoopback());
    try testing.expect(!lo4.isSafeForOutboundFetch());
    try testing.expect(!lo6.isSafeForOutboundFetch());

    const mc4 = try IpAddr.parse("224.0.0.1");
    const mc6 = try IpAddr.parse("ff02::1");
    try testing.expect(mc4.isMulticast());
    try testing.expect(mc6.isMulticast());

    const pub4 = try IpAddr.parse("93.184.216.34");
    try testing.expect(pub4.isSafeForOutboundFetch());
    try testing.expect(!pub4.isLoopback());
    try testing.expect(!pub4.isMulticast());

    // SSRF smuggling guard must survive union dispatch:
    const mapped = try IpAddr.parse("::ffff:169.254.169.254");
    try testing.expect(!mapped.isSafeForOutboundFetch());
}
```

- [ ] **Step 2: Run to verify failure**

Run: `zig build test --summary all`
Expected: compile error — `isLoopback` not a member of `IpAddr`.

- [ ] **Step 3: Implement the forwarders**

Inside the `IpAddr` union (after `eql`), add:

```zig
    /// Returns true if this is a loopback address (127.0.0.0/8 or ::1).
    pub fn isLoopback(self: Self) bool {
        return switch (self) {
            .v4 => |v4| v4.isLoopback(),
            .v6 => |v6| v6.isLoopback(),
        };
    }

    /// Returns true if this is a multicast address (224.0.0.0/4 or ff00::/8).
    pub fn isMulticast(self: Self) bool {
        return switch (self) {
            .v4 => |v4| v4.isMulticast(),
            .v6 => |v6| v6.isMulticast(),
        };
    }

    /// SSRF-safety gate: returns true only if dialing this address cannot
    /// reach loopback, link-local (incl. cloud metadata), private/CGNAT,
    /// multicast, or otherwise internal ranges. Delegates to the family-
    /// specific predicate (the IPv6 path re-checks IPv4-mapped addresses).
    /// This is NOT a routability check; see the family methods for details.
    pub fn isSafeForOutboundFetch(self: Self) bool {
        return switch (self) {
            .v4 => |v4| v4.isSafeForOutboundFetch(),
            .v6 => |v6| v6.isSafeForOutboundFetch(),
        };
    }
```

- [ ] **Step 4: Extend the parse doc comment (N5)**

Replace the doc comment on `IpAddr.parse` with:

```zig
    /// Parse an IP address, auto-detecting IPv4 vs IPv6 by the presence of
    /// colons: any input containing `:` is routed to the IPv6 parser,
    /// everything else to the IPv4 parser. Consequence: a malformed input
    /// containing a colon fails with IPv6-parser errors, never IPv4 ones.
```

- [ ] **Step 5: Run tests**

Run: `zig build test --summary all` → Expected: 264/264 PASS (new test adds 1).

- [ ] **Step 6: Commit**

```bash
git add src/types/network/ip.zig
git commit -m "feat(ip): forward isLoopback/isMulticast/isSafeForOutboundFetch through IpAddr (N2, N5)"
```

---

## Task 4: Mac.format single-writeAll rewrite (P4)

**Files:**

- Modify: `src/types/network/mac.zig:58-64`

- [ ] **Step 1: Confirm existing format tests cover output** — grep `mac.zig` tests for `bufPrint`/format expectations (e.g. `"AA:BB:CC:DD:EE:FF"`). They exist; no new test needed (pure refactor with identical output).

- [ ] **Step 2: Replace the per-byte print loop**

```zig
    /// Write this address in uppercase colon-separated hex notation to the given writer.
    pub fn format(self: Self, writer: anytype) !void {
        const hex = "0123456789ABCDEF";
        var buf: [17]u8 = undefined;
        inline for (0..6) |i| {
            if (i > 0) buf[i * 3 - 1] = ':';
            buf[i * 3] = hex[self.octets[i] >> 4];
            buf[i * 3 + 1] = hex[self.octets[i] & 0x0F];
        }
        try writer.writeAll(&buf);
    }
```

- [ ] **Step 3: Run tests**

Run: `zig build test --summary all` → Expected: all PASS (format output byte-identical).

- [ ] **Step 4: Commit**

```bash
git add src/types/network/mac.zig
git commit -m "perf(mac): format via single writeAll instead of 6 std.fmt dispatches (P4)"
```

---

## Task 5: De-hoist tainted benchmarks (P1)

**Files:**

- Modify: `bench/main.zig` — `roundCosineDistance` (:190), `roundHaversine` (:203), `roundSubnetContains` (:261), `roundHaversineBroadcast` (:304)

The pattern: constant inputs let LLVM hoist the computation out of the timed loop. Fix by making input memory opaque (`var` array + `std.mem.doNotOptimizeAway(&array)` before the timed loop) and cycling inputs by `i` where the loop currently uses a single constant pair.

- [ ] **Step 1: Capture "before" numbers**

Run: `zig build bench -Doptimize=ReleaseFast` once; note `Subnet.contains` (~0.33 ns/op) and `VectorF32.cosineDistance` (~0.7 ns/op) as the tainted evidence.

- [ ] **Step 2: Rewrite `roundCosineDistance`**

```zig
fn roundCosineDistance() !u64 {
    var pairs = [_][2]lib.VectorF32{
        .{ lib.VectorF32.init(.{ 1.0, 0.0, 0.0 }), lib.VectorF32.init(.{ 0.9, 0.1, 0.02 }) },
        .{ lib.VectorF32.init(.{ 0.5, 0.5, 0.5 }), lib.VectorF32.init(.{ -0.5, 0.5, 0.25 }) },
        .{ lib.VectorF32.init(.{ 3.0, -2.0, 1.0 }), lib.VectorF32.init(.{ 1.0, 1.0, 1.0 }) },
        .{ lib.VectorF32.init(.{ 0.1, 0.2, 0.3 }), lib.VectorF32.init(.{ 0.3, 0.2, 0.1 }) },
    };
    std.mem.doNotOptimizeAway(&pairs);
    const t0 = nowNs();
    var sink: f32 = 0.0;
    for (0..iterations_per_round) |i| {
        const p = pairs[i % pairs.len];
        sink += p[0].cosineDistance(p[1]);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}
```

- [ ] **Step 3: Rewrite `roundSubnetContains`** — change `const addrs` to `var addrs`, and add `std.mem.doNotOptimizeAway(&addrs);` plus `var net = try lib.Subnet.parse("192.168.1.0/24"); std.mem.doNotOptimizeAway(&net);` before `const t0 = nowNs();` (loop body unchanged, using `net.contains(...)`).

- [ ] **Step 4: Rewrite `roundHaversine`** — cycle destinations like the broadcast bench:

```zig
fn roundHaversine() !u64 {
    const sf = try lib.LatLon.init(37.7749, -122.4194);
    var dests = [_]lib.LatLon{
        try lib.LatLon.init(40.7128, -74.0060),
        try lib.LatLon.init(51.5074, -0.1278),
        try lib.LatLon.init(-33.8688, 151.2093),
        try lib.LatLon.init(35.6762, 139.6503),
    };
    std.mem.doNotOptimizeAway(&dests);
    const t0 = nowNs();
    var sink: f64 = 0.0;
    for (0..iterations_per_round) |i| {
        sink += sf.haversineDistance(dests[i % dests.len]);
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}
```

- [ ] **Step 5: Harden `roundHaversineBroadcast`** — change `const dests` to `var dests` and add `std.mem.doNotOptimizeAway(&dests);` before `const t0`.

- [ ] **Step 6: Verify de-hoisting empirically**

Run: `zig build bench -Doptimize=ReleaseFast`
Expected: `Subnet.contains` rises from ~0.33 to ≥1 ns/op; `VectorF32.cosineDistance` rises from ~0.7 to ≥2 ns/op; haversine values stay in the same order of magnitude (4–6 ns). If `Subnet.contains` still reads <0.5 ns/op the fold is still happening — additionally route the per-iteration input through `std.mem.doNotOptimizeAway(&addrs[i % addrs.len])` inside the loop and re-verify.

NOTE: `roundHaversine` semantics changed (4 rotating destinations vs 1 fixed) — the absolute number will shift; that is expected and gets re-baselined in Task 7.

- [ ] **Step 7: Commit**

```bash
git add bench/main.zig
git commit -m "perf(bench): de-hoist constant-input benchmark loops (P1)"
```

---

## Task 6: Add LatLonAlt.parse and GeoPoint.parse benchmarks (P5)

**Files:**

- Modify: `bench/main.zig` (new round functions + registration in `main()`)

- [ ] **Step 1: Add the two round functions** (after `roundHaversineBroadcast`):

```zig
fn roundLatLonAltParse() !u64 {
    var inputs = [_][]const u8{
        "(37.7749, -122.4194, 16.0)",
        "(40.7128, -74.0060, 10.5)",
        "(-33.8688, 151.2093, 58.0)",
        "(35.6762, 139.6503, 40.0)",
        "(0.0, 0.0, 0.0)",
    };
    std.mem.doNotOptimizeAway(&inputs);
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations_per_round) |i| {
        const p = try lib.LatLonAlt.parse(inputs[i % inputs.len]);
        sink ^= @as(usize, @intFromFloat(@abs(p.point.lat))) +% @as(usize, @intFromFloat(@abs(p.alt_m)));
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}

fn roundGeoPointParse() !u64 {
    var inputs = [_][]const u8{
        "(37.7749, -122.4194)",
        "(40.7128, -74.0060, 10.5)",
        "(-33.8688, 151.2093)",
        "(35.6762, 139.6503, 40.0)",
        "(51.5074, -0.1278)",
    };
    std.mem.doNotOptimizeAway(&inputs);
    const t0 = nowNs();
    var sink: usize = 0;
    for (0..iterations_per_round) |i| {
        const p = try lib.GeoPoint.parse(inputs[i % inputs.len]);
        sink ^= switch (p) {
            .lat_lon => |ll| @as(usize, @intFromFloat(@abs(ll.lat))),
            .lat_lon_alt => |lla| @as(usize, @intFromFloat(@abs(lla.alt_m))),
        };
    }
    const elapsed = nowNs() - t0;
    std.mem.doNotOptimizeAway(sink);
    return elapsed;
}
```

NOTE (implementation): the real field names are `p.alt`/`p.lat` (no `point`/`alt_m` fields); the committed bench uses those.

IMPORTANT: before writing, read `src/types/geographic.zig` for the actual `LatLonAlt`/`GeoPoint` field names, parse input syntax (paren-tuple format), and union tag names — adjust the sink expressions and input literals to the real API (the test blocks in geographic.zig show valid parse inputs). The bench must parse successfully every iteration (`try` would otherwise error the round).

- [ ] **Step 2: Register both in `main()`** — find the list/array of benchmark registrations (name + function pointer, around `bench/main.zig:329+`) and append entries `"LatLonAlt.parse"` → `roundLatLonAltParse` and `"GeoPoint.parse"` → `roundGeoPointParse`, matching the existing registration style exactly.

- [ ] **Step 3: Run**

`zig build bench -Doptimize=ReleaseFast` → Expected: 12 benchmarks listed, two new entries flagged `NEW` by `python3 ci/bench_gate.py` (not a failure).

- [ ] **Step 4: Commit**

```bash
git add bench/main.zig
git commit -m "perf(bench): add LatLonAlt.parse and GeoPoint.parse coverage (P5)"
```

---

## Task 7: Re-baseline all benchmarks + fix baseline metadata (P2, P3)

**Files:**

- Modify: `bench/baseline.json`

Depends on Tasks 5 and 6 being complete.

- [ ] **Step 1: Capture 3 fresh runs**

Run `zig build bench -Doptimize=ReleaseFast` three times; from each run's `BENCH_JSON_BEGIN`/`END` block collect per-benchmark min-of-N ns/op.

- [ ] **Step 2: Rewrite baseline.json** — for each of the 12 benchmarks take the **median of the three min-of-N values** and write:

```json
{
  "_comment": "BENCH-02 (#58) regression-gate baseline. Each value is the median across three fresh ReleaseFast runs of the per-run min-of-N ns/op taken from the BENCH_JSON payload (the same metric ci/bench_gate.py compares). Re-baselined 2026-06-11 after de-hoisting the Subnet.contains/cosineDistance/haversine loops (P1) — pre-2026-06-11 values were partially hoisting-tainted and uniformly stale. Tolerance stays 30% because intra-run jitter on shared hardware measured 11-17%. Re-baseline with `zig build bench -Doptimize=ReleaseFast` (3 runs, median of min-of-N) on the same host and update these values.",
  "tolerance": 1.30,
  "units": "ns/op (min-of-N, N=9 rounds of 100000 iterations each)",
  "benchmarks": { "...": "fill all 12 from Step 1" }
}
```

- [ ] **Step 3: Verify gate passes**

Run: `zig build bench -Doptimize=ReleaseFast && python3 ci/bench_gate.py`
Expected: exit 0, all 12 entries within tolerance, no NEW entries.

- [ ] **Step 4: Commit**

```bash
git add bench/baseline.json
git commit -m "perf(bench): re-baseline all 12 benchmarks post de-hoist; fix metric description (P2, P3)"
```

---

## Task 8: Add Range fuzz target (ATX-06)

**Files:**

- Modify: `tests/fuzz.zig`

- [ ] **Step 1: Add the target** (new section after the Vector parser section):

```zig
// ============================================================================
// Range parser
// ============================================================================

test "fuzz IntRange.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.IntRange), .{});
}

test "fuzz FloatRange.parse" {
    try std.testing.fuzz({}, parserFuzzer(types.FloatRange), .{});
}
```

(Verify `types.IntRange` / `types.FloatRange` are exported from `src/root.zig` — they are per the re-export hub; if names differ, use the actual aliases.)

- [ ] **Step 2: Run**

`zig build test-fuzz --summary all` → Expected: 12/12 PASS (was 10).

- [ ] **Step 3: Update the stale doc comment** at the top of `tests/fuzz.zig` (line ~17 says "the 10 per-parser fuzz wrappers") → change "10" to "12".

- [ ] **Step 4: Commit**

```bash
git add tests/fuzz.zig
git commit -m "test(fuzz): add IntRange/FloatRange parse fuzz targets (ATX-06)"
```

---

## Task 9: Harden release-sign-tag job (ATX-03)

**Files:**

- Modify: `.gitlab-ci.yml` (release-sign-tag job, around line 475-489)

- [ ] **Step 1: Replace the job script** with a fail-closed version that (a) exits early if already signed, (b) asserts the existing tag points at `$CI_COMMIT_SHA` before re-tagging, (c) asserts the GPG fingerprint is non-empty, (d) keeps the same-commit force-replace as the ONLY permitted mutation:

```yaml
release-sign-tag:
  stage: release
  image: debian:bookworm-slim
  rules:
    - if: '$CI_COMMIT_TAG && $RELEASE_GPG_PRIVATE_KEY'
  before_script:
    - apt-get update && apt-get install -y gnupg git
  script:
    - set -euo pipefail
    # ATX-03: fail closed — never sign with an unset key, never move a tag
    # to a different commit. The only permitted mutation is replacing an
    # UNSIGNED tag with a SIGNED tag pointing at the SAME commit.
    - test -n "${RELEASE_GPG_FINGERPRINT:-}" || { echo "RELEASE_GPG_FINGERPRINT is unset; refusing to sign"; exit 1; }
    - echo "$RELEASE_GPG_PRIVATE_KEY" | gpg --batch --import
    - gpg --list-secret-keys --keyid-format=long
    - git config --global user.signingkey "$RELEASE_GPG_FINGERPRINT"
    - git config --global tag.gpgSign true
    - |
      if git tag -v "$CI_COMMIT_TAG" >/dev/null 2>&1; then
        echo "Tag $CI_COMMIT_TAG is already signed; nothing to do."
        exit 0
      fi
    - |
      TAG_COMMIT="$(git rev-parse "refs/tags/${CI_COMMIT_TAG}^{commit}")"
      if [ "$TAG_COMMIT" != "$CI_COMMIT_SHA" ]; then
        echo "Refusing to re-tag: ${CI_COMMIT_TAG} points at ${TAG_COMMIT}, pipeline is for ${CI_COMMIT_SHA}"
        exit 1
      fi
    - git tag -s -f "$CI_COMMIT_TAG" -m "Signed release $CI_COMMIT_TAG" "$CI_COMMIT_SHA"
    - git push "https://oauth2:${CI_JOB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git" "refs/tags/${CI_COMMIT_TAG}:refs/tags/${CI_COMMIT_TAG}" --force
  needs:
    - build
```

Preserve the explanatory comment block above the job; extend it with one line noting the same-commit assertion.

- [ ] **Step 2: Validate YAML**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.gitlab-ci.yml')); print('YAML OK')"`
Expected: `YAML OK`. (If PyYAML is missing, use `glab ci lint` instead.)

- [ ] **Step 3: Also remove the redundant python3 install in the bench job (P6)** — find the `bench` job (~line 216); its `before_script`/`script` has `apt-get install -y python3` after `*install-zig` (which already installs python3). Delete the redundant line. Re-validate YAML.

- [ ] **Step 4: Commit**

```bash
git add .gitlab-ci.yml
git commit -m "ci(release): fail-closed tag signing with same-commit assertion (ATX-03); drop duplicate python3 install (P6)"
```

---

## Task 10: Committed Zig toolchain SHA-256 lock (ATX-02)

**Files:**

- Create: `ci/zig-sha256.lock`
- Modify: `.gitlab-ci.yml` (the `.install-zig` Linux anchor ~lines 40-80; macOS block ~273-285; Windows block ~324-330)

- [ ] **Step 1: Fetch the official shasums for Zig 0.16.0**

Run: `curl -fsSL https://ziglang.org/download/index.json | python3 -c "import json,sys; d=json.load(sys.stdin)['0.16.0']; [print(d[k]['shasum'], d[k]['tarball'].rsplit('/',1)[-1]) for k in ('x86_64-linux','aarch64-linux','aarch64-macos','x86_64-macos','x86_64-windows') if k in d]"`

(If the index uses `zig-<arch>-<os>` key naming, list the keys first and adapt. Capture shasum + tarball filename for: linux x86_64, linux aarch64, macos aarch64, macos x86_64, windows x86_64.)

- [ ] **Step 2: Write `ci/zig-sha256.lock`** in `sha256sum -c` format, one line per artifact:

```text
<sha256>  zig-x86_64-linux-0.16.0.tar.xz
<sha256>  zig-aarch64-linux-0.16.0.tar.xz
<sha256>  zig-aarch64-macos-0.16.0.tar.xz
<sha256>  zig-x86_64-macos-0.16.0.tar.xz
<sha256>  zig-x86_64-windows-0.16.0.zip
```

with a leading `# ATX-02: out-of-band Zig toolchain hashes...` comment line (sha256sum ignores `#` lines via `--ignore-missing`? No — keep the comment OUT of the file if it breaks `sha256sum -c`; test locally with a dummy file. If comments break it, put provenance in a sibling `ci/zig-sha256.lock.md` note or in the CI comment block).

- [ ] **Step 3: Wire the Linux install path to verify against the lock**

In the `.install-zig` anchor, after the tarball download and existing index-hash verification, add a second check against the committed lock:

```sh
      # ATX-02: verify against the committed lock (out-of-band anchor),
      # not only the live index fetched from the same origin.
      grep " ${TARBALL}$" ci/zig-sha256.lock | sha256sum -c - || { echo "Zig tarball failed committed-hash verification"; exit 1; }
```

Place it where `$TARBALL` is downloaded and the filename variable is in scope (the existing SEC-R6-02 verification block); keep the existing live-index check too (belt and braces).

- [ ] **Step 4: Wire macOS** — same `grep | shasum -a 256 -c -` pattern (macOS uses `shasum -a 256`); read the existing macOS block first and mirror its conventions.

- [ ] **Step 5: Wire Windows (PowerShell)** — read the existing Windows block; add:

```powershell
$lock = (Select-String -Path ci/zig-sha256.lock -Pattern ([regex]::Escape($archiveName) + '$')).Line.Split(' ')[0]
$actual = (Get-FileHash $tarball -Algorithm SHA256).Hash.ToLower()
if ($lock -ne $actual) { Write-Error "Zig archive failed committed-hash verification"; exit 1 }
```

adapted to the block's actual variable names.

- [ ] **Step 6: Validate**

`python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml')); print('YAML OK')"` → `YAML OK`.
Locally simulate the Linux check: download nothing — instead create a temp file matching a lock line? Skip simulation if impractical; the YAML-level review + lock-file correctness (hashes match the live index output from Step 1) is the acceptance bar.

- [ ] **Step 7: Commit**

```bash
git add ci/zig-sha256.lock .gitlab-ci.yml
git commit -m "ci(security): verify Zig toolchain against committed SHA-256 lock (ATX-02)"
```

---

## Task 11: Python helper hardening + ruff format (ATX-07)

**Files:**

- Modify: `scripts/detect_diamond_deps.py:167-180`
- Modify: `ci/bench_gate.py` (format only)

- [ ] **Step 1: Add hash-charset validation**

In `scripts/detect_diamond_deps.py`, add near the other module-level regexes:

```python
# ATX-07: Zig package hashes are constrained to this charset; anything else
# (path separators, "..") must never reach filesystem path construction.
SAFE_HASH_RE = re.compile(r"^[A-Za-z0-9._-]+$")
```

and at the top of `_zon_path_for_hash`:

```python
    if not SAFE_HASH_RE.fullmatch(pkg_hash) or ".." in pkg_hash:
        return None
```

- [ ] **Step 2: Run ruff format + check on both files**

Run: `pre-commit run ruff-format --files ci/bench_gate.py scripts/detect_diamond_deps.py` then `pre-commit run ruff --files ci/bench_gate.py scripts/detect_diamond_deps.py` (hook ids per `.pre-commit-config.yaml`; if different, use the actual ids). This also resolves the pre-existing ruff-format failures on both files.
Expected: files reformatted, then both hooks PASS on re-run.

- [ ] **Step 3: Smoke-run the script**

Run: `python3 scripts/detect_diamond_deps.py` → Expected: exit 0 (zero deps, nothing to do).
Run: `python3 ci/bench_gate.py --help 2>/dev/null || python3 -c "import ast; ast.parse(open('ci/bench_gate.py').read()); print('OK')"` → syntactically valid.

- [ ] **Step 4: Commit**

```bash
git add scripts/detect_diamond_deps.py ci/bench_gate.py
git commit -m "fix(scripts): validate package-hash charset before path use (ATX-07); apply ruff-format"
```

---

## Task 12: Doc-comment batch — Q27, Q29, Q37, Q41, N3, ATX-08

**Files:**

- Modify: `src/types/vector.zig`, `src/types/range.zig`, `src/types/url.zig`, `src/types/geographic.zig`, `src/types/network/ipv4.zig`, `src/types/network/ipv6.zig`

All doc-comment-only; no behavior change. After each file, `zig build check` must stay green (doc comments on wrong decls are compile errors in Zig when malformed).

- [ ] **Step 1 (Q27):** `src/types/vector.zig:147` `magnitudeSquared` — append to its doc comment: `/// Integer overflow is safety-checked in Debug/ReleaseSafe (panics) and wraps in ReleaseFast/Small.` Grep vector.zig for other arithmetic pub fns (`mul`, `divide`, `scale`, `dot`, `magnitude`, `distance*`) and add the same line wherever an integer-overflow path exists and the line is missing. `Range.span` already documents this — verify, don't duplicate.

- [ ] **Step 2 (Q29):** `src/types/vector.zig` — on `at`, append: `/// Prefer`get`when the index is not statically known to be in bounds.` On `get`, append: `/// The non-asserting counterpart of`at`.`

- [ ] **Step 3 (Q37):** Add doc comments to every public decl currently missing one:
  - `src/types/url.zig` `DomainLabelIterator` struct fields/methods — `next` has a doc; add one to the struct itself if missing (`/// Iterator over the dot-separated labels of a Domain, left to right.`).
  - `*Unchecked` constructors in `range.zig` (has one — verify), `geographic.zig:116,253` (add: `/// Create without validating ranges/NaN. Caller asserts validity; prefer`init`.`), and any in `url.zig`.
  - Verify with: `grep -B1 'pub fn initUnchecked\|pub const DomainLabelIterator\|pub fn next' src/types/*.zig src/types/network/*.zig` — every hit must show a `///` line above.

- [ ] **Step 4 (Q41):** Why-comments at non-obvious sites:
  - `src/types/range.zig:181-184` (adjacent boundary guard) — above the `a_adj` line add: `// Checking upper < maxInt before +1 (not catching overflow) keeps adjacent() branchless-cheap and avoids @addWithOverflow; at the type boundary nothing can be adjacent-above anyway.`
  - `src/types/network/ipv6.zig` IPv4-mapped re-check in `isSafeForOutboundFetch` (~:255) — add: `// Re-check mapped addresses as IPv4 so ::ffff:169.254.169.254-style smuggling cannot bypass the v4 blocklist.` (if an equivalent comment is absent).

- [ ] **Step 5 (N3):** `src/types/url.zig:140-147` `effectivePort` doc — replace with:

```zig
    /// Return the effective port: the explicit port if present, otherwise the
    /// default port for the scheme (80 for http, 443 for https).
    /// Returns 0 for schemes with no known default. Caution: 0 is also a
    /// legal explicit port (`host:0` parses), so a 0 result is ambiguous —
    /// check `self.port != null` to distinguish "explicit 0" from "no default".
```

- [ ] **Step 6 (ATX-08):** `src/types/network/ipv4.zig:136` `isSafeForOutboundFetch` doc — append:

```zig
    /// This is an SSRF-safety gate (internal-range rejection), NOT a
    /// routability check: non-routable special-use ranges that cannot reach
    /// internal services (TEST-NET-1/2/3 192.0.2/24, 198.51.100/24,
    /// 203.0.113/24; benchmarking 198.18/15) are deliberately NOT rejected.
```

Mirror a one-line version on the ipv6 variant (`ipv6.zig:248`).

- [ ] **Step 7: Verify**

Run: `zig build check && zig fmt --check src/ tests/ examples/ build.zig && zig build test --summary all`
Expected: all green, test count unchanged.

- [ ] **Step 8: Commit**

```bash
git add src/
git commit -m "docs(api): overflow-mode, at/get, Unchecked, effectivePort-sentinel, SSRF-gate-intent doc comments (Q27,Q29,Q37,Q41,N3,ATX-08)"
```

---

## Task 13: Q34 test-filter build option + Q35 Range.span wrap test

**Files:**

- Modify: `build.zig`
- Modify: `src/types/range.zig` (new test)

- [ ] **Step 1 (Q35): Write the wrap test** — append to range.zig tests:

```zig
test "Range.span wraps at integer boundary in ReleaseFast/Small (Q35, SAST-OVERFLOW-01)" {
    const builtin = @import("builtin");
    // span() = upper - lower; safety-checked modes panic on overflow, which
    // a test cannot catch — only assert the documented wrap in unsafe modes.
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) return error.SkipZigTest;
    const r = IntRange.initUnchecked(std.math.minInt(i64), std.math.maxInt(i64));
    const wrapped = r.span(); // maxInt - minInt wraps to -1 in two's complement
    try testing.expectEqual(@as(i64, -1), wrapped);
}
```

Adapt names to the file's actual test-scope imports (`IntRange` may need `Range(i64)`; `testing` alias per file convention). If `initUnchecked` ordering rejects nothing, this constructs fine; `init` would also work since min<max.

- [ ] **Step 2: Run in both mode classes**

`zig build test --summary all` → the new test reports SKIP (Debug).
`zig build test -Doptimize=ReleaseFast --summary all` → new test PASS.

- [ ] **Step 3 (Q34): Add the filter option to build.zig**

In `build.zig`, add near the top of `build()`:

```zig
    const test_filters = b.option([]const []const u8, "test-filter", "Only run tests whose names contain this string (repeatable)") orelse &.{};
```

and on every `b.addTest(...)` call site add `.filters = test_filters,` to the options struct (Zig 0.16 `addTest` accepts `.filters`).

- [ ] **Step 4: Verify the filter works**

Run: `zig build test -Dtest-filter="span wraps" --summary all`
Expected: only the matching test runs (1 skipped/passed, others filtered out).
Run: `zig build test --summary all` → full 264+ suite still runs when no filter given.

- [ ] **Step 5: Commit**

```bash
git add build.zig src/types/range.zig
git commit -m "test(range): assert documented span wrap in unsafe modes (Q35); add -Dtest-filter option (Q34)"
```

---

## Task 14: Markdown + README/CHANGELOG/SECURITY.md fixes (MD-01, CNT-01, VER-02, ATX-05, N4)

**Files:**

- Modify: `README.md`, `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `.gitlab/issue_templates/Bug Report.md`, `docs/APPSEC_REVIEW_2026-06-11.md`

- [ ] **Step 1: Get the authoritative test count** — run the full suite and sum:

`zig build test test-integration test-extensions test-fuzz test-parser-edges test-performance --summary all`

Count after all prior tasks land (expect 263+1 IpAddr +1 span = 265 unit… read the actual summary output; fuzz is now 12). Compute total = sum of all six suites. Use THIS number everywhere below (call it `<TOTAL>`).

- [ ] **Step 2: README.md** —
  - Line 14: `**304 Tests**` → `**<TOTAL> Tests**`
  - Line 25: tarball URL `v0.1.0/advanced-types-v0.1.0.tar.gz` → `v0.1.2/advanced-types-v0.1.2.tar.gz`
  - Add an `## API Overview` section after Installation: a table per module listing the public types and their key methods/contracts, explicitly including `isSafeForOutboundFetch` (v4/v6/IpAddr, SSRF-gate note), `IpAddr` predicates (new), `effectivePort` 0-sentinel, `Vector.at` (asserting) vs `get` (optional), `Subnet.contains` defensive behavior, `Url.parse` lifetime contract (slices borrow the input buffer), `HaversineOrigin`/`haversineBroadcast`, `toU32/fromU32`, `registeredDomain`/`tld`, `Range` span-wrap caveat. Keep it a compact reference table (Type | Key methods | Contract notes), not prose.

- [ ] **Step 3: CHANGELOG.md** — under `[Unreleased]`, add an entry block:

```markdown
### Changed

- `Subnet.parse` now returns `error.InvalidPrefix` (was `error.Overflow`) for prefixes exceeding the family maximum, matching `Subnet.init`.
- `Mac.format` writes via a single buffer instead of per-byte format dispatch (~2x faster).
- Bench harness de-hoisted (Subnet.contains/cosineDistance/haversine loops) and re-baselined; added LatLonAlt.parse / GeoPoint.parse benchmarks.

### Added

- `IpAddr.isLoopback` / `IpAddr.isMulticast` / `IpAddr.isSafeForOutboundFetch` forwarding predicates.
- `-Dtest-filter` build option for running single tests.
- IntRange/FloatRange fuzz targets; Range.span wrap regression test.
- Build-time version-drift guard (build.zig.zon vs root.zig).
- Committed Zig toolchain SHA-256 lock verified in CI (ATX-02).

### Fixed

- `version` constant synced to 0.1.2 (was stale at 0.1.0).
- Release tag-sign job now fails closed and asserts same-commit before re-tagging (ATX-03).
```

Also fix the line claiming `304 tests (249 unit + ...)` → update to the real current breakdown from Step 1.

- [ ] **Step 4: SECURITY.md** — line 11: `public GitHub issues` → `public GitLab issues`. Optionally add: `(or open a confidential issue on the GitLab project)` after the email line.

- [ ] **Step 5: Markdownlint fixes** —
  - `.gitlab/issue_templates/Bug Report.md:44`: ` ``` ` → ` ```text `
  - `CONTRIBUTING.md:48`: ` ``` ` → ` ```text `; `CONTRIBUTING.md:57`: add blank line before the list (MD032)
  - `CODE_OF_CONDUCT.md:50,58`: wrap bare URLs: `<conduct@codepros.dev>` form or `[text](url)`
  - `docs/APPSEC_REVIEW_2026-06-11.md:14,21`: blank line before lists

- [ ] **Step 6: Verify**

Run: `pre-commit run markdownlint --all-files` (or `markdownlint-cli2 "**/*.md"`) → Expected: PASS, zero violations.
Run: `pre-commit run --all-files` → all hooks PASS.

- [ ] **Step 7: Commit**

```bash
git add README.md CHANGELOG.md SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md ".gitlab/issue_templates/Bug Report.md" docs/APPSEC_REVIEW_2026-06-11.md
git commit -m "docs: API overview table, test-count/version sync, GitLab security contact, markdownlint fixes (N4, CNT-01, VER-02, ATX-05, MD-01)"
```

---

## Task 15: Ledger & gap-doc sync + tracker hygiene

**Files:**

- Modify: `docs/GAP_ANALYSIS.md`, `docs/QUALITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md`
- GitLab: label fix on issue #23

- [ ] **Step 1: GAP_ANALYSIS.md** —
  - GAP-0019 row: change Status from `Blocked (infra ...)` to note the GitLab issue #23 was closed 2026-04-18 as infra-blocked; move the row to a "Closed (tracked externally)" note or annotate `Issue closed (infra-blocked); CI matrix jobs remain when: manual`. Update the "Open count" line from 5 to 4 accordingly.
  - Test-count table: unit 262 → current actual; total 317 → current `<TOTAL>` (from Task 14 Step 1; fuzz now 12).
  - Update "Last updated" header line to 2026-06-11 (post 6th pass / iteration-1 audit fixes).

- [ ] **Step 2: QUALITY_GAP_ANALYSIS.md** —
  - Fix the stale Q36 rows: line ~14 `(Q14, Q27–Q29, Q34–Q37, Q39–Q41) | 11` → `(Q14, Q28, Q39, Q40) | 4`; line ~24 count likewise.
  - Add a "6th pass (2026-06-11)" status-migration section marking Q27, Q29, Q34, Q35, Q37, Q41 **Closed** (with the commit subjects from Tasks 12-13) and recording new findings N1 (Closed — subnet error alignment), N2 (Closed — IpAddr forwarding), N3 (Closed — doc), N4 (Closed — README API table), N5 (Closed — doc).
  - Remaining open ledger: Q14, Q28, Q39, Q40 with their keep rationales (numeric-refactor risk; breaking API; authored docs ×2).

- [ ] **Step 3: PERF_GAP_ANALYSIS.md** — add a 2026-06-11 section: P1 bench de-hoist (Closed), P2 re-baseline ×12 (Closed), P3 metric-comment fix (Closed), P4 Mac.format (Closed), P5 geo bench coverage (Closed), P6 CI duplicate install (Closed). Note the haversine baseline-staleness root-cause correction (stale codegen, not hoisting).

- [ ] **Step 4: SECURITY_GAP_ANALYSIS.md** — add a 2026-06-11 appsec-review section listing ATX-01..08 with dispositions: ATX-01 Accepted (documented compensating control: org-policy tag pins; record the open question "are ci-catalog tags protected/immutable?"), ATX-02 Closed (committed SHA lock), ATX-03 Closed (fail-closed signing), ATX-04 Closed (version sync + guard), ATX-05 Closed (SECURITY.md), ATX-06 Closed (Range fuzz), ATX-07 Closed (hash charset), ATX-08 Closed (documented intent). Link docs/APPSEC_REVIEW_2026-06-11.md.

- [ ] **Step 5: Tracker hygiene** — remove the stale label from closed issue #23:

```bash
glab issue update 23 --unlabel "status::open"
```

- [ ] **Step 6: Run markdownlint on the touched docs** — `pre-commit run markdownlint --all-files` → PASS.

- [ ] **Step 7: Commit**

```bash
git add docs/
git commit -m "docs(audit): sync gap-analysis ledgers for iteration-1 fixes; correct Q36/GAP-0019 staleness"
```

---

## Task 16: Final verification gate

**Files:** none (verification only)

- [ ] **Step 1:** `zig fmt --check src/ tests/ examples/ build.zig` → clean
- [ ] **Step 2:** `zig build check` → clean (version guard active)
- [ ] **Step 3:** `zig build test test-integration test-extensions test-fuzz test-parser-edges test-performance --summary all` → ALL PASS; record total
- [ ] **Step 4:** `zig build test -Doptimize=ReleaseSafe --summary all && zig build test -Doptimize=ReleaseFast --summary all && zig build test -Doptimize=ReleaseSmall --summary all` → ALL PASS (Q35 test exercises wrap in Fast/Small)
- [ ] **Step 5:** `zig build bench -Doptimize=ReleaseFast && python3 ci/bench_gate.py` → gate PASS, 12/12
- [ ] **Step 6:** `pre-commit run --all-files` → ALL hooks PASS
- [ ] **Step 7:** `git status` → clean tree, nothing unstaged
- [ ] **Step 8:** If anything failed: fix, re-run, and amend/commit before declaring done.
