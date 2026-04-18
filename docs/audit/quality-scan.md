# Quality Scan — advanced-types

Phase 2 of `/codepros:audit`. Automated scanning pass. All paths absolute.
Generated: 2026-04-18 against HEAD `f3adc69` (supersedes prior file of same name).

- **Repo:** `/home/benji/src/devnw/zig/advanced-types`
- **Zig toolchain:** local `0.16.0` (via mise); CI `0.16.0`
- **Phase 1 reference:** `/home/benji/src/devnw/zig/advanced-types/docs/audit/quality-inventory.md`
- **Closed-findings ledger (do not re-raise):** `/home/benji/src/devnw/zig/advanced-types/docs/QUALITY_GAP_ANALYSIS.md`
- **Raw logs:** `/tmp/zig-check.log`, `/tmp/zig-test.log`

---

## 1. Automated Tooling

### Lint / Format / Typecheck / Tests

| Tool | Command | Status | Notes |
|---|---|---|---|
| `zig fmt` | `zig fmt --check src/ tests/ build.zig examples/ bench/` | PASS (exit 0) | No diffs. |
| `zig build check` | `zig build check` | PASS (exit 0) | No warnings / errors. |
| `zig build test` | `zig build test --summary all` | PASS | 248/248 tests (19 ms, MaxRSS 4 M). |
| `zig build test-integration` | — | PASS | 9/9 tests. |
| `zig build test-extensions` | — | PASS | 11/11 tests. |
| `zig build test-parser-edges` | — | PASS | 16/16 tests. |
| `zig build test-performance` | — | PASS | 9/9 tests. |
| `zig build example` | — | PASS | Example runs and prints expected output. |
| Fuzz compile | via `test` run above | PASS | Fuzz targets compile; coverage-guided run is CI schedule-only. |

### Pre-commit hooks (`pre-commit run --all-files`)

| Hook | Status | Notes |
|---|---|---|
| `trailing-whitespace` / `end-of-file-fixer` / `mixed-line-ending` | PASS | |
| `check-yaml` / `check-json` / `check-toml` | PASS | |
| `check-added-large-files` / `check-merge-conflict` / `detect-private-key` | PASS | |
| `shellcheck` | SKIP | No shell scripts in the repo. |
| `markdownlint` | **FAIL** | 7 issues (see §2). |
| `pretty-format-yaml` | **FAIL** | `.cz.yaml` reformatted by `--autofix`. The committed file disagrees with the hook (confidence::confirmed). |
| `zig fmt (check)` | PASS | |
| `zig build (check)` | PASS | |
| `check-todos` (custom) | PASS | No TODO/FIXME/XXX/HACK markers anywhere in `.zig` sources. |

Coverage (`kcov`) and secret scanners (`gitleaks`) are CI-only; not exercised locally in this pass.

---

## 2. Lint / Format / Typecheck — Findings Detail

| Finding | File:Line | Tool | Confidence |
|---|---|---|---|
| MD040 fenced code block missing language | `/home/benji/src/devnw/zig/advanced-types/.gitlab/issue_templates/Bug Report.md:44` | markdownlint | confidence::confirmed |
| MD040 fenced code block missing language | `/home/benji/src/devnw/zig/advanced-types/CONTRIBUTING.md:48` | markdownlint | confidence::confirmed |
| MD032 list not surrounded by blank lines | `/home/benji/src/devnw/zig/advanced-types/CONTRIBUTING.md:57` | markdownlint | confidence::confirmed |
| MD034 bare URL (`conduct@codepros.dev`) | `/home/benji/src/devnw/zig/advanced-types/CODE_OF_CONDUCT.md:50` | markdownlint | confidence::confirmed |
| MD034 bare URL (`https://www.contributor-covenant...`) | `/home/benji/src/devnw/zig/advanced-types/CODE_OF_CONDUCT.md:58` | markdownlint | confidence::confirmed |
| MD056 table column count (expected 4, got 3) | `/home/benji/src/devnw/zig/advanced-types/docs/audit/security-inventory.md:133` | markdownlint | confidence::confirmed |
| MD034 bare URL (`support@codepros.dev`) | `/home/benji/src/devnw/zig/advanced-types/SUPPORT.md:41` | markdownlint | confidence::confirmed |
| `.cz.yaml` reformatted by `pretty-format-yaml --autofix` (14 lines modified) | `/home/benji/src/devnw/zig/advanced-types/.cz.yaml` | pretty-format-yaml | confidence::confirmed |

