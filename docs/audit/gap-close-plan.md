# Gap Closure Plan

**Date:** 2026-04-18
**Repo:** `/home/benji/src/devnw/zig/advanced-types`
**Branch:** `main` (per-gap direct commits, user-confirmed)
**Platform:** gitlab.com/devnw/zig/advanced-types (`glab` authorized)
**Zig toolchain (local + CI):** 0.16.0
**Prior-phase artifacts:** `docs/audit/{AUDIT_SUMMARY,gap-review,quality-review,perf-review,security-review}.md`

---

## 1. Gap Files Discovered

| File | Domain | Open | Partial | Closed | Blocked | Won't Do | Total |
|------|--------|-----:|--------:|-------:|--------:|---------:|------:|
| `docs/GAP_ANALYSIS.md` | functional / CI / testing | 6 | 0 | 12 | 4 | 0 | 22 (GAP-0001..0022) |
| `docs/QUALITY_GAP_ANALYSIS.md` | code quality | 27 | 0 | 11 | 0 | 2 | 41 (Q1..Q41; Q24 accepted) |
| `docs/PERF_GAP_ANALYSIS.md` | performance | 3 | 0 | 2 | 0 | 10 | 15 + monitor (A1, S1) |
| `docs/SECURITY_GAP_ANALYSIS.md` | security / SSRF / parsers | 8 | 0 | 7 | 0 | 0 | 15 |

All four ledger files were read end-to-end to verify the briefing summary; counts match.

---

## 2. Build / Test Tooling

| Action | Command | Source | Status |
|--------|---------|--------|--------|
| Unit tests | `zig build test` | `build.zig` | **PASS — 233/233** |
| Integration | `zig build test-integration` | `build.zig` | **PASS — 9/9** |
| Extensions | `zig build test-extensions` | `build.zig` | **PASS — 11/11** |
| Performance | `zig build test-performance` | `build.zig` | **PASS — 9/9** |
| Fuzz | `zig build test-fuzz` | `build.zig:60-72` | **SKIPPED (broken; GAP-0020 / Q30 — part of work)** |
| Format | `zig fmt --check .` | pre-commit `zig-fmt` | **PASS (clean)** |
| Build check | `zig build check` | pre-commit `zig-build` | **PASS (clean)** |
| Pre-commit (hooks) | `pre-commit run -a` | `.pre-commit-config.yaml` | configured; CI uses local hooks only in pre-push |
| Lint (dedicated) | — | none installed | `zig fmt --check` is the whole lint surface |
| Benchmark | `zig build bench` | **MISSING (I1)** | — |

**Baseline total:** `262 / 262 passing` across the four non-fuzz suites — matches `README.md` and `GAP_ANALYSIS.md`.

**Zig version on workstation:** `0.16.0` (matches CI per commit 380045a).

---

## 3. Baseline Test Results (exact)

```text
$ zig build test --summary all
Build Summary: 3/3 steps succeeded; 233/233 tests passed

$ zig build test-integration --summary all
Build Summary: 3/3 steps succeeded; 9/9 tests passed

$ zig build test-extensions --summary all
Build Summary: 3/3 steps succeeded; 11/11 tests passed

$ zig build test-performance --summary all
Build Summary: 3/3 steps succeeded; 9/9 tests passed

$ zig fmt --check .          # exit 0, no output
$ zig build check            # exit 0, no output
```

No pre-existing failures. Every regression after this point is attributable to gap-closure work.

---

## 4. Actionable Scope (from briefing, verified against ledgers)

### Gap ledger

Actionable (Open): **GAP-0011, GAP-0018, GAP-0019, GAP-0020, GAP-0021, GAP-0022**.
Blocked (skip): GAP-0014, GAP-0015, GAP-0016, GAP-0017.
(GAP-0001..0010, 0012, 0013 already Closed.)

### Quality ledger (PriorityScore ≥ 40 issues)

**Q30, Q26, Q25, Q36, Q17, Q15, Q31, Q33.**
Note: **Q30 ≡ GAP-0020**, **Q26 ≡ SAST-01**, **Q31 ≡ GAP-0011**, **Q36 ⊂ GAP-0022**. De-duped in commit plan below.

### Perf ledger

**I1 (bench harness), D1 (README overflow docs), D2 (network.zig:466-469 assert).**
Monitor-only (A1, S1): stay unclosed.

### Security ledger

**SAST-09, SAST-05, SAST-01, SAST-07, SAST-04, SC-01, NEW-01, NEW-02.**

---

## 5. Implementation Order (semantic-dependency + file-grouping)

