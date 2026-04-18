# Gap Closure Completion Report

**Date:** 2026-04-18
**Branch:** main
**Owner:** `benji@codepros.org`
**Ledger commit:** `aca8968`
**Verifier:** docs/audit/gap-close-verify.md (PASS)
**Blockers doc:** docs/audit/gap-close-blockers.md

---

## Summary

| Bucket | Count | IDs |
|--------|-------|-----|
| Closed (evidence in-tree) | 24 | GAP-0011, GAP-0018, GAP-0020, GAP-0021, GAP-0022, Q15, Q17, Q25, Q26, Q30, Q31, Q33, Q36, P1, I1, D1, D2, SAST-01, SAST-04, SAST-05, SAST-07, SAST-09, NEW-01, (Q10 via Q33, Q11 via Q36 as cross-refs) |
| Won't Do (scoped, documented) | 2 | SC-01, NEW-02 |
| Partial (YAML landed, runners pending) | 1 | GAP-0019 |
| Ledger-only (PriorityScore < 40) | 20 | Q14, Q16, Q18-Q24, Q27-Q29, Q32, Q34, Q35, Q37-Q41 |
| Monitor (gated on I1 bench data, now decision-ready) | 2 | A1, S1 |
| Blocked on external deps (pre-existing) | 4 | GAP-0014 (Geode wiring), GAP-0015 (DateRange), GAP-0016 (st_* helpers), GAP-0017 (Geode integration tests) |

### Ledger file tallies

| File | Closed | Won't Do | Partial | Blocked | Open (ledger-only / monitor) |
|------|--------|----------|---------|---------|------------------------------|
| docs/GAP_ANALYSIS.md | 5 new + 12 historical | 1 historical | 1 (GAP-0019) | 4 | 0 |
| docs/QUALITY_GAP_ANALYSIS.md | 8 new + 10 historical | 2 historical | 0 | 0 | 20 |
| docs/PERF_GAP_ANALYSIS.md | 4 new + 2 historical | 10 | 0 | 0 | 2 (Monitor) |
| docs/SECURITY_GAP_ANALYSIS.md | 6 new + 7 historical | 2 | 0 | 0 | 0 |

### Test suite delta

| Metric | Baseline (pre-run) | Post-run | Delta |
|--------|-------------------:|---------:|------:|
| Total tests | 262 | **303** | +41 |
| unit (`zig build test`) | 233 | 248 | +15 |
| integration | 9 | 9 | 0 |
| extensions | 11 | 11 | 0 |
| performance | 9 | 9 | 0 |
| parser-edges (new suite) | 0 | 16 | +16 (new) |
| fuzz (`zig build test-fuzz`) | 0 (broken) | 10 | +10 (restored) |

---

## Commits landed on main (16 gap-close commits + 1 ledger commit)

| # | SHA | Type | Subject | Closes |
|--:|-----|------|---------|--------|
| 1 | 3702dd1 | chore | bump minimum_zig_version to 0.16.0 and reconcile README | GAP-0022, Q36 |
| 2 | 503c1f5 | fix(network) | Subnet.init validate prefix_len + refactor contains | SAST-01, Q26, Q17 |
| 3 | 1234a9f | perf(network) | assert prefix_len invariant at Ipv4 shift site | D2 |
| 4 | a178648 | feat(network) | isSafeForOutboundFetch + v4-mapped downcast | SAST-09 |
| 5 | f175133 | fix(url) | reject userinfo, control bytes, leading-zero port | SAST-05, SAST-07, NEW-01 |
| 6 | 5c97228 | docs(url) | slice-lifetime contract | Q25, SAST-04 |
| 7 | ca54cdb | refactor(geographic) | shared tuple-parser helper | Q15 |
| 8 | 9e937b5 | test(parsers) | IPv4/IPv6/Url edge-case regression suite (16) | Q33, Q10 |
| 9 | d786b46 | build(bench) | `zig build bench` harness | P1, I1 |
| 10 | 0c2ebbd | docs(readme) | ReleaseFast overflow-wrap semantics | D1 |
| 11 | c0e07ee | fix(tests) | port tests/fuzz.zig to Zig 0.16 Smith API | GAP-0020, GAP-0018, Q30 |
| 12 | a5abd3e | ci | test-extensions/test-performance/ReleaseSmall jobs | GAP-0021 |
| 13 | 505fe43 | ci | macOS/Windows/aarch64 unit-test matrix (dormant pending runners) | Refs GAP-0019 |
| 14 | 20b233c | ci | kcov coverage job (report-only) | GAP-0011, Q31 |
| 15 | 152d0f8 | chore | close SC-01 won't-do (platform-team controls) | SC-01 |
| 16 | df972dd | chore | close NEW-02 scoped-wontdo (Domain ASCII-only) | NEW-02 |
| 17 | aca8968 | docs | update gap analysis tracking -- 28 closed, 1 partial, 2 won't-do | — (ledger sync) |

