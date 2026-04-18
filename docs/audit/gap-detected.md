# Gap Determination Ledger

Generated: 2026-04-18
Phase: 3 of `/codepros:audit` (gap-detector)
Repo: `gitlab.com/devnw/zig/advanced-types`
Toolchain: Zig 0.16.0 (CI + local)
Trace input: `docs/audit/gap-trace.md`
Prior-state inputs: `docs/GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS_RESOLVED.md`

Highest Gap-ID in prior state: **GAP-0018**. New IDs start at **GAP-0019**.

## 1. Gap Determination Report

### 1.1 Summary

- **Total requirements analyzed:** 22 (issues #1..#22, from `gap-requirements.md`)
- **Implemented:** 16 (#1, #2, #3, #4, #5, #6, #7, #9, #10, #11, #12, #15, #17, #18, #19, #22)
- **Partial:** 1 (#21 AT-NFR-004)
- **Not Implemented:** 5 (#8 AT-PKG-002, #13 Geode wiring, #14 st_* helpers, #16 Geode integration tests, #20 AT-NFR-003)
- **Unknown:** 0
- **New gaps raised this phase:** 4 (GAP-0019..GAP-0022)
- **Refuted closures (reopened):** 2 (GAP-0011, GAP-0018)
- **Open gaps after this phase (total):** 10
  - Net new actionable: GAP-0019 (cross-platform CI), GAP-0020 (fuzz broken), GAP-0021 (CI mode/suite coverage), GAP-0022 (test-count doc drift)
  - Reopen: GAP-0011 (coverage), GAP-0018 (fuzz -- also superseded by GAP-0020)
  - Remaining blocked/deferred (unchanged): GAP-0014, GAP-0015, GAP-0016, GAP-0017

### 1.2 Open Gaps -- After This Phase

| Gap-ID | Title | Category | Severity | Status | Action |
|--------|-------|----------|----------|--------|--------|
| GAP-0011 | No code coverage measurement in CI | CI | Medium | Reopen | reopen-existing |
| GAP-0014 | Wire Geode to consume types from this package | Functionality | High | Blocked | keep-open (blocked by downstream) |
| GAP-0015 | DateRange deferred -- pending datetime package | Functionality | Low | Deferred | keep-open (deferred) |
| GAP-0016 | Geographic `st_*` helpers staged for future release | Functionality | Low | Deferred | keep-open (deferred) |
| GAP-0017 | Port Geode integration tests for type consumption | Testing | Medium | Blocked | keep-open (blocked by downstream) |
| GAP-0018 | Fuzzing / property-based testing for parsers | Testing | High | Reopen (regression) | reopen-existing; supersede with GAP-0020 |
| GAP-0019 | AT-NFR-003 -- CI is Linux/x86_64 only, contradicts "Cross-Platform" README claim | Compliance | **Critical** | Open | create-new |
| GAP-0020 | `tests/fuzz.zig` does not compile under Zig 0.16 (`std.testing.fuzz` signature change) | Testing / Compliance | **Critical** | Open | create-new |
| GAP-0021 | `test-extensions` + `test-performance` not wired into `.gitlab-ci.yml`; `test-integration` misses ReleaseSmall | CI | High | Open | create-new |
| GAP-0022 | Test-count drift: `README.md` says 230; `GAP_ANALYSIS.md` says 272; actual runnable = 262 | Docs | Low | Open | create-new |

### 1.3 Severity Rubric (this repo)

- **Critical:** Broken advertised NFR (cross-platform claim), or tooling regression that silently breaks a declared invariant (fuzz suite).
- **High:** CI surface gap for already-declared test suite; reopened closures where the original fix regressed.
- **Medium:** Doc drift of measurable claims; incomplete optimize-mode coverage for non-unit suites.
- **Low:** Inventory / metadata / counts / blocked externals.

## 2. New Gaps

### GAP-0019: CI is Linux/x86_64 only -- contradicts README "Cross-Platform" claim

- **Category:** Compliance
- **Severity:** Critical
- **Requirement source:** Issue #20 AT-NFR-003; `README.md:13` ("Cross-Platform: Linux, macOS, Windows, aarch64 support"); spec `docs/REQUIREMENTS.md` AT-NFR-003
- **Current state (evidence):**
  - `.gitlab-ci.yml:5..7` -- `default.tags: [company]` single runner pool.
  - `.gitlab-ci.yml:88, 97, 108, 119, 129, 140, 150, 161, 178` -- every job hard-codes `image: debian:bookworm-slim`.
  - `.gitlab-ci.yml:42..76` -- the inline install script detects aarch64 but no job tags an aarch64 runner; no Windows or macOS runner present.
  - `docs/audit/gap-trace.md:131..142` -- detailed confirmation of single-runner topology.
- **Why this is a gap:** The README publicly promises macOS/Windows/aarch64, yet CI runs only on Linux/x86_64. There is no enforcement of the advertised NFR; regressions on other platforms will not be detected.
- **Impact / Risk:** Users relying on the README claim receive silent breakage on macOS, Windows, or aarch64. For a "portable value types" library this is the central value proposition.
- **Recommended fix:**
  1. Add `parallel:matrix` jobs covering `macos` (GitLab SaaS macOS runner) and `windows` (shared Windows runner), plus a `tags: [company, aarch64]` job for Linux aarch64.
  2. Build + run unit and integration test suites on each.
  3. OR: narrow the README claim to "Linux x86_64 supported; cross-platform intended but not CI-verified," and reduce severity of the remaining gap to Medium.
- **Acceptance criteria:**
  - CI runs `zig build test` on at least `{linux-amd64, linux-aarch64, macos, windows}`, all green, before the README cross-platform claim is re-asserted, **OR** README is updated to match current CI coverage.

### GAP-0020: `tests/fuzz.zig` does not compile under Zig 0.16 (`std.testing.fuzz` signature change)

- **Category:** Testing / Compliance
- **Severity:** Critical
- **Requirement source:** Originally closed as GAP-0018 in `docs/GAP_ANALYSIS_RESOLVED.md:82..84`. Regressed due to upstream Zig API change.
- **Current state (evidence):**
  - `tests/fuzz.zig:109..115` -- fuzz target passes `fn (_: void, input: []const u8) anyerror!void` into `std.testing.fuzz`, but Zig 0.16.0 now expects `fn (context, *Smith) anyerror!void`.
  - `docs/audit/gap-trace.md:20..33` -- `zig build test-fuzz --summary all` fails compilation with 10 errors (one per fuzz test: lines ~25..114 of `tests/fuzz.zig`).
  - `.gitlab-ci.yml:176..188` -- `fuzz` job runs `timeout 60 zig build test --fuzz` (unit tests, not `test-fuzz`). It therefore does **not** surface the broken fuzz suite; the failure is silently masked on `schedule`-triggered runs.
  - `docs/GAP_ANALYSIS.md:77` claims "Fuzz tests ... 10 ... Passing," which no longer holds.
- **Why this is a gap:**
  1. 10 declared tests are unusable -- the previously claimed closure of GAP-0018 is refuted.
  2. CI's `fuzz` job does not execute the broken suite, giving a false green signal.
  3. Documentation (`GAP_ANALYSIS.md`) advertises a test count that depends on the broken suite.
- **Impact / Risk:** Parser invariants (IP, MAC, URL, domain, lat/lon, vector) are advertised as fuzzed. They are not. Any regression in parsers will pass CI and ship.
- **Recommended fix:**
  1. Port each of the 10 `test "fuzz ..."` blocks in `tests/fuzz.zig` to the Zig 0.16 API -- replace the `[]const u8` run-argument with `*std.testing.Smith` (or the equivalent current API name) and use `Smith.readBytes(...)` for input.
  2. Update the CI `fuzz` job to invoke `zig build test-fuzz --fuzz` (not `zig build test --fuzz`) so the correct target is exercised.
  3. Add a non-fuzz compile check (`zig build test-fuzz --summary all`) to the default pipeline so the suite's buildability is gated on MRs.
- **Acceptance criteria:**
  - `zig build test-fuzz --summary all` passes locally and in CI on Zig 0.16.
  - CI `fuzz` job exits 0 or 124 (timeout) but never with a compile error.
  - `docs/GAP_ANALYSIS.md` test table reinstates "10 Passing" only after the compile fix lands.

### GAP-0021: `test-extensions` + `test-performance` not in CI; `test-integration` missing ReleaseSmall

- **Category:** CI
- **Severity:** High
- **Requirement source:** Issue #21 AT-NFR-004 (optimize-mode coverage); `CONTRIBUTING.md` "Tests pass on all optimization levels."
- **Current state (evidence):**
  - `.gitlab-ci.yml:95..167` defines only unit + integration jobs. Grep for `test-extensions` or `test-performance` inside `.gitlab-ci.yml` returns no match.
  - Integration coverage matrix (from `docs/audit/gap-trace.md:146..151`):

    | Mode         | Unit | Integration | Extensions | Performance |
    |--------------|:----:|:-----------:|:----------:|:-----------:|
    | Debug        | yes  | yes         | no         | no          |
    | ReleaseSafe  | yes  | yes         | no         | no          |
    | ReleaseFast  | yes  | yes         | no         | no          |
    | ReleaseSmall | yes  | **no**      | no         | no          |

  - `build.zig` exposes `test-extensions` and `test-performance` targets, and `zig build test-extensions` + `zig build test-performance` pass locally (11/11 and 9/9 per trace), confirming the suites are runnable -- they are simply not invoked from CI.
- **Why this is a gap:** CONTRIBUTING.md and issue #21 (label `status::closed`) assert that all optimize modes are exercised for all declared test suites. In reality only the unit slice is fully covered; the issue-level "closed" label is defensible for the letter of the spec but overstates coverage of the actually-declared test surface.
- **Impact / Risk:** Type-extension regressions (cross-feature invariants) and performance-shaped edge cases (bulk parsing, large-N searches) can land on `main` without CI visibility. A ReleaseSmall-only integration regression (e.g., size-optimized inlining of parsers) ships undetected.
- **Recommended fix:**
  1. Add `test-extensions` + `test-performance` CI jobs (Debug at minimum; preferably all four modes via `parallel:matrix` on `-Doptimize`).
  2. Add a `test-integration-release-small` job mirroring `test-integration-release-{safe,fast}`.
  3. Re-verify issue #21's `status::closed` label -- either retain after CI expansion, or reopen with a scoped plan.
- **Acceptance criteria:**
  - `.gitlab-ci.yml` contains jobs that execute `zig build test-extensions` and `zig build test-performance` on at least Debug, and `test-integration -Doptimize=ReleaseSmall`.
  - Pipeline green on `main`.

### GAP-0022: Test-count drift across README and GAP_ANALYSIS

- **Category:** Docs
- **Severity:** Low
- **Requirement source:** Derived from scanner's test-count reconciliation, `docs/audit/gap-trace.md:37..45`.
- **Current state (evidence):**
  - `README.md:14` -- "230 Tests"
  - `docs/GAP_ANALYSIS.md:77` -- "Total ... 272 ... All passing" (table sums 233 + 9 + 11 + 9 + 10)
  - Actual runnable total: **262** (233 + 9 + 11 + 9); the 10 fuzz tests do not compile (see GAP-0020)
- **Why this is a gap:** Two public numbers disagree with each other and with ground truth; both overstate or understate the verified runnable count.
- **Impact / Risk:** Minor; erodes document trustworthiness and complicates future audits.
- **Recommended fix:**
  1. Update `README.md:14` to `262 Tests` (or neutral wording "200+ tests across 5 suites").
  2. Update `docs/GAP_ANALYSIS.md:70..77` test table to show 262 runnable + fuzz marked broken until GAP-0020 closes.
  3. Re-derive counts from `zig build ... --summary all` rather than hand-maintained values.
- **Acceptance criteria:**
  - `README.md` and `docs/GAP_ANALYSIS.md` agree with each other and with the output of the four `zig build test*` commands.

## 3. Updated / Reopened Gaps

| Gap-ID | Change | Updated Evidence |
|--------|--------|------------------|
| GAP-0011 | **Reopen** (closure refuted) | `docs/audit/gap-trace.md:120`: "No evidence of coverage measurement in current pipeline." `.gitlab-ci.yml` contains no `coverage:`/`kcov`/`llvm-cov`/artifacts:reports:coverage. Closure evidence in `docs/GAP_ANALYSIS_RESOLVED.md:71..72` only added Makefile targets -- never wired into CI. |
| GAP-0018 | **Reopen** as regression; supersede with GAP-0020 for remediation tracking | `tests/fuzz.zig:109..114` does not compile under Zig 0.16. Closure claim at `docs/GAP_ANALYSIS_RESOLVED.md:82..84` is out of date due to upstream API change. |

Rationale for both reopens: per severity rubric, "refuted closures" are High. They are tracked as reopen rather than create-new so traceability to original closure evidence is preserved.

### Recommendation on GAP-0011

Two acceptable resolutions:

1. **Reopen and fix:** Add an `llvm-cov` / `kcov`-based job emitting `coverage.xml` to `.gitlab-ci.yml`; surface as `coverage:` regex. Raise the issue severity back to its 2026-03 Medium classification.
2. **Explicit won't-do:** Update `docs/GAP_ANALYSIS_RESOLVED.md` to record "coverage intentionally not measured in CI because Zig lacks first-class coverage tooling; Makefile targets remain for local use." Close permanently under "Won't Do."

The gap-sync agent should surface this decision to the maintainer rather than auto-selecting.

## 4. Resolved Gaps (ready to move to GAP_ANALYSIS_RESOLVED.md)

None this phase. All 2026-03-23 closures either remain closed (`GAP-0005`, `GAP-0007`, `GAP-0009`, `GAP-0012`, `GAP-0013`, etc.) or are reopened above (GAP-0011, GAP-0018).

## 5. Gap Priority Matrix

| Severity  | Count | Gap-IDs |
|-----------|:-----:|---------|
| Critical  | 2     | GAP-0019, GAP-0020 |
| High      | 3     | GAP-0014, GAP-0018 (reopen), GAP-0021 |
| Medium    | 2     | GAP-0011 (reopen), GAP-0017 |
| Low       | 3     | GAP-0015, GAP-0016, GAP-0022 |

Total open post-phase: **10** (4 new + 2 reopen + 4 pre-existing blocked/deferred).

## 6. Instructions for gap-sync (Phase 4)

### 6.1 Create-as-new (new GitLab issues)

- **GAP-0019** -- "AT-NFR-003: CI is Linux/x86_64 only; contradicts README cross-platform claim"
  - Labels: `requirement`, `gap`, `status::open`, `priority::critical`, `type::enhancement`
  - Link: issue #20 (existing), `README.md:13`
- **GAP-0020** -- "Fuzz suite broken under Zig 0.16 (std.testing.fuzz signature change)"
  - Labels: `requirement`, `gap`, `status::open`, `priority::critical`, `type::bug`, `test::unit`
  - Supersedes GAP-0018; reference original in description.
- **GAP-0021** -- "AT-NFR-004: extend CI to cover test-extensions, test-performance, and ReleaseSmall integration"
  - Labels: `requirement`, `gap`, `status::open`, `priority::high`, `type::enhancement`
  - Link: issue #21 (existing)
- **GAP-0022** -- "Test-count doc drift: README vs GAP_ANALYSIS vs actual 262"
  - Labels: `gap`, `status::open`, `priority::low`, `type::bug`, `docs::user`

### 6.2 Reopen-existing (flip labels on existing issues)

- **GAP-0011** (code coverage) -- remove `status::closed`, apply `status::open`, `priority::medium`. OR write a "won't do" decision note; flag for maintainer review.
- **GAP-0018** (fuzz) -- remove `status::closed`, apply `status::open`, `priority::critical`. Cross-link GAP-0020.

### 6.3 No-op (remain as-is)

- **GAP-0014, GAP-0015, GAP-0016, GAP-0017** -- retain current `blocked` / `deferred` state; no new work this cycle.
- Issue **#21 AT-NFR-004** -- keep `status::closed` defensible for unit-slice only; GAP-0021 tracks the non-unit expansion separately to preserve the closure trail.

### 6.4 Doc updates to stage alongside sync

- Append GAP-0019..GAP-0022 rows to `docs/GAP_ANALYSIS.md` "Gaps" table.
- Flip GAP-0011 and GAP-0018 rows in `docs/GAP_ANALYSIS.md` from "Closed" back to "Open (regressed)"; leave `docs/GAP_ANALYSIS_RESOLVED.md` entries intact with an added "Regressed on 2026-04-18" note.
- Update `README.md:14` and `docs/GAP_ANALYSIS.md:70..77` test counts to 262 (per GAP-0022).

## 7. Artefact Paths

- This file: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-detected.md`
- Input trace: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-trace.md`
- Requirements inventory: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-requirements.md`
- Prior-state ledger: `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md`
- Prior-state resolved ledger: `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS_RESOLVED.md`
- Evidence sources for new gaps:
  - `/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml` (L5..7, L88..188)
  - `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` (L25..115)
  - `/home/benji/src/devnw/zig/advanced-types/README.md` (L13..14)
