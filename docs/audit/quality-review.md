# Phase 3 Quality Review — advanced-types

- **Repo:** `devnw/zig/advanced-types`
- **Scope:** full repo (`src/`, `tests/`, `examples/`, `docs/`, `build.zig`, `build.zig.zon`, `README.md`)
- **Inputs:** Phase 1 inventory (`quality-inventory.md`), Phase 2 scan (`quality-scan.md`), prior ledger (`docs/QUALITY_GAP_ANALYSIS.md` Q1–Q13)
- **Toolchain:** Zig 0.16.0 (CI + local). All 233 unique test functions pass in Debug / ReleaseSafe / ReleaseFast / ReleaseSmall.

---

## Reconciliation with Q1–Q13 Ledger

| Prior Q | Status in ledger | Phase-2/3 delta |
|---------|------------------|-----------------|
| Q1 Vector.format signature | Closed | still clean at `vector.zig:197` (confirmed) |
| Q2 network.zig doc coverage | Closed | **confirmed**: 40/40 pub decls documented |
| Q3 docs README dead links | Closed | out of scope this phase |
| Q4 examples/basic.zig | Closed | verified via `zig build example` step |
| Q5 Duplicate hex-digit parsers | Closed | **partially reopen** — see Q20; `hexDigitValue` and `Mac.hexVal` shims remain (DC2, DC3) |
| Q6 vector format dead branch | Closed | verified removed |
| Q7 geographic whitespace helpers | Closed | verified removed |
| Q8 Range.isEmpty rename | Closed | verified — uses `isPoint` |
| Q9 network.zig > 800 LOC | Won't Do | **confirms** — now 965 LOC; refactor candidates C1/C2/C3/C4 would cut ~30 LOC |
| Q10 Missing edge-case tests | Won't Do | **reopen** — IPv4 leading zeros, IPv6 double `::`, URL userinfo still absent (see Q33) |
| Q11 CI Zig version | Closed | **reopen as Q36** — CI now runs 0.16.0 while `build.zig.zon:5` still declares `0.15.1` |
| Q12 CI reinstalls Zig | Won't Do | unchanged |
| Q13 examples build step | Closed | verified at `build.zig:90` |

Net: 10 prior findings stand as closed; Q10 and Q11 reopen with new detail; Q5 is partially reopened as Q20.

---

## 1. Readability & Maintainability