---

## Closed Items -- Public Issues

| Gap-ID | Issue | Commit | Evidence |
|--------|-------|--------|----------|
| GAP-0011 / Q31 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/30> | 20b233c | .gitlab-ci.yml `coverage` job (report-only) |
| GAP-0011 / Q31 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/40> | 20b233c | dup -- closed |
| GAP-0018 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/32> | c0e07ee | tests/fuzz.zig 10/10 green |
| GAP-0020 / Q30 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/24> | c0e07ee | Smith API port |
| GAP-0020 / Q30 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/26> | c0e07ee | dup -- closed |
| GAP-0021 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/25> | a5abd3e | CI jobs added |
| GAP-0022 / Q36 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/27> | 3702dd1 | README + ledgers reconciled |
| Q25 / SAST-04 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/31> | 5c97228 | slice-lifetime doc |
| Q25 / SAST-04 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/44> | 5c97228 | dup -- closed |
| Q26 / SAST-01 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/28> | 503c1f5 | Subnet.init validator |
| Q36 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/34> | 3702dd1 | manifest + README |
| Q17 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/37> | 503c1f5 | containsV4/containsV6 split |
| Q15 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/38> | ca54cdb | tuple-parser helper |
| Q33 / Q10 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/41> | 9e937b5 | 16 edge-case tests |
| P1 / I1 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/29> | d786b46 | bench/main.zig harness |
| D1 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/33> | 0c2ebbd | README caveats |
| D2 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/36> | 1234a9f | debug-assert above @intCast |
| SAST-07 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/43> | f175133 | validateHostChars |
| NEW-01 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/46> | f175133 | leading-zero port guard |

## Closed Items -- Confidential Issues (content redacted)

| Gap-ID | Issue | Commit | Action |
|--------|-------|--------|--------|
| SAST-09 | #35 (confidential) | a178648 | confidential, closed |
| SAST-01 | #39 (confidential) | 503c1f5 | confidential, closed |
| SAST-05 | #42 (confidential) | f175133 | confidential, closed |

## Won't-Do Items

| Gap-ID | Issue | Commit | Reason |
|--------|-------|--------|--------|
| SC-01 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/47> | 152d0f8 | System-policy override: CI/CD hash + Docker tag pinning handled via different controls (platform-team supply-chain, not per-consumer-repo). See docs/audit/gap-close-blockers.md. |
| NEW-02 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/45> | df972dd | Domain is ASCII-only by design; IDN/Punycode is a feature, not a fix. Documented in SECURITY.md. |

## Partial / Blocked -- Not Closed

| Gap-ID | Issue | Status | Blocker | Unblock Steps |
|--------|-------|--------|---------|---------------|
| GAP-0019 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/23> | **Partial** (commented, open) | macOS/Windows/aarch64 runners not provisioned; jobs dormant with `allow_failure:true` and `rules:when:manual` | 1) Register runners with macos, windows, aarch64 tags. 2) Verify Zig 0.16.0 install paths per target. 3) Promote jobs from `rules:when:manual` once green. See docs/audit/gap-close-blockers.md. |
| GAP-0014 | (no issue) | **Blocked** | External dep -- Geode repo | Wire Geode consumer to advanced-types module |
| GAP-0015 | (no issue) | **Blocked** | External dep -- datetime package | Provide datetime type, then restore DateRange alias |
| GAP-0016 | (no issue) | **Deferred** | Feature-level scoping decision | Stage `st_*` helpers when query-layer work lands |
| GAP-0017 | (no issue) | **Blocked** | External dep -- Geode repo | Port Geode integration tests once consumer is wired |

