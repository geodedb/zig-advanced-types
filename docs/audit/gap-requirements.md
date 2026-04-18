# Gap Analysis -- Requirements Inventory

Generated: 2026-04-18 (fresh pass; supersedes prior revision at commit `f3adc69`)
Phase: 1 of `/codepros:audit` (orientation / requirements gather)
Repo: `gitlab.com/devnw/zig/advanced-types`
Language / toolchain: Zig 0.16.0 (manifest floor + CI + local; README badge aligned)
Scope: full repo (`src/`, `tests/`, `examples/`, `bench/`, `build.zig`, `.gitlab-ci.yml`, `docs/`)

This document is the canonical input for downstream `gap-scanner`,
`gap-detector`, and `gap-sync` phases. All Gap-IDs listed here are stable
and cross-reference the prior-state ledgers in `docs/GAP_ANALYSIS.md`,
`docs/GAP_ANALYSIS_RESOLVED.md`, and `docs/audit/gap-detected.md`. New
work in this phase only adds labels and confirms state; no Gap-IDs are
reissued.

## 1. Platform & Authentication

| Item | Value |
|------|-------|
| Authoritative tracker | GitLab SaaS |
| Project path | `devnw/zig/advanced-types` |
| Project full name | "Developer Network / Zig Shared Projects / advanced-types" |
| Issues CLI | `glab` v1.x, authenticated as `benjiv` |
| Auth status | OK (API calls succeed; `glab auth status` emits an "invalid token" warning from the config file -- false positive, not blocking) |
| GitHub mirror at `devnw/zig-advanced-types` | **Does not exist** (`gh repo view` returns "Could not resolve to a Repository") -- see Section 9 blocker entry |

The originating prompt nominated GitHub `devnw/zig-advanced-types` as
the platform. The real git remote (`origin`) resolves to the GitLab
project above. All tracker operations in this phase and downstream
phases use GitLab.

## 2. Label Taxonomy

### 2.1 Labels present before this run (kept as-is)

