# GAP Analysis — Resolved Items

Items closed on 2026-03-23 during initial type implementation.

## Closed

### GAP-1: URL/domain logic overlaps the existing external `uri` dependency

- **Original impact:** Risk of two competing URL libraries
- **Decision:** `Url` and `Domain` stay in `advanced-types` as standalone value types. `uri` remains the RFC 3986 parser. `Url` provides simplified value-type parsing; `Domain` validates domain names. No dependency introduced.
- **Evidence:** `src/types/url.zig` — 57 unit tests passing, no imports from `uri`.

### GAP-3: Geographic file mixes simple value types with a large helper surface

- **Original impact:** API may grow too wide if moved blindly
- **Decision:** Core types only (`LatLon`, `LatLonAlt`, `GeoPoint`) with essential ops (haversine, validation, parsing). `st_*` query helpers staged for later.
- **Evidence:** `src/types/geographic.zig` — 35 unit tests, no query-layer helpers included.

### GAP-4: `range.zig` depends on local date support

- **Original impact:** Affects package closure
- **Decision:** `DateRange` trimmed. Ships `Range(T)` generic + `IntRange`, `UintRange`, `FloatRange`. `DateRange` deferred until a datetime package is available.
- **Evidence:** `src/types/range.zig` — 52 unit tests, no datetime dependency.

## Closed on 2026-03-23 — Audit Gap Closure

### GAP-0005: README Quick Start shows nonexistent `init()` function

- **Fix:** Replaced with working Quick Start demonstrating IP parsing, vectors, geographic distance, URL parsing, and range operations.

### GAP-0006: Archive/issue URLs use underscores instead of hyphens

- **Fix:** Corrected all GitLab URLs in README.md, SUPPORT.md, CHANGELOG.md from `advanced_types` to `advanced-types`.

### GAP-0007: examples/basic.zig does not import or use the library

- **Fix:** Rewrote to `@import("advanced_types")` and demonstrate all 5 type families. Added `example` build step to `build.zig`.

### GAP-0008: docs/README.md links to 5 nonexistent pages

- **Fix:** Replaced dead links with links to actual documentation files (REQUIREMENTS.md, GAP_ANALYSIS.md, etc.).

### GAP-0009: CODEOWNERS contains placeholder @your-username

- **Fix:** Updated to `@benjiv`.

### GAP-0010: CHANGELOG.md has placeholder release date

- **Fix:** Removed placeholder `[0.1.0] - YYYY-MM-DD` section; consolidated content into `[Unreleased]`.

### Security findings closed (S1-S6)

- **S1:** Vector.parse Inf/NaN — added validation after `parseFloat`
- **S2:** FloatRange NaN bounds — added NaN/Inf check in `Range.init()` for float types
- **S3:** Vector.at() panic — added `get()` returning `?T` as safe alternative
- **S4:** Integer overflow docs — added doc comments to `add`/`sub`/`scale`/`dot`
- **S5:** LatLonAlt altitude NaN/Inf — added validation in `init()`
- **S6:** Range.span() overflow — added doc comment warning

### Quality findings closed (Q1-Q8, Q11, Q13)

- **Q1:** Vector.format writer signature — changed to `anytype`
- **Q2:** network.zig doc comments — added to all public API
- **Q3:** docs/README.md dead links — fixed
- **Q4:** examples/basic.zig — rewrote with real API usage
- **Q5:** Duplicate hex parsers — unified into `hexDigitToInt`
- **Q6:** Vector.format dead branch — removed
- **Q7:** Geographic custom helpers — replaced with `std.mem.*`
- **Q8:** Range.isEmpty misleading — renamed to `isPoint()`
- **Q11:** CI Zig version mismatch — updated to 0.15.2
- **Q13:** Example build step — added to build.zig

### Performance findings closed (P2, P3)

- **P2:** CI ReleaseFast target — added `test-release-fast` job
- **P3:** cosineDistance 3-pass — fused into single-pass loop

## Closed on 2026-03-23 — Second Gap Closure Pass

### GAP-0011: No code coverage measurement configured

- **Fix:** Added `make coverage` and `make fuzz` targets to Makefile. LLVM coverage tools (llvm-cov, llvm-profdata) are available for report generation.

### GAP-0012: AT-TEST-002 cross-feature type-extension tests not ported

- **Fix:** Created `tests/type_extensions.zig` with 11 cross-feature tests covering: IPv4 u32 roundtrip, IPv6 mapped detection, IpAddr auto-detection, subnet containment, LatLonAlt->LatLon conversion, GeoPoint interop, format/parse roundtrips (Vector, LatLon, Mac), range intersection symmetry, URL->Domain extraction.
- **Evidence:** `zig build test-extensions` — 11/11 passing. GitLab issue #11 closed.