---

## Tests Executed (from verifier report)

| Command | Result |
|---------|--------|
| `zig fmt --check .` | PASS |
| `zig build check` | PASS |
| `zig build test` | PASS 248 / 248 |
| `zig build test-integration` | PASS 9 / 9 |
| `zig build test-extensions` | PASS 11 / 11 |
| `zig build test-performance` | PASS 9 / 9 |
| `zig build test-parser-edges` | PASS 16 / 16 |
| `zig build test-fuzz` | PASS 10 / 10 |
| `zig build bench` | PASS (exit 0, 5 benchmarks) |
| `zig build test -Doptimize=ReleaseSafe` | PASS 248 / 248 |
| `zig build test -Doptimize=ReleaseFast` | PASS 248 / 248 |

**Total across all suites:** 303 / 303.

---

## Security Notes

- **Three pre-release confidential fixes landed:** SAST-09 (SSRF predicate, a178648), SAST-05 (userinfo bypass, f175133), SAST-01 (Subnet prefix validation, 503c1f5).
- **No secrets or credentials** added or detected. `gitleaks` and `trufflehog` baseline scans both 0.
- **No new unchecked narrowings:** the sole new `@intCast(u5)` at `containsV4:564` is guarded by both a `prefix_len < 32` early-return (`:555`) and a `std.debug.assert` (`:563`).
- **Fuzz suite restored** (10 parsers, panic-free on random bytes under Zig 0.16 Smith API).
- **Pre-commit markdownlint**: ledger files now lint-clean (headings normalized, bare URLs angle-bracketed); pre-existing debt in CODE_OF_CONDUCT.md / CONTRIBUTING.md / SUPPORT.md remains out of scope.

---

## Remaining Blockers / Immediate Follow-Ups

1. **GAP-0019 runner provisioning** -- register macOS, Windows, aarch64 runners; promote the three dormant CI jobs. Tracked at <https://gitlab.com/devnw/zig/advanced-types/-/work_items/23>.
2. **GAP-0011 percentage-gate** -- collect one week of kcov runs, set realistic floor (expected ~85%), add threshold-enforcing job. Ledger-tracked; no new issue yet.
3. **A1 Url.parse fused-scan** -- gated on I1 bench numbers now that harness exists. Decision: promote to Fix if `Url.parse` lands in top-5 hot paths on URL-heavy workload.
4. **S1 precomputed-origin haversine** -- gated on consumer (Geode) committing to bulk 1-to-many sweeps.
5. **GAP-0014/0015/0016/0017** -- external-dep blockers; no in-repo action.

---

## Platform Issues Updated

| Gap-ID | Issue | Action |
|--------|-------|--------|
| GAP-0020 | #24 | closed |
| GAP-0021 | #25 | closed |
| Q30 | #26 | closed |
| GAP-0022 | #27 | closed |
| Q26 / SAST-01 | #28 | closed |
| I1 / P1 | #29 | closed |
| GAP-0011 | #30 | closed |
| Q25 | #31 | closed |
| GAP-0018 | #32 | closed |
| D1 | #33 | closed |
| Q36 | #34 | closed |
| SAST-09 | #35 | closed (confidential) |
| D2 | #36 | closed |
| Q17 | #37 | closed |
| Q15 | #38 | closed |
| SAST-01 | #39 | closed (confidential) |
| Q31 | #40 | closed |
| Q33 | #41 | closed |
| SAST-05 | #42 | closed (confidential) |
| SAST-07 | #43 | closed |
| SAST-04 | #44 | closed |
| NEW-02 | #45 | closed (won't-do) |
| NEW-01 | #46 | closed |
| SC-01 | #47 | closed (won't-do) |
| GAP-0019 | #23 | commented (partial; remains open) |

**Totals:** 23 closed, 1 commented-open.

---

## Final Status

**Ready for release.** All fully-actionable gaps closed; one (GAP-0019) dormantly landed pending external runner provisioning; external-dep blockers (GAP-0014/0015/0016/0017) remain pre-existing and out of repo scope.