All failures are in Markdown / YAML — no Zig issues. Fixing MD034 mail links, adding a language to the two fenced blocks, adjusting one table row in `security-inventory.md`, and either landing the formatter diff or relaxing the hook unblocks pre-commit.

---

## 3. Duplication & Complexity

### File size

| File | LOC | Flag |
|---|---|---|
| `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig` | 1166 | > 800 — very large |
| `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig` | 789 | > 500 — large |
| `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig` | 634 | > 500 — large |
| `/home/benji/src/devnw/zig/advanced-types/tests/performance.zig` | 601 | > 500 — large (test file, many literal tables) |
| `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig` | 577 | > 500 — large |
| `/home/benji/src/devnw/zig/advanced-types/src/types/range.zig` | 573 | > 500 — large |

All six large files pair a public type with its tests; inventory confirms the `src/types/*.zig` pattern pulls unit tests in-file. Network is the only > 800-line hot spot; a split (Ipv4/Ipv6/Subnet/Mac) would be mechanical.

### Long functions (> 40 lines, source only)

| Function | File:Line | LOC |
|---|---|---|
| `Url.parse` | `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig:190` | 108 |
| `Ipv6Addr.format` | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:311` | 45 |
| `Ipv6Addr.parse` | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:214` | 45 |

`Url.parse` is linear (scheme → fragment → query → authority → host → port → validation); each stage is cohesive, but at 108 lines it is the one function in the codebase where a stage-level refactor (helper per stage: `parseScheme`, `splitFragmentQuery`, `parseHostPort`) would noticeably reduce review burden. `Ipv6Addr.parse` / `format` are tight given RFC-5952 canonicalisation. Confidence::suspected (stylistic, not a defect).

### Nesting depth

- Deepest indentation observed in `src/types/*.zig` is **5 levels** (20 spaces), driven almost entirely by the `pub fn Range(comptime T: type) type { return struct { … } }` comptime-container pattern rather than real control-flow nesting.
- No line exceeds 24 spaces of leading indentation anywhere in `src/`. Logical nesting is ≤ 3 in every function inspected.
- Verdict: not a complexity hotspot (confidence::confirmed via Grep sweep).

### Duplication

