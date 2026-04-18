# Gap Determination Ledger

Generated: 2026-04-18 (fresh pass; supersedes prior ledger at commit `f3adc69`)
Phase: 3 of `/codepros:audit` (gap-detector)
Repo: `gitlab.com/devnw/zig/advanced-types`
Platform: GitLab (`glab` CLI); GitHub mirror does not exist.
Toolchain: Zig 0.16.0 (CI + local)
Trace input: `docs/audit/gap-trace.md` (32 reconciled requirements; 26 I / 2 P / 4 N / 0 U)
Requirements input: `docs/audit/gap-requirements.md`
Prior-state inputs: `docs/GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS_RESOLVED.md`, prior `docs/audit/gap-detected.md`

Highest Gap-ID in prior state: **GAP-0022**. Next new Gap-ID if needed: **GAP-0023**.

## 1. Gap Determination Report

### 1.1 Summary

- **Total requirements analyzed:** 32
- **Implemented:** 26 | **Partial:** 2 | **Not Implemented:** 4 | **Unknown:** 0
- **New gaps raised this phase:** 1 (GAP-0023 -- README/CHANGELOG test-count prose drift)
- **Previously open gaps confirmed resolved (close-ready):** 4
  - GAP-0020 fuzz suite ported (`c0e07ee`)
  - GAP-0021 CI mode/suite expansion (`a5abd3e`)
  - GAP-0011 code-coverage measurement in CI (report-only, `20b233c`)
  - GAP-0018 fuzz regression (superseded by GAP-0020 closure, `c0e07ee`)
- **GAP-0022 status:** Partial-resolution. `docs/GAP_ANALYSIS*.md` ledgers were reconciled to 303 in `3702dd1`, but the README and CHANGELOG copies were not refreshed. That doc-surface tail is split out as **GAP-0023** so GAP-0022 can be closed cleanly against its original scope ("ledger reconciliation") and the new finding carries a separate Gap-ID aligned with the stable-ID rule (never re-use an ID, never retroactively widen a closed one).
- **Total open gaps after this phase:** 6
  - Net new actionable: GAP-0023 (docs drift -- trivial edits)
  - Still open (unchanged): GAP-0019 (cross-platform runners), GAP-0014 (Geode consumer), GAP-0015 (DateRange), GAP-0016 (`st_*` helpers), GAP-0017 (Geode integration tests)

### 1.2 Open Gaps -- After This Phase

| Gap-ID | Title | Category | Severity | Status | Action |
|--------|-------|----------|----------|--------|--------|
| GAP-0014 | Wire Geode to consume types from this package | Feature | High | Blocked (external) | keep-open |
| GAP-0015 | DateRange deferred -- blocked on datetime package | Feature | Low | Deferred (external) | keep-open |
| GAP-0016 | Geographic `st_*` helpers staged for future release | Feature | Low | Deferred | keep-open |
| GAP-0017 | Port Geode integration tests for type consumption | Test | Medium | Blocked (external) | keep-open |
| GAP-0019 | AT-NFR-003 -- cross-platform CI runners dormant | CI-CD | High | Partial | keep-open (runner provisioning) |
| GAP-0023 | README + CHANGELOG test-count prose drift (262 / 230 vs actual 303) | Docs | Low | Open | create-new |

### 1.3 Severity Rubric (this repo)

This is a Zig value-types library consumed by downstream packages. Correctness and CI safety outrank feature breadth; docs-drift on publicly advertised numbers is a trust, not a correctness, issue.

- **Critical:** Silent correctness/security regression in an advertised invariant; CI that masks failures.
- **High:** CI surface blindness for an advertised NFR; functional gap that blocks a stated consumer.
- **Medium:** Optional test-suite coverage not enforced in CI; blocked-external integration work.
- **Low:** Doc drift on countable facts; deferred features with explicit scope decisions.

### 1.4 Severity Justification Per Open Gap

