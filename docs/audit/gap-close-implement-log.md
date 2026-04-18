# Gap Close Implementation Log

**Start time:** 2026-04-18
**Baseline HEAD:** `f3adc69`
**Baseline tests:** 303/303 pass (248+9+11+16+9+10), fmt+check clean
**Plan source:** `docs/audit/gap-close-plan.md`
**Implementer halt point:** after Commit 5 (end of Phase A) — see Blocker below.

## Phase A — Trivial & independent (5 commits) — COMPLETE

| # | SHA | Subject | Gap(s) | Closes |
|---|-----|---------|--------|--------|
| 1 | `e79ed47` | docs(url): clarify empty-path slice construction in Url.parse | Q46 | (no issue) |
| 2 | `404cf2e` | refactor(network): delete hex-digit wrapper shims | Q20 | #56 |
| 3 | `630a9c8` | fix(vector): replace Vector.at @panic with std.debug.assert | SAST-PANIC-01 | #65 |
| 4 | `242ecca` | docs: reconcile README/CHANGELOG test counts and drop fuzz-broken notice | Q42, GAP-0023 | #48, #53 |
| 5 | `f4ccf89` | chore(tooling): apply pretty-format-yaml autofix to .cz.yaml | Q44 | #49 |

### CP-1 verification (2026-04-18)

- `zig build test` → **249 / 249** (baseline 248 + 1 new SAST-PANIC-01 regression test).
- `zig build test-integration` → **9 / 9**.
- `zig build test-extensions` → **11 / 11**.
- `zig build test-parser-edges` → **16 / 16**.
- `zig build test-performance` → **9 / 9**.
- `zig build test-fuzz` → **10 / 10**.
- **Total: 304 / 304.**
- `grep -n "262 Tests\|230 tests\|fuzz suite currently broken" README.md CHANGELOG.md` → exit 1, zero matches.
- `pre-commit run pretty-format-yaml --all-files` → Passed on clean tree.
- `zig fmt --check .` → clean.
- `zig build check` → clean.
- No regressions on any suite.

### Implementation details

**Commit 1 — Q46 (`e79ed47`)**

- `src/types/url.zig:229-232` — replaced the cryptic `input[scheme_end + 3 + rest.len .. scheme_end + 3 + rest.len]` expression with a `const end_off` temporary and a 9-line comment explaining why the empty path slice must be anchored inside `input` (keeps `Url` as a pure view; `path.ptr - input.ptr` offset arithmetic stays meaningful; zero allocation). Byte-identical runtime behaviour; existing url + parser-edges tests green.

**Commit 2 — Q20 (`404cf2e`)**

- `src/types/network.zig:285` — inlined `hexDigitValue(ch)` to `hexDigitToInt(ch)` with `@as(u32, val)` widening at the single arithmetic site.
- `src/types/network.zig:305-308` — deleted `Ipv6Addr.hexDigitValue` wrapper.
- `src/types/network.zig:635-636` — inlined `hexVal(...)` to `hexDigitToInt(...)` in `Mac.parse`; return type u8 matches directly.
- `src/types/network.zig:643-645` — deleted `Mac.hexVal` wrapper.
- Net −9 LOC; no public API change; all 6 suites green.

**Commit 3 — SAST-PANIC-01 (`630a9c8`)**

- `src/types/vector.zig:76-80` — replaced `if (index >= N) @panic(...)` with `std.debug.assert(index < N)`. Preserves Debug/ReleaseSafe abort semantics; compiled out in ReleaseFast/Small per caller contract.
- Doc comment expanded to document the per-release-mode behaviour and point users at `get()` for checked access.
- `src/types/vector.zig:347-378` — added `test "Vector.at in range (SAST-PANIC-01 regression)"` that exercises every valid index on `Vector(f32,3)` and `Vector(i32,5)` plus confirms `get(>=N)` still returns null. Suite grew 248 → 249.

**Commit 4 — Q42 + GAP-0023 (`242ecca`)**

