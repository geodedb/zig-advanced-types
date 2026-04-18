# Full Codebase Audit Summary

**Date:** 2026-04-18 (second pass)
**Project:** devnw/zig/advanced-types
**Platform:** GitLab (gitlab.com/devnw/zig/advanced-types)
**Languages:** Zig 0.16.0
**Scope:** Full repo
**Issue creation:** Authorized and performed
**Prior audit:** commit `f3adc69` (same day, ~12 h earlier)

---

## Repository

- Pure-Zig library extracted from Geode — portable value types (IPv4/v6, MAC, Subnet, URL, Domain, LatLon, GeoPoint, Vector, Range).
- **14 `.zig` files, 303 runnable tests** (248 unit + 11 extensions + 9 integration + 16 parser-edges + 9 performance + 10 fuzz), zero runtime dependencies (`build.zig.zon:6 .dependencies = .{}`).
- Apache-2.0. Single code owner `@benjiv` (bus-factor 1).
- CI: `.gitlab-ci.yml` runs SAST / gitleaks / secret-detection / dependency-scan / SBOM; unit tests across Debug/ReleaseSafe/ReleaseFast/ReleaseSmall; cross-OS jobs (macOS, Windows, Linux-aarch64) gated `allow_failure: true`; fuzz 60 s manual/schedule; **kcov coverage report-only** (added `20b233c`).
- No `.github/` workflows — GitHub is unused for this project.

---

## Domain Results

### Gap Analysis

**Requirements traced:** 32 reconciled (up from 22). Trace: 26 Implemented / 2 Partial / 4 Not Implemented / 0 Unknown.

| Status | Count | Percentage |
|--------|-------|-----------|
| Implemented | 26 | 81 % |
| Partial | 2 | 6 % |
| Not Implemented | 4 | 13 % |
| Unknown | 0 | 0 % |

**Open gaps: 6** (Critical 0 · High 2 · Medium 1 · Low 3).

| Gap-ID | Title | Severity | State |
|--------|-------|:--------:|-------|
| GAP-0014 | Geode consumer integration | High | Blocked (external repo) |
| GAP-0019 | Cross-platform CI runners (macOS/Windows/aarch64) | High | Partial (`allow_failure: true`) |
| GAP-0017 | Geode integration-test port | Medium | Blocked |
| GAP-0015 | `DateRange` type | Low | Deferred (upstream datetime) |
| GAP-0016 | `st_*` helpers | Low | Deferred |
| GAP-0023 | README/CHANGELOG test-count drift | Low | **New** (262/230 vs actual 303) |

**Closed since prior audit (5):** GAP-0011 coverage-in-CI, GAP-0018 fuzz-broken, GAP-0020 fuzz-signature, GAP-0021 extensions/perf/ReleaseSmall matrix, GAP-0022 test-count drift (ledgers only).

### Code Quality

**Top finding by PriorityScore:** Q42 — `README.md:14` claims "262 Tests ... fuzz suite currently broken under Zig 0.16"; both clauses are stale (actual 303, fuzz green). PriorityScore **64** (High). Tied: Q44 — `.cz.yaml` fails `pretty-format-yaml` hook on every clean checkout (64).

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 2 (Q42, Q44) |
| Medium | 6 (Q45, Q16, Q43, Q20, Q18, Q19) |
| Low | 2 (Q46, Q32) |

**Tooling status:** PASS — `zig fmt --check`, `zig build check`, `zig build test` (248/248), all Zig test suites (303 total), pre-commit Zig/whitespace/JSON/YAML-schema hooks. FAIL — `markdownlint` (7 issues in docs/templates), `pretty-format-yaml` (`.cz.yaml`). SKIP — `shellcheck` (no shell scripts).

### Performance

**Top finding by PerfScore:** **BENCH-01 / I2** — bench harness has no warm-up / min-of-N / stdev; measured 1.3-2.2× intra-run variance (`Ipv4Addr.parse`: 11.87 / 25.92 / 14.05 ns/op). PerfScore **80** (Fix). Mechanically gates every `confidence::suspected` finding from promoting past Monitor.