| Label | Purpose |
|-------|---------|
| `gap` | Pre-existing audit marker (applied to issues #1..#27, #30, #32) |
| `priority::critical`, `priority::high`, `priority::medium`, `priority::low` | Prioritization (legacy `priority::0..4` also present; new work uses the named labels) |
| `type::feature`, `type::bug`, `type::enhancement`, `type::security` | Issue type |
| `requirement` | Tracked requirement from docs or README claims |
| `status::open`, `status::closed`, `status::deferred` | Requirement-gap state |
| `sec::vuln`, `sec::remediation` | Security workflow |
| `quality`, `performance`, `refactor`, `tooling`, `testing`, `test::unit`, `test::integration`, `test::load`, `docs`, `docs::dev`, `docs::user` | Category tags |
| `backlog`, `backlog::prioritized`, `dev::active`, `dev::blocked`, `dev::on-hold`, `qa`, `code-complete`, `needs-validation`, `blocked`, `released`, `customer::needs-information`, `jira-import::DEV` | Workflow tags |

### 2.2 Labels created in this run

| Label | Color | Purpose |
|-------|-------|---------|
| `gap-analysis` | `#fbca04` | Gap-analysis audit finding (phase-1 requirements inventory) |
| `gap-implemented` | `#36a64f` | Requirement is fully implemented and verified |
| `gap-partial` | `#ffa500` | Requirement is partially implemented (caveats recorded in ledger) |
| `gap-not-implemented` | `#dc143c` | Requirement is not implemented |
| `severity::critical` | `#dc143c` | Gap severity: Critical (broken advertised invariant / silent data loss) |
| `severity::high` | `#ff6347` | Gap severity: High (CI surface gap / regressed closure) |
| `severity::medium` | `#ffa500` | Gap severity: Medium (doc drift / incomplete optimize-mode coverage) |
| `severity::low` | `#90ee90` | Gap severity: Low (inventory / metadata / blocked externals) |

Downstream `gap-detector` and `gap-sync` phases MAY apply the
`gap-implemented` / `gap-partial` / `gap-not-implemented` labels on top
of the existing `status::*` labels. This phase does not relabel issues;
it only ensures the taxonomy is present.

## 3. Source Inventory

### 3.1 Requirements sources scanned (10 files, authoritative)

| Path | Role |
|------|------|
| `docs/REQUIREMENTS.md` | Primary spec -- 6 functional, 3 packaging, 3 test, 4 documentation, 3 migration statements |
| `README.md` | Feature claims (zero-deps / zero-alloc / cross-platform / 17 types / 262-or-303 tests / 0.16.0+) + Quick Start + "Build Modes and Overflow Semantics" |
| `CHANGELOG.md` | `[Unreleased]` only; test count (230) is stale vs README (262) and vs resolved-ledger total (303) |
| `CONTRIBUTING.md` | Process requirements -- Conventional Commits, `make ci`, "Tests must pass on all optimization levels" |
| `SECURITY.md` | Threat model + "Security Measures" (memory safety, dep scanning, gitleaks, SSRF defense, URL hardening) + scoped Won't-Do for IDN/Punycode |
| `docs/GAP_ANALYSIS.md` | Authoritative per-gap ledger (Gap-IDs GAP-0005..GAP-0022 + functional boundary table) |
| `docs/GAP_ANALYSIS_RESOLVED.md` | Closure notes with commit hashes for every closed gap |
| `docs/QUALITY_GAP_ANALYSIS.md` | 41 quality findings (Q1..Q41) with PriorityScore |
| `docs/PERF_GAP_ANALYSIS.md` | 15 perf findings (P1..P10 + I1, D1, D2, A1, A3..A5, M3, S1..S3) with PerfScore |
| `docs/SECURITY_GAP_ANALYSIS.md` | 15 security findings (S1..S7 + SAST-01/04/05/07/09 + SC-01 + NEW-01/02) with Risk score |

### 3.2 Audit artifacts from prior phase (context only; not requirements sources)

| Path | Role |
|------|------|
| `docs/audit/gap-trace.md` | Scanner output from last pass |
| `docs/audit/gap-detected.md` | Gap determination ledger with new Gap-IDs GAP-0019..GAP-0022 |
| `docs/audit/gap-close-plan.md`, `gap-close-verify.md`, `gap-close-blockers.md`, `GAP_CLOSE_REPORT.md` | Closure evidence (this is the audit artefact downstream of the requirements inventory) |
| `docs/audit/{quality,perf,security}-inventory.md`, `...-review.md`, `...-scan.md` | Sub-audit artefacts |
| `docs/audit/AUDIT_SUMMARY.md` | Roll-up |

### 3.3 Code / config / build scanned (cross-check only)

| Path | Notes |
|------|-------|
| `src/root.zig` | 17 public re-exports (matches README "17 Public Types") |
| `src/types/network.zig`, `vector.zig`, `geographic.zig`, `url.zig`, `range.zig` | 5 value-type modules |
| `tests/integration.zig`, `type_extensions.zig`, `performance.zig`, `parser_edges.zig`, `fuzz.zig` | 5 separate suites beyond in-module unit tests |
| `build.zig` | Targets: `test`, `test-integration`, `test-extensions`, `test-performance`, `test-parser-edges`, `test-fuzz`, `example`, `bench`, `check` |
| `build.zig.zon` | Zero runtime deps; `minimum_zig_version` = 0.16.0 (reconciled in Q36 closure) |
| `bench/main.zig` | 5 benchmarks (Ipv4/Ipv6/Url/Subnet/Vector/LatLon) -- landed with P1 closure |
| `Makefile` | Dev / CI convenience targets |
| `.gitlab-ci.yml` | Components (SAST/gitleaks/secrets/dep-scan/SBOM/release); Debian x86_64 primary; dormant matrix jobs for macOS/Windows/Linux-aarch64 (`allow_failure: true` until runner provisioning lands -- GAP-0019 partial) |
| `.gitlab/issue_templates/` | Bug Report, Feature Request |

## 4. Requirements from the Issue Tracker (authoritative)

The tracker holds 47 issues. The 22 requirement-bearing issues (labelled
`requirement`) are the canonical scope; the other 25 issues are finer-grained
audit findings (Q*, perf-D*, SAST-*, SC-*, NEW-*, GAP-00*) that roll up into
the 22 requirement umbrellas.

### 4.1 Requirement issues (label `requirement`)

| Issue | Gap-ID / Spec-ID | Title | Source | State | Priority | Type |
|-------|------------------|----|-------|-------|----------|------|
| [#1](https://gitlab.com/devnw/zig/advanced-types/-/issues/1) | AT-REQ-001 | Expose reusable network types and helpers | REQUIREMENTS.md | closed | medium | feature |
| [#2](https://gitlab.com/devnw/zig/advanced-types/-/issues/2) | AT-REQ-002 | Expose vector types with distance operations | REQUIREMENTS.md | closed | medium | feature |
| [#3](https://gitlab.com/devnw/zig/advanced-types/-/issues/3) | AT-REQ-003 | Expose geographic value types and distance helpers | REQUIREMENTS.md | closed | medium | feature |
| [#4](https://gitlab.com/devnw/zig/advanced-types/-/issues/4) | AT-REQ-004 | Expose URL and domain parsing/formatting | REQUIREMENTS.md | closed | medium | feature |
| [#5](https://gitlab.com/devnw/zig/advanced-types/-/issues/5) | AT-REQ-005 | Expose generic range support | REQUIREMENTS.md | closed | medium | feature |
| [#6](https://gitlab.com/devnw/zig/advanced-types/-/issues/6) | AT-REQ-006 | Exclude Geode heap/storage hash types | REQUIREMENTS.md | closed | medium | feature |
| [#7](https://gitlab.com/devnw/zig/advanced-types/-/issues/7) | AT-PKG-001 | URL/domain ownership vs `uri` | REQUIREMENTS.md | closed | medium | feature |
| [#8](https://gitlab.com/devnw/zig/advanced-types/-/issues/8) | AT-PKG-002 (GAP-0015) | DateRange deferred until datetime package exists | REQUIREMENTS.md | **open** (deferred) | low | feature |
| [#9](https://gitlab.com/devnw/zig/advanced-types/-/issues/9) | AT-PKG-003 | Geode index wrappers stay outside this repo | REQUIREMENTS.md | closed | medium | feature |
| [#10](https://gitlab.com/devnw/zig/advanced-types/-/issues/10) | AT-TEST-001 | Port source-level tests for all type modules | REQUIREMENTS.md | closed | medium | feature |
| [#11](https://gitlab.com/devnw/zig/advanced-types/-/issues/11) | AT-TEST-002 | Preserve cross-feature type-extension coverage | REQUIREMENTS.md | closed | medium | feature |
| [#12](https://gitlab.com/devnw/zig/advanced-types/-/issues/12) | AT-TEST-003 | Preserve integration and performance coverage | REQUIREMENTS.md | closed | medium | feature |
| [#18](https://gitlab.com/devnw/zig/advanced-types/-/issues/18) | AT-NFR-001 | Zero external runtime dependencies | README.md:10 | **open** (label drift; `status::closed` applied) | high | feature |
| [#19](https://gitlab.com/devnw/zig/advanced-types/-/issues/19) | AT-NFR-002 | Zero-allocation value types | README.md:12 | **open** (label drift; `status::closed` applied) | high | feature |
| [#20](https://gitlab.com/devnw/zig/advanced-types/-/issues/20) | AT-NFR-003 (GAP-0019) | Cross-platform CI (Linux, macOS, Windows, aarch64) | README.md:13 | **open** (partial via commit `505fe43`; runners dormant) | medium | feature |
| [#21](https://gitlab.com/devnw/zig/advanced-types/-/issues/21) | AT-NFR-004 (GAP-0021) | Tests pass under Debug, ReleaseSafe, ReleaseFast, ReleaseSmall | CONTRIBUTING.md | **open** (label drift; GAP-0021 CI expansion closed in `a5abd3e`) | medium | feature |
| [#22](https://gitlab.com/devnw/zig/advanced-types/-/issues/22) | AT-SEC-001 | CI SAST + secret + dep scanning + SBOM every pipeline | SECURITY.md | **open** (label drift; `status::closed` applied) | high | security |
| [#23](https://gitlab.com/devnw/zig/advanced-types/-/issues/23) | GAP-0019 | AT-NFR-003 -- CI is Linux/x86_64 only | README.md:13 | **open** (partial) | critical | enhancement |
| [#24](https://gitlab.com/devnw/zig/advanced-types/-/issues/24) | GAP-0020 | Fuzz suite broken under Zig 0.16 (`std.testing.fuzz` signature change) | tests/fuzz.zig | closed (`c0e07ee`) | critical | bug |
| [#25](https://gitlab.com/devnw/zig/advanced-types/-/issues/25) | GAP-0021 | AT-NFR-004 -- CI coverage for test-extensions/-performance + ReleaseSmall | CONTRIBUTING.md, `.gitlab-ci.yml` | closed (`a5abd3e`) | high | enhancement |

Note: Issues #18, #19, #21, #22 remain state=`opened` in GitLab even though
the `status::closed` label has been applied. This is a known label-vs-state
drift (see Section 8 #3) and does not affect the ledger truth -- the
authoritative closure signal is the `status::closed` label + the evidence
commits in `docs/GAP_ANALYSIS_RESOLVED.md`. Issue #20 is an umbrella whose
partial-implementation is tracked via #23/GAP-0019.

### 4.2 Non-requirement tracker issues (audit findings that roll up into the 22 above)

| Issue | Gap-ID / Spec-ID | Title | State | Rolls up under |
|-------|------------------|-------|-------|----------------|
| [#13](https://gitlab.com/devnw/zig/advanced-types/-/issues/13) | GAP-0014 | Wire Geode to consume types from advanced-types | **open** (blocked external) | -- (integration) |
| [#14](https://gitlab.com/devnw/zig/advanced-types/-/issues/14) | GAP-0016 | Stage geographic `st_*` spatial query helpers | **open** (deferred) | AT-REQ-003 (staged) |
| [#15](https://gitlab.com/devnw/zig/advanced-types/-/issues/15) | -- | Documentation: usage examples for vector/geo/network | closed | AT-REQ-001..003 |
| [#16](https://gitlab.com/devnw/zig/advanced-types/-/issues/16) | GAP-0017 | Port Geode integration tests for type operations | **open** (blocked external) | AT-TEST-003 |
| [#17](https://gitlab.com/devnw/zig/advanced-types/-/issues/17) | GAP-0005 | README Quick Start shows incorrect API usage | closed | AT-REQ-001..005 (Docs) |
| [#26](https://gitlab.com/devnw/zig/advanced-types/-/issues/26) | Q30 | Fuzz suite broken on Zig 0.16 | closed (`c0e07ee`) | GAP-0020 / #24 |
| [#27](https://gitlab.com/devnw/zig/advanced-types/-/issues/27) | GAP-0022 | Test-count doc drift | closed (`3702dd1`) | AT-REQ (Docs) |
| [#28](https://gitlab.com/devnw/zig/advanced-types/-/issues/28) | Q26 / SAST-01 | Subnet pub-constructible with invalid prefix_len | closed (`503c1f5`) | AT-REQ-001 |
| [#29](https://gitlab.com/devnw/zig/advanced-types/-/issues/29) | P1 / I1 | `zig build bench` harness | closed (`d786b46`) | -- (perf tooling) |
| [#30](https://gitlab.com/devnw/zig/advanced-types/-/issues/30) | GAP-0011 | Code coverage measurement in CI | closed report-only (`20b233c`) | AT-TEST-001..003 |
| [#31](https://gitlab.com/devnw/zig/advanced-types/-/issues/31) | Q25 / SAST-04 | Url/Domain slice-lifetime contract undocumented | closed (`5c97228`) | AT-REQ-004 |
| [#32](https://gitlab.com/devnw/zig/advanced-types/-/issues/32) | GAP-0018 | Fuzz suite broken (regression of prior closure) | closed (`c0e07ee`) | GAP-0020 / #24 |
| [#33](https://gitlab.com/devnw/zig/advanced-types/-/issues/33) | D1 | ReleaseFast overflow-wrap docs | closed (`0c2ebbd`) | AT-REQ-002, AT-REQ-005 |
| [#34](https://gitlab.com/devnw/zig/advanced-types/-/issues/34) | Q36 / Q11 | `minimum_zig_version` + README + CI Zig version drift | closed (`3702dd1`) | -- (tooling) |
| [#35](https://gitlab.com/devnw/zig/advanced-types/-/issues/35) | SAST-09 | IP classification misses SSRF ranges | closed (`a178648`) | AT-REQ-001 / AT-SEC-001 |
| [#36](https://gitlab.com/devnw/zig/advanced-types/-/issues/36) | D2 | Non-local `@intCast(u5)` invariant | closed (`1234a9f`) | AT-REQ-001 |
| [#37](https://gitlab.com/devnw/zig/advanced-types/-/issues/37) | Q17 | Subnet.contains 6-deep nesting | closed (`503c1f5`) | AT-REQ-001 |
| [#38](https://gitlab.com/devnw/zig/advanced-types/-/issues/38) | Q15 | Bracket-parser pattern repeated 5x | closed (`ca54cdb`) | -- (refactor) |
| [#39](https://gitlab.com/devnw/zig/advanced-types/-/issues/39) | SAST-01 | Subnet.contains panics/wrong on OOB prefix_len | closed (`503c1f5`) | AT-REQ-001 / AT-SEC-001 |
| [#40](https://gitlab.com/devnw/zig/advanced-types/-/issues/40) | Q31 | Coverage instrumentation wiring | closed report-only (`20b233c`) | GAP-0011 / #30 |
| [#41](https://gitlab.com/devnw/zig/advanced-types/-/issues/41) | Q33 / Q10 | Edge-case tests (IPv4 leading zeros, IPv6 `::`, URL userinfo) | closed (`9e937b5`) | AT-TEST-001 |
| [#42](https://gitlab.com/devnw/zig/advanced-types/-/issues/42) | SAST-05 | Url.parse userinfo-as-host allowlist bypass | closed (`f175133`) | AT-REQ-004 / AT-SEC-001 |
| [#43](https://gitlab.com/devnw/zig/advanced-types/-/issues/43) | SAST-07 | Url.parse accepts control bytes in host | closed (`f175133`) | AT-REQ-004 / AT-SEC-001 |
| [#44](https://gitlab.com/devnw/zig/advanced-types/-/issues/44) | SAST-04 | Url/Domain lifetime obligation undocumented (UAF risk) | closed (`5c97228`) | AT-REQ-004 / Q25 |
| [#45](https://gitlab.com/devnw/zig/advanced-types/-/issues/45) | NEW-02 | Domain has no IDN/Punycode/homograph handling | closed won't-do (`df972dd`) | AT-REQ-004 (scope decision documented in SECURITY.md) |
| [#46](https://gitlab.com/devnw/zig/advanced-types/-/issues/46) | NEW-01 | Url port parser accepts leading zeros | closed (`f175133`) | AT-REQ-004 |
| [#47](https://gitlab.com/devnw/zig/advanced-types/-/issues/47) | SC-01 | Pin CI-catalog components to commit SHA | closed won't-do (`152d0f8`) | AT-SEC-001 (platform-policy override) |

## 5. Doc-Sourced Requirements Cross-Check

Every requirement statement located in repo documentation was matched against
the tracker. The table below is the full cross-check; no new issues are needed
this pass.

### 5.1 `docs/REQUIREMENTS.md`

| Item | Tracker coverage |
|------|------------------|
| AT-REQ-001..006 (Functional) | issues #1..#6 |
| AT-PKG-001..003 (Packaging) | issues #7..#9 |
| AT-TEST-001..003 (Test) | issues #10..#12 |
| "Provide one example for vector math" | #15 |
| "Provide one example for geographic distance/proximity" | #15 |
| "Provide one example for network parsing" | #15 |
| "Clearly document URL/domain ownership" | #4 / #7 |
| Migration #1 -- extract portable type modules first | satisfied by #1..#5 |
| Migration #2 -- keep Geode index wrappers in Geode | #9 |
| Migration #3 -- revisit `hash.zig` later | #6 (scope decision recorded) |

### 5.2 `README.md` feature claims

| Claim | Tracker coverage |
|-------|------------------|
| "Zero Dependencies" | #18 (AT-NFR-001) |
| "17 Public Types" | satisfied via #1..#5 (count verified in `src/root.zig`) |
| "Zero Allocation" | #19 (AT-NFR-002) |
| "Cross-Platform: Linux, macOS, Windows, aarch64" | #20 (AT-NFR-003) + #23 (GAP-0019, partial) |
| "262 Tests" claim | **conflict** -- see Section 8 #1 |
| "fuzz suite currently broken under Zig 0.16 -- see GAP-0020" | **stale** -- GAP-0020 closed `c0e07ee`; README copy needs a follow-up edit |
| "Zig 0.16.0 or later" | satisfied via `build.zig.zon:minimum_zig_version` (Q36 closure) |
| "Build Modes and Overflow Semantics" section | #33 (D1 perf docs closure) |

### 5.3 `CONTRIBUTING.md`

| Statement | Tracker coverage |
|-----------|------------------|
| "Tests must pass on all optimization levels" | #21 (AT-NFR-004) + #25 (GAP-0021 CI expansion) |
| Conventional Commits / pre-commit hooks / PR review timing | team-process, not library requirements -- no issue |

### 5.4 `SECURITY.md`

| Security measure claimed | Tracker coverage |
|--------------------------|------------------|
| Memory Safety (Zig compile-time) | language guarantee, not per-issue |
| Dependency Scanning in CI | #22 (AT-SEC-001) |
| Secret Detection (gitleaks) | covered by #22 |
| SSRF Defense (`isSafeForOutboundFetch`) | #35 (SAST-09, closed `a178648`) |
| URL Parsing Hardening (userinfo strip / control-byte reject / leading-zero port) | #42/#43/#46 (SAST-05/07 + NEW-01, closed `f175133`) |
| IDN/Punycode out-of-scope disclosure | #45 (NEW-02 scoped won't-do, closed `df972dd`) |
| Responsible disclosure contact | policy, not testable -- no issue |

### 5.5 `docs/*_GAP_ANALYSIS.md` findings

The Q-/P-/S-/GAP-/SAST-/NEW-/SC- numbered items in the quality, performance,
security, and top-level gap ledgers are **historical audit findings**, not
standalone requirements. Every item PriorityScore/Risk >= 40 has a GitLab
issue (see Section 4.2); lower-ranked items (Q14, Q16, Q18-Q29 subset,
Q32, Q34..Q41 -- 20 items) are ledger-only per `QUALITY_GAP_ANALYSIS.md`
policy, documented in `docs/QUALITY_GAP_ANALYSIS.md#issue-creation-audit`.
**No new tracker issues are required this pass.**

## 6. Reconciled Requirements List

Grouped by category. State: `C` = closed (label + commit evidence),
`P` = partial (acknowledged caveats), `O` = open (blocked / deferred / in-flight).

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
| 8 | DateRange deferred until datetime package exists | REQUIREMENTS.md | #8 (GAP-0015) | **O** (deferred) |
| 9 | Geode index wrappers remain outside this repo | REQUIREMENTS.md | #9 | C |

### 6.3 Test

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 10 | Port source-level tests for all type modules | REQUIREMENTS.md | #10 | C |
| 11 | Preserve cross-feature type-extension coverage | REQUIREMENTS.md | #11 | C |
| 12 | Preserve integration/performance coverage | REQUIREMENTS.md | #12 | C |
| 13 | Port additional Geode integration tests | GAP_ANALYSIS.md | #16 (GAP-0017) | **O** (blocked external) |

### 6.4 Documentation

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 14 | Usage examples for vector/geographic/network | REQUIREMENTS.md | #15 | C |
| 15 | README Quick Start reflects real API | README.md | #17 (GAP-0005) | C |

### 6.5 Non-Functional

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 16 | Zero external runtime dependencies | README.md | #18 | C |
| 17 | Zero-allocation value types | README.md | #19 | C |
| 18 | Cross-platform CI matrix (Linux x86_64/aarch64, macOS, Windows) | README.md | #20 / #23 (GAP-0019) | **P** (YAML landed, runners dormant) |
| 19 | Tests pass on all Zig optimization modes | CONTRIBUTING.md | #21 / #25 (GAP-0021) | C |

### 6.6 Security

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 20 | SAST + secret + dep-scan + SBOM every pipeline | SECURITY.md | #22 (AT-SEC-001) | C |
| 21 | SSRF defense on IP classification | SECURITY.md | #35 (SAST-09) | C |
| 22 | URL parsing hardening (userinfo / control bytes / leading-zero port) | SECURITY.md | #42 / #43 / #46 | C |
| 23 | Url/Domain slice-lifetime contract documented | `src/types/url.zig` + SECURITY.md implicit | #31 / #44 (Q25 / SAST-04) | C |
| 24 | IDN/Punycode out-of-scope documented | SECURITY.md | #45 (NEW-02) | C (scoped won't-do) |
| 25 | Subnet prefix_len validation (CWE-1284) | SECURITY.md implicit | #28 / #39 (Q26 / SAST-01) | C |

### 6.7 CI / Quality / Performance (supporting)

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 26 | Code coverage measurement in CI | `QUALITY_GAP_ANALYSIS.md` | #30 / #40 (GAP-0011 / Q31) | C (report-only; percentage gate deferred) |
| 27 | Fuzz suite operational on Zig 0.16 | `QUALITY_GAP_ANALYSIS.md` | #24 / #26 / #32 (GAP-0020 / Q30 / GAP-0018) | C |
| 28 | `zig build bench` harness | `PERF_GAP_ANALYSIS.md` | #29 (P1 / I1) | C |
| 29 | Toolchain pin consistency (manifest vs README vs CI) | `QUALITY_GAP_ANALYSIS.md` | #34 (Q36 / Q11) | C |
| 30 | Test-count ledger reconciliation | `QUALITY_GAP_ANALYSIS.md` | #27 (GAP-0022) | C (reconciled to 303; README copy still says 262 -- see Section 8 #1) |

### 6.8 Integration (downstream)

| # | Requirement | Source | Issue | State |
|---|-------------|--------|-------|-------|
| 31 | Wire Geode to consume this package | GAP_ANALYSIS.md | #13 (GAP-0014) | **O** (blocked on Geode repo) |
| 32 | Stage geographic `st_*` spatial helpers for later | GAP_ANALYSIS.md | #14 (GAP-0016) | **O** (deferred) |

### 6.9 Summary totals

| Category | Count |
|----------|------:|
| Functional (library surface) | 6 |
| Packaging | 3 |
| Test | 4 |
| Documentation | 2 |
| Non-Functional | 4 |
| Security | 6 |
| CI / Quality / Performance | 5 |
| Integration | 2 |
| **Total requirements** | **32** |

| State | Count | Issues |
|-------|------:|--------|
| Closed | 27 | #1-7, 9-12, 15, 17, 19, 21, 22, 24-25, 27-36, 39-46 |
| Partial | 1 | #20/#23 (cross-platform CI runners dormant) |
| Open (deferred / blocked external) | 4 | #8 (GAP-0015), #13 (GAP-0014), #14 (GAP-0016), #16 (GAP-0017) |

## 7. Downstream Agent Inputs

### 7.1 Canonical filters

- **All requirements (canonical scope):** `glab issue list -R devnw/zig/advanced-types --label requirement --all`
- **Open actionable gaps:** `glab issue list -R devnw/zig/advanced-types --label status::open --all`
- **Closed-by-label (closure evidence):** `glab issue list -R devnw/zig/advanced-types --label status::closed --all`
- **Functional slice:** title regex `^AT-REQ-\d{3}`
- **Non-functional slice:** title regex `^AT-NFR-\d{3}`
- **Security slice:** title regex `^AT-SEC-\d{3}` or label `type::security`
- **New Gap-ID slice:** title regex `^GAP-\d{4}`
- **Integration / externally blocked:** issues #8, #13, #14, #16

### 7.2 Stable Gap-ID registry (do not reissue)

| Namespace | Range | Source of truth |
|-----------|-------|-----------------|
| `AT-REQ-00N` | 001-006 | `docs/REQUIREMENTS.md` |
| `AT-PKG-00N` | 001-003 | `docs/REQUIREMENTS.md` |
| `AT-TEST-00N` | 001-003 | `docs/REQUIREMENTS.md` |
| `AT-NFR-00N` | 001-004 | `README.md` feature claims + `CONTRIBUTING.md` |
| `AT-SEC-00N` | 001 | `SECURITY.md` |
| `GAP-000N` | 0005-0022 (non-contiguous; see ledger) | `docs/GAP_ANALYSIS.md` |
| `Q1..Q41` | historical Q1-Q13 + audit Q14-Q41 | `docs/QUALITY_GAP_ANALYSIS.md` |
| `P1..P10, I1, D1, D2, A1, A3-A5, M3, S1-S3` | | `docs/PERF_GAP_ANALYSIS.md` |
| `S1..S7, SAST-01, SAST-04, SAST-05, SAST-07, SAST-09, SC-01, NEW-01, NEW-02` | | `docs/SECURITY_GAP_ANALYSIS.md` |

**Highest Gap-ID in use: `GAP-0022`.** Next new Gap-ID if needed: **`GAP-0023`**.

### 7.3 Open gaps snapshot (as of 2026-04-18)

| Issue | Gap-ID | Requirement | State reason | Actionable? |
|-------|--------|-------------|--------------|:-----------:|
| #8 | GAP-0015 | DateRange | Blocked on Zig datetime package | no |
| #13 | GAP-0014 | Geode consumer wiring | Blocked on Geode repo | no |
| #14 | GAP-0016 | `st_*` spatial helpers | Deferred (design decision) | no |
| #16 | GAP-0017 | Port additional Geode integration tests | Blocked on Geode wiring | no |
| #20 / #23 | AT-NFR-003 / GAP-0019 | Cross-platform CI matrix | YAML jobs landed `allow_failure:true`; runners dormant | **yes** (requires runner provisioning) |

`#23 / GAP-0019` is the only fully-actionable open gap in the tracker.
Everything else is gated on external work.

## 8. Conflicts & Ambiguities

1. **Test-count drift is re-emerging.** `docs/GAP_ANALYSIS_RESOLVED.md`
   §"Closed on 2026-04-18 -- Third Gap Closure Pass" (GAP-0022) records
   that README + all four `*GAP_ANALYSIS.md` ledgers were reconciled to
   **303** tests (248 unit + 9 integration + 11 extensions + 9 perf +
   16 parser-edges + 10 fuzz, via commit `3702dd1`). The current
   `README.md:14` still says **"262 Tests ... (fuzz suite currently
   broken under Zig 0.16 -- see GAP-0020)"**, and `CHANGELOG.md:17`
   still says **"230 tests"**. Both are stale relative to the closed
   GAP-0022 evidence. **Flagged for downstream docs-sync**: README and
   CHANGELOG should match `docs/GAP_ANALYSIS.md:70-78` (303 runnable).

2. **Zig-version prose in `README.md:4` and `:93` agrees on 0.16.0+**
   after the Q36 closure (`3702dd1`). No conflict; historical
   `GAP_ANALYSIS.md` row claimed "0.15.2" which has since been
   superseded -- ledger is internally consistent.

3. **Label drift on issues #18, #19, #21, #22.** These issues have
   `status::closed` applied but their GitLab state is still `opened`.
   The label is the authoritative closure signal per the label
   taxonomy; the opened-state is a housekeeping task (close in the
   tracker UI) for `gap-sync`. Not a correctness issue; flagged for
   the next sync phase.

4. **Priority legacy labels** (`priority::0..4`) coexist with the
   named labels (`priority::critical..low`). Only the named labels
   are used on active issues. No action required; noted for
   awareness.

5. **CI fuzz job is scheduled / manual** per `.gitlab-ci.yml`
   `rules:`. Not a conflict; `gap-scanner` must not assume fuzz runs
   on every MR. Historical note only.

6. **Platform identity discrepancy.** The orientation prompt named
   GitHub `devnw/zig-advanced-types` as the platform; the real git
   remote resolves to GitLab `devnw/zig/advanced-types` and
   `gh repo view devnw/zig-advanced-types` returns "Could not resolve
   to a Repository." Adopted GitLab as the authoritative tracker;
   see Section 9 blocker entry.

## 9. Blockers

| Blocker | Category | Detail | Action taken |
|---------|----------|--------|--------------|
| Prompt-specified GitHub mirror does not exist | Platform | User nominated `devnw/zig-advanced-types` on GitHub; `gh repo view` returns "Could not resolve to a Repository" | Proceeded on GitLab (the real `origin`); flagged so the prompt author can clarify whether a GitHub mirror is intended. Does not block any of the 32 requirements. |
| `glab auth status` reports "Invalid token provided in configuration file" | Platform | Config warning; all API calls against `devnw/zig/advanced-types` succeed (label create, issue list) | None; treated as false positive. If downstream phases see 401s, rerun `glab auth login`. |
| Cross-platform CI runners for macOS / Windows / Linux-aarch64 | Infrastructure | Jobs exist in `.gitlab-ci.yml` as `allow_failure: true` placeholders; no runners provisioned. Blocks full closure of GAP-0019 / AT-NFR-003. | Captured in `docs/audit/gap-close-blockers.md`; tracked under #23. Not actionable at the requirements-inventory layer. |

No blockers prevent the requirements inventory itself from being
complete. All 32 requirements have tracker coverage.

## 10. Delta Since Prior Revision

Prior revision (committed at `f3adc69` on 2026-04-18, pre-closure) catalogued 22
requirement issues and flagged 4 open gaps (GAP-0019..GAP-0022) as new. This
revision:

- Re-counts the canonical requirement set at **32** (the prior "22"
  counted only issues bearing `label=requirement`; this revision rolls
  up tracker issues #28-47 into their governing requirement lines so
  all closure evidence is visible in one inventory).
- Records closures from the gap-close pass (commits `c0e07ee`,
  `a5abd3e`, `d786b46`, `5c97228`, `503c1f5`, `3702dd1`, `20b233c`,
  `0c2ebbd`, `1234a9f`, `ca54cdb`, `9e937b5`, `3702dd1`, `a178648`,
  `f175133`, `df972dd`, `152d0f8`). All evidence commits are
  verifiable via `git log --oneline`.
- Keeps all prior Gap-IDs stable; no renaming, no reissuing.
- Adds 8 new labels to the taxonomy (`gap-analysis`, `gap-implemented`,
  `gap-partial`, `gap-not-implemented`, `severity::critical`,
  `severity::high`, `severity::medium`, `severity::low`). No labels
  were deleted or renamed; the existing `gap`, `priority::*`, and
  `status::*` taxonomies remain authoritative.
- Identifies two new **docs-sync** follow-ups for the next cycle
  (README test-count prose + CHANGELOG test count; see Section 8 #1)
  and a label-vs-state housekeeping task (Section 8 #3). Neither
  requires a new tracker issue; both are trivial deltas that
  `gap-sync` should flush together.

## 11. Artefact Paths

- This file: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-requirements.md`
- Prior-state ledger: `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md`
- Resolved ledger: `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS_RESOLVED.md`
- Detected-gaps ledger: `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-detected.md`
- Spec: `/home/benji/src/devnw/zig/advanced-types/docs/REQUIREMENTS.md`
- Sub-audit ledgers:
  - `/home/benji/src/devnw/zig/advanced-types/docs/QUALITY_GAP_ANALYSIS.md`
  - `/home/benji/src/devnw/zig/advanced-types/docs/PERF_GAP_ANALYSIS.md`
  - `/home/benji/src/devnw/zig/advanced-types/docs/SECURITY_GAP_ANALYSIS.md`
