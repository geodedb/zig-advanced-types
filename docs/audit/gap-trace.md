# Gap Analysis -- Requirements-to-Code Trace Matrix

Generated: 2026-04-18 (fresh scan; supersedes prior trace at commit `f3adc69`)
Phase: 2 of `/codepros:audit` (gap-scanner)
Repo: `gitlab.com/devnw/zig/advanced-types`
Platform: GitLab (`git@gitlab.com:devnw/zig/advanced-types.git`)
Zig toolchain (local): **0.16.0** (`/home/benji/.local/share/mise/shims/zig`); CI `ZIG_VERSION = "0.16.0"` (`.gitlab-ci.yml:27`)
Trace source: `docs/audit/gap-requirements.md` (**32** reconciled requirements)

## 1. Test Suite and Static-Check Validation

All declared build steps were executed against the local toolchain on
2026-04-18. Results are captured verbatim from `zig build ... --summary all`.

| Check | Command | Result | Count | Notes |
|-------|---------|--------|-------|-------|
| Build / compile check | `zig build check` | PASS | -- | Build Summary: 2/2 steps succeeded |
| Format | `zig fmt --check .` | PASS (exit 0) | -- | No files require reformatting |
| Unit tests | `zig build test --summary all` | PASS | 248/248 | run time 17 ms |
| Integration | `zig build test-integration --summary all` | PASS | 9/9 | |
| Type extensions | `zig build test-extensions --summary all` | PASS | 11/11 | |
| Performance | `zig build test-performance --summary all` | PASS | 9/9 | |
| Parser edges | `zig build test-parser-edges --summary all` | PASS | 16/16 | Q33 regression net |
| Fuzz (compile+smoke) | `zig build test-fuzz --summary all` | **PASS** | 10/10 | Previously broken; now ported to Zig 0.16 `Smith` API (GAP-0020 / Q30 closed in `c0e07ee`) |
| Debug (optimize) | `zig build test` | PASS | 248/248 | |
| ReleaseSafe | `zig build test -Doptimize=ReleaseSafe` | PASS | 248/248 | |
| ReleaseFast | `zig build test -Doptimize=ReleaseFast` | PASS | 248/248 | |
| ReleaseSmall | `zig build test -Doptimize=ReleaseSmall` | PASS | 248/248 | compile took ~6 s cold |

**Total runnable: 303 tests passing** (248 unit + 9 integration + 11 extensions,
plus 9 performance + 16 parser-edges + 10 fuzz), four Zig optimize modes green.

### 1.1 Test-count reconciliation

| Source | Claimed | Actual (runnable) | Delta |
|--------|---------|-------------------|-------|
| `README.md:14` | **"262 Tests ... fuzz suite currently broken"** | 303 (fuzz now green) | **stale** -- README carries pre-closure copy |
| `CHANGELOG.md:17` | "230 tests (221 unit + 9 integration)" | 303 | **stale** -- `[Unreleased]` block never updated |
| `docs/GAP_ANALYSIS.md` GAP-0022 closure | 303 | 303 | match |
| `docs/audit/gap-requirements.md §8` | 303 | 303 | match |