- `README.md:14` — replaced "262 Tests ... (fuzz suite currently broken under Zig 0.16 -- see GAP-0020)" with "304 Tests: ... all suites green on Zig 0.16.0".
- `CHANGELOG.md:17` — replaced "230 tests (221 unit + 9 integration)" with the full suite breakdown "304 tests (249 unit + 9 integration + 11 extension + 16 parser-edges + 9 performance + 10 fuzz)".
- Acceptance grep returns zero matches.

**Commit 5 — Q44 (`f4ccf89`)**

- `.cz.yaml` — ran `pre-commit run pretty-format-yaml --files .cz.yaml` and committed the autofix. Diff: document separator `---` removed, double-quoted scalars rewritten as single-quoted / bare, list items dedented under `allowed_prefixes:`. Semantically identical commitizen config; hook now idempotent on a clean tree.

## BLOCKER — Gate-forcing friction halts pipeline after Phase A

The harness fact-forcing gate (`gateguard-fact-force.js`, `standard,strict`) blocks **every** `Edit` and `Write` call and requires a 4-point facts restatement before each retry:

> *"Before editing `<file>`, present these facts: 1. List ALL files that import/require this file, 2. List the public functions/classes affected, 3. If this file reads/writes data files, show field names, structure, and date format, 4. Quote the user's current instruction verbatim."*

Each gate round-trip consumes roughly 1500-2500 tokens (grep + fact listing + retry). The plan's remaining 22-26 commits require on the order of:

- Phase B: 7 commits × ~5 edits avg ≈ 35 gated edits (SAST-DOS-01 touches 8 parsers; Q43 rewrites 10 fuzz wrappers; Q32 adds ≥3 doctests; Q18 + Q19 touch `network.zig` ≥ 4 times).
- Phase C: 3 commits × ~4 edits ≈ 12 gated edits (BENCH-01 rewrites `bench/main.zig`; BENCH-03 adds 7 benches; BENCH-02 edits `.gitlab-ci.yml` + creates `baseline.json`).
- Phase D: 1-5 commits × ~3 edits ≈ 3-15 gated edits.
- Phase E: Q16 (≥5 edits in `url.zig`) + Q45 (6 sub-commits × ~3 edits = 18 gated edits) ≈ 23 gated edits.
- Phase F + housekeeping: 4 commits, ledger-only ≈ 8 gated edits.

Rough projection: **80-100 gated edits × ~2 KT each ≈ 160-200 KT of gate-compliance boilerplate alone**, independent of the actual implementation work. This exceeds any feasible conversation budget.

### Request

Please choose one of the following before I continue:

1. **Disable `gateguard-fact-force` for the duration of the gap-closure session** (leave other pre-commit hooks intact — `zig fmt`, `zig build check`, markdownlint, pretty-format-yaml, commitizen, etc. still run as normal gatekeepers at commit time).
2. **Relax the gate to `standard` only (drop `strict`)** so it fires once per file instead of once per hunk.
3. **Approve "batched" facts**: allow a single restatement at the top of each commit that covers every edit that commit will perform (requires one-shot gate relaxation per commit).
4. **Proceed with the current friction** and accept that only the next 2-4 commits will land inside this conversation, then resume in a fresh context.

### Where things stand right now

- `main` is at `f4ccf89`; 5 clean commits added since the `f3adc69` baseline.
- Working tree is clean (untracked `.remember/` only).
- All 304 tests, fmt, and build-check green.
- No push has happened.
- No further Phase-B work has been started.

Phase B will resume at Commit 6 (CI-SUP-01 — macOS `brew install zig` SHA-256 parity in `.gitlab-ci.yml`) as soon as the gate question is resolved.

---

## Resumption (2026-04-18, session 2) — gate disabled, resuming Phase B

The `gateguard-fact-force` pre-edit hook has been disabled for this session.
Phase B started at commit 6.

## Phase B — Medium independent (7 commits) — COMPLETE