| Gap-ID | Severity | Reasoning |
|--------|----------|-----------|
| GAP-0014 | High | Library's reason-for-being is Geode consumption; downstream wiring is the acceptance criterion for the whole extraction. Scope is entirely outside this repo -- **not actionable here**, but severity reflects business impact. |
| GAP-0015 | Low | Single deferred type (`DateRange`); explicit scope decision documented; blocked on a separate package that does not yet exist. |
| GAP-0016 | Low | Spatial `st_*` helpers explicitly deferred by design in `docs/GAP_ANALYSIS.md` §"Intended Boundary". No advertised promise that they ship in this library. |
| GAP-0017 | Medium | Additional Geode integration tests; blocked on GAP-0014. Would raise confidence in the contract but nothing in this repo depends on it. |
| GAP-0019 | High | Downgraded from Critical. YAML scaffolding is present (`505fe43`); the only remaining work is runner provisioning. The README claim is accurate *in intent*, misleading *in CI evidence* -- so the risk of silent per-platform regressions is real but it is not a code bug. Remains High until a runner runs. |
| GAP-0023 | Low | Public README and CHANGELOG prose overstate breakage ("fuzz suite currently broken under Zig 0.16") and understate count. Code is correct; only prose is wrong. Pure docs edit. |

## 2. New Gaps

### GAP-0023: README + CHANGELOG test-count prose drift

- **Category:** Docs
- **Severity:** Low
- **Requirement source:** `docs/audit/gap-requirements.md` §8 #1 ("Test-count drift is re-emerging"); `docs/audit/gap-trace.md` §1.1 reconciliation table; stable-ID policy in `docs/audit/gap-requirements.md` §7.2.
- **Current state (evidence):**
  - `README.md:14` -- *"**262 Tests**: Comprehensive unit, integration, type-extension, and performance tests (fuzz suite currently broken under Zig 0.16 -- see GAP-0020)"* (verified via `sed -n '10,20p' README.md` on 2026-04-18).
  - `CHANGELOG.md:17` -- *"230 tests (221 unit + 9 integration)"* inside the `[Unreleased]` block (verified via `sed -n '10,25p' CHANGELOG.md` on 2026-04-18).
  - Ground truth (from `docs/audit/gap-trace.md:19..31`, `zig build ... --summary all`, Zig 0.16.0 local): **303 runnable** -- 248 unit + 9 integration + 11 extensions + 9 performance + 16 parser-edges + 10 fuzz. Fuzz suite is green (`c0e07ee` closed GAP-0020).
  - `docs/GAP_ANALYSIS.md:70..78` and all three specialised ledgers (`QUALITY_GAP_ANALYSIS.md`, `PERF_GAP_ANALYSIS.md`, `SECURITY_GAP_ANALYSIS.md`) correctly carry 303 (reconciled in `3702dd1` under GAP-0022).
- **Why this is a gap:** Two load-bearing public documents contradict the authoritative ledgers and understate verified coverage. The README additionally advertises a fuzz-broken state that no longer exists; external users may wrongly conclude parsers are un-fuzzed, or see a stale "broken" marker for a now-green suite.
- **Impact / Risk:** Low -- no runtime effect, no security exposure. Primary risk is erosion of documentation trust and onboarding confusion: a user who reads the README might skip fuzzing because of the stale "currently broken" phrase, or fork expecting ~262 tests and trip over 303 in CI.
- **Recommended fix:**
  1. Replace `README.md:14` with: *"**303 Tests**: Unit, integration, type-extension, performance, parser-edge, and fuzz suites (all green on Zig 0.16)."*
  2. Update `CHANGELOG.md:17` under `[Unreleased]` to the itemised 303 breakdown: `303 tests (248 unit + 9 integration + 11 extensions + 9 performance + 16 parser-edges + 10 fuzz)`.
  3. Re-derive counts from `zig build ... --summary all` output rather than hand-editing in future passes (prevents re-drift).
- **Acceptance criteria:**
  - `README.md` and `CHANGELOG.md` both report 303 tests with no "broken fuzz" language.
  - The four authoritative ledgers (`docs/GAP_ANALYSIS.md`, `docs/QUALITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md`) remain consistent at 303.
  - Change verifiable via a single `grep -n "262 Tests\|230 tests\|fuzz suite currently broken" README.md CHANGELOG.md` that returns zero matches.

## 3. Updated / Status Migrations Since `f3adc69`

The prior ledger at `f3adc69` listed 10 open gaps. Evidence from `docs/audit/gap-trace.md` §6 and the closure commits below shows 5 of those migrated.

