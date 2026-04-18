# Full Codebase Audit Summary

**Date:** 2026-04-18
**Project:** devnw/zig/advanced-types
**Platform:** GitLab (gitlab.com/devnw/zig/advanced-types)
**Languages:** Zig 0.15.1+ (CI runs 0.16.0)
**Scope:** Full repo
**Issue creation:** Authorized and performed

---

## Repository

- Pure-Zig library extracted from Geode — portable value types (IPv4/v6, MAC, Subnet, URL, Domain, LatLon, GeoPoint, Vector, Range).
- **17 public types, 4,609 LOC, 11 .zig files, 262 runnable tests**, zero runtime dependencies.
- Apache-2.0. Single code owner `@benjiv` (bus-factor 1).
- CI: `.gitlab-ci.yml` runs SAST, gitleaks, secret detection, dependency scan, SBOM generate+scan; unit tests across Debug/ReleaseSafe/ReleaseFast/ReleaseSmall; Zig tarball SHA-256 verified.

---

## Domain Results

### Gap Analysis

**Requirements traced:** 22 (17 pre-existing + 5 new this run). Trace: 16 Implemented / 1 Partial / 5 Not Implemented / 0 Unknown.

| Status | Count |
|--------|-------|
| Implemented | 16 |
| Partial | 1 (#21 AT-NFR-004) |
| Not Implemented | 5 |
| Unknown | 0 |

**Open gaps after this phase: 10** (Critical 2 · High 3 · Medium 2 · Low 3).

**Refuted prior closures:** GAP-0011 (no coverage job in CI), GAP-0018 (fuzz broken on Zig 0.16).

Test-count reconciliation: README 230 / ledger 272 → actual **262** (272 − 10 fuzz broken).

### Code Quality

28 new findings (Q14–Q41); 10 of Q1–Q13 confirmed closed; Q5/Q10/Q11 partially reopen as Q20/Q33/Q36.

| Severity | Count |
|----------|-------|
| Critical | 1 (Q30) |
| High | 3 (Q26, Q25, Q36) |
| Medium | 4 |
| Low | 20 |

**PriorityScore top finding:** Q30 — Fuzz suite broken on Zig 0.16 (score **80**).

**Green baseline:** `zig fmt` clean, `zig build check` clean, 233/233 tests × 4 optimize modes. Doc coverage 80.9% overall / 95.0% excluding `root.zig` façade.

### Performance

| PerfSeverity | Count |
|-------------|-------|
| P1 | 2 (I1 bench harness, D1 README overflow docs) |
| P2 | 3 (D2 assert, A1 Url scans, S1 haversine) |
| P3 | 0 |

**PerfScore top finding:** I1 — no `zig build bench` harness (score **80**). P1 ledger entry reopened; every P5/P7/P9 "Won't Do" rests on "trust the compiler" with nothing defending against toolchain regressions.

**Ledger corrections:** P7 scan count 5 → 6; P9 trig count 6 → 7 (atan2 was omitted).

**Zero-alloc contract confirmed** by grep across `src/`. Integer-overflow semantic divergence (panic in Debug/Safe vs wrap in ReleaseFast) is per-function documented but not at README/NFR level — D1 fix recommended.

### Security

| Risk Level | Count |
|-----------|-------|
| Critical | 1 (SAST-09) |
| High | 2 (SAST-05, SAST-01) |
| Medium | 4 (SAST-07, SC-01, SAST-04, NEW-02) |
| Low | 1 (NEW-01) |

**Immediate actions before next release:** patch SAST-09, SAST-05, SAST-01. Zero secret rotations (gitleaks 0 / trufflehog 0).

**Top finding — SAST-09 (Risk 80, Critical, CWE-918):** `Ipv4Addr.isPrivate`/`isLoopback` + `Ipv6Addr.isLoopback` miss link-local (`169.254.169.254`), CGNAT, IPv6 `fc00::/7`, `fe80::/10`, and IPv4-mapped-v6 (`::ffff:169.254.169.254`). Consumers using these as an SSRF allow-gate are bypassable. Recommended API: add `isSafeForOutboundFetch(self)` on v4 and v6 with v4-mapped-v6 downcast.

**Ledger drift corrected:** S7 flipped from "Won't Do" to "Closed" — CI implements SHA-256 verify at `.gitlab-ci.yml:39-77`.

---

## Cross-Domain Summary

| Domain | Findings | Issues Created | Issues Updated | Ledger Reopened |
|--------|----------|----------------|----------------|----------------|
| Gap Analysis | 10 open | 6 (#23, #24, #25, #27, #30, #32) | 0 | GAP-0011, GAP-0018 |
| Quality | 28 new | 8 (#26, #28, #31, #34, #37, #38, #40, #41) | 20 ledger-only | Q5→Q20, Q10→Q33, Q11→Q36 |
| Performance | 5 actionable | 3 (#29, #33, #36) | 2 monitor | P1 |
| Security | 8 new | 8 (#35*, #39*, #42*, #43, #44, #45, #46, #47) | 0 | — |
| **Total** | **51** | **25** | — | — |

\* Confidential issues (#35 SAST-09, #39 SAST-01, #42 SAST-05).

**Cross-domain dedup:** Q26 ≡ SAST-01 (same code path, two lenses). Issues cross-linked, not duplicated — #28 is the quality/API ticket, #39 is the confidential security ticket.

### Docs Updated

| File | Domain | Action |
|------|--------|--------|
| `README.md` | Gap | Test count 230 → 262; fuzz-broken note |
| `docs/GAP_ANALYSIS.md` | Gap | Appended GAP-0019..0022; flipped GAP-0011/0018 to Open |
| `docs/GAP_ANALYSIS_RESOLVED.md` | Gap | Annotated GAP-0011/0018 as "Regressed on 2026-04-18" |
| `docs/QUALITY_GAP_ANALYSIS.md` | Quality | Rewritten 41-row ledger; PriorityScore column; Q-reopens; roadmap |
| `docs/PERF_GAP_ANALYSIS.md` | Perf | Reopened P1; corrected P7/P9 counts; appended I1/D1/D2/A1/S1 |
| `docs/SECURITY_GAP_ANALYSIS.md` | Security | Flipped S7 to Closed; appended SAST-01/04/05/07/09, NEW-01/02, SC-01 |
| `docs/audit/*` (12 files) | All | Orientation, scan, review artifacts per domain |

### Top 10 Findings (cross-domain, by severity/score)

| # | Domain | Finding | Severity | Score | Issue |
|---|--------|---------|----------|-------|-------|
| 1 | Security | SAST-09 SSRF cloud-metadata bypass (isPrivate/isLoopback) | Critical | Risk 80 | #35 (confidential) |
| 2 | Gap | GAP-0019 CI Linux/x86_64-only vs README cross-platform claim | Critical | — | #23 |
| 3 | Gap | GAP-0020 Fuzz suite broken under Zig 0.16 (std.testing.fuzz API change) | Critical | — | #24 |
| 4 | Quality | Q30 Fuzz suite broken (≡ GAP-0020) | Critical | 80 | #26 |
| 5 | Perf | I1 No `zig build bench` harness (reopen P1) | P1 | 80 | #29 |
| 6 | Security | SAST-05 Url userinfo bypass (`http://a@b/`) | High | Risk 64 | #42 (confidential) |
| 7 | Quality | Q25 Url/Domain slice-lifetime contract undocumented | High | 64 | #31 |
| 8 | Quality | Q36 `minimum_zig_version` 0.15.1 vs CI 0.16.0 drift | High | 64 | #34 |
| 9 | Security | SAST-01 Subnet IPv6 OOB panic with invalid prefix_len | High | Risk 48 | #39 (confidential) |
| 10 | Gap | GAP-0021 CI missing test-extensions/test-performance + ReleaseSmall integration | High | — | #25 |

### Blockers

- **None.** All domains completed cleanly.
- Cosmetic: `glab auth status` warns "Invalid token provided in configuration file," but all API calls succeeded (25 issues created, all returned 201).

---

## Immediate Action Plan (recommended order)

1. **Patch SAST-09, SAST-05, SAST-01** before next release (security blocker).
2. **Port `tests/fuzz.zig` to Zig 0.16 Smith API** (GAP-0020 / Q30) — restores core parser-robustness invariant.
3. **Bump `build.zig.zon:minimum_zig_version` to 0.16.0** (Q36) — align with CI.
4. **Expand CI to macOS/Windows/aarch64** (GAP-0019) — matches README NFR claim, or retract the claim.
5. **Wire `test-extensions` + `test-performance` into CI** (GAP-0021) — close the CI surface gap.
6. **Add `zig build bench` harness** (I1) — defend the zero-alloc / single-pass / auto-vectorize claims against toolchain regressions.
7. **Document `Url`/`Domain` slice-lifetime contract** (Q25 / SAST-04) — prevents downstream UAF.
8. **Doc drift fixes** (Q36, GAP-0022, README test count) — small, high-signal.