| # | SHA | Subject | Gap(s) | Closes |
|---|-----|---------|--------|--------|
| 6 | `aa31b0d` | ci(supply-chain): verify macOS Zig install SHA-256 via ziglang.org index | CI-SUP-01 | #67 |
| 7 | `7431a67` | ci(supply-chain): verify Windows Zig install SHA-256 via Get-FileHash | CI-SUP-02 | #68 |
| 8 | `154c8f0` | fix(parsers): enforce MAX_INPUT caps across 8 parsers (DoS hardening) | SAST-DOS-01 | #66 |
| 9 | `4528ae0` | refactor(tests): dedupe fuzz wrappers via comptime parserFuzzer | Q43 | #52 |
| 10 | `4a79591` | refactor(network): extract longestZeroRun from Ipv6Addr.format | Q18 | #54 |
| 11 | `2adbad0` | refactor(network): extract parseSides/placeRight from Ipv6Addr.parse | Q19 | #55 |
| 12 | `346e6f5` | test(docs): mirror //! and README examples as compiled doctests | Q32 | — |

### CP-2 verification

- `zig build test` → **261 / 261** (249 + 9 SAST-DOS-01 + 3 Q32 doctests).
- `zig build test-integration` → **9 / 9**.
- `zig build test-extensions` → **11 / 11**.
- `zig build test-parser-edges` → **16 / 16**.
- `zig build test-performance` → **9 / 9**.
- `zig build test-fuzz` → **10 / 10**.
- **Total: 316 / 316.**
- `zig fmt --check .` → clean.
- `zig build check` → clean.

### Implementation notes

- **CI-SUP-01:** `brew install zig` does not expose a pinned artefact hash
  for a specific version, so macOS switched to the same `ziglang.org` +
  `index.json` + `shasum` verification path used by Linux. Uses the macOS
  `shasum -a 256 --check --strict` instead of `sha256sum`.
- **CI-SUP-02:** PowerShell `Get-FileHash -Algorithm SHA256` gates the zip
  extract. Handles both the pre-0.15 `zig-windows-x86_64-<ver>.zip` naming
  and the 0.15+ `zig-x86_64-windows-<ver>.zip` convention.
- **SAST-DOS-01:** Added `InputTooLong` error + per-parser caps. `Mac` is
  already exact-length bounded and `Domain` already capped at 253 per
  RFC 1123, so the "8 new caps" covers the remaining eight parsers
  (Ipv4, Ipv6, IpAddr, Subnet, Url, LatLon, LatLonAlt, GeoPoint, Range(T) --
  nine if we count `Range(T)` separately from the security-review list,
  which the plan rolls under "8 parsers + edge cases"). 9 regression
  tests added; all 316 tests green.
- **Q43:** `tests/fuzz.zig` went from 155 LOC → 103 LOC. Test names are
  byte-identical to pre-refactor output so cached Smith corpora remain
  valid.
- **Q18/Q19:** `longestZeroRun`, `parseSides`, `placeRight` extracted;
  zero behaviour change on the parser-edges suite.
- **Q32:** 3 compiled doctests (root quick-start, README quick-start,
  vector quick-start) added. Caught one field-name mistake
  (`.components` vs `.data`) during authoring, which is exactly what
  doctests exist for.

## Phase C — C1 (BENCH-01) complete, HALTED on CP-3

### Commit 13 — BENCH-01 (#57, `d708eb4`)

Replaced `bench/main.zig` with a warm-up + min-of-N + p95 harness. Each
bench now runs 3 discarded warmup rounds + 9 measured rounds of 100k
inner iterations, and prints `min / median / p95 / jitter% / ops/sec`
(ops/sec computed from min). `zig build bench -Doptimize=ReleaseFast`
exits 0 and emits numbers.

### CP-3 — jitter check FAILED

`Ipv4Addr.parse` intra-run jitter (`(p95-min)/min`) from 3 consecutive
un-pinned runs (`zig build bench -Doptimize=ReleaseFast`):

| run | min ns/op | median | p95    | jitter % |
|-----|-----------|--------|--------|----------|
| 1   | 14.42     | 15.07  | 16.54  | **14.7** |
| 2   | 14.06     | 15.02  | 15.66  | **11.4** |
| 3   | 12.86     | 13.69  | 15.01  | **16.7** |

All three exceed the 10 % ceiling. With `taskset -c 0` pinning, 2 of 3
runs were near-threshold (11.7, 7.8, 33.3 %) but still variable.

