# Gap Analysis -- Requirements Inventory

Generated: 2026-04-18
Phase: 1 of `/codepros:audit`
Repo: `gitlab.com/devnw/zig/advanced-types`
Language / toolchain: Zig 0.15.1+ (CI pinned to 0.16.0)
Scope: full repo (`src/`, `tests/`, `examples/`, `build.zig`, `.gitlab-ci.yml`, docs)

This document is the authoritative input for downstream
`gap-scanner` / `gap-detector` / `gap-sync` agents. Every tracked requirement
has a GitLab issue; every doc-sourced requirement is either already in the
tracker or was created in this run.

## 1. Platform & Authentication

| Item | Value |
|------|-------|
| Platform | GitLab (SaaS) |
| Project | `devnw/zig/advanced-types` |
| Issues CLI | `glab` v1.x, authenticated as `benjiv` |
| Auth status | OK (token warning from config file; all API calls succeed) |

## 2. Label Taxonomy

Labels **present before this run** (kept as-is):

| Label | Purpose | Color |
|-------|---------|-------|
| `gap` | Gap between docs and tracker | #fbca04 |
| `priority::critical` | Security / blocking | #dc143c |
| `priority::high` | Important for next release | #ff6347 |
| `priority::medium` | Should be addressed | #ffa500 |
| `priority::low` | Nice to have | #90ee90 |
| `type::feature` | New feature | existing |
| `type::bug` | Bug | existing |
| `type::enhancement` | Enhancement | existing |
| `type::security` | Security | existing |
| `sec::vuln`, `sec::remediation` | Security workflow | existing |
| Dev/QA workflow labels | `backlog`, `dev::*`, `qa`, `staged`, `released`, `code-complete`, `needs-validation`, `blocked`, `spec::waiting`, `docs::dev`, `docs::user`, `test::unit`, `test::integration`, `test::load` | existing |
| Jira import tag | `jira-import::DEV` | existing |
| Legacy priority | `priority::0/1/3/4` | existing (kept; new work uses `priority::critical..low`) |

Labels **created in this run**:

| Label | Purpose | Color |
|-------|---------|-------|
| `requirement` | Tracked requirement from docs or README claims | #0052CC |
| `status::open` | Requirement gap open / needs work | #dc143c |
| `status::closed` | Requirement gap closed / satisfied | #36a64f |
| `status::deferred` | Requirement gap deferred / won't do this cycle | #cccccc |

The `requirement` label was then back-applied to issues #1--#12.

## 3. Source Inventory

### 3.1 Documents scanned

| Path | Role |
|------|------|
| `README.md` | Feature claims + Quick Start |
| `CHANGELOG.md` | Feature list (Unreleased only) |
| `CONTRIBUTING.md` | Process requirements (tests/all optimizations, commit style) |
| `SECURITY.md` | Security measures claimed |
| `SUPPORT.md` | Support channels (no requirements) |
| `CODE_OF_CONDUCT.md` | Community policy (no requirements) |
| `CODEOWNERS` | Ownership (`@benjiv`) |
| `docs/README.md` | Doc index |
| `docs/REQUIREMENTS.md` | Primary spec -- 6 functional, 3 packaging, 3 test, 4 documentation, 3 migration items |
| `docs/GAP_ANALYSIS.md` | Repo-level status (also lists 14 historical gaps GAP-0005..GAP-0018) |
| `docs/GAP_ANALYSIS_RESOLVED.md` | Historical closure notes |
| `docs/QUALITY_GAP_ANALYSIS.md` | 13 items (Q1--Q13) -- 10 Closed, 3 Won't Do |
| `docs/PERF_GAP_ANALYSIS.md` | 10 items (P1--P10) -- 2 Closed, 8 Won't Do |
| `docs/SECURITY_GAP_ANALYSIS.md` | 7 items (S1--S7) -- 6 Closed, 1 Won't Do |
| `docs/audit/quality-inventory.md` | Prior audit quality inventory (reference; not a requirement source) |

### 3.2 Code / config scanned (not a requirement source, but cross-checked)