**Scanner verdict:** README and CHANGELOG are stale docs-only drift (flagged in
requirements doc §8 #1). Not a code regression.

### 1.2 Unit-test count by module

`grep -c '^test\b'` across `src/**`: network 38, vector 49, geographic 38,
url 67, range 55, root 1 (a `refAllDecls` umbrella) = **248**, matching the
test runner.

## 2. Per-Requirement Trace

Status legend: **I** = Implemented, **P** = Partial, **N** = Not Implemented,
**U** = Unknown. Every row cites `file:line` in current `HEAD` (`main`).

### 2.1 Functional -- `REQUIREMENTS.md` AT-REQ-00x

| # | Req | Status | Implementation | Tests | CI |
|---|-----|--------|----------------|-------|----|
| 1 | AT-REQ-001 Network types | **I** | `src/types/network.zig` -- `Ipv4Addr` (L42), `Ipv6Addr` (L179), `IpAddr` (L431), `Subnet` (L481), `Mac` (L608); re-exports `src/root.zig:50..54` | 38 unit tests in-module; `tests/integration.zig`, `type_extensions.zig`, `parser_edge_cases.zig` | `test` + 3 release-mode variants + `test-integration*` + `test-parser-edges` |
| 2 | AT-REQ-002 Vector types | **I** | `src/types/vector.zig` -- `Vector(T,N)` (L30), `VectorF32` (L261), `VectorI32` (L264); re-exports `src/root.zig:60..62` | 49 unit tests; extensions L122 | same as #1 |
| 3 | AT-REQ-003 Geographic | **I** | `src/types/geographic.zig` -- `LatLon` (L91), `LatLonAlt` (L173), `GeoPoint` (L227); haversine helper at `LatLon`; re-exports `src/root.zig:68..70` | 38 unit tests; extensions L89..137 | same as #1 |
| 4 | AT-REQ-004 URL / Domain | **I** | `src/types/url.zig` -- `Domain` (L48, `parse` L52), `Url` (L179, `parse` L190); re-exports `src/root.zig:76..77`; lifetime contract documented at L31..46 and L158..166 | 67 unit tests; integration; extensions | same as #1 |
| 5 | AT-REQ-005 Generic ranges | **I** | `src/types/range.zig` -- `Range(T)` (L20, `init` L28, `contains` L45, `parse` L107), `IntRange` (L195), `UintRange` (L196), `FloatRange` (L197); re-exports `src/root.zig:83..86` | 55 unit tests | same as #1 |
| 6 | AT-REQ-006 Exclude Geode hash types | **I** | `src/types/hash.zig` absent (confirmed via `ls src/types/`); no hash-aliases re-exported in `src/root.zig` | negative assertion, no dedicated test required | -- |

### 2.2 Packaging -- AT-PKG-00x

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 7 | AT-PKG-001 URL ownership vs `uri` | **I** | `build.zig.zon:6` declares `.dependencies = .{}`; `src/types/url.zig` is standalone |
| 8 | AT-PKG-002 DateRange deferred | **N (deferred)** | No `DateRange` symbol anywhere in `src/` (grep returned 0 matches). Intentionally blocked on a datetime package upstream. |
| 9 | AT-PKG-003 Geode wrappers external | **I** | `src/` contains only `root.zig` and `types/`; no `index/*` |

### 2.3 Test -- AT-TEST-00x + GAP-0017

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 10 | AT-TEST-001 Source-level tests | **I** | 248 `test ...` blocks executed via `std.testing.refAllDecls(@This())` at `src/root.zig:94` |
| 11 | AT-TEST-002 Type-extension coverage | **I** | `tests/type_extensions.zig` -- 11 tests, pass 11/11 via `zig build test-extensions` |
| 12 | AT-TEST-003 Integration + perf coverage | **I** | `tests/integration.zig` 9 pass; `tests/performance.zig` 9 pass |
| 13 | Port additional Geode integration tests (GAP-0017) | **N (blocked external)** | Gated on downstream Geode wiring (#13 / GAP-0014) |

### 2.4 Documentation

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 14 | Examples for vector/geographic/network | **I** | `examples/basic.zig` compiles via `zig build example`; `build.zig:106..119` wires the step |
| 15 | README Quick Start matches real API | **I** | `README.md:47..66` calls `Ipv4Addr.parse`, `VectorF32.init`, `LatLon.init`, `Url.parse`, `IntRange.init` -- all match signatures in `src/types/*.zig` |

### 2.5 Non-Functional -- AT-NFR-00x

| # | Req | Status | Evidence | Gap |
|---|-----|--------|----------|-----|
| 16 | AT-NFR-001 Zero runtime deps | **I** | `build.zig.zon:6` `.dependencies = .{}`; every `src/**/*.zig` imports only `std` | -- |
| 17 | AT-NFR-002 Zero-allocation value types | **I** | No `*Allocator` parameter on any public `parse`/`init`/`format` in network/vector/geographic/url/range (grep across module public fns confirms signatures); all types are plain structs / unions | Not asserted via a negative test, but the signature surface is the authoritative contract |
| 18 | AT-NFR-003 Cross-platform CI matrix | **P** | `.gitlab-ci.yml:238..297` ships dormant `test-macos`, `test-windows`, `test-linux-aarch64` jobs with `rules: when: manual` + `allow_failure: true`; company-tag Linux/x86_64 runners are the only ones provisioned. GAP-0019 partial closure (`505fe43`). | Runner provisioning only; YAML is in place |
| 19 | AT-NFR-004 Tests pass on all Zig optimize modes | **I** | `.gitlab-ci.yml` jobs: `test` Debug (L102), `test-release-safe` (L124), `test-release-fast` (L135), `test-release-small` (L221), plus integration variants for Safe/Fast/Small (L145/L155/L165), plus `test-extensions` (L176), `test-performance` (L187), `test-parser-edges` (L198). Local `zig build test -Doptimize=<Debug\|ReleaseSafe\|ReleaseFast\|ReleaseSmall>` all returned 248/248. GAP-0021 closed `a5abd3e`. | -- |

### 2.6 Security -- AT-SEC-001 + SECURITY.md rollups

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 20 | SAST + secrets + dep-scan + SBOM every pipeline | **I** | `.gitlab-ci.yml:10..21` -- `security-sast@v1.7.1`, `security-dependency-scanning@v1.7.1`, `security-secrets@v1.7.1`, `security-gitleaks@v1.7.1`, `sbom-generate@v1.7.1`, `sbom-scan@v1.7.1` (unconditional includes) |
| 21 | SSRF defense on IP classification | **I** | `src/types/network.zig:155` (`Ipv4Addr.isSafeForOutboundFetch`), L394 (`Ipv6Addr.isSafeForOutboundFetch`); both reject loopback/private/link-local/CGNAT/multicast/reserved and downcast IPv4-mapped IPv6. Closed `a178648`. |
| 22 | URL parsing hardening (userinfo / control bytes / leading-zero port) | **I** | `src/types/url.zig:190` (`Url.parse`) enforces userinfo strip, control-byte rejection, port leading-zero reject; closed `f175133`. Regression tests in `tests/parser_edge_cases.zig` (16/16 pass). |
| 23 | Url/Domain slice-lifetime contract documented | **I** | `src/types/url.zig:31..46` (Domain) and `src/types/url.zig:158..166` (Url) explicitly document the "doesn't own its bytes" contract. Closed `5c97228`. |
| 24 | IDN/Punycode out of scope documented | **I** | `SECURITY.md:55..81` "Domain Names are ASCII-Only (NEW-02)". Scoped won't-do (`df972dd`). |
| 25 | Subnet prefix_len validation (CWE-1284) | **I** | `src/types/network.zig:493..499` (`Subnet.init` rejects OOB); L541..588 (`contains` dispatch to `containsV4`/`containsV6` with guarded shifts, `std.debug.assert(prefix_len > 0 and prefix_len < 32)` at L563). Closed `503c1f5`/`1234a9f`. |

### 2.7 CI / Quality / Performance (supporting)

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 26 | Code coverage measurement in CI | **I (report-only)** | `.gitlab-ci.yml:307..332` -- kcov-driven `coverage` job, HTML artifact (`coverage/`), regex on `Total.*(\d+\.\d+)%` surfaces Pipelines Coverage column, `allow_failure: true`. Closed report-only `20b233c`; percentage-gate explicitly deferred. |
| 27 | Fuzz suite operational on Zig 0.16 | **I** | `tests/fuzz.zig:1..50` uses `std.testing.Smith` (Zig 0.16 API); 10/10 tests pass via `zig build test-fuzz`. CI `fuzz` job at `.gitlab-ci.yml:341..360` with `timeout 60 zig build test --fuzz` (schedule/manual). Closed `c0e07ee`. |
| 28 | `zig build bench` harness | **I** | `build.zig:124..137` + `bench/main.zig` + CI `bench` job at L203..212 (`allow_failure: true`, exit-0 gate). Closed `d786b46`. |
| 29 | Toolchain pin consistency (manifest vs README vs CI) | **I** | `build.zig.zon:5` `minimum_zig_version = "0.16.0"`; README badge and prose (`README.md:4`, L93) agree; `.gitlab-ci.yml:27` `ZIG_VERSION: "0.16.0"`. Closed `3702dd1`. |
| 30 | Test-count ledger reconciliation | **P** | `docs/GAP_ANALYSIS.md` reconciled to 303 (GAP-0022 closure `3702dd1`); **but** `README.md:14` still says "262 Tests ... fuzz suite currently broken under Zig 0.16 -- see GAP-0020" and `CHANGELOG.md:17` still says "230 tests (221 unit + 9 integration)". Docs-only drift; no code regression. |

### 2.8 Integration (downstream)

| # | Req | Status | Evidence |
|---|-----|--------|----------|
| 31 | Wire Geode consumer (GAP-0014) | **N (blocked external)** | No downstream artefacts present; gated on the Geode repo. |
| 32 | Stage geographic `st_*` helpers (GAP-0016) | **N (deferred)** | `grep -rn "st_intersect\|st_contains\|st_distance"` in `src/` returns 0 matches; deferred by design. |

## 3. Closure-Claim Verification (against `docs/GAP_ANALYSIS*.md`)

Spot-checks of prior closure claims against the current tree:

| Gap-ID | Claim | Actual | Verdict |
|--------|-------|--------|---------|
| GAP-0005 README Quick Start nonexistent `init()` | Closed | `README.md:47..66` matches `src/root.zig:50..86` re-exports | Confirmed |
| GAP-0007 `examples/basic.zig` imports library | Closed | `build.zig:106..119` wires `example` step against `module` | Confirmed (indirect) |
| GAP-0011 Code coverage | Closed report-only | `.gitlab-ci.yml:307..332` kcov job present | **Confirmed** (prior trace flagged "Refuted"; superseded by `20b233c`) |
| GAP-0018 Fuzz suite | Closed | `tests/fuzz.zig` 10/10 pass on Zig 0.16 | **Confirmed** (prior trace flagged "Refuted"; superseded by `c0e07ee`) |
| GAP-0019 Cross-platform CI | Partial | dormant matrix jobs exist | Confirmed partial |
| GAP-0020 / Q30 fuzz signature | Closed | see GAP-0018 row | Confirmed |
| GAP-0021 CI coverage for extensions / perf / ReleaseSmall | Closed | `.gitlab-ci.yml:176, 187, 198, 221, 165` | Confirmed |
| GAP-0022 Test-count doc drift | Closed (partial refresh) | `docs/GAP_ANALYSIS.md` reconciled; README/CHANGELOG still stale (row 30) | Confirmed partial -- docs-only follow-up |
| Q26 / SAST-01 Subnet prefix_len | Closed | `network.zig:498, 555, 570` | Confirmed |
| Q25 / SAST-04 Url/Domain lifetime | Closed | `url.zig:31..46, 158..166` | Confirmed |
| SAST-05 userinfo allowlist bypass | Closed | `url.zig:190` parse hardening | Confirmed |
| SAST-07 control bytes in host | Closed | same as SAST-05 | Confirmed |
| SAST-09 / NEW-01 SSRF + leading-zero port | Closed | `network.zig:155, 394`; `url.zig:190` | Confirmed |
| NEW-02 IDN/Punycode | Closed scoped won't-do | `SECURITY.md:55..81` | Confirmed |
| SC-01 CI-catalog SHA pinning | Closed won't-do | `.gitlab-ci.yml:11..24` uses `@v1.7.1` tags by platform policy | Confirmed |

## 4. Optimize-Mode and Cross-Platform CI Detail

### 4.1 Optimize modes (AT-NFR-004)

| Mode | Unit | Integration | Extensions | Performance | Parser edges |
|------|:----:|:-----------:|:----------:|:-----------:|:------------:|
| Debug | YES (L102) | YES (L113) | YES (L176) | YES (L187) | YES (L198) |
| ReleaseSafe | YES (L124) | YES (L145) | NO (in CI) | NO (in CI) | NO (in CI) |
| ReleaseFast | YES (L135) | YES (L155) | NO (in CI) | NO (in CI) | NO (in CI) |
| ReleaseSmall | YES (L221) | YES (L165) | NO (in CI) | NO (in CI) | NO (in CI) |

The unit and integration slices cover all four modes per AT-NFR-004. Auxiliary
suites (extensions / performance / parser-edges) run Debug-only in CI; all four
modes pass locally. Per `CONTRIBUTING.md` "Tests must pass on all optimization
levels," the compliant slice is `zig build test` + `zig build test-integration`,
which matches. Extension/perf/parser-edges in release modes are an untracked
strengthening opportunity -- not a regression against any prior closure.

### 4.2 Cross-platform matrix (AT-NFR-003 / GAP-0019)

| Target | Job | Trigger | Tag | Runner available? |
|--------|-----|---------|-----|-------------------|
| Linux/x86_64 | `test` + variants | auto | `company` | yes (provisioned) |
| macOS | `test-macos` | manual + schedule | `macos` | **no** (`allow_failure: true`) |
| Windows | `test-windows` | manual + schedule | `windows` | **no** (`allow_failure: true`) |
| Linux/aarch64 | `test-linux-aarch64` | manual + schedule | `aarch64` | **no** (`allow_failure: true`) |

YAML landed in `505fe43`; runner provisioning blocker recorded in
`docs/audit/gap-close-blockers.md`.

### 4.3 Security scanning (AT-SEC-001)

| Component | Version | Location | Trigger |
|-----------|---------|----------|---------|
| SAST | v1.7.1 | L11 | unconditional |
| Dep scanning | v1.7.1 | L12 | unconditional |
| Secrets | v1.7.1 | L13 | unconditional |
| Gitleaks | v1.7.1 | L14 | unconditional |
| SBOM generate | v1.7.1 | L20 | unconditional |
| SBOM scan | v1.7.1 | L21 | unconditional |

All six run on every pipeline (no `rules:` limiter).

## 5. Status Rollup

| Status | Count | Requirements |
|--------|------:|--------------|
| Implemented | **26** | 1-7, 9-12, 14-17, 19-29 |
| Partial | **2** | 18 (AT-NFR-003 cross-platform runners dormant), 30 (README/CHANGELOG test-count docs drift) |
| Not Implemented | **4** | 8 (GAP-0015 DateRange -- blocked), 13 (GAP-0017 Geode integration tests -- blocked), 31 (GAP-0014 Geode consumer -- blocked), 32 (GAP-0016 `st_*` helpers -- deferred) |
| Unknown | **0** | -- |

26 I + 2 P + 4 N + 0 U = **32** (matches reconciled requirements count).

## 6. Delta vs Prior Audit (`f3adc69`)

The prior trace (committed 2026-04-18, pre-closure) counted **22** requirements
(only `label=requirement` tracker items) and reported: 16 Implemented, 1 Partial
(#21 AT-NFR-004), 5 Not Implemented (#8, #13, #14, #16, #20), 0 Unknown.

Fresh scan (this file) counts the reconciled **32** requirements and includes
the Q-/P-/S-/SAST-/NEW-/SC- rollups. Concrete status migrations since
`f3adc69`:

| Item | Prior | Now | Why |
|------|-------|-----|-----|
| AT-NFR-004 (#21) optimize modes | Partial (ext/perf absent from CI) | **I** | `a5abd3e` added `test-extensions`, `test-performance`, plus ReleaseSmall integration variant; Debug covers all aux suites; Safe/Fast/Small cover unit + integration |
| GAP-0018 / fuzz suite | Refuted (didn't compile) | **I** | `c0e07ee` ported to `std.testing.Smith`; 10/10 tests pass |
| GAP-0011 / code coverage | Refuted (no CI job) | **I (report-only)** | `20b233c` added kcov job |
| SAST-01 / Q26 Subnet prefix_len | n/a (post-scope) | **I** | `503c1f5` + `1234a9f` |
| SAST-04 / Q25 slice lifetime | n/a | **I** | `5c97228` |
| SAST-05 / SAST-07 / NEW-01 Url parse hardening | n/a | **I** | `f175133` |
| SAST-09 SSRF classification | n/a | **I** | `a178648` |
| NEW-02 IDN/Punycode | n/a | **I (won't-do)** | `df972dd` |
| SC-01 CI-catalog SHA pinning | n/a | **I (won't-do)** | `152d0f8` |
| Q33 / Q10 parser edge tests | n/a | **I** | `9e987b5` + `test-parser-edges` CI job |
| Q36 / Q11 Zig version pin | n/a | **I** | `3702dd1` |
| Test-count doc drift (GAP-0022) | n/a | **P** | `docs/GAP_ANALYSIS*` reconciled to 303; README.md:14 + CHANGELOG.md:17 still stale (docs-only) |

**Net:** 10 requirement rows moved to Implemented; 1 row stays Partial due to
README + CHANGELOG test-count stale copy; the 4 blocked/deferred rows
(AT-PKG-002, GAP-0014, -0016, -0017) are unchanged; the cross-platform runner
blocker (AT-NFR-003) is unchanged.

## 7. Signals for downstream phases

1. **README.md:14 and CHANGELOG.md:17 need a docs sync.** README still says
   "262 Tests ... fuzz suite currently broken under Zig 0.16 -- see GAP-0020"
   while the fuzz suite is green and totals are 303. CHANGELOG `[Unreleased]`
   says 230. Both are trivial edits, no code change. Flagged under requirement
   row 30 (Partial).

2. **Cross-platform runners (AT-NFR-003 / GAP-0019)** remain the only unblocked
   open gap. YAML is complete; action required is runner provisioning, not code.

3. **Integration/extensions/performance release-mode coverage** is a
   strengthening opportunity but **not** a spec violation -- `CONTRIBUTING.md`
   says "Tests must pass on all optimization levels"; unit + integration
   already satisfy that across all four modes.

4. **Blocked externals** (GAP-0014 / GAP-0015 / GAP-0017 / GAP-0016) are
   non-actionable until the datetime package / Geode repo advances.

## 8. Blocked checks

| Check | Status | Notes |
|-------|--------|-------|
| macOS CI run | Blocked | `allow_failure: true` + manual; no runner provisioned |
| Windows CI run | Blocked | same |
| Linux/aarch64 CI run | Blocked | same |
| Coverage percentage gate | Deferred by design | Report-only per `20b233c`; follow-up issue will add gate after baseline |

## 9. Artefact Paths (absolute)

Requirements and audit inputs:

- `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-requirements.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/GAP_ANALYSIS_RESOLVED.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/audit/gap-detected.md`
- `/home/benji/src/devnw/zig/advanced-types/docs/REQUIREMENTS.md`
- `/home/benji/src/devnw/zig/advanced-types/SECURITY.md`
- `/home/benji/src/devnw/zig/advanced-types/CONTRIBUTING.md`
- `/home/benji/src/devnw/zig/advanced-types/README.md`
- `/home/benji/src/devnw/zig/advanced-types/CHANGELOG.md`

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
- `/home/benji/src/devnw/zig/advanced-types/tests/parser_edge_cases.zig`
- `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` (ported to Zig 0.16)

Build / CI:

- `/home/benji/src/devnw/zig/advanced-types/build.zig`
- `/home/benji/src/devnw/zig/advanced-types/build.zig.zon`
- `/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml`
- `/home/benji/src/devnw/zig/advanced-types/bench/main.zig`