| Gap-ID | Prior Status | New Status | Evidence | Closure commit |
|--------|--------------|------------|----------|----------------|
| AT-NFR-004 (issue #21) | Partial | **Implemented** | `.gitlab-ci.yml:176..198, 221, 165` runs `test-extensions`, `test-performance`, `test-parser-edges`, ReleaseSmall integration; unit + integration green on Debug/Safe/Fast/Small locally (4x 248/248) | `a5abd3e` |
| GAP-0018 | Refuted (regression) | **Implemented** | `tests/fuzz.zig` ported to `std.testing.Smith`; 10/10 pass via `zig build test-fuzz` | `c0e07ee` (supersedes GAP-0020) |
| GAP-0020 | Open (new critical, f3adc69) | **Implemented** | same as GAP-0018 row | `c0e07ee` |
| GAP-0021 | Open (high, f3adc69) | **Implemented** | `.gitlab-ci.yml` CI expansion; new jobs green on `main` | `a5abd3e` |
| GAP-0011 | Refuted | **Implemented (report-only)** | `.gitlab-ci.yml:307..332` kcov job; HTML artefact published; percentage-gate explicitly deferred in `docs/audit/gap-close-blockers.md` | `20b233c` |
| GAP-0022 | Open (low, f3adc69) | **Implemented (ledger scope)** | All four `*_GAP_ANALYSIS.md` ledgers and `docs/GAP_ANALYSIS.md` reconciled to 303 | `3702dd1` |

### Additional closures from the intervening pass (not previously tracked as open in `f3adc69`)

These are recorded for trace continuity; no status migration relative to the prior ledger is required because they were introduced and closed inside the same audit cycle.

| ID | Evidence | Closure |
|----|----------|---------|
| Q26 / SAST-01 (Subnet prefix_len) | `src/types/network.zig:493..499, 555..588` | `503c1f5`, `1234a9f` |
| Q25 / SAST-04 (Url/Domain slice lifetime) | `src/types/url.zig:31..46, 158..166` | `5c97228` |
| SAST-05 / SAST-07 / NEW-01 (Url parse hardening) | `src/types/url.zig:190..` | `f175133` |
| SAST-09 (SSRF classification) | `src/types/network.zig:155, 394` | `a178648` |
| NEW-02 (IDN/Punycode scoped won't-do) | `SECURITY.md:55..81` | `df972dd` |
| SC-01 (CI-catalog SHA pinning won't-do) | `.gitlab-ci.yml:11..24` (`@v1.7.1` tags; platform-policy override) | `152d0f8` |
| Q33 / Q10 (parser edge tests) | `tests/parser_edge_cases.zig` + CI `test-parser-edges` | `9e937b5` |
| Q36 / Q11 (Zig version pin) | `build.zig.zon:5`, `README.md:4, 93`, `.gitlab-ci.yml:27` | `3702dd1` |
| D1 (ReleaseFast overflow-wrap docs) | README "Build Modes and Overflow Semantics" | `0c2ebbd` |
| D2 (Non-local `@intCast(u5)` invariant) | `src/types/network.zig:555..588` | `1234a9f` |
| Q15 (bracket-parser duplication) | `src/types/url.zig` helper consolidation | `ca54cdb` |
| P1 / I1 (`zig build bench` harness) | `bench/main.zig`, `build.zig:124..137`, `.gitlab-ci.yml:203..212` | `d786b46` |

## 4. Resolved Gaps (ready to move to GAP_ANALYSIS_RESOLVED.md)

| Gap-ID | Resolution Evidence | Evidence commit |
|--------|---------------------|-----------------|
| GAP-0011 | `.gitlab-ci.yml:307..332` kcov job, HTML artefact, coverage regex. Report-only scope; percentage-gate deferred in `docs/audit/gap-close-blockers.md`. | `20b233c` |
| GAP-0018 | `tests/fuzz.zig` uses `std.testing.Smith`; 10/10 pass via `zig build test-fuzz`; prior regression closed. | `c0e07ee` |
| GAP-0020 | Same as GAP-0018; fuzz signature migrated to Zig 0.16; CI invokes `zig build test-fuzz`. | `c0e07ee` |
| GAP-0021 | `.gitlab-ci.yml` carries `test-extensions` (L176), `test-performance` (L187), `test-parser-edges` (L198), `test-integration -Doptimize=ReleaseSmall` (L165), `test-release-small` (L221). | `a5abd3e` |
| GAP-0022 | `docs/GAP_ANALYSIS.md:70..78` + three specialised ledgers all reconciled to 303. Remaining README/CHANGELOG drift split into **GAP-0023** (does not widen the original GAP-0022 scope). | `3702dd1` |

`gap-sync` should flip the `status::closed` label on issues **#30, #32, #24, #25, #27** to match and close tracker state.

## 5. Gap Priority Matrix

| Severity | Count | Gap-IDs |
|----------|:-----:|---------|
| Critical | 0 | -- |
| High | 2 | GAP-0014, GAP-0019 |
| Medium | 1 | GAP-0017 |
| Low | 3 | GAP-0015, GAP-0016, GAP-0023 |

Total open post-phase: **6** (5 carried from prior ledger with unchanged blocked/deferred/partial status, 1 net new from GAP-0023).

## 6. Instructions for gap-sync (Phase 4)

### 6.1 Create-as-new (new GitLab issue)

- **GAP-0023** -- "README + CHANGELOG test-count prose drift (262/230 vs actual 303)"
  - Labels: `gap`, `gap-analysis`, `gap-partial`, `status::open`, `priority::low`, `severity::low`, `type::bug`, `docs::user`
  - Blocks: none; trivial docs edit.

### 6.2 Close-existing (flip labels + tracker state)

- **#30 / GAP-0011** -- apply `gap-implemented`, retain `status::closed`, close state. Reference `20b233c`.
- **#32 / GAP-0018** -- apply `gap-implemented`, retain `status::closed`, close state. Reference `c0e07ee`.
- **#24 / GAP-0020** -- apply `gap-implemented`, retain `status::closed`, close state. Reference `c0e07ee`.
- **#25 / GAP-0021** -- apply `gap-implemented`, retain `status::closed`, close state. Reference `a5abd3e`.
- **#27 / GAP-0022** -- apply `gap-implemented`, retain `status::closed`, close state. Reference `3702dd1`. Cross-link to the new GAP-0023 for the prose-level tail.

### 6.3 No-op (remain as-is)

- **GAP-0014 / GAP-0015 / GAP-0016 / GAP-0017** -- retain `status::open` + blocked/deferred labels. No new work this cycle.
- **#23 / GAP-0019** -- retain `gap-partial` + `status::open`. Runner provisioning is the only action; tracked in `docs/audit/gap-close-blockers.md`.
- Label-vs-state drift on **#18, #19, #21, #22** (noted in `gap-requirements.md` §8 #3): these carry `status::closed` but remain `state=opened` in GitLab. Close the tracker state to match label truth; no gap.

### 6.4 Doc updates to stage alongside sync

- Flip GAP-0011, GAP-0018, GAP-0020, GAP-0021, GAP-0022 rows in `docs/GAP_ANALYSIS.md` "Gaps" table from their current open/partial statuses to "Closed" with commit references.
- Move the five newly-resolved Gap-ID stanzas into `docs/GAP_ANALYSIS_RESOLVED.md` under a "Closed on 2026-04-18 -- Fourth Gap Closure Pass" heading, preserving the existing entries.
- Add the GAP-0023 row to `docs/GAP_ANALYSIS.md` "Gaps" table.
- Execute the README/CHANGELOG edits described in GAP-0023 §Recommended fix in the same MR as the GAP-0023 issue closure (closes the gap in the same commit).

## 7. Blockers

| Blocker | Category | Detail | Impact |
|---------|----------|--------|--------|
| Cross-platform CI runners (macOS / Windows / Linux-aarch64) | Infrastructure | Jobs exist in `.gitlab-ci.yml` as `allow_failure: true` placeholders; no runners provisioned. | Blocks full closure of GAP-0019 / AT-NFR-003. Tracked in `docs/audit/gap-close-blockers.md`. Not actionable inside this repo. |
| Coverage percentage gate | Scope decision | Coverage is report-only in CI; deferred by design until a baseline is established. | Not a gap -- explicit scope decision (`docs/audit/gap-close-blockers.md`). |
| Geode repo wiring | External project | GAP-0014 / GAP-0017 depend on downstream consumption. | Not actionable inside this repo. |
| Datetime package | External | GAP-0015 `DateRange` blocked on upstream. | Not actionable inside this repo. |

No new blockers introduced this phase.

## 8. Artefact Paths

- This file: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-detected.md`
- Input trace: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-trace.md`
- Requirements inventory: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-requirements.md`
- Prior-state ledgers:
  - `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md`
  - `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS_RESOLVED.md`
- Evidence sources for GAP-0023:
  - `/home/benji/src/devnw/zig/advanced-types/README.md` (L10..14)
  - `/home/benji/src/devnw/zig/advanced-types/CHANGELOG.md` (L15..17)
  - `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md` (L70..78, reconciled)
- Evidence sources for newly-resolved gaps:
  - `/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml` (L165, 176, 187, 198, 221, 307..332)
  - `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` (Zig 0.16 Smith API)
  - `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md` and specialised ledgers (303 test count)
