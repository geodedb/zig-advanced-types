# Quality Gap Analysis

Last updated: 2026-06-11 (post 6th pass / audit iteration 1, branch `audit/iteration-1-fixes`)

## Summary

| Status | Count |
|--------|-------|
| Closed — historical Q1–Q13 | 13 (12 closed incl. Q9 via Q45, 1 Won't-Do: Q12) |
| Closed 4th pass (Q15, Q17, Q25, Q26, Q30, Q31, Q33, Q36) | 8 |
| **Closed 5th pass (Q16, Q18, Q19, Q20, Q32, Q42, Q43, Q44, Q45, Q46)** | **10** |
| **Closed 6th pass (Q27, Q29, Q34, Q35, Q37, Q41)** | **6** |
| **New findings 6th pass, found and closed same pass (N1–N5)** | **5** |
| Superseded (Q38 → Q42) | 1 |
| Accepted (Q21, Q22, Q23, Q24) | 4 |
| **Open — ledger-only / low-priority (Q14, Q28, Q39, Q40)** | **4** |
| **Total tracked** | **51 (46 Q + 5 N)** |

### Severity distribution (remaining open)

| Tier | PriorityScore | Count | IDs |
|------|---------------|-------|-----|
| Critical | >= 80 | 0 | — |
| High | 60–79 | 0 | — |
| Medium | 40–59 | 0 | — |
| Low | < 40 | 4 | Q14, Q28, Q39, Q40 |

All High- and Medium-priority quality gaps were closed in the 5th pass. (Note:
the prior revision of this table stale-listed Q36 as open — Q36 was closed in
the 4th pass, commit `3702dd1`; the summary never caught up.) The 6th pass
(2026-06-11) closed Q27, Q29, Q34, Q35, Q37, Q41, leaving 4 Low-priority /
ledger-only items open by deliberate choice.

### Status migrations — 6th pass (2026-06-11)

| Q-ID | Prior | New | Reason |
|------|-------|-----|--------|
| Q27 | Open (Low) | **Closed (6th pass)** | Per-method overflow-mode doc comments on `Vector` arithmetic and `Range.span`, commit `8d8772d`. |
| Q29 | Open (Low) | **Closed (6th pass)** | `at`-asserts-vs-`get`-optional contract documented at type level, commit `8d8772d`. |
| Q34 | Open (Low) | **Closed (6th pass)** | `-Dtest-filter` build option added, commit `fd4d9db`. |
| Q35 | Open (Low) | **Closed (6th pass)** | `Range.span` wrap regression test in unsafe modes, commits `fd4d9db` + `8d307df` (comment correction). |
| Q37 | Open (Low) | **Closed (6th pass)** | `DomainLabelIterator`/`next` and `*Unchecked` constructors documented, commit `8d8772d`. |
| Q41 | Open (Low) | **Closed (6th pass)** | "Why" comments added at non-obvious sites (incl. `range.zig` parse rationale), commit `8d8772d`. |

New findings this pass — found and closed in the same pass:

| N-ID | Finding | Resolution | Commit |
|------|---------|------------|--------|
| N1 | `Subnet.parse` returned `error.Overflow` for out-of-range prefix while `init` returned `error.InvalidPrefix` | `parse` now returns `error.InvalidPrefix`, matching `init` | `a2eda93` |
| N2 | `IpAddr` lacked `isLoopback`/`isMulticast`/`isSafeForOutboundFetch` forwarding, forcing callers to switch on the variant | Forwarding methods added with tests | `50ae19f` |
| N3 | `Url.effectivePort` 0-sentinel for unknown schemes undocumented | Doc comment on the 0-as-no-known-default sentinel | `8d8772d` |
| N4 | README test count (304) and tarball URL (v0.1.0) stale; SECURITY.md said "GitHub issues" | README/CHANGELOG/SECURITY synced (322 tests, v0.1.2, GitLab confidential-issue path) | `02ac589` |
| N5 | `IpAddr.parse` v4/v6 dispatch rule (colon presence) undocumented | Dispatch + error-attribution consequence documented | `50ae19f` |

### Status migrations — 5th pass (2026-04-18)

| Q-ID | Prior | New | Reason |
|------|-------|-----|--------|
| Q16 | Open (Medium) | **Closed (5th pass)** | `Url.parse` stage extraction, commit `d2e462f`. |
| Q18 | Open (Medium) | **Closed (5th pass)** | `longestZeroRun` extracted, commit `4a79591`. |
| Q19 | Open (Medium) | **Closed (5th pass)** | `parseSides`/`placeRight` extracted, commit `2adbad0`. |
| Q20 | Open (Medium) | **Closed (5th pass)** | Hex-digit shims deleted, commit `404cf2e`. |
| Q32 | Open (Low) | **Closed (5th pass)** | Compiled doctests landed, commit `346e6f5`. |
| Q42 | Open (High) | **Closed (5th pass)** | README prose reconciled, commit `242ecca` (resolves GAP-0023 too). |
| Q43 | Open (Medium) | **Closed (5th pass)** | Comptime `parserFuzzer` dedup, commit `4528ae0`. |
| Q44 | Open (High) | **Closed (5th pass)** | `pretty-format-yaml` autofix, commit `f4ccf89`. |
| Q45 | Open (Medium) | **Closed (5th pass)** | `network.zig` split into 7 files, commits `6e10b41`..`b5d16ec`. |
| Q46 | Open (Low) | **Closed (5th pass)** | Empty-slice rationale documented, commit `e79ed47`. |

---

## Historical findings (Q1–Q13)

| # | Finding | Severity | Status | Resolution |
|---|---------|----------|--------|-----------|
| Q1 | Vector.format uses concrete `*std.Io.Writer` instead of `anytype` | High | Closed | Changed to `anytype` in vector.zig |
| Q2 | network.zig doc coverage ~7% | High | Closed | Added `///` to all public types/fns |
| Q3 | docs/README.md dead links | Medium | Closed | Replaced with live links |
| Q4 | examples/basic.zig did not import library | Medium | Closed | Rewrote to use all 5 type families |
| Q5 | Duplicate hex-digit parsers | Medium | Closed (partial reopen → Q20, closed 5th pass) | Extracted `hexDigitToInt`; shims removed |
| Q6 | Identical branches in vector.zig format | Medium | Closed | Dead conditional removed |
| Q7 | Custom whitespace helpers in geographic.zig | Medium | Closed | Use stdlib |
| Q8 | `Range.isEmpty` misleading | Medium | Closed | Renamed to `isPoint()` |
| Q9 | network.zig 919 LOC | Low | Won't Do → Reopened as Q45 → Closed 5th pass (commit `b5d16ec`) | Facade + 7 per-type files |
| Q10 | Missing edge-case tests | Low | Closed via Q33 (9e937b5) | 16 regression tests landed |
| Q11 | CI Zig version drift | Medium | Closed via Q36 (3702dd1) | Reconciled to 0.16.0 |
| Q12 | CI reinstalls Zig per job | Medium | Won't Do | Requires custom Docker image |
| Q13 | examples/basic.zig no build step | Low | Closed | Added `example` build step |

---

## Closed this pass (5th Gap Closure Pass, 2026-04-18)

| Q-ID | Severity | PriorityScore | Status | Resolution | Commit / Issue |
|------|----------|--------------:|--------|------------|----------------|
| Q42 | High | 64 | Closed 2026-04-18 | README + CHANGELOG reconciled to 304 tests; fuzz-broken notice dropped | `242ecca` / [#48](https://gitlab.com/devnw/zig/advanced-types/-/issues/48) |
| Q44 | High | 64 | Closed 2026-04-18 | `.cz.yaml` pretty-format-yaml autofix applied | `f4ccf89` / [#49](https://gitlab.com/devnw/zig/advanced-types/-/issues/49) |
| Q45 | Medium | 48 | Closed 2026-04-18 | `network.zig` split: 68-LOC facade + 7 per-concern files under `src/types/network/` | `6e10b41`..`b5d16ec` / [#50](https://gitlab.com/devnw/zig/advanced-types/-/issues/50) |
| Q16 | Medium | 48 | Closed 2026-04-18 | `Url.parse` split into 7 named stage helpers; orchestrator 36 LOC | `d2e462f` / [#51](https://gitlab.com/devnw/zig/advanced-types/-/issues/51) |
| Q43 | Medium | 48 | Closed 2026-04-18 | `tests/fuzz.zig` deduped via comptime `parserFuzzer` (155 → 103 LOC) | `4528ae0` / [#52](https://gitlab.com/devnw/zig/advanced-types/-/issues/52) |
| Q18 | Medium | 48 | Closed 2026-04-18 | `longestZeroRun` extracted from `Ipv6Addr.format` | `4a79591` / [#54](https://gitlab.com/devnw/zig/advanced-types/-/issues/54) |
| Q19 | Medium | 48 | Closed 2026-04-18 | `parseSides` + `placeRight` extracted from `Ipv6Addr.parse` | `2adbad0` / [#55](https://gitlab.com/devnw/zig/advanced-types/-/issues/55) |
| Q20 | Medium | 40 | Closed 2026-04-18 | Hex-digit wrapper shims inlined to `hexDigitToInt` | `404cf2e` / [#56](https://gitlab.com/devnw/zig/advanced-types/-/issues/56) |
| Q32 | Low | 24 | Closed 2026-04-18 | 3 compiled doctests mirror `//!` + README examples | `346e6f5` / — |
| Q46 | Low | 24 | Closed 2026-04-18 | Empty-slice rationale doc-comment added to `Url.parse` | `e79ed47` / — |

---

## Closed prior passes (Q15, Q17, Q25, Q26, Q30, Q31, Q33, Q36)

| Q-ID | Severity | PriorityScore | Status | Resolution | Commit / Issue |
|------|----------|--------------:|--------|------------|----------------|
| Q30 | Critical | 80 | Closed 2026-04-18 (4th pass) | Ported fuzz suite to 0.16 Smith API; 10/10 green | `c0e07ee` / [#26](https://gitlab.com/devnw/zig/advanced-types/-/issues/26) |
| Q25 | High | 64 | Closed 2026-04-18 (4th pass) | Lifetime contract docs on `Url`/`Domain` | `5c97228` / [#31](https://gitlab.com/devnw/zig/advanced-types/-/issues/31) |
| Q26 | High | 64 | Closed 2026-04-18 (4th pass) | `Subnet.init` validator + defensive `containsV4`/`containsV6` | `503c1f5` / [#28](https://gitlab.com/devnw/zig/advanced-types/-/issues/28) |
| Q36 | High | 64 | Closed 2026-04-18 (4th pass) | Reconciled manifest/README/CI to 0.16.0 | `3702dd1` / [#34](https://gitlab.com/devnw/zig/advanced-types/-/issues/34) |
| Q17 | Medium | 48 | Closed 2026-04-18 (4th pass) | Split into `containsV4`/`containsV6` | `503c1f5` / [#37](https://gitlab.com/devnw/zig/advanced-types/-/issues/37) |
| Q15 | Medium | 48 | Closed 2026-04-18 (4th pass) | Extracted `internal/parse.zig` iterator | `ca54cdb` / [#38](https://gitlab.com/devnw/zig/advanced-types/-/issues/38) |
| Q31 | Medium | 48 | Closed (report-only) 2026-04-18 (4th pass) | kcov job wired; percentage gate deferred | `20b233c` / [#40](https://gitlab.com/devnw/zig/advanced-types/-/issues/40) |
| Q33 | Medium | 48 | Closed 2026-04-18 (4th pass) | 16 edge-case regression tests landed | `9e937b5` / [#41](https://gitlab.com/devnw/zig/advanced-types/-/issues/41) |
| Q38 | Low → High | — | **Superseded by Q42** | Same root cause; severity raised | — / [#27](https://gitlab.com/devnw/zig/advanced-types/-/issues/27) |

### Accepted

| Q-ID | Severity | PriorityScore | Status | Reason |
|------|----------|--------------:|--------|--------|
| Q21 | Low | 8 | Accepted (ledger-only) | Low-value shim removal; batched with future cleanup |
| Q22 | Low | 16 | Accepted | Hand-rolled digit accumulation — benchmark-driven |
| Q23 | Low | 24 | Accepted | Hand-rolled big-endian packing — acceptable |
| Q24 | Low | 4 | Accepted | Idiomatic Zig generic factories |

---

## Remaining open findings (all Low, ledger-only)

PriorityScore = Impact (1-5) × Likelihood (1-5) × 4. Critical >= 80, High 60–79, Medium 40–59, Low < 40.

| Rank | Q-ID | Severity | PriorityScore | Category | Finding | Component | Status |
|-----:|------|----------|--------------:|----------|---------|-----------|--------|
| 1 | Q14 | Low | 32 | refactor | Magic literals in `geographic.zig` (180, 90, π/180) | `src/types/geographic.zig:100,103,128,180,183,328,379` | Open (ledger-only) — kept: numeric-refactor risk; wants its own PR with bench verification |
| 2 | Q28 | Low | 24 | docs | `ParseError` name collision across 5 modules | `network.zig:29`, `url.zig:16`, `vector.zig:26`, `range.zig:14`, `geographic.zig:17` | Open (ledger-only) — kept: rename is a breaking API change |
| 3 | Q39 | Low | 24 | docs | Missing `docs/ARCHITECTURE.md` | `docs/ARCHITECTURE.md` (missing) | Open (ledger-only) — kept: authored doc, scheduled deliberately |
| 4 | Q40 | Low | 16 | docs | No ADRs (`docs/adr/` missing) | `docs/adr/` | Open (ledger-only) — kept: authored doc, scheduled deliberately |

Q27, Q29, Q34, Q35, Q37, and Q41 left this table in the 6th pass (2026-06-11);
see "Status migrations — 6th pass" above. The 4 remaining items stay open by
deliberate choice, not neglect. None have a corresponding open GitLab issue.

---

## Findings by category (remaining open)

- **Docs (3):** Q28, Q39, Q40
- **Refactor (1):** Q14

---

## Roadmap

### Quick wins (< 1 day) — all landed

(Every quick win closed this pass; see "Closed this pass" above.)

### Medium (1–5 days) — all landed

(Every medium-effort item closed this pass.)

### Strategic (> 5 days) — still outstanding

- **Q31 follow-on** — 85% CI coverage-percentage gate (deferred from 4th pass; tracked in `docs/audit/gap-close-blockers.md`)
- **Q39 + Q40** — architecture doc + ADR set
- ~~**Q34 + Q35** — build-system filter + mode-specific test harness~~ Closed 6th pass (`fd4d9db`)

---

## Reconciliation with security tracker

- Q26 ≡ SAST-01 — closed 2026-04-18 (4th pass) by `503c1f5`. Primary ticket [#28](https://gitlab.com/devnw/zig/advanced-types/-/issues/28).

---

## Issue state (this pass)

All 8 work items opened against the 5th-pass plan were closed on GitLab.

| Q | Issue | Action |
|---|-------|--------|
| Q42 | [#48](https://gitlab.com/devnw/zig/advanced-types/-/issues/48) | Closed |
| Q44 | [#49](https://gitlab.com/devnw/zig/advanced-types/-/issues/49) | Closed |
| Q45 | [#50](https://gitlab.com/devnw/zig/advanced-types/-/issues/50) | Closed |
| Q16 | [#51](https://gitlab.com/devnw/zig/advanced-types/-/issues/51) | Closed |
| Q43 | [#52](https://gitlab.com/devnw/zig/advanced-types/-/issues/52) | Closed |
| Q18 | [#54](https://gitlab.com/devnw/zig/advanced-types/-/issues/54) | Closed |
| Q19 | [#55](https://gitlab.com/devnw/zig/advanced-types/-/issues/55) | Closed |
| Q20 | [#56](https://gitlab.com/devnw/zig/advanced-types/-/issues/56) | Closed |

Ledger-only (no issue): Q14, Q27*, Q28, Q29*, Q32*, Q34*, Q35*, Q37*, Q39, Q40, Q41*, Q46*, N1–N5*. (*Closed in-code — Q32/Q46 in the 5th pass, Q27/Q29/Q34/Q35/Q37/Q41 and N1–N5 in the 6th pass — but carry no tracker ticket. Still open: Q14, Q28, Q39, Q40.)