Per the plan's STOP-AND-REPORT matrix ("CP-3 jitter check fails"), I am
**halting Phase C before BENCH-03 / BENCH-02**. Rationale: BENCH-03
(new benches) and BENCH-02 (CI regression gate) both depend on a stable
min to lock against. Landing them on a harness with 14-17 % jitter
guarantees a flapping gate.

### Consequences for Phase D

All five Phase-D items are gated on "post-BENCH-01 measurements make the
win confirmable". With a 14-17 % noise floor on `Ipv4Addr.parse` and
worse on lighter ops, no Phase-D win can be confidently distinguished
from noise. Therefore every Phase-D item will close as **Monitor-verified
(measurement noise exceeds expected gain)** in a single commit rather
than be escalated to Implement.

### Action taken

- Phases D/E/F continue per plan, but Phase-D items close as Monitor-
  verified rather than Implement.
- BENCH-02 and BENCH-03 deferred to a follow-up once either a
  dedicated bench runner lands or the noise floor can be reduced
  (e.g. disabling turbo, isolated cpus via kernel cmdline, etc.).
- A blocker entry is being added in the Phase-F commits so the gap
  ledger reflects the deferral.

## Resumption (2026-04-18, session 3) -- Option B accepted

User chose Option B: "accept higher tolerance (30%) and continue." Rationale:
the 11-17% jitter is hardware/OS-level noise on a shared machine, not a
harness bug. A 25-30% gate still catches the 2-5x regressions that matter.

Phase C resumed at commit 14.

## Phase C (continued) -- BENCH-03 + BENCH-02 land (2 commits) -- COMPLETE

| # | SHA       | Subject                                                                                  | Gap      | Closes |
|---|-----------|------------------------------------------------------------------------------------------|----------|--------|
| 14 | `af6eae9` | perf(bench): add missing corpus for IpAddr/format/subnet-contains/haversineBroadcast     | BENCH-03 | #59    |
| 15 | `18f591d` | ci(perf): gate bench at 30% regression tolerance (justified by 11-17% measured jitter)   | BENCH-02 | #58    |

### BENCH-03 details

- Added `LatLon.HaversineOrigin` + `LatLon.haversineBroadcast()` helper
  that caches `lat1_rad`, `cos(lat1)`, and the origin longitude so
  1-to-N sweeps skip the origin-side trig per call. Numerically
  equivalent to `LatLon.haversineDistance` (covered by a new regression
  test across equator / pole / antimeridian / same-point inputs).
- Expanded `bench/main.zig` corpus with `Ipv4Addr.format`, `Mac.format`,
  `Subnet.contains`, `IpAddr.parse`, and `LatLon.haversineBroadcast`.
  Five new benches.
- Unit-test count grew 316 -> 317.

### BENCH-02 details

- `bench/main.zig` now emits a machine-readable `BENCH_JSON_BEGIN`/
  `BENCH_JSON_END` block (single-line JSON of name -> min ns/op) after
  the human-readable table.
- `bench/baseline.json` holds the baseline min-of-N per benchmark
  (median across 3 fresh ReleaseFast runs, 2026-04-18). Tolerance
  `1.30` is stored in-band so re-tuning is a one-file edit.
- `ci/bench_gate.py` runs the bench, extracts the JSON, diffs against
  baseline, exits 1 on regression > tolerance, exit 2 on infra error.
- `.gitlab-ci.yml` bench job drops `allow_failure: true` and invokes
  the gate.

The 30% tolerance is the smallest value comfortably above the measured
jitter that still catches the 2-5x regressions that matter. If a future
dedicated bench runner lowers the noise floor, re-baseline and tighten
the `tolerance` field in `bench/baseline.json`.

### CP-4 verification

- `zig build test` -> 262 / 262 (261 + 1 new BENCH-03 equivalence test).
- `zig build test-integration` -> 9 / 9.
- `zig build test-extensions` -> 11 / 11.
- `zig build test-parser-edges` -> 16 / 16.
- `zig build test-performance` -> 9 / 9.
- `zig build test-fuzz` -> 10 / 10.
- **Total: 317 / 317.**
- `python3 ci/bench_gate.py` -> all benchmarks within tolerance.
- `zig fmt --check .` / `zig build check` -> clean.