| Finding | Files | Confidence |
|---|---|---|
| `Ipv6Addr.hexDigitValue` and `Mac.hexVal` are thin wrappers around module-level `hexDigitToInt` | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:305`, `:643` vs. `:17` | confidence::confirmed |
| 10 near-identical fuzz wrappers (`fuzzIpv4Parse`, `fuzzIpv6Parse`, `fuzzIpAddrParse`, `fuzzSubnetParse`, `fuzzMacParse`, `fuzzUrlParse`, `fuzzDomainParse`, `fuzzLatLonParse`, `fuzzLatLonAltParse`, `fuzzVectorF32Parse`) each have the same 3-line body (`takeSlice` → `_ = Type.parse(input) catch return;`) | `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig:44-152` | confidence::confirmed |
| Inline magic literals `180.0` / `-180.0` / `90.0` / `-90.0` and `math.pi / 180.0` conversion factor recur across geographic validators and haversine math without a named constant | `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig:103,128,183,327-328,379` | confidence::suspected |

No near-duplicate full-function bodies in `src/`. Parser functions share control-flow shape (validate → accumulate → return), but their per-family semantics differ; not extractable without contriving generics.

### Circular dependencies

`src/types/*.zig` files do not import each other (confirmed from Phase-1 module graph). `src/root.zig` is the sole aggregator; no cycles (confidence::confirmed).

---

## 4. Dead Code

| Finding | File:Line | Type | Confidence |
|---|---|---|---|
| No TODO / FIXME / XXX / HACK markers in any `.zig` file | — | marker | confidence::confirmed |
| `hexDigitValue` (u32 wrapper) could be inlined / deleted — the `hexDigitToInt` body already fits the call site with an explicit cast | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:305-308` | trivial wrapper | confidence::suspected |
| `hexVal` (u8 wrapper) could be inlined / deleted | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:643-645` | trivial wrapper | confidence::suspected |

No unused private functions were found. Private symbols inspected: `hexDigitToInt`, `parseTupleInParens`, `segments`, `findDoubleColon`, `parseGroups`, `hexDigitValue`, `hexVal`, `containsV4`, `containsV6`, `validateLabel`, `isValidDomainChar`, `validateHostChars`, `parsePortStrict`, `looksLikeIpv4`, `optionalEql`, `parseValue`, `mapParseError`, `isFloat`, `equal`, `lessThan`, `greaterThan`, `max`, `min`, `adjacent`, `parseElement` — all reachable from public entry points (confidence::confirmed).

No stale feature flags (library has no runtime feature-flag concept). Zero runtime dependencies → no stale dependency manifest entries.

---

## 5. Zig-Specific Brittle Patterns

| Finding | File:Line | Category | Confidence |
|---|---|---|---|
| 16 `@intCast` call sites in `network.zig` — every one is preceded by an explicit range guard (mask to `0xFF`, modulo, or a just-validated `prefix_len ≤ 128` / `≤ 32`). Confirmed safe on manual review. | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:62-65, 91, 108, 198-199, 280-281, 298-299, 533, 564, 574, 581` | `@intCast` safety | confidence::confirmed |
| `@panic("Vector index out of bounds")` inside `Vector.at` — documented (doc comment "Panics if index >= N.") and paired with a non-panicking `get(index) ?T` sibling. Acceptable pattern; worth a mention. | `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig:76-81` | `@panic` in hot path | confidence::confirmed |
| Every `catch unreachable` occurrence (22 total) is inside `test "…" { … }` blocks (testing-local `bufPrint` roundtrips where the 64-byte buffer is trivially sufficient). None outside tests. | `src/types/geographic.zig`, `src/types/network.zig`, `src/types/range.zig`, `src/types/vector.zig` | `catch unreachable` outside tests | confidence::confirmed (none found) |
| No `@truncate`, `@ptrCast`, `@alignCast`, or `@bitCast` in `src/` — library is free of unsafe reinterpretation | — | unsafe casts | confidence::confirmed |
| Long-chain `switch` — longest observed is 4 arms (IpAddr/v4-v6 nested dispatch in `Subnet.contains`, `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:541-552`). Not a hot spot. | — | `switch` length | confidence::confirmed |
| Magic numbers in geographic bounds and conversions (`180.0`, `-180.0`, `90.0`, `-90.0`, `math.pi/180.0`) — named constants (`earth_radius_m`) exist for Earth radius but not for degree ranges or the degrees-to-radians factor | `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig:103,128,183,327-328` | magic numbers | confidence::suspected |

---

## 6. Test Quality

### Assertion density by test file

| File | LOC | Tests | Assertions | Density |
|---|---|---|---|---|
| `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` | 154 | 10 | 0 (crash-only invariant is the assertion) | n/a (by design) |
| `/home/benji/src/devnw/zig/advanced-types/tests/integration.zig` | 172 | 9 | 21 | 2.3 / test |
| `/home/benji/src/devnw/zig/advanced-types/tests/parser_edge_cases.zig` | 156 | 16 | 38 | 2.4 / test |
| `/home/benji/src/devnw/zig/advanced-types/tests/performance.zig` | 601 | 9 | 33 | 3.7 / test (large literal tables inflate LOC) |
| `/home/benji/src/devnw/zig/advanced-types/tests/type_extensions.zig` | 206 | 11 | 32 | 2.9 / test |

### Specific test-quality findings

| Finding | File:Line | Type | Confidence |
|---|---|---|---|
| Shallow compile-time smoke test: `test "integration: all public types are accessible"` is a sequence of `_ = lib.Type;` discards. This is a **build-time reference check only** — it never exercises behaviour. Fine as a drift guard, but should be documented or paired with one real call per type. | `/home/benji/src/devnw/zig/advanced-types/tests/integration.zig:20-47` | shallow / no-assert | confidence::confirmed |
| Version smoke test asserts one string literal equality only | `/home/benji/src/devnw/zig/advanced-types/tests/integration.zig:16-18` | low-value | confidence::confirmed |
| Fuzz tests contain zero `testing.expect*` calls. The invariant "no parser may panic" is implicit (test exits normally → pass). Documented in the file's doc comment — acceptable, but a comment on each wrapper would clarify intent for readers. | `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig` | implicit assertion | confidence::confirmed |
| Missing explicit negative-case fuzz seeds. `tests/fuzz.zig` seeds only with `Smith` arbitrary bytes — there is no corpus file for known-bad inputs (e.g. the IDN / punycode patterns from Q33 / NEW-02 are covered by `parser_edge_cases.zig`, not by fuzzing). Documented gap in Phase-1 inventory (§Missing Tooling item 5) — not raised again here. | — | coverage | confidence::suspected |
| Performance tests act as large-table parser tests (100 valid + 100 invalid IPv4, etc.). They assert parse success/failure and occasional roundtrip equality but do not assert timing/throughput — consistent with the comment in Phase-1 inventory that these are "integration-at-scale". The filename is misleading (suggests microbenchmarks). Worth renaming or splitting. | `/home/benji/src/devnw/zig/advanced-types/tests/performance.zig:25-…` | naming | confidence::suspected |
| No test flags fuzz-corpus persistence — CI fuzz job (`.gitlab-ci.yml:341`) emits `zig-out/fuzz/` on failure only; there is no seed-import step so rerunning a discovered crash requires manual copying. | `/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml:341-357` | CI wiring | confidence::suspected |

No source `test` blocks inside `src/types/*.zig` were sampled for shallowness — 247 declarations and full green run in 19 ms suggest sound coverage; spot-checks during the Zig-specific sweep showed realistic assertions on parse/format/roundtrip behaviour. Confidence::suspected that this remains the case across all 247.

---

## 7. Build & CI Performance

Out-of-scope for this pass per task brief (CI config was covered in Phase-1 inventory §Missing Tooling and §CI Pipeline Stages). No new findings surface from the scanning tooling itself.

---

## Blockers for Downstream Phases

None. All Zig-toolchain gates are green; the only failing hooks are documentation/markdown and a single YAML formatter disagreement — both orthogonal to code correctness and safe to address in a docs commit.

---

## Handoff

- **quality-reviewer:** Spend cycles on `src/types/network.zig` (1,166 LOC, the one file past the 800 threshold) and `src/types/url.zig:190` (`Url.parse`, 108 lines). Both are the obvious candidates for a stage-level split. Duplicate `hexDigitValue` / `hexVal` wrappers are low-hanging. Fuzz-wrapper DRY-up (10 copies) would turn into ~20 lines with a comptime generic.
- **quality-issue-tracker:** New items from this pass are all low severity: markdownlint cleanup, `.cz.yaml` formatter disagreement, `Url.parse` refactor, fuzz-wrapper dedup, and magic-number extraction in `geographic.zig`. No existing closed gap is resurrected.
