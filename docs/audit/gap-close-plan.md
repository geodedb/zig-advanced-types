# Gap Closure Plan

**Date:** 2026-04-18 (Option A — full pipeline, one commit per closure)
**Repo:** `/home/benji/src/devnw/zig/advanced-types`
**Branch:** `main` (per-gap direct commits, user-confirmed)
**Platform:** gitlab.com/devnw/zig/advanced-types (`glab` authorised as `benjiv`, SSH git remote)
**Zig toolchain (local + CI):** 0.16.0
**Prior-phase artefacts:** `docs/audit/{AUDIT_SUMMARY,gap-{requirements,trace,detected},quality-{inventory,scan,review},perf-{context,scan,review},security-{inventory,scan,review}}.md`
**Canonical ledgers (this pass):** `docs/GAP_ANALYSIS.md`, `docs/QUALITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md` (all rewritten 2026-04-18).

---

## 1. Gap Files Discovered

| File | Domain | Open | Partial | Closed / Accepted | Blocked / Deferred | Won't-Do | Total Tracked |
|------|--------|-----:|--------:|------------------:|-------------------:|---------:|--------------:|
| `docs/GAP_ANALYSIS.md` | functional / CI / docs | 1 (GAP-0023) | 1 (GAP-0019) | 16 closed | 4 (GAP-0014/15/16/17) | 0 | 22 (GAP-0001..0023) |
| `docs/QUALITY_GAP_ANALYSIS.md` | code quality | 10 (Q42, Q44, Q45, Q16, Q43, Q18, Q19, Q20, Q46, Q32) | 0 | 18 closed + 4 accepted | 0 | 2 (Q9 reopened→Q45; Q12) | 46 |
| `docs/PERF_GAP_ANALYSIS.md` | performance | 3 Fix + 5 Monitor | 0 | 5 | 0 | 11 | 24 |
| `docs/SECURITY_GAP_ANALYSIS.md` | security | 4 (SAST-PANIC-01, SAST-DOS-01, CI-SUP-01, CI-SUP-02) | 0 | 12 + 5 accepted | 1 (NEW-REL-01 suspected) | 1 (CI-CAT-01) | 24 |

Cross-ledger duplicates identified:

- **GAP-0023 ≡ Q42** — same root cause (README `262 Tests` + `fuzz suite currently broken` string + CHANGELOG `230 tests`). One closure, one commit. GAP-0023 closes automatically when Q42 lands.
- **Q26 ≡ SAST-01** — both already **Closed** in `503c1f5`; no action.
- **Q30 ≡ GAP-0018 ≡ GAP-0020** — all **Closed** in `c0e07ee`; no action.
- **Q31 ≡ GAP-0011** — **Closed report-only** in `20b233c`; no action.
- **Q36 ⊂ GAP-0022** — **Closed** in `3702dd1`; no action.

---

## 2. Build / Test / Lint Tooling

| Action | Command | Source | Baseline Status (2026-04-18) |
|--------|---------|--------|------------------------------|
| Unit tests | `zig build test` | `build.zig:18-27` | **PASS — 248/248** |
| Integration | `zig build test-integration` | `build.zig:30-42` | **PASS — 9/9** |
| Extensions | `zig build test-extensions` | `build.zig:45-57` | **PASS — 11/11** |
| Parser edges | `zig build test-parser-edges` | `build.zig:76-88` | **PASS — 16/16** |
| Performance | `zig build test-performance` | `build.zig:91-103` | **PASS — 9/9** |
| Fuzz | `zig build test-fuzz` | `build.zig:60-72` | **PASS — 10/10** |
| Benchmark | `zig build bench` | `build.zig:124-137` | **PASS (exit 0, prints ns/op)** |
| Example | `zig build example` | `build.zig:106-119` | `PASS` |
| Format | `zig fmt --check .` | pre-commit `zig-fmt` | **PASS (clean)** |
| Build check | `zig build check` | pre-commit `zig-build` | **PASS (clean)** |
| Commit lint | commitizen `cz check` (hook `commit-msg`, `v4.1.0`) | `.pre-commit-config.yaml:54-58`, `.cz.yaml` | works — but `.cz.yaml` fails `pretty-format-yaml` (Q44) |
| Markdown lint | `markdownlint-cli v0.43.0` (config `.markdownlint.json`, excludes CHANGELOG) | `.pre-commit-config.yaml:38-43` | **FAIL** — see §3 failure list |
| YAML format | `pretty-format-yaml --autofix --indent 2` (excludes `.gitlab-ci.yml`) | `.pre-commit-config.yaml:46-51` | **FAIL** — `.cz.yaml` reformatted by hook (Q44 confirmed) |
| Shell lint | `shellcheck --severity=error` | `.pre-commit-config.yaml:31-35` | PASS (no shell scripts tracked) |
| Trailing-ws / EOL / JSON / YAML-schema / TOML / XML / merge-conflict / private-key | `pre-commit-hooks v5.0.0` | `.pre-commit-config.yaml:9-28` | PASS |
| TODO scan | local hook `check-todos` | `.pre-commit-config.yaml:86-92` | PASS (warn-only) |
| Coverage | `.gitlab-ci.yml` `coverage` job (kcov, report-only) | added `20b233c` | PASS (no threshold) |