| PerfSeverity | Count |
|-------------|-------|
| P0 | 0 |
| P1 | 2 (BENCH-01, BENCH-02) |
| P2 | 2 (BENCH-03, A1 / URL-01) |
| P3 | 4 (A6 / FMT-01, S1 / PRECOMP-01, IPADDR-01, S3) |

**Bench health vs prior scan baseline:** no regression — Ipv4=24.5, Ipv6=26.6, Url=95.4, cosine=1.2, haversine=1.2 ns/op (ReleaseFast). Every min ≤ baseline; jitter exceeds every finding's projected win (→ BENCH-01 is the gate).

### Security

**Top finding by Risk Score:** SAST-PANIC-01 — `Vector.at(i)` at `src/types/vector.zig:76-80` calls `@panic("Vector index out of bounds")`; documented but reachable from untrusted `usize`. Risk **24** (Medium). One-line hardening: replace `@panic` with `std.debug.assert(i < N)`.

| Risk Level | Count |
|-----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 4 (SAST-PANIC-01, SAST-DOS-01, CI-SUP-01, CI-SUP-02) |
| Low | 6 |

**Immediate actions:** None. 0 secret rotations, 0 active vulnerabilities. Gitleaks v8 scanned 26 commits / ~580 KB — 0 findings. Dependency graph empty — nothing for OSV/Trivy/Grype to resolve.

Previously-Critical items (SAST-01/04/05/07/09, NEW-01) all **closed on main** and verified by security-review.md against current sources.

---

## Cross-Domain Summary