| # | Finding | File:Line | Root cause | Impact | Confidence | Recommendation |
|---|---------|-----------|------------|--------|------------|----------------|
| **Q14** | Duplicate `(lat, lon[, alt])` tuple parsers (D1) | `geographic.zig:106`, `:176`, `:285` | Three structs each re-implement trim → paren-strip → comma-split → `parseFloat` → `init` | ~60 LOC of duplicated logic; divergence risk when one parser gets a fix (e.g. Q7 whitespace update) | `confidence::confirmed` | **REFACTOR** — extract a private helper `parseTuple(comptime arity: usize, input: []const u8) ParseError![arity]f64` in `geographic.zig` at file scope. `LatLon.parse`, `LatLonAlt.parse` call it with arity 2/3. `GeoPoint.parse` keeps comma-count dispatch. Churn: ~40 LOC net reduction. |
| **Q15** | Bracket-parser pattern repeated 5× across modules (D4) | `geographic.zig:106,176`; `range.zig:107`; `vector.zig:211`; `network.zig:426` | No shared iterator; each parser hand-rolls bracket check + split + trim | moderate: each fix has to land in 5 places; cognitive load on readers scanning modules | `confidence::confirmed` | **REFACTOR (medium churn)** — add `src/types/internal/parse.zig` with `pub fn bracketedTokens(input: []const u8, open: u8, close: u8, sep: u8) Iterator` that returns trimmed tokens and advances past closer. Each parser becomes 10-15 LOC. Alternative accept-with-rationale: each module's brackets differ (`(...)`, `[...]`, `n.n.n.n/n`) — but at least the `[/]` and `(/)` forms overlap. Pick the refactor. |
| **Q16** | `Url.parse` 86 LOC single function (C1) | `url.zig:161-246` | Linear walk scheme → fragment → query → authority → host/port in one function | readability only; correctness is fine | `confidence::confirmed` | **REFACTOR** — extract three private helpers: `parseScheme(input) !{scheme, rest}`, `splitAuthorityAndPath(rest) !{authority, path}`, `parseHostPort(authority) !{host, port}`. `Url.parse` becomes orchestrator (~25 LOC). Also eliminates the awkward `path = input[x..x]` empty-slice trick at line 202. |
| **Q17** | `Subnet.contains` 6-level nesting (C2) | `network.zig:461-506` | Outer switch on `self.network`, inner switch on `addr`, then if-chain for byte-aligned vs bit-aligned v6 prefix | control flow hard to audit (this is a security-sensitive predicate — any bug allows/denies traffic wrongly) | `confidence::confirmed` | **REFACTOR** — split into two free functions `containsV4(net: Ipv4Addr, prefix: u8, addr: Ipv4Addr) bool` and `containsV6(net: Ipv6Addr, prefix: u8, addr: Ipv6Addr) bool`; `contains` becomes a single switch that family-matches and delegates (v4/v4, v6/v6 dispatch; cross-family returns false). Drops nesting to 3. |
| **Q18** | `Ipv6Addr.format` 5-deep nesting (C3) | `network.zig:287-331` | Inline best-run bookkeeping in `format` | minor — correct and tested | `confidence::confirmed` | **REFACTOR (light)** — extract `longestZeroRun(segs: [8]u16) struct{start: usize, len: usize}`, drops to 3-deep. |
| **Q19** | `Ipv6Addr.parse` 5-deep nesting (C4) | `network.zig:190-234` | `::` left/right branching inline | minor | `confidence::confirmed` | **REFACTOR (light)** — factor `parseSides(left, right, octets) !usize` so the `::` branch is flat. |
| **Q20** | Redundant hex-digit wrappers (DC2, DC3) | `network.zig:281-284`, `:560-562` | `hexDigitValue` / `Mac.hexVal` are one-liners around file-scope `hexDigitToInt` | dead-ish; leftover from Q5 consolidation | `confidence::confirmed` | **REFACTOR (trivial)** — inline: `parseGroups` calls `hexDigitToInt` directly (casting the captured value via `@as(u32, v)`); `Mac.parse` calls `hexDigitToInt` directly. Delete both shims. |
| **Q21** | Redundant error-mapping shim (DC4) | `range.zig:140-145` | `mapParseError` switches on a 2-variant error set, both identity-mapped, while `RangeError` already includes both | dead-ish code; small footgun if `std.fmt.ParseIntError` gains a variant | `confidence::suspected` | **REFACTOR** — replace call sites with direct `catch \|e\| return e;` (the error set is already a subset of `RangeError`). Delete `mapParseError`. Verify with `zig build test`. |
| **Q22** | `Ipv4Addr.parse` hand-rolls digit accumulation (D3) | `network.zig:77-110` | Per-octet state machine instead of `splitScalar` + `std.fmt.parseInt(u8, …, 10)` | 34 LOC where 15 would do; consistent with `Ipv6Addr.parseGroups` hand-roll (D2) | `confidence::suspected` (perf trade-off) | **ACCEPT-WITH-RATIONALE** — benchmark first (defer to perf phase). Current code rejects multi-digit per-octet overflow in one pass; `splitScalar` + `parseInt` would call `parseInt` 4 times. If perf is within 10%, refactor. Otherwise document intent with a `// perf: hand-rolled …` comment. |
| **Q23** | Manual big-endian packing for u32/u16/mac (D5) | `network.zig:59-74`, `:171-187`, format sites | Bit-shifts instead of `std.mem.readInt(.big)` / `writeInt(.big)` | readability only | `confidence::suspected` | **REFACTOR (light)** — swap to `std.mem.readInt`/`writeInt`; halves each helper. Runtime equivalent. |
| **Q24** | Vector/Range "giant" comptime bodies (C5) | `vector.zig:30`, `range.zig:20` | Idiomatic Zig generic factories | — | `confidence::confirmed` | **ACCEPT** — documented in scan as not-a-finding. Splitting would hurt Zig's comptime locality. |

---

## 2. API & Contract Consistency