**Total runnable local test count:** **303** (248 + 9 + 11 + 16 + 9 + 10). Every ledger already cites 303 — consistent.

---

## 3. Baseline Capture (exact)

```text
$ zig build test --summary all
Build Summary: 3/3 steps succeeded; 248/248 tests passed

$ zig build test-integration --summary all
Build Summary: 3/3 steps succeeded; 9/9 tests passed

$ zig build test-extensions --summary all
Build Summary: 3/3 steps succeeded; 11/11 tests passed

$ zig build test-performance --summary all
Build Summary: 3/3 steps succeeded; 9/9 tests passed

$ zig build test-parser-edges --summary all
Build Summary: 3/3 steps succeeded; 16/16 tests passed

$ zig build test-fuzz --summary all
Build Summary: 3/3 steps succeeded; 10/10 tests passed

$ zig fmt --check .      # exit 0, no output
$ zig build check        # exit 0, no output
```

**Markdownlint failures (pre-existing, unrelated to any open gap):**

- `SUPPORT.md:41` MD034 bare URL `support@codepros.dev`.
- `docs/GAP_ANALYSIS.md:94,95,105,106,116,117,127,128,138,139,149,150` MD022/MD032 blanks around headings/lists (inside the new `### GAP-00XX:` detail blocks).
- `docs/audit/quality-review.md:96` MD040 missing language on a fenced block; `docs/audit/quality-review.md:182` MD056 column count.
- `docs/audit/security-scan.md:204-236` MD058/MD022 around several scanner sub-headings/tables.
- `docs/audit/security-review.md:21,141` MD038/MD056 formatting inside wide risk tables.

These breakages pre-date this closure pass and are NOT caused by upcoming gap work. A single housekeeping commit at the end of Phase F reconciles them (commit 24).

**Pretty-format-yaml:** `.cz.yaml` is mutated by the hook on every clean checkout — Q44 live. The hook change has been reverted via `git checkout -- .cz.yaml`.

**Git status:** 18 canonical audit docs modified from this morning's rewrite pass (expected), plus untracked `.remember/` (session scratch). Last commit: `f3adc69 docs(audit): add audit + gap-close artifacts`. Note — "clean" in the user brief refers to no stray code edits; the ledger edits are the expected input to this plan.

**Fuzz status:** 10/10 green on Zig 0.16.0 Smith API (commit `c0e07ee`). The README "fuzz suite currently broken under Zig 0.16" claim is the stale artefact Q42/GAP-0023 targets.

---

## 4. Authoritative Actionable Item List

PriorityScore legend: `Impact (1-5) × Likelihood (1-5) × 4`. Critical ≥80, High 60–79, Medium 40–59, Low <40. Same formula for Quality (Q), Perf (PerfScore), Security (Risk).