| Domain | Findings | Issues Created | Issues Updated | Issues Closed |
|--------|---------:|---------------:|---------------:|--------------:|
| Gap Analysis | 6 open | 1 (#53) | 6 (label/state sync) | 5 (sync) |
| Quality | 10 (top 10 tracked) | 8 (#48-52, #54-56) | 2 (comments) | 0 new |
| Performance | 8 | 8 (#57-64) | 0 | 0 new |
| Security | 9 | 9 (#65-73) | 0 | 0 new |
| **Total** | **33** | **26** | **8** | **5** |

## Docs Updated

| File | Domain | Action |
|------|--------|--------|
| `docs/audit/gap-requirements.md` | Gap | rewritten (32 reqs, up from 22) |
| `docs/audit/gap-trace.md` | Gap | rewritten (26 / 2 / 4 / 0) |
| `docs/audit/gap-detected.md` | Gap | rewritten (6 open) |
| `docs/GAP_ANALYSIS.md` | Gap | updated (6 open) |
| `docs/GAP_ANALYSIS_RESOLVED.md` | Gap | updated (+5 closed + rollup sync) |
| `docs/audit/quality-inventory.md` | Quality | rewritten |
| `docs/audit/quality-scan.md` | Quality | rewritten |
| `docs/audit/quality-review.md` | Quality | rewritten |
| `docs/QUALITY_GAP_ANALYSIS.md` | Quality | updated |
| `docs/audit/perf-context.md` | Perf | rewritten |
| `docs/audit/perf-scan.md` | Perf | rewritten |
| `docs/audit/perf-review.md` | Perf | rewritten |
| `docs/PERF_GAP_ANALYSIS.md` | Perf | updated |
| `docs/audit/security-inventory.md` | Security | rewritten |
| `docs/audit/security-scan.md` | Security | rewritten |
| `docs/audit/security-review.md` | Security | rewritten |
| `docs/SECURITY_GAP_ANALYSIS.md` | Security | updated |

## Top 10 Findings (cross-domain)

| # | Domain | Finding | Severity | Score | Issue |
|--:|--------|---------|----------|:-----:|-------|
| 1 | Perf | BENCH-01 / I2 — bench harness: no warm-up/min-of-N/stdev → 1.3-2.2× jitter | P1 | 80 | #57 |
| 2 | Quality | Q42 — README/CHANGELOG test-count drift (262/230 vs 303); claims fuzz broken | High | 64 | #48 |
| 3 | Quality | Q44 — `.cz.yaml` fails `pretty-format-yaml` hook every clean checkout | High | 64 | #49 |
| 4 | Perf | BENCH-02 / I3 — no perf-regression gate; bench is `allow_failure: true` | P1 | 48 | #58 |
| 5 | Perf | BENCH-03 / I4 — missing bench corpus (IpAddr/Ipv4Addr.format/Mac.format/Subnet.contains/haversineBroadcast) | P2 | 48 | #59 |
| 6 | Perf | A1 / URL-01 — `Url.parse` 6-8 linear scans, fused state-machine targets 30-40 % | P2 | 48 | #60 |
| 7 | Quality | Q45 — `network.zig` 1,166 LOC — split Ipv4/Ipv6/Subnet/Mac into `src/types/network/` | Medium | 48 | #50 |
| 8 | Quality | Q16 — `Url.parse` 108 LOC — stage extraction (elevated Low → Medium) | Medium | 48 | #51 |
| 9 | Security | SAST-PANIC-01 — `Vector.at` `@panic` reachable on untrusted index; replace with `std.debug.assert` | Medium | 24 | #65 |
| 10 | Security | SAST-DOS-01 — 8 parsers lack `MAX_INPUT` cap (Ipv4/Ipv6/IpAddr/Subnet/Url/LatLon/GeoPoint/Range) | Medium | 16 | #66 |

## Status Migrations (since `f3adc69`)

- AT-NFR-004 Partial → **Implemented** (`a5abd3e`)
- GAP-0018 Refuted → **Implemented** (`c0e07ee`)
- GAP-0011 Refuted → **Implemented (report-only)** (`20b233c`)
- Q9 Won't-Do → **reopened as Q45** (network.zig grew to 1,166 LOC)
- Q16 Low → **Medium** (Url.parse now 108 LOC)
- Q20 Low → **Medium**
- Q38 Low → **superseded by Q42 (High)**

## Blockers

- **GAP-0014 / GAP-0017** — gated on Geode consumer repo availability. External blocker.
- **GAP-0015** — gated on upstream `datetime` package. External blocker.
- **GAP-0019** — cross-OS runners unprovisioned (infra cost). `allow_failure: true` on MRs.
- **BENCH-01** — gatekeeper for 5 of 8 open Perf items. Until harness lands min-of-N aggregation, `suspected → confirmed` promotions are numerically impossible.
- **NEW-REL-01** — suspected; confirmation requires inspecting next `release-semantic` pipeline output (tag signature, SBOM-as-release-asset, SLSA provenance).

## Comparison to Prior Audit (`f3adc69`, same day)

| Metric | Prior | This run | Delta |
|--------|------:|---------:|------:|
| Requirements tracked | 22 | 32 | +10 (scope expansion) |
| Open gaps | 10 | 6 | -4 |
| Critical findings (any domain) | 3 (gap) + 1 (Q30) | 0 | **cleared** |
| Tests runnable | 262 | 303 | +41 |
| Bench regressions | 0 | 0 | — |
| Secret findings | 0 | 0 | — |
| Dep vulnerabilities | 0 | 0 | — |

## Recommended Next Actions (one-MR bundle)

1. **Q42** — edit `README.md:14`, `CHANGELOG.md:17` — remove "fuzz broken", update to 303 tests (≤ 10 LOC, 1 commit).
2. **Q44** — run `pretty-format-yaml --autofix .cz.yaml`, commit diff (or add to `.pre-commit-config` excludes with rationale).
3. **SAST-PANIC-01** — `src/types/vector.zig:76-80`, swap `@panic` for `std.debug.assert(i < N)` (1-line change).
4. **CI-SUP-01/02** — add SHA-256 verify to macOS `brew` / Windows `iwr` Zig install steps in `.gitlab-ci.yml`.
5. **BENCH-01** — add warm-up + min-of-N + stdev to `bench/main.zig`; unblocks #58, #59, #60, #61, #62, #63, #64.

All five are self-contained, low-risk, and together close the top Quality and Security items while unblocking the Perf backlog.