| # | Finding | File:Line | Root cause | Impact | Confidence | Recommendation |
|---|---------|-----------|------------|--------|------------|----------------|
| **Q25** | `Url.raw/scheme/host/path/query/fragment` and `Domain.raw` alias caller buffer; lifetime undocumented | `url.zig:37-38`, `:147-158` | Zero-allocation parser stores `[]const u8` slices into input; doc comments don't mention the invariant | caller keeping a `Url` after the original buffer is freed gets use-after-free with no diagnostic; same for `Domain` | `confidence::confirmed` | **DOC** (primary) + optionally add a `clone(allocator)` helper. Update `//!` block and each `pub struct` doc to state: "Slices reference the caller-provided input; the value is only valid while that input lives." |
| **Q26** | `Subnet` struct is pub-constructible with invalid `prefix_len` | `network.zig:419-423` | `pub const Subnet = struct { network: IpAddr, prefix_len: u8 };` — bare-struct init bypasses `parse`'s 0-32 / 0-128 validation | in Debug/ReleaseSafe the `@intCast` and shifts may panic on bad input; in ReleaseFast silent wrong-answer | `confidence::confirmed` | **DOC + GUARD** — two non-breaking options: (a) add an `init(network, prefix_len) ParseError!Subnet` and mark direct struct init "unchecked; use `init` or `parse`" in the doc; (b) add a debug-only `assert` at the top of `contains` / `format` so misuse surfaces early even on bare-struct init. Preferred: do both. |
| **Q27** | Integer-overflow behavior in `Vector.add/sub/scale/dot` and `Range.span` differs across optimize modes; only documented per-function | `vector.zig:105, 114, 123, 132`; `range.zig:82-86` | Zig safety semantics differ Debug/ReleaseSafe (panic) vs ReleaseFast (wrap) | consumer surprise; no README-level disclaimer | `confidence::confirmed` | **DOC** — add a README section "Optimize-mode semantics" that states the rule once. Keep the per-function notes but cross-reference them. No code change required. |
| **Q28** | `ParseError` type-name collision across modules | `network.zig:29`, `url.zig:16`, `vector.zig:26`; `geographic.zig:17` (`GeoError`), `range.zig:14` (`RangeError`) | Each module defines its own error set; some named `ParseError`, others named by domain | when re-exported via `root.zig`, consumers writing `advanced_types.network.ParseError` vs `advanced_types.url.ParseError` may confuse which set they are catching; `root.zig` does not re-export error types | `confidence::suspected` | **DOC + CONSIDER HARMONIZE** — (a) add a doc line on each error set cross-referencing the module; (b) consider re-exporting the error types from `root.zig` with unique names (`NetworkParseError`, `UrlParseError`, `VectorParseError`) or merging into one `AdvancedTypesError` union. Low-risk: just doc. |
| **Q29** | `Vector.at` panics on OOB while sibling `Vector.get` returns `?T` | `vector.zig:76-87` | Two access APIs with different failure modes; no doc guidance on which to use | API surface bloat; callers must know to pick `get` for untrusted indices | `confidence::suspected` | **DOC** — update `at` doc to "Prefer `get` unless the index is statically known to be in range. Panics in all build modes when `index >= N`." Keeps the ergonomic `at` but makes the contract explicit. |

---

## 3. Reliability Enablers