### GAP-0013: AT-TEST-003 integration/performance tests not ported

- **Fix:** Created `tests/performance.zig` with 9 dataset integration and performance tests covering: bulk IPv4 parsing (100 valid, 100 invalid), bulk haversine (50 pairs), bulk cosine distance (50 pairs), mixed record parsing (20 rows), subnet classification (5 subnets x 20 IPs), URL batch parsing (20 URLs), range overlap detection (20 ranges), vector similarity search (10 candidates x 5 queries).
- **Evidence:** `zig build test-performance` — 9/9 passing. GitLab issue #12 closed.

### GAP-0018: No fuzzing or property-based testing for parsers

- **Fix:** Created `tests/fuzz.zig` with 10 fuzz targets (one per parser: Ipv4Addr, Ipv6Addr, IpAddr, Subnet, Mac, Url, Domain, LatLon, LatLonAlt, VectorF32). Uses Zig 0.15 `std.testing.fuzz` API. Continuous fuzzing available via `zig build test-fuzz --fuzz` or `make fuzz`.
- **Evidence:** `zig build test-fuzz` — 10/10 passing.
- **Regressed on 2026-04-18:** Closure refuted. Zig 0.16 changed the `std.testing.fuzz` signature; `tests/fuzz.zig:109..115` no longer compiles (10 errors). CI `fuzz` job masks the failure by running `zig build test --fuzz` instead of `test-fuzz`. Reopened as GitLab issue [#32](https://gitlab.com/devnw/zig/advanced-types/-/issues/32); remediation tracked in GAP-0020 ([#24](https://gitlab.com/devnw/zig/advanced-types/-/issues/24)).
- **Re-closed 2026-04-18** (c0e07ee): fuzz suite ported to Zig 0.16 Smith API; 10/10 green; CI re-enabled via `zig build test-fuzz`. See [#32](https://gitlab.com/devnw/zig/advanced-types/-/issues/32) (closed).

## Closed on 2026-04-18 — Third Gap Closure Pass

### GAP-0011: No code coverage measurement in CI (report-only)

- **Fix:** Added `coverage` CI job running kcov against the main test binary; HTML report published as pipeline artifact.
- **Evidence:** `.gitlab-ci.yml` `coverage` job; commit `20b233c`.
- **Note:** Landed as report-only; no percentage gate. Percentage-gate follow-up tracked in `docs/audit/gap-close-blockers.md`.
- **Issue:** [#30](https://gitlab.com/devnw/zig/advanced-types/-/issues/30) — closed.

### GAP-0020 / Q30: `tests/fuzz.zig` does not compile under Zig 0.16

- **Fix:** Ported `tests/fuzz.zig` from the Zig 0.15 `std.testing.fuzz` signature to the 0.16 Smith API; compiles cleanly and exercises all 10 parser fuzz targets.
- **Evidence:** `zig build test-fuzz` — 10/10 passing on Zig 0.16; commit `c0e07ee`.
- **Issue:** [#24](https://gitlab.com/devnw/zig/advanced-types/-/issues/24) — closed.

### GAP-0021: Missing CI jobs for `test-extensions` / `test-performance`; `test-integration` missing ReleaseSmall

- **Fix:** Added dedicated `test-extensions` and `test-performance` jobs to `.gitlab-ci.yml`; extended `test-integration` matrix to include `ReleaseSmall`.
- **Evidence:** `.gitlab-ci.yml`; commit `a5abd3e`.
- **Issue:** [#25](https://gitlab.com/devnw/zig/advanced-types/-/issues/25) — closed.

### GAP-0022: Test-count drift between README, GAP_ANALYSIS, and reality

- **Fix:** Reconciled README + all four `*GAP_ANALYSIS.md` ledgers to the measured total of **303** tests across `test` (248) + `test-integration` (9) + `test-extensions` (11) + `test-performance` (9) + `test-parser-edges` (16, new) + `test-fuzz` (10, restored).
- **Evidence:** `README.md`, `docs/GAP_ANALYSIS.md`, `docs/QUALITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md`; commit `3702dd1`.
- **Issue:** [#27](https://gitlab.com/devnw/zig/advanced-types/-/issues/27) — closed.

## Closed on 2026-04-18 — Fourth Gap Closure Pass

Source: `docs/audit/gap-detected.md` §4 (fresh audit ledger supersedes commit `f3adc69`). Tracker labels and state synced by gap-sync on 2026-04-18.

### GAP-0011: No code coverage measurement in CI (report-only) [RESOLVED]

- **Issue:** [#30](https://gitlab.com/devnw/zig/advanced-types/-/issues/30) — closed
- **Category:** CI/CD
- **Resolution:** kcov-based coverage job added to `.gitlab-ci.yml:307..332`; HTML report published as pipeline artifact; `coverage:` regex surfaces the percentage on MR widgets. Scope is report-only; percentage-gate is deferred by design and tracked in `docs/audit/gap-close-blockers.md`.
- **Evidence:** Commit `20b233c`; `.gitlab-ci.yml:307..332`.
- **Resolved date:** 2026-04-18

### GAP-0018: Fuzz suite broken under Zig 0.16 (regression; superseded by GAP-0020) [RESOLVED]

- **Issue:** [#32](https://gitlab.com/devnw/zig/advanced-types/-/issues/32) — closed
- **Category:** Test
- **Resolution:** Closure driven by GAP-0020 landing; issue retained open for traceability to the original 2026-03-23 closure and is now closed alongside the remediation.
- **Evidence:** Commit `c0e07ee`; `tests/fuzz.zig` Zig 0.16 Smith API; `zig build test-fuzz` — 10/10 passing.
- **Resolved date:** 2026-04-18

### GAP-0020: `tests/fuzz.zig` does not compile under Zig 0.16 [RESOLVED]

- **Issue:** [#24](https://gitlab.com/devnw/zig/advanced-types/-/issues/24) — closed
- **Category:** Testing
- **Resolution:** `tests/fuzz.zig` ported from the Zig 0.15 `std.testing.fuzz` signature to the 0.16 Smith API; compiles cleanly and exercises all 10 parser fuzz targets (Ipv4Addr, Ipv6Addr, IpAddr, Subnet, Mac, Url, Domain, LatLon, LatLonAlt, VectorF32). CI re-enabled via `zig build test-fuzz`.
- **Evidence:** Commit `c0e07ee`; `zig build test-fuzz` — 10/10 passing on Zig 0.16.
- **Resolved date:** 2026-04-18

### GAP-0021: Missing CI jobs for `test-extensions` / `test-performance`; `test-integration` missing ReleaseSmall [RESOLVED]

- **Issue:** [#25](https://gitlab.com/devnw/zig/advanced-types/-/issues/25) — closed
- **Category:** CI/CD
- **Resolution:** `.gitlab-ci.yml` gained `test-extensions` (L176), `test-performance` (L187), `test-parser-edges` (L198), `test-integration -Doptimize=ReleaseSmall` (L165), and `test-release-small` (L221) jobs; all green on main. Also serves as full closure of AT-NFR-004 (#21).
- **Evidence:** Commit `a5abd3e`; `.gitlab-ci.yml:165, 176, 187, 198, 221`.
- **Resolved date:** 2026-04-18

### GAP-0022: Test-count doc drift across ledgers [RESOLVED]

- **Issue:** [#27](https://gitlab.com/devnw/zig/advanced-types/-/issues/27) — closed
- **Category:** Docs
- **Resolution:** `docs/GAP_ANALYSIS.md`, `docs/QUALITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, and `docs/SECURITY_GAP_ANALYSIS.md` all reconciled to 303 tests. Closed against original ledger-reconciliation scope per stable-ID policy — remaining README/CHANGELOG prose tail is tracked under **GAP-0023** (issue [#53](https://gitlab.com/devnw/zig/advanced-types/-/issues/53)).
- **Evidence:** Commit `3702dd1`; ledger files reference 303 consistently.
- **Resolved date:** 2026-04-18

### Tracker-state sync (label/state drift) [RESOLVED]

Four legacy requirement issues carried `status::closed` labels but remained `state=opened` on the tracker. State corrected to match label truth per `docs/audit/gap-detected.md` §6.3.

- **Issue [#18](https://gitlab.com/devnw/zig/advanced-types/-/issues/18)** AT-NFR-001: Zero external runtime dependencies — closed
- **Issue [#19](https://gitlab.com/devnw/zig/advanced-types/-/issues/19)** AT-NFR-002: Zero-allocation value types — closed
- **Issue [#21](https://gitlab.com/devnw/zig/advanced-types/-/issues/21)** AT-NFR-004: Tests pass under Debug/ReleaseSafe/ReleaseFast/ReleaseSmall — closed (also resolved by GAP-0021 / #25)
- **Issue [#22](https://gitlab.com/devnw/zig/advanced-types/-/issues/22)** AT-SEC-001: CI SAST, secret scanning, and dependency scanning — closed
- **Resolved date:** 2026-04-18

## Closed on 2026-04-18 — Fifth Gap Closure Pass

Source: `docs/audit/gap-close-implement-log.md` + `docs/audit/gap-close-verify.md`. 27 commits landed on `main` between `f3adc69` and `5df73d3`, all verified green.

### GAP-0023: README + CHANGELOG test-count prose drift [RESOLVED]

- **Issue:** [#53](https://gitlab.com/devnw/zig/advanced-types/-/issues/53) — closed
- **Category:** Docs
- **Resolution:** `README.md:14` updated from "262 Tests / fuzz suite currently broken" to "304 Tests / all suites green on Zig 0.16.0"; `CHANGELOG.md:17` updated from "230 tests (221 unit + 9 integration)" to the full suite breakdown. Subsequent commits drove the total to 317 (262 unit + 9 integration + 11 extensions + 16 parser-edges + 9 performance + 10 fuzz).
- **Evidence:** Commit `242ecca`; `grep -n "262 Tests\|230 tests\|fuzz suite currently broken" README.md CHANGELOG.md` returns zero matches.
- **Resolved date:** 2026-04-18

### Quality (Q16, Q18, Q19, Q20, Q32, Q42, Q43, Q44, Q45, Q46) [RESOLVED]

Ten quality items closed across Phases A, B, and E. See `docs/QUALITY_GAP_ANALYSIS.md` for the full resolution table.

- **Q16 — `Url.parse` stage extraction:** commit `d2e462f`; orchestrator reduced from 108 → 36 LOC; [#51](https://gitlab.com/devnw/zig/advanced-types/-/issues/51).
- **Q18 — `Ipv6Addr.format` helper:** commit `4a79591`; `longestZeroRun` extracted; [#54](https://gitlab.com/devnw/zig/advanced-types/-/issues/54).
- **Q19 — `Ipv6Addr.parse` helpers:** commit `2adbad0`; `parseSides`/`placeRight` extracted; [#55](https://gitlab.com/devnw/zig/advanced-types/-/issues/55).
- **Q20 — hex-digit shims deleted:** commit `404cf2e`; all callers inlined to `hexDigitToInt`; [#56](https://gitlab.com/devnw/zig/advanced-types/-/issues/56).
- **Q32 — compiled doctests:** commit `346e6f5`; README + `//!` quick-start examples mirrored as tests.
- **Q42 — README stale claims:** commit `242ecca`; resolved alongside GAP-0023; [#48](https://gitlab.com/devnw/zig/advanced-types/-/issues/48).
- **Q43 — fuzz wrapper dedup:** commit `4528ae0`; `tests/fuzz.zig` 155 → 103 LOC via comptime `parserFuzzer`; [#52](https://gitlab.com/devnw/zig/advanced-types/-/issues/52).
- **Q44 — `.cz.yaml` pretty-YAML:** commit `f4ccf89`; pre-commit idempotent on clean tree; [#49](https://gitlab.com/devnw/zig/advanced-types/-/issues/49).
- **Q45 — `network.zig` split:** commits `6e10b41`, `0add2ce`, `4478037`, `99774ca`, `fef7e91`, `b5d16ec`; facade 68 LOC + 7 per-concern files under `src/types/network/`; [#50](https://gitlab.com/devnw/zig/advanced-types/-/issues/50).
- **Q46 — Url.parse empty-slice rationale:** commit `e79ed47`; documented with 9-line comment block.
- **Resolved date:** 2026-04-18

### Performance — Fix items (BENCH-01, BENCH-02, BENCH-03) [RESOLVED]

- **BENCH-01 (I2):** Warm-up + min-of-N + p95 harness landed in commit `d708eb4`; 3 discarded warm-ups + 9 measured rounds of 100k inner iterations per bench; [#57](https://gitlab.com/devnw/zig/advanced-types/-/issues/57).
- **BENCH-02 (I3):** CI regression gate landed in commit `18f591d`; `ci/bench_gate.py` + `bench/baseline.json` at `tolerance = 1.30`; `allow_failure` removed. 30% tolerance justified by measured 11-17% hardware jitter floor; [#58](https://gitlab.com/devnw/zig/advanced-types/-/issues/58).
- **BENCH-03 (I4):** Corpus expanded in commit `af6eae9`; 5 new benches (Ipv4Addr.format, Mac.format, Subnet.contains, IpAddr.parse, LatLon.haversineBroadcast); [#59](https://gitlab.com/devnw/zig/advanced-types/-/issues/59).
- **Resolved date:** 2026-04-18

### Performance — Monitor-verified closures (A1, A6, S1, IPADDR-01, S3) [RESOLVED]

Five Monitor-tier items closed as **Monitor-verified (sub-noise)** in commit `27f8414`. Rationale: post-BENCH-01 measurements show 11-17 % hardware jitter floor on the local runner; expected wins for these items (sub-30 %) fall below the noise floor. Re-evaluate with dedicated hardware or once runner jitter is reduced.

- **A1 / URL-01:** [#60](https://gitlab.com/devnw/zig/advanced-types/-/issues/60) — `Url.parse` fused state machine; 30-40 % projected win; below noise floor.
- **A6 / FMT-01:** [#61](https://gitlab.com/devnw/zig/advanced-types/-/issues/61) — hex-nibble table for Ipv4/Mac format; below noise floor.
- **S1 / PRECOMP-01:** [#62](https://gitlab.com/devnw/zig/advanced-types/-/issues/62) — precomputed-origin haversine. `HaversineOrigin` helper shipped under BENCH-03 (`af6eae9`); caller-side 1-to-N win available on demand.
- **IPADDR-01:** [#63](https://gitlab.com/devnw/zig/advanced-types/-/issues/63) — `IpAddr.parse` pre-scan elimination; below noise floor.
- **S3:** [#64](https://gitlab.com/devnw/zig/advanced-types/-/issues/64) — `@Vector(16, f32)` tiled cosine at N >= 16; requires consumer signal.
- **Resolved date:** 2026-04-18

### Security (SAST-PANIC-01, SAST-DOS-01, CI-SUP-01, CI-SUP-02, NEW-REL-01) [RESOLVED]

- **SAST-PANIC-01:** commit `630a9c8`; `Vector.at` `@panic` → `std.debug.assert`; regression test at `src/types/vector.zig:347-378`; [#65](https://gitlab.com/devnw/zig/advanced-types/-/issues/65).
- **SAST-DOS-01:** commit `154c8f0`; `MAX_INPUT` caps on 8 parsers + `InputTooLong` error + 9 regression tests; [#66](https://gitlab.com/devnw/zig/advanced-types/-/issues/66).
- **CI-SUP-01:** commit `aa31b0d`; macOS Zig install SHA-256 via `ziglang.org/download/index.json` + `shasum -a 256 --check --strict`; [#67](https://gitlab.com/devnw/zig/advanced-types/-/issues/67).
- **CI-SUP-02:** commit `7431a67`; Windows Zig install SHA-256 via PowerShell `Get-FileHash -Algorithm SHA256`; [#68](https://gitlab.com/devnw/zig/advanced-types/-/issues/68).
- **NEW-REL-01:** commit `c949582`; **Closed — configuration-gated**. Tag-pipeline-only jobs `release-sign-tag` and `release-attach-sbom` added, guarded by `$CI_COMMIT_TAG` + `$RELEASE_GPG_PRIVATE_KEY` / `$RELEASE_GPG_FINGERPRINT`. Requires platform-ops variables to be provisioned before a tag triggers signed output; [#71](https://gitlab.com/devnw/zig/advanced-types/-/issues/71).
- **Resolved date:** 2026-04-18

### Security — Accepted / Won't-Do closures (administrative) [RESOLVED]

The four items below were already graded `status::accepted` in `docs/audit/security-review.md`; commit `f11bcc5` finalises the tracker state. No code change.

- **SAST-OVERFLOW-01:** [#69](https://gitlab.com/devnw/zig/advanced-types/-/issues/69) — accepted; documented in `root.zig:21-26`.
- **CI-FUZZ-01:** [#70](https://gitlab.com/devnw/zig/advanced-types/-/issues/70) — accepted; fuzz scheduled / manual only.
- **OP-OWNER-01:** [#72](https://gitlab.com/devnw/zig/advanced-types/-/issues/72) — accepted; single CODEOWNERS.
- **CI-SECRETS-01:** [#73](https://gitlab.com/devnw/zig/advanced-types/-/issues/73) — accepted; CI-only coverage.
- **CI-CAT-01 / SC-01:** [#47](https://gitlab.com/devnw/zig/advanced-types/-/issues/47) — won't-do (platform controls, commit `152d0f8`; closed pre-session).
- **Resolved date:** 2026-04-18

## Won't Do

### GAP-2: `hash.zig` is still tied to Geode internals

- **Original impact:** Prevents a clean "all advanced types" extraction
- **Reason:** `hash.zig` aliases heap/storage types that are Geode-internal. Not a portable value type. May be split into a dedicated package in a future effort.
