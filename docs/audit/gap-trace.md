# Gap Analysis -- Requirements-to-Code Trace Matrix

Generated: 2026-04-18
Phase: 2 of `/codepros:audit` (gap-scanner)
Repo: `gitlab.com/devnw/zig/advanced-types`
Zig toolchain (local): 0.16.0; CI `ZIG_VERSION`: 0.16.0
Trace source: `docs/audit/gap-requirements.md` (22 tracked requirements, issues #1..#22)

## 1. Test Suite Validation

Executed the four declared test targets against the local toolchain. Results
captured directly from `zig build ... --summary all` output:

| Suite | Command | Result | Count |
|-------|---------|--------|-------|
| Unit | `zig build test --summary all` | PASS | 233/233 |
| Integration | `zig build test-integration --summary all` | PASS | 9/9 |
| Type extensions | `zig build test-extensions --summary all` | PASS | 11/11 |
| Performance | `zig build test-performance --summary all` | PASS | 9/9 |
| Fuzz (declared) | `zig build test-fuzz --summary all` | **FAIL (compile)** | 0/10 |
| Debug (optimize) | `zig build test` (default) | PASS | 233/233 |
| ReleaseSafe | `zig build test -Doptimize=ReleaseSafe` | PASS | 233/233 |
| ReleaseFast | `zig build test -Doptimize=ReleaseFast` | PASS | 233/233 |
| ReleaseSmall | `zig build test -Doptimize=ReleaseSmall` | PASS | 233/233 |

Totals (local, runnable): **262 tests passing**
(233 unit + 9 integration + 11 extensions + 9 performance).

`test-fuzz` fails to compile against Zig 0.16.0 because
`std.testing.fuzz` signature changed: it now expects
`fn (context, *Smith) anyerror!void`, but `tests/fuzz.zig:114` still passes
`fn (context, []const u8) anyerror!void` (10 compile errors, one per test).
See `tests/fuzz.zig:25..114`.

### Test-count reconciliation

| Source | Claimed | Actual | Delta |
|--------|---------|--------|-------|
| `README.md:14` | 230 | 262 runnable (+10 broken fuzz) | README stale |
| `docs/GAP_ANALYSIS.md:72..77` | 272 (233+9+11+9+10) | 262 runnable | Fuzz (10) broken |
| Scanner sum (phase 1) | 271 | 262 runnable | Counted broken fuzz |

**Conflict resolved:** the 272 figure double-counts a broken fuzz suite. With
fuzz excluded, totals are 262. A reconciling edit to `README.md` and
`docs/GAP_ANALYSIS.md` is recommended and is not yet actioned by scanner.

## 2. Per-Requirement Trace

Status legend: **I** = Implemented, **P** = Partial, **N** = Not Implemented,
**U** = Unknown. "Tests" references the test(s) that directly exercise the
requirement; "CI" indicates whether the check is executed by `.gitlab-ci.yml`.

### 2.1 Functional -- `REQUIREMENTS.md` AT-REQ-00x

| Issue | ID | Status | Implementation | Tests | CI |
|-------|----|--------|----------------|-------|----|
| #1 | AT-REQ-001 Network types | **I** | `src/types/network.zig` -- `Ipv4Addr` (L41), `Ipv6Addr` (L155), `IpAddr` (L369), `Subnet` (L419), `Mac` (L525); re-exported in `src/root.zig:42..46` | 33 unit tests `network.zig:599..959`; integration `tests/integration.zig:53,103`; extensions `tests/type_extensions.zig:17..72` | `test`, `test-release-safe`, `test-release-fast`, `test-release-small`, `test-integration*` |
| #2 | AT-REQ-002 Vector types | **I** | `src/types/vector.zig` -- `Vector(T,N)` (L30), `VectorF32` (L261), `VectorI32` (L264); distance/magnitude/normalize/cosine L150..180; re-exported `src/root.zig:52..54` | 49 unit tests `vector.zig:277..630`; integration `tests/integration.zig:66,133`; extensions `tests/type_extensions.zig:122` | same as #1 |
| #3 | AT-REQ-003 Geographic | **I** | `src/types/geographic.zig` -- `LatLon` (L39), `LatLonAlt` (L138), `GeoPoint` (L216); haversine L70+; re-exported `src/root.zig:60..62` | 38 unit tests `geographic.zig:307..562`; integration `tests/integration.zig:66`; extensions `tests/type_extensions.zig:89..137` | same as #1 |
| #4 | AT-REQ-004 URL/domain | **I** | `src/types/url.zig` -- `Domain` (L37), `DomainLabelIterator` (L122), `Url` (L151); re-exported `src/root.zig:68..69`; `build.zig.zon:6` shows zero deps (no `uri` overlap) | 57 unit tests `url.zig:321..634`; integration `tests/integration.zig:116`; extensions `tests/type_extensions.zig:176` | same as #1 |
| #5 | AT-REQ-005 Generic ranges | **I** | `src/types/range.zig` -- `Range(T)` (L20), `IntRange` (L195), `UintRange` (L196), `FloatRange` (L197); re-exported `src/root.zig:75..78` | 55 unit tests `range.zig:203..569`; integration `tests/integration.zig:160`; extensions `tests/type_extensions.zig:151` | same as #1 |
| #6 | AT-REQ-006 Exclude hash types | **I** | `src/types/hash.zig` absent (confirmed via `find`). No references to heap/storage hash aliases in `src/`. | Negative assertion; no dedicated test required | -- |

### 2.2 Packaging -- AT-PKG-00x

| Issue | ID | Status | Evidence | Notes |
|-------|----|--------|----------|-------|
| #7 | AT-PKG-001 URL ownership | **I** | `build.zig.zon:6` declares `.dependencies = .{}`; `src/types/url.zig` is standalone. Docs decision recorded in `docs/GAP_ANALYSIS.md:39`. | Closed |
| #8 | AT-PKG-002 DateRange | **N (deferred)** | No `DateRange` symbol in `src/` (grep returned no matches). Intentionally deferred pending a datetime package. | Blocked (external dep) |
| #9 | AT-PKG-003 Geode wrappers external | **I** | `src/` has no `index/*` directory; only `types/` and `root.zig`. | Closed |

### 2.3 Test -- AT-TEST-00x + GAP-0017

| Issue | ID | Status | Evidence |
|-------|----|--------|----------|
| #10 | AT-TEST-001 Source-level tests | **I** | 232 `test ...` blocks across the 5 type modules (`grep -c "^test"`): network 33, vector 49, geographic 38, url 57, range 55; all run under `zig build test` via `refAllDecls` at `src/root.zig:86`. |
| #11 | AT-TEST-002 Type-extension coverage | **I** | `tests/type_extensions.zig` has 11 `test` blocks (L17..L196); executed by `zig build test-extensions` (pass 11/11). |
| #12 | AT-TEST-003 Integration + perf coverage | **I** | `tests/integration.zig` (9 tests, L16..L160) + `tests/performance.zig` (9 tests, L25..L548). Both suites pass. |
| #16 | Port additional Geode integration tests | **N (blocked)** | No `tests/integration/test_*` subdirectory. Requires Geode repo as source. |

### 2.4 Documentation -- Docs section + README bug

| Issue | Topic | Status | Evidence |
|-------|-------|--------|----------|
| #15 | Examples (vector/geographic/network) | **I** | `examples/basic.zig` covers all five type families (network L17..23, vector L27..30, geographic L34..37, URL L41..44, range L48..51). Built via `zig build example` step in `build.zig:90..103`. |
| #17 | README Quick Start matches real API | **I** | `README.md` Quick Start uses `Ipv4Addr.parse`, `LatLon.init`, `VectorF32.init` -- all defined in current `src/root.zig:42..54`. Verified by `examples/basic.zig` compiling under `zig build example`. |

### 2.5 Non-Functional -- AT-NFR-00x

| Issue | ID | Status | Evidence | Gap |
|-------|----|--------|----------|-----|
| #18 | AT-NFR-001 Zero runtime deps | **I** | `build.zig.zon:6` `.dependencies = .{}`. `src/**/*.zig` imports only `std`. | -- |
| #19 | AT-NFR-002 Zero-allocation value types | **I** | No `Allocator` parameter on any public `parse`/`init`/`format` API (spot-checked signatures in all 5 modules). Types are plain structs/unions. | Not formally asserted by a negative-test; acceptable for a value-type library. |
| #20 | AT-NFR-003 Cross-platform CI | **N** (confirmed open) | `.gitlab-ci.yml` uses only `image: debian:bookworm-slim` on amd64; no matrix job for macOS, Windows, or aarch64. Install script at L42..76 *accepts* aarch64 architecture, but no runner actually runs aarch64. | **Refutes any implicit claim** of multi-platform CI. Still the only actionable unblocked gap. |
| #21 | AT-NFR-004 All 4 optimize modes | **P** (closed-status disputed) | CI runs: `test` (Debug, L95), `test-release-safe` (L117), `test-release-fast` (L128), `test-release-small` (L159) for *unit tests*. Integration only covers Debug + ReleaseSafe + ReleaseFast (L138..156). ReleaseSmall integration is **not** in CI. Extensions and performance suites run **only once** under Debug, via no explicit CI job -- `test-extensions` and `test-performance` are **not referenced in `.gitlab-ci.yml`** at all. | Unit tests: all 4 modes covered (CI) -- confirmed. Integration: 3/4 modes. Extensions/performance: not enforced by CI. Per spec the requirement is "Tests pass on all optimization levels" (CONTRIBUTING.md) -- unit slice is compliant, others are not. |

### 2.6 Security -- AT-SEC-001

| Issue | ID | Status | Evidence |
|-------|----|--------|----------|
| #22 | AT-SEC-001 SAST + secret + dep + SBOM | **I** | `.gitlab-ci.yml:10..21` includes `security-sast@v1.7.1`, `security-dependency-scanning@v1.7.1`, `security-secrets@v1.7.1`, `security-gitleaks@v1.7.1`, `sbom-generate@v1.7.1`, `sbom-scan@v1.7.1`. All gated on default pipeline via `include:` (no `rules:` limiter). |

### 2.7 Integration (downstream) -- GAP_ANALYSIS items

| Issue | Topic | Status | Evidence |
|-------|-------|--------|----------|
| #13 | Wire Geode consumer | **N (blocked)** | No Geode-side artefacts present in this repo; requires downstream work. |
| #14 | Stage `st_*` spatial helpers | **N (deferred)** | `grep -rn "st_"` in `src/` returns no matches. Intentionally deferred (`docs/GAP_ANALYSIS.md:41`). |

## 3. Closure-Claim Verification (`docs/GAP_ANALYSIS.md:82..96`)

| Gap-ID | Doc claim | Actual evidence | Verdict |
|--------|-----------|-----------------|---------|
| GAP-0005 Quick Start nonexistent `init()` | Closed | `README.md` Quick Start matches `examples/basic.zig` which compiles | **Confirmed** |
| GAP-0006 Archive/issue URLs underscores | Closed | Not re-verified (doc-only) | Unknown (not revisited) |
| GAP-0007 examples/basic.zig imports library | Closed | `examples/basic.zig:7` imports `advanced_types` | **Confirmed** |
| GAP-0008 docs/README links | Closed | Not re-verified (doc-only) | Unknown (not revisited) |
| GAP-0009 CODEOWNERS placeholder | Closed | `CODEOWNERS` present; `@benjiv` per gap-requirements.md | **Confirmed** (indirect) |
| GAP-0010 CHANGELOG placeholder date | Closed | Not re-verified (doc-only) | Unknown |
| GAP-0011 Code coverage | Closed | Not observed in `.gitlab-ci.yml`. No `kcov`/`llvm-cov`/`coverage` jobs or artefacts in CI. | **Refuted** -- no evidence of coverage measurement in current pipeline |
| GAP-0012 AT-TEST-002 ported | Closed | 11 tests pass | **Confirmed** |
| GAP-0013 AT-TEST-003 ported | Closed | 9+9 tests pass | **Confirmed** |
| GAP-0014 Geode consumer wiring | Blocked | Still blocked; no change | Confirmed still blocked |
| GAP-0015 DateRange | Blocked | Still absent; no datetime dep | Confirmed still blocked |
| GAP-0016 `st_*` helpers | Deferred | Still absent | Confirmed deferred |
| GAP-0017 Geode integration tests | Blocked | Still blocked | Confirmed blocked |
| GAP-0018 Fuzzing | Closed | `tests/fuzz.zig` exists with 10 tests but **does not compile under Zig 0.16.0** (`std.testing.fuzz` signature changed); CI fuzz job runs `timeout 60 zig build test --fuzz` (L182), which compiles unit tests only -- so the fuzz job's timeout may mask the broken fuzz suite depending on interpretation. | **Refuted** -- fuzz suite is broken; closure claim is out-of-date |

## 4. Cross-Platform & Optimize-Mode CI Validation (detail)

### Issue #20 AT-NFR-003 (cross-platform)

Current `.gitlab-ci.yml` structure:

- `default.tags: [company]` (L5..7) -- custom runner pool, not matrix
- Every stage uses `image: debian:bookworm-slim` (L88, L97, L108, L119, L129,
  L140, L150, L161, L178). No `image:` variant for macOS (macOS GitLab SaaS
  runners are managed separately) or Windows.
- Install script at L42..L76 *supports* aarch64 detection, but no job
  specifies an aarch64 runner tag, so in practice all runners are x86_64.

**Conclusion: CI exercises Linux/x86_64 only.** Issue #20 is genuinely open
and actionable. The phase-1 label `status::open` on #20 is correct.

### Issue #21 AT-NFR-004 (optimize modes)

| Optimize mode | Unit (CI) | Integration (CI) | Extensions (CI) | Performance (CI) |
|---------------|-----------|------------------|-----------------|------------------|
| Debug | YES (L95) | YES (L107) | NO | NO |
| ReleaseSafe | YES (L117) | YES (L138) | NO | NO |
| ReleaseFast | YES (L128) | YES (L148) | NO | NO |
| ReleaseSmall | YES (L159) | NO | NO | NO |

**Conclusion:** Unit-test slice covers all 4 modes (the letter of the
requirement as stated in CONTRIBUTING.md), but integration misses
ReleaseSmall, and the extension/performance suites are **absent from CI
entirely** -- they are only runnable locally. The `status::closed` label on
Issue #21 is defensible for unit tests but hides the extension/performance gap.

### Issue #22 AT-SEC-001 (security scans)

| Component | Version | CI location |
|-----------|---------|-------------|
| SAST | v1.7.1 | `.gitlab-ci.yml:11` |
| Dependency scanning | v1.7.1 | `.gitlab-ci.yml:12` |
| Secrets | v1.7.1 | `.gitlab-ci.yml:13` |
| Gitleaks | v1.7.1 | `.gitlab-ci.yml:14` |
| SBOM generate | v1.7.1 | `.gitlab-ci.yml:20` |
| SBOM scan | v1.7.1 | `.gitlab-ci.yml:21` |

All six run unconditionally (no `rules:` limit in the `include:` block). `status::closed` on #22 is correct.

## 5. Rollup: Status Breakdown

| Status | Count | Issues |
|--------|-------|--------|
| Implemented | **16** | #1, #2, #3, #4, #5, #6, #7, #9, #10, #11, #12, #15, #17, #18, #19, #22 |
| Partial | **1** | #21 (unit-test mode coverage complete; integration/ext/perf partial) |
| Not Implemented | **5** | #8 (blocked), #13 (blocked), #14 (deferred), #16 (blocked), #20 (actionable) |
| Unknown | **0** | -- |

16 I + 1 P + 5 N + 0 U = 22.

## 6. Signals for the gap-detector

- **#20 AT-NFR-003 remains the only fully-unblocked open gap.** Recommended
  action: add `rules` / `parallel:matrix` jobs for macOS, Windows, and
  Linux-aarch64 runners, or document the platform claim as best-effort.
- **#21 AT-NFR-004 is overstated.** Consider either:
  (a) narrowing the claim to "unit tests pass on all optimization modes", or
  (b) adding CI jobs for `test-integration -Doptimize=ReleaseSmall`,
  `test-extensions` (all modes), and `test-performance` (all modes).
- **GAP-0018 / fuzz suite is broken.** `tests/fuzz.zig` must be ported to
  Zig 0.16 `std.testing.fuzz` API (accept `*Smith` not `[]const u8`).
  Either reopen GAP-0018 or raise a new follow-up.
- **GAP-0011 coverage.** No coverage tool is wired into CI. Either reopen
  GAP-0011 or document an explicit "coverage not tracked" decision.
- **Test-count mismatch.** `README.md:14` ("230 Tests") and
  `docs/GAP_ANALYSIS.md:77` (272) both need a refresh; the verified runnable
  total is **262** (233 + 9 + 11 + 9) with 10 fuzz tests broken.
- **Scanner phase-1 count of 271** double-counted by including one fuzz test
  that doesn't compile; actual value is 262.

## 7. Artefact Paths (absolute)

Requirements source:

- `/home/benji/src/devnw/zig/advanced-types/docs/REQUIREMENTS.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-requirements.md`

Implementation:

- `/home/benji/src/devnw/zig/advanced-types/src/root.zig`
- `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig`
- `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig`
- `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig`
- `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig`
- `/home/benji/src/devnw/zig/advanced-types/src/types/range.zig`

Tests:

- `/home/benji/src/devnw/zig/advanced-types/tests/integration.zig`
- `/home/benji/src/devnw/zig/advanced-types/tests/type_extensions.zig`
- `/home/benji/src/devnw/zig/advanced-types/tests/performance.zig`
- `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` (broken under Zig 0.16)

Build / CI:

- `/home/benji/src/devnw/zig/advanced-types/build.zig`
- `/home/benji/src/devnw/zig/advanced-types/build.zig.zon`
- `/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml`