Ordering rules applied:

- Same-file edits batched into one commit to avoid rebase conflicts.
- Hard dependencies first (SAST-01 → D2; SAST-01 ↔ Q17 together).
- Parsers hardened in `url.zig` as one commit (SAST-05 + SAST-07 + NEW-01) before the doc-only SAST-04/Q25 commit lands.
- Doc / CI / infra commits interleaved where they do not block code work.
- Won't-Do commits at the end so design-decision cost isn't paid mid-implementation.

| # | Commit subject (sketch) | Files | Closes | Depends on | Test cmd |
|--:|-------------------------|-------|--------|------------|----------|
| 1 | `chore(manifest): bump minimum_zig_version to 0.16.0 and reconcile README` | `build.zig.zon:5`, `README.md:4,71`, `README.md:14` (test count already 262) | **Q36, GAP-0022** | — | `zig build check` |
| 2 | `fix(network): validate prefix_len in Subnet.init and refactor contains into v4/v6 helpers` | `src/types/network.zig:419-506` | **SAST-01, Q26, Q17** | 1 | `zig build test` (add IPv6 OOB regression + prefix_len>128 tests) |
| 3 | `perf(network): assert prefix_len invariant at Ipv4 shift site` | `src/types/network.zig:466-469` | **D2** | 2 (redundant-but-documented once #2 lands) | `zig build test` Debug + ReleaseFast |
| 4 | `feat(network): add isSafeForOutboundFetch on Ipv4Addr + Ipv6Addr with v4-mapped downcast` | `src/types/network.zig` (new methods + tests in `tests/unit/network_test.zig` or file-local) | **SAST-09** | 2 (same file) | `zig build test` (new cases: 169.254/16, 100.64/10, fc00::/7, fe80::/10, 0.0.0.0, ::ffff:169.254.169.254) |
| 5 | `fix(url): reject userinfo, control bytes, and port leading-zeros in parse` | `src/types/url.zig:207-230`, port helper | **SAST-05, SAST-07, NEW-01** | — | `zig build test` + new unit tests |
| 6 | `docs(url): document slice-lifetime contract on Url and Domain` | `src/types/url.zig:37-38, 147-158` | **SAST-04, Q25** | 5 (same file, avoid rebase) | `zig build check` |
| 7 | `refactor(geographic): extract shared tuple-parser helper` | `src/types/geographic.zig:106, 176, 285` | **Q15** | — | `zig build test` |
| 8 | `test(parsers): add IPv4 leading-zero, IPv6 '::'-double, URL userinfo, prefix boundary cases` | new tests under `tests/unit/` | **Q33, Q31-partial** | 2, 5 | `zig build test` (expect count to rise from 233) |
| 9 | `build(bench): add zig build bench harness covering Ipv4/Ipv6/Url/Subnet/Vector/LatLon/GeoPoint` | `bench/bench.zig` (~150 LOC), `build.zig` step | **I1** (and P1) | — | `zig build bench` (exit-0 gate only) |
| 10 | `docs(readme): document ReleaseFast overflow-wrap semantics for Vector and Range.span` | `README.md` new section (~10 LOC), `src/root.zig` `//!` cross-ref | **D1** | — | none |
| 11 | `fix(tests): port tests/fuzz.zig to Zig 0.16 std.testing.fuzz (*std.testing.Smith) API` | `tests/fuzz.zig`, `build.zig:60-72` | **GAP-0020, GAP-0018, Q30** | — | `zig build test-fuzz` (exit-0 with small iteration cap) |
| 12 | `ci: add test-extensions and test-performance jobs; add ReleaseSmall to integration matrix` | `.gitlab-ci.yml` | **GAP-0021** | — | pipeline green |
| 13 | `ci: expand unit-test matrix to macOS, Windows, aarch64` | `.gitlab-ci.yml` | **GAP-0019** | 12 (touches same file) | pipeline green; document runner gaps |
| 14 | `ci: add kcov-based coverage job` | `.gitlab-ci.yml`, optional `scripts/coverage.sh` | **GAP-0011, Q31** | 12, 13 (same file) | pipeline green |
| 15 | `ci(security): pin ci-catalog components to commit SHAs` | `.gitlab-ci.yml` | **SC-01** | 14 | pipeline green |
| 16 | `docs(security): document Domain ASCII-only policy (scoped won't-do)` | `src/types/url.zig` Domain doc block, `SECURITY_GAP_ANALYSIS.md` | **NEW-02 (scoped won't-do)** | 6 | `zig build check` |

All commit subjects use conventional-commit prefixes (the repo's commitizen hook runs on `commit-msg`).

---

## 6. Dependencies (hard)

- **Commit 2 before Commit 3.** D2 is the `@intCast(u5)` safety net. After SAST-01 `Subnet.init` validates `prefix_len` at construction, the assert at `network.zig:469` becomes defense-in-depth; it still ships (pub field is not removed) but the commit message must cross-reference the new constructor.
- **Commit 2 before Commit 4.** Both touch `network.zig` — sequential to avoid edit-conflict on the `Subnet` / classification surface.
- **Commit 5 before Commit 6.** Same file (`url.zig`); doc comment must reference the new userinfo-stripping behavior.
- **Commit 5 before Commit 8.** Edge-case tests include URL userinfo rejection — must run against the hardened parser.
- **Commits 12 -> 13 -> 14 -> 15.** All edit `.gitlab-ci.yml`. Linear ordering eliminates rebase cost.
- **No ordering constraint** between the `geographic.zig` refactor (7), bench harness (9), README overflow docs (10), and fuzz port (11).

---

## 7. Won't-Do / Deferred Recommendations

| Item | Recommendation | Rationale |
|------|----------------|-----------|
| **NEW-02 — IDN/Punycode** | Close as **scoped Won't Do** with doc caveat (Commit 16). | Punycode/UTS-46 is a multi-hundred-LOC feature, not a fix. Briefing explicitly authorizes this. Add `Domain.isAscii()` + doc block stating "ASCII-only by design; IDN support is out of scope for `advanced-types` v0.1." |
| **GAP-0011 / Q31 coverage gate at 85%** | Ship the **kcov job** (Commit 14) but **do not gate CI on a coverage percentage** in this pass. Report as artifact only. | Reviewer alternative was "reopen *or* explicit won't-do"; user said "follow recommendations." Implementing the job satisfies the reopen. A hard percentage gate can regress unexpectedly on refactors and is a separate decision. File a follow-up issue for the gate threshold after one week of collected coverage runs. |
| **Q14, Q16, Q18–Q24, Q27–Q29, Q32, Q34, Q35, Q37–Q41** | Remain **ledger-only** (PriorityScore < 40). | Briefing scope is >= 40. Skipping is already the approved behavior. |
| **A1 `Url.parse` fused scan, S1 precomputed-origin haversine** | Stay **Monitor**. | Gated on I1 bench data (commit 9). Promotion decision deferred until bench runs land numbers in CI artifacts. |
| **GAP-0014/0015/0016/0017** | **Blocked** (unchanged). | Require Geode consumer wiring or external datetime package. Out of scope. |
| **Q9, Q12, P4, P5, P6, P7, P8, P9, P10, A3, A4, A5, M3, S2** | Stay **Won't Do**. | Prior decisions, re-confirmed in phase-3/4 reviews. No action. |

---

## 8. Nothing Blocks the Implementer

- Baseline is green (262/262; `zig fmt` + `zig build check` clean).
- All design decisions called out in the briefing (SAST-09 API name, SAST-01 constructor signature, SAST-05 strip-vs-reject, NEW-02 scope) are resolved per the deep reviews.
- `glab` creates issues successfully (per audit: 25/25 at 201), so linking commits to issues via `Closes #NN` trailer will work for every gap.
- Local Zig toolchain matches CI (0.16.0); no dev-env drift.
- **One caveat (carry-forward, not blocking):** Commit 13 (multi-OS matrix) may fail on company-tagged GitLab runners if macOS/Windows/aarch64 runners are not provisioned. Implementer should use the same ci-catalog components as the existing Linux job and, if a runner is missing, land the YAML as `rules: allow_failure: true` plus a Blocker row in `GAP_ANALYSIS.md` flagging the infra gap — *not* revert the commit.

---

## 9. Acceptance Checklist for Implementer

- [ ] All 16 commits landed on `main` with `Closes #NN` trailers.
- [ ] `zig build test`, `test-integration`, `test-extensions`, `test-performance`, **`test-fuzz`** all pass.
- [ ] `zig build bench` exits 0 and writes to `zig-out/bench/`.
- [ ] `zig fmt --check .` and `zig build check` clean.
- [ ] CI pipeline green, including new jobs (extensions/performance/coverage/multi-OS).
- [ ] Each gap-ledger status flipped to **Closed** (or **Won't Do** for NEW-02) with resolution column populated.
- [ ] Test count in `README.md:14` reconciled to new total (currently 262 → expect +N from Commit 8 + fuzz restoration).