| # | Finding | File:Line | Root cause | Impact | Confidence | Recommendation |
|---|---------|-----------|------------|--------|------------|----------------|
| **Q30** | Fuzz suite broken on Zig 0.16 | `tests/fuzz.zig:26-30` (and all 13 fuzz tests), `build.zig:60-72` | `std.testing.fuzz` signature / `--fuzz` runner semantics changed 0.15 → 0.16; Phase-2 scan notes "test-fuzz already broke" | fuzz coverage is zero on current CI image; regression in parser robustness would not be caught | `confidence::confirmed` | **FIX (medium)** — follow the Zig 0.16 migration notes for `std.testing.fuzz`. Rewrite each fuzz test to the new API or wrap in `if (@hasDecl(std.testing, "fuzz"))`. Add a CI job that runs `zig build test-fuzz -- --fuzz --max-iterations=100000` nightly. |
| **Q31** | No coverage instrumentation | build.zig / CI | Not set up; Zig 0.16 has `kcov`/`llvm-cov` integration but it's not wired | unknown which branches are test-free; 80.9% doc-coverage metric gives false confidence as a proxy | `confidence::confirmed` | **FIX** — add `make coverage` target calling `kcov --include-path=src/ kcov-out/ zig-out/test`. Gate CI at 85% line coverage to start. |
| **Q32** | `//!` module-level doc examples are not compiled | `root.zig:11-17`, `vector.zig:13-21`, and other `//!` blocks | Zig has no `--test-doc` equivalent; examples drift silently | examples can compile-rot. The `root.zig` example relies on `VectorF32.init(.{…})` with 3 elements; any dimension change breaks silently | `confidence::confirmed` | **FIX (light)** — convert each `//!` example into a `test "doc-example-X"` block in the same file (picked up by `refAllDecls`). Keeps the same code visible in docs but now compiled on every `zig build test`. |
| **Q33** | Missing edge-case tests (reopens prior Q10) | `network.zig` tests; `url.zig` tests | IPv4 leading zeros, IPv6 with multiple `::`, URL userinfo (`user:pass@host`), Unicode-IDN domains, maxint subnet prefix | silent correctness gaps on adversarial input | `confidence::suspected` | **ADD TESTS** — per item, one positive + one negative case. Start with: `Ipv4Addr.parse("01.2.3.4")` (reject or accept? document), `Ipv6Addr.parse("1::2::3")` (must error), `Url.parse("http://user:pass@host/")` (must error or extract). |
| **Q34** | Per-optimize-mode test runs share one binary; no separate fuzz/perf gate | `build.zig:18-87` (B2) | Single `test_step` runs all inline tests regardless of optimize mode; fuzz/perf are separate steps but not wired into a single `ci` target | slow local iteration (can't skip perf tests); CI verbosity | `confidence::suspected` | **FIX** — add `-Dtest-filter=…` forwarding to `unit_tests.addArgs`, and a `zig build test-quick` that runs only Debug inline tests. |
| **Q35** | Integer-wrap behavior in `Range.span` not tested at u64 max | `range.zig:85-87` + tests | Doc warns about overflow; no test triggers it in ReleaseFast | silent behavior divergence between modes would land in a consumer's hands before this library's CI catches it | `confidence::suspected` | **ADD TEST** — `test "span wraps at boundary in ReleaseFast"` gated on `@import("builtin").mode == .ReleaseFast`. Also consider adding `overflowingSpan(self) ?T` that returns null for unrepresentable widths. |

---

## 4. Documentation Gaps

| # | Finding | File:Line | What's missing | Impact | Confidence | Recommendation |
|---|---------|-----------|----------------|--------|------------|----------------|
| **Q36** | `minimum_zig_version` / README drift (reopens prior Q11) | `build.zig.zon:5` (`"0.15.1"`), `README.md:4` badge, `:71` "Zig 0.15.1 or later" | CI now runs 0.16.0; pkg manifest and README both say 0.15.1 | downstream users pinning to 0.15.1 may fail to build against code that uses 0.16-only APIs (see Q30) | `confidence::confirmed` | **FIX** — decide the support floor. If supporting 0.15.1, the fuzz suite must compile there (couples with Q30). If 0.16-only, bump `minimum_zig_version = "0.16.0"`, badge to `0.16.0+`, README to `Zig 0.16.0 or later`. |
| **Q37** | 6 undocumented `pub` decls in leaf modules | `geographic.zig:17` `GeoError`; `url.zig:16` `ParseError`; `range.zig:14` `RangeError`; `range.zig:195-197` `IntRange`/`UintRange`/`FloatRange` | No `///` doc comment | 19.1% of the public surface is undocumented; error sets surface in signatures but have no description of when each variant fires | `confidence::confirmed` | **FIX (trivial)** — add 1-3 lines per symbol. For error sets, enumerate each variant with the trigger. For `IntRange`/`UintRange`/`FloatRange`, one-line "convenience alias for `Range(i64)` etc." |
| **Q38** | README test-count drift | `README.md:14` | "230 Tests" — actual per Phase 2 is 233 inline unique + ~39 in `tests/` = 272 `test` blocks | credibility/accuracy; metric used in promo materials | `confidence::confirmed` | **FIX (trivial)** — update to "260+ tests across unit, integration, type-extension, fuzz, and perf suites". Better: make it a build-generated number so it stays honest. |
| **Q39** | No module-level README / architecture doc | missing `src/types/README.md` or top-level ARCH.md | 5 type families and their relationships (e.g. `IpAddr ⟶ Subnet`, `GeoPoint ⟶ LatLon/LatLonAlt`) are not diagrammed | onboarding friction | `confidence::suspected` | **FIX (light)** — add `docs/ARCHITECTURE.md` with one-screen overview: module boundaries, error-set ownership, value-type contract (no allocation, slices-alias-input). |
| **Q40** | No ADRs capturing key decisions | `docs/` has `REQUIREMENTS.md` and gap docs, no `docs/adr/` | Why hand-rolled IPv4 parser (Q22), why `::` shorthand at parse time not format, why `Ipv6Addr.segments` is private | implicit knowledge lost when maintainers change | `confidence::suspected` | **FIX** — add 2-3 short ADRs: (1) "Zero-allocation parsing contract", (2) "Hand-rolled numeric parsers for network types", (3) "Integer overflow policy". Use `codepros:adr` skill if available. |
| **Q41** | "Why" comments missing on non-obvious code | `network.zig:483-499` (`Subnet.contains` byte/bit split), `range.zig:181-182` (maxInt adjacency guard) | Code is correct but the *why* is not explained | any future refactor (e.g. Q17) must rediscover intent | `confidence::suspected` | **FIX (light)** — 1-2 line comments per site: "Byte-aligned portion first to let std.mem.eql vectorize; remainder handled with explicit mask." and "Guard against overflow at type boundaries to keep adjacency pure." |

---

## Recommendation Summary

| Category | Count | Refactor | Doc-only | Fix / test | Accept-with-rationale |
|----------|-------|----------|----------|------------|-----------------------|
| Readability & Maintainability | 11 (Q14–Q24) | 8 | 0 | 0 | 3 (Q22, Q23 optional, Q24) |
| API & Contracts | 5 (Q25–Q29) | 0 | 4 | 1 (Q26 guard) | 0 |
| Reliability | 6 (Q30–Q35) | 0 | 0 | 6 | 0 |
| Documentation | 6 (Q36–Q41) | 0 | 6 | 0 | 0 |

**Total new findings:** 28 (Q14–Q41). No single item is a correctness defect in shipped behavior; the aggregate risk is maintainability drift and contract ambiguity.

---

## Verification Plan (per-fix)

- **Q14–Q23 refactors** — `zig fmt --check && zig build check && zig build test` in all 4 modes; confirm test count unchanged at 233.
- **Q26 Subnet guard** — add negative test `Subnet{.network = ipv4, .prefix_len = 200}` invoking `contains` — expect assertion fail in ReleaseSafe.
- **Q30 fuzz** — `zig build test-fuzz -- --fuzz --max-iterations=10000` returns exit 0 on clean tree.
- **Q32 doc examples** — add compiled doctests, `zig build test` picks them up via `refAllDecls`.
- **Q36 version drift** — `zig version` locally + `grep minimum_zig_version build.zig.zon` + README grep must agree.
- **Q38 test count** — optional: generate from `find src tests -name '*.zig' -exec grep -c '^test ' {} +` and embed at build time.

---

## Inputs for Phase 4 (quality-issue-tracker)

Top-5 by impact (suggested triage order):

1. **Q30 Fuzz suite broken** — highest reliability impact; parser robustness is core to this library.
2. **Q26 `Subnet` invalid-state** — API-contract bug with real panic risk in the one security-sensitive predicate.
3. **Q25 Slice-lifetime contract undocumented** — silent use-after-free footgun across `Url`/`Domain`.
4. **Q17 `Subnet.contains` 6-deep nesting** — the function where nesting most matters (security predicate).
5. **Q36 `minimum_zig_version` / README drift** — downstream build breakage; trivial fix.

All 28 findings (Q14–Q41) should be filed as separate tickets with the IDs above so the ledger can track them alongside Q1–Q13.