| Path | Notes |
|------|-------|
| `src/root.zig` | Public re-exports (17 types advertised; count matches README) |
| `src/types/network.zig`, `vector.zig`, `geographic.zig`, `url.zig`, `range.zig` | 5 type modules |
| `tests/integration.zig`, `type_extensions.zig`, `performance.zig`, `fuzz.zig` | 4 separate test suites beyond in-module unit tests |
| `build.zig` | Targets: `test`, `test-integration`, `test-extensions`, `test-fuzz`, `test-performance`, `example`, `check` |
| `build.zig.zon` | Zero runtime deps |
| `Makefile` | Dev / CI convenience targets |
| `.gitlab-ci.yml` | Debian x86_64 only; SAST/gitleaks/secrets/dep-scan/SBOM/release components; fuzz job with 60s timeout |
| `.gitlab/issue_templates/` | Bug Report, Feature Request |

## 4. Requirements from the Issue Tracker (authoritative)

All issues carry labels `gap` + `requirement` (the latter added this run) and
a `priority::*` and `type::*` label.

| Issue | ID | Title | Source | State | Priority | Type |
|-------|----|----|-------|-------|----------|------|
| [#1](https://gitlab.com/devnw/zig/advanced-types/-/issues/1) | AT-REQ-001 | Expose reusable network types and helpers | REQUIREMENTS.md | closed | medium | feature |
| [#2](https://gitlab.com/devnw/zig/advanced-types/-/issues/2) | AT-REQ-002 | Expose vector types with distance operations | REQUIREMENTS.md | closed | medium | feature |
| [#3](https://gitlab.com/devnw/zig/advanced-types/-/issues/3) | AT-REQ-003 | Expose geographic value types and distance helpers | REQUIREMENTS.md | closed | medium | feature |
| [#4](https://gitlab.com/devnw/zig/advanced-types/-/issues/4) | AT-REQ-004 | Expose URL and domain parsing/formatting | REQUIREMENTS.md | closed | medium | feature |
| [#5](https://gitlab.com/devnw/zig/advanced-types/-/issues/5) | AT-REQ-005 | Expose generic range support | REQUIREMENTS.md | closed | medium | feature |
| [#6](https://gitlab.com/devnw/zig/advanced-types/-/issues/6) | AT-REQ-006 | Exclude Geode heap/storage hash types | REQUIREMENTS.md | closed | medium | feature |
| [#7](https://gitlab.com/devnw/zig/advanced-types/-/issues/7) | AT-PKG-001 | URL/domain ownership vs `uri` | REQUIREMENTS.md | closed | medium | feature |
| [#8](https://gitlab.com/devnw/zig/advanced-types/-/issues/8) | AT-PKG-002 | DateRange deferred until datetime package exists | REQUIREMENTS.md | **open** | low | feature |
| [#9](https://gitlab.com/devnw/zig/advanced-types/-/issues/9) | AT-PKG-003 | Geode index wrappers stay outside this repo | REQUIREMENTS.md | closed | medium | feature |
| [#10](https://gitlab.com/devnw/zig/advanced-types/-/issues/10) | AT-TEST-001 | Port source-level tests for all type modules | REQUIREMENTS.md | closed | medium | feature |
| [#11](https://gitlab.com/devnw/zig/advanced-types/-/issues/11) | AT-TEST-002 | Preserve cross-feature type-extension coverage | REQUIREMENTS.md | closed | medium | feature |
| [#12](https://gitlab.com/devnw/zig/advanced-types/-/issues/12) | AT-TEST-003 | Preserve integration and performance coverage | REQUIREMENTS.md | closed | medium | feature |
| [#13](https://gitlab.com/devnw/zig/advanced-types/-/issues/13) | -- | Wire Geode to consume types from this package | GAP_ANALYSIS.md | **open** | high | feature |
| [#14](https://gitlab.com/devnw/zig/advanced-types/-/issues/14) | -- | Stage geographic `st_*` spatial query helpers | GAP_ANALYSIS.md | **open** | low | feature |
| [#15](https://gitlab.com/devnw/zig/advanced-types/-/issues/15) | -- | Provide usage examples (vector, geographic, network) | REQUIREMENTS.md Docs section | closed | medium | enhancement |
| [#16](https://gitlab.com/devnw/zig/advanced-types/-/issues/16) | -- | Port Geode-specific integration tests | GAP_ANALYSIS.md | **open** | medium | feature |
| [#17](https://gitlab.com/devnw/zig/advanced-types/-/issues/17) | -- | README Quick Start shows incorrect API usage | README.md | closed | high | bug |

**Issues created in this audit run:**

| Issue | ID | Title | Source | State | Priority | Type |
|-------|----|----|-------|-------|----------|------|
| [#18](https://gitlab.com/devnw/zig/advanced-types/-/issues/18) | AT-NFR-001 | Zero external runtime dependencies | README.md line 10 | closed | high | feature |
| [#19](https://gitlab.com/devnw/zig/advanced-types/-/issues/19) | AT-NFR-002 | Zero-allocation value types | README.md line 12 | closed | high | feature |
| [#20](https://gitlab.com/devnw/zig/advanced-types/-/issues/20) | AT-NFR-003 | Cross-platform (Linux, macOS, Windows, aarch64) | README.md line 13 | **open** | medium | feature |
| [#21](https://gitlab.com/devnw/zig/advanced-types/-/issues/21) | AT-NFR-004 | Tests pass on all four Zig optimization modes | CONTRIBUTING.md | closed | medium | feature |
| [#22](https://gitlab.com/devnw/zig/advanced-types/-/issues/22) | AT-SEC-001 | CI SAST + secret + dep scanning + SBOM every pipeline | SECURITY.md | closed | high | security |

## 5. Doc-Sourced Requirements Cross-Check

Every requirement statement located in repo documentation was matched against
the tracker. The table below is the full cross-check used to decide whether a
new issue needed to be filed.

### 5.1 `docs/REQUIREMENTS.md`

| Item | Tracker coverage |
|------|------------------|
| AT-REQ-001..006 (Functional) | issues #1--#6 |
| AT-PKG-001..003 (Packaging) | issues #7--#9 |
| AT-TEST-001..003 (Test) | issues #10--#12 |
| "Provide one example for vector math" | #15 |
| "Provide one example for geographic distance/proximity" | #15 |
| "Provide one example for network parsing" | #15 |
| "Clearly document URL/domain ownership" | #4 / #7 |
| Migration #1: extract portable type modules first | satisfied by #1--#5; no separate issue needed |
| Migration #2: keep Geode index wrappers in Geode | #9 |
| Migration #3: revisit `hash.zig` later | #6 (scope decision recorded) |

### 5.2 `README.md` feature claims

| Claim | Tracker coverage |
|-------|------------------|
| "Zero Dependencies" | **created #18 (AT-NFR-001)** |
| "17 Public Types" | satisfied via #1--#5 (count verified in `src/root.zig`) |
| "Zero Allocation" | **created #19 (AT-NFR-002)** |
| "Cross-Platform: Linux, macOS, Windows, aarch64" | **created #20 (AT-NFR-003)** -- gap, CI is Linux-only |
| "230 Tests" | status metric, not a requirement -- no issue needed |

### 5.3 `CONTRIBUTING.md`

| Statement | Tracker coverage |
|-----------|------------------|
| "Tests must pass on all optimization levels" | **created #21 (AT-NFR-004)** |
| Conventional Commits, pre-commit hooks, PR review timing | team-process, not a library requirement -- no issue |

### 5.4 `SECURITY.md`

| Security measure claimed | Tracker coverage |
|--------------------------|------------------|
| Memory Safety (Zig compile-time) | language guarantee, not a per-issue requirement |
| Dependency Scanning in CI | **created #22 (AT-SEC-001)** |
| Secret Detection (gitleaks) | covered by #22 |
| Responsible disclosure contact | policy, not a testable requirement |

### 5.5 `docs/*_GAP_ANALYSIS.md` findings

The Q-/P-/S-/GAP-numbered items in the quality, performance, security, and
top-level gap docs are **historical audit findings**, not standalone
requirements. Their open/remaining items are already represented by the 22
tracker issues above. No new issues required from these files.

## 6. Reconciled Requirements List

Grouped by category. State `O` = open, `C` = closed.

### 6.1 Functional (library surface)

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 1 | Network types (IPv4/IPv6/IpAddr/Subnet/Mac) | REQUIREMENTS.md | #1 | C |
| 2 | Vector types (f32/i32/generic) with distance ops | REQUIREMENTS.md | #2 | C |
| 3 | Geographic types + haversine distance | REQUIREMENTS.md | #3 | C |
| 4 | URL + Domain parsing/formatting | REQUIREMENTS.md | #4 | C |
| 5 | Generic range types (`Range(T)`, Int/Uint/Float) | REQUIREMENTS.md | #5 | C |
| 6 | Exclude Geode hash types | REQUIREMENTS.md | #6 | C |

### 6.2 Packaging

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 7 | URL/domain ownership resolved vs `uri` | REQUIREMENTS.md | #7 | C |
| 8 | DateRange deferred until datetime package exists | REQUIREMENTS.md | #8 | **O** (blocked) |
| 9 | Geode index wrappers remain outside this repo | REQUIREMENTS.md | #9 | C |

### 6.3 Test

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 10 | Port source-level tests for all type modules | REQUIREMENTS.md | #10 | C |
| 11 | Preserve cross-feature type-extension coverage | REQUIREMENTS.md | #11 | C |
| 12 | Preserve integration/performance coverage | REQUIREMENTS.md | #12 | C |
| 13 | Port additional Geode integration tests | GAP_ANALYSIS.md | #16 | **O** (blocked) |

### 6.4 Documentation

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 14 | Usage examples for vector/geographic/network | REQUIREMENTS.md | #15 | C |
| 15 | README Quick Start reflects real API | README.md | #17 | C |

### 6.5 Non-Functional (created in this run)

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 16 | Zero external runtime dependencies | README.md | #18 | C |
| 17 | Zero-allocation value types | README.md | #19 | C |
| 18 | Cross-platform CI (Linux x86_64+aarch64, macOS, Windows) | README.md | #20 | **O** |
| 19 | Tests pass on all Zig optimization modes | CONTRIBUTING.md | #21 | C |

### 6.6 Security

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 20 | SAST + secret + dep-scan + SBOM every pipeline | SECURITY.md | #22 | C |

### 6.7 Integration (downstream)

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 21 | Wire Geode to consume this package | GAP_ANALYSIS.md | #13 | **O** (blocked on Geode) |
| 22 | Stage geographic `st_*` spatial helpers for later | GAP_ANALYSIS.md | #14 | **O** (deferred) |

## 7. Downstream Agent Inputs

The following filters are what `gap-scanner` / `gap-detector` / `gap-sync`
should use:

- **All requirements:** `glab issue list --repo devnw/zig/advanced-types --label requirement --all`
- **Open gaps only:** `glab issue list --repo devnw/zig/advanced-types --label requirement --state opened`
- **Functional slice:** title regex `^AT-REQ-\d{3}`
- **Non-functional slice:** title regex `^AT-NFR-\d{3}`
- **Security slice:** title regex `^AT-SEC-\d{3}` or label `type::security`
- **Integration / blocked:** issues #13, #14, #16 (externally gated)

### 7.1 Open gaps snapshot (as of 2026-04-18)

| Issue | Requirement | Blocked on |
|-------|-------------|-----------|
| #8 AT-PKG-002 | DateRange | Zig datetime package |
| #13 | Geode consumer wiring | Geode repo work |
| #14 | `st_*` spatial helpers | Geode wiring + design decision |
| #16 | Port additional Geode integration tests | Geode wiring |
| #20 AT-NFR-003 | Cross-platform CI matrix | **not blocked -- actionable now** |

Issue #20 is the **only fully-unblocked open gap** in this inventory and should be
the first candidate for the `gap-close` phase.

## 8. Conflicts & Ambiguities

1. **Test count.** `README.md` says "230 Tests". `docs/GAP_ANALYSIS.md` table
   says 272 (233 unit + 9 integration + 11 extensions + 9 perf + 10 fuzz).
   Either the README is stale or the GAP_ANALYSIS total is post-audit. Not
   blocking, flagged for downstream docs sync.
2. **Zig version.** `README.md` badge and "Requirements" say 0.15.1+.
   `QUALITY_GAP_ANALYSIS.md` Q11 resolution says "updated CI to 0.15.2".
   Current `.gitlab-ci.yml` has `ZIG_VERSION: "0.16.0"` (bumped 2026-04-18
   per `git log`). Pin and README should be reconciled in a docs-sync issue
   (not filed now -- will surface naturally in gap-close).
3. **Priority legacy labels.** Old `priority::0..4` labels coexist with the
   newer `priority::critical..low`. Only the named labels are used on active
   issues. No action required, noted for awareness.
4. **CI fuzz job is manual/scheduled only** (see `.gitlab-ci.yml` `rules:`).
   Not a conflict, but `gap-scanner` should not assume fuzz runs on every MR.

## 9. Blockers

None for Phase 1. All intended tracker actions completed:

- 5 new issues filed (#18--#22)
- 4 new labels created (`requirement`, `status::open`, `status::closed`,
  `status::deferred`)
- `requirement` label back-applied to #1--#12
- Inventory written to `docs/audit/gap-requirements.md`

Downstream agents have one authoritative query surface (`label=requirement`)
covering all 22 requirement issues across 7 categories.