| Order | ID | Ledger | Phase | Title | Severity | Effort | Deps | Affected files | Acceptance criteria (abridged) | Issue |
|------:|----|--------|:----:|-------|:---------:|:------:|------|----------------|--------------------------------|-------|
| 1 | **Q46** | Quality | A | Opaque empty-path slice in `Url.parse` — 1-line "why" comment or `emptyAt` helper | Low (24) | XS | — | `src/types/url.zig:229-232` | `///` comment added OR helper extracted; existing tests pass | — |
| 2 | **Q20** | Quality | A | Delete hex-digit wrapper shims (`hexDigitValue`, `Mac.hexVal`) | Medium (40) | XS | — | `src/types/network.zig:305-308, 643-645` | Shims deleted; callers use `hexDigitToInt`; `zig build test` 248/248 | [#56](https://gitlab.com/devnw/zig/advanced-types/-/work_items/56) |
| 3 | **SAST-PANIC-01** | Security | A | Replace `@panic` with `std.debug.assert(i < N)` in `Vector.at` | Medium (Risk 24) | XS | — | `src/types/vector.zig:76-80` | Assert replaces panic; `Vector.at in range` regression test green | [#65](https://gitlab.com/devnw/zig/advanced-types/-/work_items/65) |
| 4 | **Q42 + GAP-0023** | Quality / Gap | A | README + CHANGELOG test-count drift (262/230→303; remove "fuzz broken") | High (64) | S | — | `README.md:14`, `CHANGELOG.md:17` | `grep -n "262 Tests\|230 tests\|fuzz suite currently broken" README.md CHANGELOG.md` returns 0 | [#48](https://gitlab.com/devnw/zig/advanced-types/-/work_items/48), [#53](https://gitlab.com/devnw/zig/advanced-types/-/issues/53) |
| 5 | **Q44** | Quality | A | `.cz.yaml` disagrees with `pretty-format-yaml` — run hook, commit diff | High (64) | XS | — | `.cz.yaml` | `pre-commit run pretty-format-yaml --all-files` exits 0 on clean tree | [#49](https://gitlab.com/devnw/zig/advanced-types/-/work_items/49) |
| 6 | **CI-SUP-01** | Security | B | macOS runner `brew install zig` — add SHA-256 verify parity with Linux template | Medium (Risk 16) | S | — | `.gitlab-ci.yml:242-243` | Install step fetches ziglang.org `index.json`, verifies SHA256 before use | [#67](https://gitlab.com/devnw/zig/advanced-types/-/work_items/67) |
| 7 | **CI-SUP-02** | Security | B | Windows `iwr`+`Expand-Archive` — add SHA-256 verify | Medium (Risk 16) | S | CI-SUP-01 (same file) | `.gitlab-ci.yml:259-276` | PowerShell `Get-FileHash -Algorithm SHA256` gate before extract | [#68](https://gitlab.com/devnw/zig/advanced-types/-/work_items/68) |
| 8 | **SAST-DOS-01** | Security | B | Per-parser `MAX_INPUT` caps across 8 parsers | Medium (Risk 16) | M | — | `src/types/{network,url,geographic,range}.zig` | Each `parse()` returns `error.InputTooLong` over fixed cap; 8 regression tests; fuzz 10/10 | [#66](https://gitlab.com/devnw/zig/advanced-types/-/work_items/66) |
| 9 | **Q43** | Quality | B | Dedupe 10 near-identical fuzz wrappers via comptime `parserFuzzer` | Medium (48) | S | — | `tests/fuzz.zig:44-154` | File shrinks ~60%; `zig build test-fuzz` 10/10 green | [#52](https://gitlab.com/devnw/zig/advanced-types/-/work_items/52) |
| 10 | **Q18** | Quality | B | `Ipv6Addr.format` 5-deep nested loop — extract `longestZeroRun` | Medium (48) | S | — | `src/types/network.zig:311-355` | Helper extracted; all v6-format + parser-edges tests green | [#54](https://gitlab.com/devnw/zig/advanced-types/-/work_items/54) |
| 11 | **Q19** | Quality | B | `Ipv6Addr.parse` mixes split/parse/place — extract `parseSides` + `placeRight` | Medium (48) | S | Q18 (same file) | `src/types/network.zig:214-258` | Helpers extracted; parse + parser-edges tests green | [#55](https://gitlab.com/devnw/zig/advanced-types/-/work_items/55) |
| 12 | **Q32** | Quality | B | Mirror `//!` / README doc examples as compiled `test "doc-example-X"` blocks | Low (24) | S | — | `src/root.zig:11-17`, `src/types/vector.zig:13-21`, tests | 3+ new doctests green; README snippets untouched | — |
| 13 | **BENCH-01** (`I2`) | Perf | C1 | Bench harness: warm-up + min-of-N + stdev + `taskset -c 0` | P1 (80) | M | — | `bench/main.zig:80-164`, `.gitlab-ci.yml` bench job | Prints min/median/p95; jitter ≤10% on 3× back-to-back runs; exit 0 | [#57](https://gitlab.com/devnw/zig/advanced-types/-/work_items/57) |
| 14 | **BENCH-03** (`I4`) | Perf | C2 | Add 7 missing benches (format, Subnet.contains, IpAddr.parse, haversineBroadcast, GeoPoint.parse, Vector.parse) | P2 (48) | M | BENCH-01 | `bench/main.zig:177-183` | 7 new benches wired; each emits min/median/p95 through BENCH-01 aggregator | [#59](https://gitlab.com/devnw/zig/advanced-types/-/work_items/59) |
| 15 | **BENCH-02** (`I3`) | Perf | C3 | CI regression gate — snapshot `baseline.json`, new `bench-regression` job (20% tolerance) | P1 (48) | M | BENCH-01, BENCH-03 | `.gitlab-ci.yml:202-212`, new `bench/baseline.json` | Gate fails on ≥20% slowdown; passes with current numbers | [#58](https://gitlab.com/devnw/zig/advanced-types/-/work_items/58) |
| 16 | **A1 / URL-01** | Perf | D | `Url.parse` fused state-machine (6-8 scans → 1) | P2 (48) | L | C1+C2+C3 | `src/types/url.zig:165-371` | Escalate to **Implement** only if BENCH-03 shows fused win ≥20% with jitter ≤10%; otherwise close **Monitor-verified** | [#60](https://gitlab.com/devnw/zig/advanced-types/-/work_items/60) |
| 17 | **A6 / FMT-01** | Perf | D | Hex-nibble table for `Ipv4Addr.format` / `Mac.format` | P3 (36) | S | C1+C2 | `src/types/network.zig:113-120, 627-649` | Same escalate-or-verify gate as #16 | [#61](https://gitlab.com/devnw/zig/advanced-types/-/work_items/61) |
| 18 | **S1 / PRECOMP-01** | Perf | D | `PreparedOrigin` haversine for 1-to-many | P3 (36) | M | C1+C2 + consumer signal | `src/types/geographic.zig:75-92, 127-144` | Escalate only if consumer commits AND broadcast bench shows win | [#62](https://gitlab.com/devnw/zig/advanced-types/-/work_items/62) |
| 19 | **IPADDR-01** | Perf | D | `IpAddr.parse` short-circuit + late dispatch | P3 (32) | S | C1+C2 | `src/types/network.zig:441-450` | Escalate-or-verify gate | [#63](https://gitlab.com/devnw/zig/advanced-types/-/work_items/63) |
| 20 | **S3** | Perf | D | `@Vector(16,f32)` tiled cosine at comptime N≥16 | P3 (32) | L | C1 + consumer at N≥16 | `src/types/vector.zig:175-189` | Escalate-or-verify; expected verdict: Monitor-verified (no N≥16 consumer today) | [#64](https://gitlab.com/devnw/zig/advanced-types/-/work_items/64) |
| 21 | **Q16** | Quality | E | `Url.parse` 108-LOC single function — stage extraction | Medium (48) | M | A clear (Q42 edits same area's docs) | `src/types/url.zig:190-297` | 5 stage helpers; `Url.parse` ≤40 LOC; all url + parser-edges tests green | [#51](https://gitlab.com/devnw/zig/advanced-types/-/work_items/51) |
| 22 | **Q45** | Quality | E | `network.zig` 1,166 LOC → split `src/types/network/{ipv4,ipv6,ip,subnet,mac}.zig` | Medium (48) | L | Q18, Q19 | `src/types/network.zig` (whole) + new `src/types/network/*.zig` | All `zig build test*` green after every sub-commit; history preserved via `git mv` | [#50](https://gitlab.com/devnw/zig/advanced-types/-/work_items/50) |

### Q45 multi-commit sub-plan (per user directive §7)

git rename-detection works by content similarity at `log --follow` time, so extracting one type-block per commit preserves `-follow` history:

| Sub-commit | Subject | Mechanic |
|:----------:|---------|----------|
| 22a | `refactor(network): create src/types/network/ directory + barrel file` | Add `src/types/network/mod.zig` barrel re-export; temporarily stage legacy file under new path. Tests green. |
| 22b | `refactor(network): extract Ipv4Addr to src/types/network/ipv4.zig` | Cut `Ipv4Addr` block into `ipv4.zig`; barrel re-export; tests green. |
| 22c | `refactor(network): extract Ipv6Addr to src/types/network/ipv6.zig` | Depends on 22b (v4-mapped path uses Ipv4Addr). |
| 22d | `refactor(network): extract Subnet to src/types/network/subnet.zig` | Depends on 22b+22c. |
| 22e | `refactor(network): extract Mac to src/types/network/mac.zig` | Independent of Subnet; lands after 22c. |
| 22f | `refactor(network): extract IpAddr tagged union; delete legacy shim` | Final collapse. Public API surface preserved byte-for-byte via `src/root.zig`. |

Total Phase E commits: **1 (Q16) + 6 (Q45 a-f) = 7**.

### Phase F — blocked / won't-do / suspected (ledger-only)

| ID | Ledger | Action | Commit |
|----|--------|--------|--------|
| GAP-0014 | Gap | **Blocked (external)** — await Geode MR | 23a `docs(gap): re-affirm GAP-0014 blocked pending Geode consumer` |
| GAP-0015 | Gap | **Deferred (upstream datetime)** | 23a |
| GAP-0016 | Gap | **Deferred (`st_*` staged)** | 23a |
| GAP-0017 | Gap | **Blocked (external)** | 23a |
| GAP-0019 | Gap | **Partial** per `gap-close-blockers.md`; carry forward | 23a |
| SAST-OVERFLOW-01 | Security | **Accepted** — documented `src/root.zig:21-26` | 23b `docs(security): re-affirm accepted findings` |
| CI-CAT-01 | Security | **Won't-Do** — already closed `152d0f8` | 23b |
| CI-FUZZ-01 | Security | **Accepted** — scheduled/manual policy intentional | 23b |
| OP-OWNER-01 | Security | **Accepted** — single CODEOWNERS | 23b |
| CI-SECRETS-01 | Security | **Accepted (CI-only coverage)** | 23b |
| **NEW-REL-01** | Security | **Suspected → investigate** (§6); close as (a) Resolved-with-evidence or (b) Partial-sign-tags-followup or (c) Open-with-new-blocker | 23c `docs(security): close NEW-REL-01 as <§6 verdict>` |

### Markdown housekeeping (pre-existing breakage caught in §3 baseline)

| Commit | Subject | Files |
|--------|---------|-------|
| 24 | `docs: fix markdownlint MD022/MD032/MD034/MD038/MD040/MD056/MD058 in audit docs` | `SUPPORT.md`, `docs/GAP_ANALYSIS.md`, `docs/audit/quality-review.md`, `docs/audit/security-scan.md`, `docs/audit/security-review.md` |

---

## 5. Implementation Order Summary

| Phase | Items | Commits | Rationale |
|-------|-------|:-------:|-----------|
| **A — Trivial & independent** | Q46, Q20, SAST-PANIC-01, Q42+GAP-0023, Q44 | 5 | No cross-dependencies; different files (url.zig / network.zig / vector.zig / README+CHANGELOG / .cz.yaml). |
| **B — Medium independent** | CI-SUP-01, CI-SUP-02, SAST-DOS-01, Q43, Q18, Q19, Q32 | 7 | Q18→Q19 (same file). CI-SUP-01→02 (same YAML). SAST-DOS-01 touches 4 parsers — single commit. |
| **C — Perf harness (strictly sequential)** | BENCH-01 → BENCH-03 → BENCH-02 | 3 | Harness → corpus → regression gate. Reversing risks flapping gate on current ~50% jitter. |
| **D — Perf monitors (gated)** | A1, A6, S1, IPADDR-01, S3 | 1-5 | Each gets **Escalate-or-Verify** decision using post-C data: ≥20% win & jitter ≤10% ⇒ Implement (one commit); otherwise close `Monitor-verified`. S3 expected verdict: Monitor-verified (no N≥16 consumer). |
| **E — Large refactors** | Q16 (Url.parse stages), Q45 (network.zig split ×6) | 7 | Final — isolated to contain rebase cost. |
| **F — Blocked / Won't-Do / Suspected** | GAP-0014/15/16/17/19, SAST-OVERFLOW-01, CI-CAT-01, CI-FUZZ-01, OP-OWNER-01, CI-SECRETS-01, NEW-REL-01 | 3 | Ledger-only. NEW-REL-01 verdict per §6. |
| **Housekeeping** | Markdownlint fixes | 1 | Clears pre-existing breakage from §3. |

**Commit-count budget (worst case):** 5 + 7 + 3 + 5 + 7 + 3 + 1 = **31 commits**.
**Commit-count budget (likely case, Phase D all Monitor-verified):** 5 + 7 + 3 + 1 + 7 + 3 + 1 = **27 commits**.

### Global ordering (commit-by-commit)

| # | Phase | Commit subject (sketch) | Closes |
|--:|:-----:|-------------------------|--------|
| 1 | A | `docs(url): clarify empty-path slice in Url.parse` | Q46 |
| 2 | A | `refactor(network): delete hex-digit wrapper shims` | Q20 |
| 3 | A | `fix(vector): replace Vector.at @panic with std.debug.assert` | SAST-PANIC-01 |
| 4 | A | `docs: reconcile README + CHANGELOG test counts to 303; remove stale fuzz-broken notice` | Q42, GAP-0023 |
| 5 | A | `chore(tooling): apply pretty-format-yaml to .cz.yaml` | Q44 |
| 6 | B | `ci(supply-chain): verify macOS Zig install SHA-256 via ziglang.org index` | CI-SUP-01 |
| 7 | B | `ci(supply-chain): verify Windows Zig install SHA-256 via Get-FileHash` | CI-SUP-02 |
| 8 | B | `fix(parsers): enforce MAX_INPUT cap across 8 parsers (DoS hardening)` | SAST-DOS-01 |
| 9 | B | `refactor(tests): dedupe fuzz wrappers via comptime parserFuzzer` | Q43 |
| 10 | B | `refactor(network): extract longestZeroRun from Ipv6Addr.format` | Q18 |
| 11 | B | `refactor(network): extract parseSides/placeRight from Ipv6Addr.parse` | Q19 |
| 12 | B | `test(docs): mirror //! and README examples as compiled doctests` | Q32 |
| 13 | C1 | `perf(bench): add warm-up + min-of-N + p95 aggregation to bench harness` | BENCH-01 |
| 14 | C2 | `perf(bench): add 7 missing benches (format, Subnet.contains, IpAddr.parse, geo-broadcast, parses)` | BENCH-03 |
| 15 | C3 | `ci(bench): add regression gate with 20% tolerance against bench/baseline.json` | BENCH-02 |
| 16-20 | D | (conditional, per escalate-or-verify gate) A1, A6, S1, IPADDR-01, S3 | — |
| 21 | E | `refactor(url): extract parse stages (scheme/frag/authority/host/validate)` | Q16 |
| 22a-f | E | `refactor(network): split network.zig into per-type files` (6 commits via `git mv`) | Q45 |
| 23a | F | `docs(gap): re-affirm GAP-0014/0015/0016/0017/0019 blocked/deferred` | ledger |
| 23b | F | `docs(security): re-affirm SAST-OVERFLOW-01/CI-CAT-01/CI-FUZZ-01/OP-OWNER-01/CI-SECRETS-01 accepted` | ledger |
| 23c | F | `docs(security): close NEW-REL-01 as <TBD after §6>` | ledger |
| 24 | Housekeep | `docs: fix markdownlint MD022/MD032/MD034/MD038/MD040/MD056/MD058 in audit docs` | n/a |

---

## 6. NEW-REL-01 Investigation Plan (read-only, pre-verdict)

Goal: confirm or refute "No release provenance (unsigned tags / no SLSA / no SBOM attached)" before writing the verdict commit.

1. Render effective release job:

   ```sh
   glab ci view --merged-yaml | awk '/^release-semantic:/,/^[a-z]/' > /tmp/release-effective.yml
   ```

2. List last 5 tags and assets:

   ```sh
   glab release list --per-page=5
   glab api -X GET projects/devnw%2Fzig%2Fadvanced-types/releases \
     | jq '.[0:5] | [.[] | {tag_name, name, released_at, assets: .assets.links}]'
   ```

3. Inspect last successful release-semantic pipeline for SBOM + signature artefacts:

   ```sh
   glab ci list --status success --stage release --per-page 3
   glab ci artifacts <JOB_ID>
   ```

4. Verdict matrix:
   - **SBOM + tag signature both present** ⇒ close NEW-REL-01 as **Resolved (evidence)**; commit 23c references pipeline/job IDs.
   - **SBOM present but tag unsigned** ⇒ close as **Partial — sign-tags follow-up** and `glab issue create` for the remainder.
   - **Neither** ⇒ keep NEW-REL-01 **Open**, add Sigstore/GPG signing + SLSA provenance job as a new Phase-E item (out-of-scope here; new blocker row).

Investigation is entirely read-only (glab GET + artefact download); no pipeline triggered.

---

## 7. Dependencies (hard)

- **Phase-C strict order** — BENCH-01 → BENCH-03 → BENCH-02. Reversing risks flapping regression gate.
- **Phase-D is gated on Phase-C** — every Monitor item requires measurement credibility (jitter ≤10% + corpus coverage).
- **Q18 before Q19** — both edit `src/types/network.zig` IPv6 region.
- **Q45 AFTER Q18+Q19** — Q18/Q19 land inside legacy file; splitting first would double refactor cost.
- **Q16 AFTER Q42** — Q42 touches URL-area docs in repo-root .md files; sequencing avoids conflict on Q16 same-file edits.
- **CI-SUP-01 before CI-SUP-02** — both edit `.gitlab-ci.yml`.
- **BENCH-02 edits `.gitlab-ci.yml`** — land after CI-SUP-01/02 block for atomic YAML diffs.

---

## 8. Cross-Cutting Concerns (implementer must read before committing)

- **Commit convention (commitizen, `commit-msg` hook):** `type(scope): subject` where `type ∈ {fix,feat,refactor,docs,chore,test,ci,perf,build,style,revert}`. Subject ≤72 chars. Bodies should include `Closes #NN` trailers pointing at the GitLab work-item IDs in §4. **Breaking changes** go in the body prefixed `BREAKING CHANGE:` — `release-semantic` uses this to trigger a MAJOR bump. Do **not** break the public API (`src/root.zig` re-exports) while closing these items.
- **Pre-commit hook behaviour:**
  - `pre-commit` stage runs on every commit: Zig fmt/check, markdownlint, pretty-format-yaml (excludes `.gitlab-ci.yml`), whitespace/EOL/JSON/YAML-schema/TOML/XML/merge-conflict/private-key, shellcheck-error.
  - `commit-msg` stage runs commitizen — `--no-verify` is disallowed per instructions.
  - `pre-push` stage runs `zig build test`; every pushed commit must be locally green.
  - The `.pre-commit-config.yaml:98` `ci.skip` list applies only to the pre-commit.ci bot, not to human pushes.
- **Semantic-release tag implications:** `.gitlab-ci.yml:24` runs `release-semantic@v1.7.1`. Plan commits use `fix/refactor/docs/ci/perf/test/chore`:
  - PATCH-triggering types: `fix`, `perf`.
  - No-release types: `chore`, `docs`, `test`, `refactor`, `style`, `ci`.
  - None of the 27-31 planned commits should trigger MINOR or MAJOR. **Double-check before each push:** `npx commitizen check <subject>` locally.
- **`glab` issue-closure trailers:** GitLab auto-closes on `Closes #NN` in the MR or commit message. For direct-to-main commits, use the trailer in the commit body and optionally `glab issue close NN --message "Closed by <sha>"` if auto-close does not fire.
- **`.gitlab-ci.yml` pretty-format-yaml exclusion:** line 51 excludes `.gitlab-ci.yml`. Preserve existing indentation manually.
- **`git mv` history preservation (Q45):** log-time rename detection requires ≥50% similarity; sub-plan 22a-f keeps each extracted hunk contiguous.

---

## 9. STOP-AND-REVIEW Checkpoints

| Checkpoint | After commit | What to verify | Recovery path |
|-----------|:------------:|----------------|--------------|
| **CP-1 — Phase A complete** | 5 | `zig build test` 248/248; `grep -n "262 Tests\|230 tests\|fuzz suite currently broken" README.md CHANGELOG.md` = 0; `pre-commit run pretty-format-yaml --all-files` exits 0. | Revert offending commit; do not cascade into Phase B. |
| **CP-2 — Phase B complete** | 12 | All 6 `zig build test*` suites green; CI pipeline green; SAST-DOS-01 asserts `error.InputTooLong`. | If CI-SUP-01/02 lands red on mac/win runners, set `allow_failure: true` and log in `gap-close-blockers.md` — do NOT revert SHA-verify code. |
| **CP-3 — BENCH-01 in** | 13 | `zig build bench` × 3 locally, jitter ≤10% on min-of-N; one CI bench pipeline green. | **Critical gate.** If jitter >10%, iterate on harness before C2. Do not advance. |
| **CP-4 — Phase C complete** | 15 | `bench/baseline.json` committed; regression job passes; failure mode exercised via stale-baseline spike. | If gate flaps: `allow_failure: true` on BENCH-02 + blocker note. Do NOT drop tolerance below 20%. |
| **CP-5 — Phase D verdicts posted** | 15+N | Each D-item has a Monitor-verified or Implement-closed ledger entry with numeric evidence (min/median/p95, corpus path, verdict). | If Implement-path regresses non-targeted benches, revert and close as Monitor-verified. |
| **CP-6 — Q16 in** | (15+N)+1 | url.zig stages extracted; url + parser-edges + integration + extensions + performance tests green; no public-API drift. | Revert on red; Q45 can still proceed (different file). |
| **CP-7 — Q45 split per sub-commit** | 22a … 22f | **After every** 22-series commit: `zig build test` 248/248 + `zig build example` green. Public API byte-identical (`grep -n "pub " src/root.zig` unchanged). | Stop Q45, revert to last-green 22-series commit. Do not start next sub-commit. |
| **CP-8 — Phase F + housekeeping in** | 24 | Every ledger row has terminal status; `pre-commit run -a` returns 0 on clean tree. | Final guarantee before Step 3 (verifier). |

---

## 10. Blockers (carry-forward)

- **GAP-0014 / GAP-0017** — external (Geode consumer). No action in this repo.
- **GAP-0015** — external (upstream datetime package). Deferred.
- **GAP-0016** — product-scope (`st_*` staged). Deferred.
- **GAP-0019** — infrastructure (macOS / Windows / aarch64 runners unprovisioned); `allow_failure: true` carries risk per `gap-close-blockers.md`.
- **BENCH-01 (harness)** — gatekeeper for all 5 Phase-D items.
- **NEW-REL-01** — verdict pending §6 investigation.
- **Pre-commit hook `zig-test` at pre-push** — requires local Zig 0.16.0 (confirmed present).
- **`.remember/`** (untracked session scratch) — ignore-list candidate later; non-blocking.

---

## 11. Acceptance Checklist for Implementer (Step 2)

- [ ] Phase-A (5) + Phase-B (7) + Phase-C (3) commits on `main` with `Closes #NN` trailers.
- [ ] Phase-D: each of A1/A6/S1/IPADDR-01/S3 has either (a) an **Implement** commit with benchmark evidence OR (b) ledger row `Monitor-verified <numbers>`.
- [ ] Phase-E: Q16 + Q45 (6 sub-commits) green; public API unchanged.
- [ ] Phase-F: 3 ledger-only commits (23a/23b/23c); NEW-REL-01 verdict via §6.
- [ ] Housekeeping commit 24 clears markdownlint baseline.
- [ ] `zig build test | test-integration | test-extensions | test-parser-edges | test-performance | test-fuzz | bench` all green.
- [ ] `zig fmt --check .` + `zig build check` clean.
- [ ] `pre-commit run --all-files` exits 0 on clean tree.
- [ ] CI pipeline green on `main` including new `bench-regression` job.
- [ ] All corresponding GitLab work-items closed.