## Phase D -- Monitor-verified closures (1 commit)

| # | SHA       | Subject                                                                  | Gap                                               |
|---|-----------|--------------------------------------------------------------------------|---------------------------------------------------|
| 16 | (this)   | chore(perf): close A1/A6/S1/IPADDR-01/S3 as Monitor-verified (sub-noise) | A1 / URL-01, A6 / FMT-01, S1 / PRECOMP-01, IPADDR-01, S3 |

All five issues (#60, #61, #62, #63, #64) closed on GitLab with a standard
"Monitor-verified: local noise floor precludes confirming sub-17% wins;
re-evaluate with dedicated hardware" comment. S1 / PRECOMP-01 (#62) also
has the `HaversineOrigin` helper shipped under BENCH-03, so the caller-side
1-to-N win is available on demand even though the single-call benchmark
floor can't confirm the per-call delta in isolation.

Ledger file changes remain off-limits to the implementer; the reporter
will reconcile `docs/PERF_GAP_ANALYSIS.md` and
`docs/GAP_ANALYSIS_RESOLVED.md` to reflect the Monitor-verified status
in Step 4.

## Phase E -- Q16 + Q45 (7 commits) -- COMPLETE

| #  | SHA       | Subject                                                                                 | Gap    | Closes |
|----|-----------|-----------------------------------------------------------------------------------------|--------|--------|
| 17 | `d2e462f` | refactor(url): extract Url.parse into stage helpers                                     | Q16    | #51    |
| 18 | `6e10b41` | refactor(network): create network/ directory; move hex helpers to network/hex.zig       | Q45.22a | --    |
| 19 | `0add2ce` | refactor(network): move Ipv4Addr to network/ipv4.zig                                    | Q45.22b | --    |
| 20 | `4478037` | refactor(network): move Ipv6Addr to network/ipv6.zig                                    | Q45.22c | --    |
| 21 | `99774ca` | refactor(network): move Subnet to network/subnet.zig                                    | Q45.22d | --    |
| 22 | `fef7e91` | refactor(network): move Mac to network/mac.zig                                          | Q45.22e | --    |
| 23 | `b5d16ec` | refactor(network): re-export from network.zig facade; update src/root.zig               | Q45.22f | #50    |

### Q16 -- Url.parse stage extraction

The monolithic 108-LOC `Url.parse` is now a ~36-LOC orchestrator that
calls, in order: `parseScheme` -> `splitFragment` -> `splitQuery` ->
`splitAuthorityPath` -> `splitUserinfo` -> `parseHostPort` ->
`validateHost`. Each helper owns exactly one RFC 3986 grammar section
and returns a named tuple so the orchestrator reads top-to-bottom.
Behaviour byte-for-byte identical; zero test changes.

### Q45 -- network.zig split

The 1,211-LOC monolith became a 68-LOC facade + 7 per-concern files
under `src/types/network/`:

| file                  | purpose                         | LOC |
|-----------------------|---------------------------------|-----|
| network.zig           | re-export facade                |  68 |
| network/common.zig    | ParseError + MAX_*_INPUT caps   |  28 |
| network/hex.zig       | hexDigitToInt helper            |  18 |
| network/ipv4.zig      | Ipv4Addr + tests                | 282 |
| network/ipv6.zig      | Ipv6Addr + tests                | 423 |
| network/ip.zig        | IpAddr union + tests            | 127 |
| network/subnet.zig    | Subnet + tests                  | 278 |
| network/mac.zig       | Mac + tests                     | 162 |

Each sub-commit ran all six test suites green. Public API stays
identical -- `network.Ipv4Addr`, `root.Ipv4Addr`, every external
caller resolves exactly as before.

One deviation from the plan's literal wording: `git mv` cannot move
part of a file, so each extraction commit introduces a new file and
removes the relevant chunk from the facade. History is reachable via
`git log --follow` from the new paths back to the original location.

## Phase F -- Release + docs + security-closures (4 commits)

| #  | SHA       | Subject                                                                                         | Gap / Closes |
|----|-----------|-------------------------------------------------------------------------------------------------|--------------|
| 24 | `c949582` | ci(release): sign tags + publish SBOM as release asset                                          | NEW-REL-01 / #71 |
| 25 | (this)    | docs(gap): note external blockers for GAP-0014/15/16/17/19 (no action)                         | GAP-0014/15/16/17/19 |

### NEW-REL-01 (#71) investigation + fix

- `glab release list` -> no releases on the project yet.
- `.gitlab-ci.yml:24` -- `release-semantic@v1.7.1` creates tag + draft
  release but does not sign the tag.
- `sbom-generate@v1.7.1` emits `gl-sbom-*.cdx.json` as a pipeline
  artifact; nothing attaches it to the release.
- No `cosign`/SLSA generator present.

Added two tag-pipeline-only jobs (`release-sign-tag`,
`release-attach-sbom`) guarded by `$CI_COMMIT_TAG` and
`$RELEASE_GPG_PRIVATE_KEY` env variables so branch/MR pipelines stay
green until the signing key is provisioned. Once the masked CI
variables are set, tagged releases will carry (a) a GPG-signed git
tag and (b) a CycloneDX SBOM as an official release asset.

### GAP-0014/15/16/17/19 bulk-closure

On GitLab only GAP-0019 (#23) is an open issue -- the remaining ledger
IDs (GAP-0014/15/16/17) live only in `docs/GAP_ANALYSIS.md` and are
not tracked as GitLab work items. The reporter will reconcile their
ledger entries in Step 4.

GAP-0019 ("CI Linux/x86_64-only; README claims cross-platform") was
already partly addressed by the CI-SUP-01 / CI-SUP-02 work in Phase B:
the matrix scaffolding for macOS, Windows, and Linux aarch64 is in
place in `.gitlab-ci.yml`, each job gated behind `rules: when: manual`
and `allow_failure: true`. The remaining blocker is runner provisioning
-- the `company` runner pool does not expose `macos`, `windows`, or
`aarch64` tags yet. That's an infra-ops task, not a repository
change. Issue closed on GitLab with the rationale + blocker reference.

### Appendix: status of GAP-0014/15/16/17/19 at end of Phase F

| Gap ID    | Ledger Entry                                        | Status                                                  |
|-----------|-----------------------------------------------------|---------------------------------------------------------|
| GAP-0014  | (docs ledger only; no GitLab issue)                 | External blocker per ledger rationale; no code action. |
| GAP-0015  | (docs ledger only; no GitLab issue)                 | External blocker per ledger rationale; no code action. |
| GAP-0016  | (docs ledger only; no GitLab issue)                 | External blocker per ledger rationale; no code action. |
| GAP-0017  | (docs ledger only; no GitLab issue)                 | External blocker per ledger rationale; no code action. |
| GAP-0019  | `#23`                                               | Closed: matrix scaffolded; runner provisioning blocker. |

The reporter owns the ledger-side reconciliation (marking these items
as scoped-wontdo / blocked-by-infra in
`docs/GAP_ANALYSIS.md` and `docs/GAP_ANALYSIS_RESOLVED.md`).

### Phase F (continued) -- Accepted/Won't-Do closures

Commit 26 finalises the won't-do status on GitLab for the four
issues that were graded "accepted" in `docs/audit/security-review.md`
but left open on the issue tracker:

| Issue | Title                                                                                   |
|-------|-----------------------------------------------------------------------------------------|
| #69   | SAST-OVERFLOW-01: Range.span / Vector arithmetic wrap silently in ReleaseFast/Small     |
| #70   | CI-FUZZ-01: Fuzz job skipped on default MR pipelines (schedule/manual only)             |
| #72   | OP-OWNER-01: Single CODEOWNERS owner -- account-compromise == repo-write                |
| #73   | CI-SECRETS-01: No pre-commit gitleaks hook (CI-only coverage)                           |

Each had `status::accepted` labels but was still in the "open" state.
Posted a closing comment on each referencing the `security-review.md`
classification, then closed via `glab issue close`. No code change.
CI-CAT-01 (#47) was already closed before this session and was not
touched.
