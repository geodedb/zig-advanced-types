# Quality Gap Analysis

Last updated: 2026-04-18 (gap-closure report)

## Summary

| Status | Count |
|--------|-------|
| Closed (Q1–Q13 historical) | 10 |
| Closed 2026-04-18 (Q15, Q17, Q25, Q26, Q30, Q31, Q33, Q36) | 8 |
| Won't Do | 2 (Q9, Q12) |
| Accepted (Q24) | 1 |
| Reopened — now closed | Q10→Q33 closed; Q11→Q36 closed; Q5→Q20 still open (ledger-only) |
| Open — ledger-only (PriorityScore < 40) | 20 (Q14, Q16, Q18–Q24, Q27–Q29, Q32, Q34–Q35, Q37–Q41) |
| **Total tracked** | **41** |

### Severity distribution (new findings Q14–Q41)

| Tier | PriorityScore | Count | IDs |
|------|---------------|-------|-----|
| Critical | ≥ 80 | 1 | Q30 |
| High | 60–79 | 3 | Q25, Q26, Q36 |
| Medium | 40–59 | 4 | Q15, Q17, Q31, Q33 |
| Low | < 40 | 20 | Q14, Q16, Q18–Q24, Q27–Q29, Q32, Q34–Q35, Q37–Q41 |

### Top 5 risks (all closed 2026-04-18)

1. **Q30** Fuzz suite broken on Zig 0.16 — **Closed** (c0e07ee): ported to Smith API; 10/10 green.
2. **Q25** `Url`/`Domain` slice-lifetime contract — **Closed** (5c97228): lifetime contract docs landed on public URL API.
3. **Q26** `Subnet` pub-constructible with invalid `prefix_len` — **Closed** (503c1f5): `Subnet.init` validator + defensive returns in `containsV4`/`containsV6`.
4. **Q36** `minimum_zig_version` / README drift — **Closed** (3702dd1): reconciled manifest/README/CI to 0.16.0.
5. **Q17** `Subnet.contains` 6-deep nesting — **Closed** (503c1f5): split into `containsV4`/`containsV6` helpers.

---

## Historical findings (Q1–Q13)

| # | Finding | Severity | Status | Resolution |
|---|---------|----------|--------|-----------|
| Q1 | Vector.format uses concrete `*std.Io.Writer` instead of `anytype` | High | Closed | Changed to `anytype` in vector.zig |
| Q2 | network.zig doc comment coverage is ~7% | High | Closed | Added `///` doc comments to all public types and functions |
| Q3 | docs/README.md links to 5 nonexistent pages | Medium | Closed | Replaced dead links with links to actual docs |
| Q4 | examples/basic.zig does not import or use the library | Medium | Closed | Rewrote to import library and demonstrate all 5 type families |
| Q5 | Duplicate hex-digit parsers in network.zig | Medium | Closed (partial reopen → Q20) | Extracted shared `hexDigitToInt`; `hexDigitValue` and `Mac.hexVal` shims remain |
| Q6 | Identical branches in vector.zig format | Medium | Closed | Removed dead conditional branch |
| Q7 | Custom whitespace/comma helpers in geographic.zig | Medium | Closed | Replaced with `std.mem.trim`/`indexOfScalar`/`count` |
| Q8 | `Range.isEmpty` name is misleading | Medium | Closed | Renamed to `isPoint()` |
| Q9 | network.zig at 919 lines exceeds 800-line guideline | Low | Won't Do | File grew with doc comments; types cohesive |
| Q10 | Missing edge-case tests (IPv6 `::`, IPv4 leading zeros, URL userinfo) | Low | **Closed via Q33** (9e937b5) | Reopened with expanded coverage list; 16 new regression tests landed 2026-04-18 |
| Q11 | CI Zig version drift | Medium | **Closed via Q36** (3702dd1) | Reconciled to 0.16.0 across manifest/README/CI 2026-04-18 |
| Q12 | CI reinstalls Zig in every job | Medium | Won't Do | Requires custom Docker image; out of scope |
| Q13 | examples/basic.zig has no build step in build.zig | Low | Closed | Added `example` build step in build.zig |

---

## New findings (Q14–Q41), ranked by PriorityScore

PriorityScore = Impact (1-5) × Likelihood (1-5) × 4. Critical ≥ 80, High 60-79, Medium 40-59, Low < 40.

| Rank | Severity | PriorityScore | Category | Finding | Component | Issue | Fix Summary | Effort | Status |
|------|----------|--------------:|----------|---------|-----------|-------|-------------|--------|--------|
| 1 | Critical | 80 | testing/tooling | Q30: Fuzz suite broken on Zig 0.16 | `tests/fuzz.zig`, `build.zig:60-72` | [#26](https://gitlab.com/devnw/zig/advanced-types/-/work_items/26) | Port to 0.16 `std.testing.fuzz` API; nightly CI job | M | **Closed 2026-04-18** (c0e07ee) |
| 2 | High | 64 | docs | Q25: Url/Domain slice-lifetime contract undocumented | `src/types/url.zig:37-38, 147-158` | [#31](https://gitlab.com/devnw/zig/advanced-types/-/work_items/31) | Doc module + struct with alias-lifetime invariant; optional `clone` | S | **Closed 2026-04-18** (5c97228) |
| 3 | High | 64 | refactor/docs/security | Q26: Subnet pub-constructible with invalid prefix_len (= SAST-01) | `src/types/network.zig:419-423, 487` | [#28](https://gitlab.com/devnw/zig/advanced-types/-/work_items/28) | Add `init` validator + debug assert + doc update | S | **Closed 2026-04-18** (503c1f5) |
| 4 | High | 64 | docs/tooling | Q36: minimum_zig_version / README drift (reopens Q11) | `build.zig.zon:5`, `README.md:4,71` | [#34](https://gitlab.com/devnw/zig/advanced-types/-/work_items/34) | Reconcile manifest / badge / prose to 0.16.0 floor | S | **Closed 2026-04-18** (3702dd1) |
| 5 | Medium | 48 | refactor | Q17: Subnet.contains 6-deep nesting | `src/types/network.zig:461-506` | [#37](https://gitlab.com/devnw/zig/advanced-types/-/work_items/37) | Split v4/v6 paths into helpers; dispatcher becomes thin | M | **Closed 2026-04-18** (503c1f5) |
| 6 | Medium | 48 | refactor | Q15: Bracket-parser pattern repeated 5× | geographic/range/vector/network | [#38](https://gitlab.com/devnw/zig/advanced-types/-/work_items/38) | Extract `internal/parse.zig` iterator | M | **Closed 2026-04-18** (ca54cdb) |
| 7 | Medium | 48 | testing/tooling | Q31: No coverage instrumentation | `build.zig`, CI | [#40](https://gitlab.com/devnw/zig/advanced-types/-/work_items/40) | Wire kcov/llvm-cov; report-only (percentage gate deferred — see blockers doc) | M | **Closed (report-only) 2026-04-18** (20b233c) |
| 8 | Medium | 48 | testing | Q33: Missing edge-case tests (reopens Q10) | network.zig, url.zig | [#41](https://gitlab.com/devnw/zig/advanced-types/-/work_items/41) | IPv4 leading zeros, IPv6 `1::2::3`, URL userinfo, IDN, max/zero prefix | S | **Closed 2026-04-18** (9e937b5) |
| 9 | Low | 36 | docs | Q27: Integer-overflow semantics not hoisted to README | `vector.zig`, `range.zig` | — | Add "Optimize-mode semantics" README section | S | open |
| 10 | Low | 36 | testing | Q32: `//!` doc examples not compiled | `root.zig:11-17`, `vector.zig:13-21` | — | Convert to `test "doc-example-X"` blocks | S | open |
| 11 | Low | 32 | refactor | Q14: Duplicate tuple parsers in geographic.zig | `geographic.zig:106, 176, 285` | — | Extract `parseTuple(arity, input)` helper | S | open |
| 12 | Low | 32 | refactor | Q16: `Url.parse` 86-LOC single function | `url.zig:161-246` | — | Extract scheme / authority-path / host-port helpers | M | open |
| 13 | Low | 32 | docs | Q37: 6 undocumented `pub` decls in leaf modules | geographic/url/range | — | 1–3 line `///` per symbol | S | open |
| 14 | Low | 24 | refactor | Q18: `Ipv6Addr.format` 5-deep nesting | `network.zig:287-331` | — | Extract `longestZeroRun` | S | open |
| 15 | Low | 24 | refactor | Q19: `Ipv6Addr.parse` 5-deep nesting | `network.zig:190-234` | — | Factor `parseSides` helper | S | open |
| 16 | Low | 24 | refactor | Q20: Redundant hex-digit shims (Q5 partial reopen) | `network.zig:281-284, 560-562` | — | Inline callers to `hexDigitToInt`, delete shims | S | open |
| 17 | Low | 24 | refactor | Q23: Manual big-endian packing | `network.zig:59-74, 171-187` | — | Swap to `std.mem.readInt(.big)` / `writeInt(.big)` | S | open |
| 18 | Low | 24 | docs | Q28: `ParseError` type-name collision across modules | network/url/vector/geographic/range | — | Cross-reference doc; consider `root.zig` re-exports | S | open |
| 19 | Low | 24 | docs | Q29: `Vector.at` panics while `get` returns `?T` | `vector.zig:76-87` | — | Doc contract on `at` | S | open |
| 20 | Low | 24 | testing/tooling | Q34: No per-mode split / quick-test target | `build.zig:18-87` | — | Add `-Dtest-filter` forwarding + `test-quick` alias | S | open |
| 21 | Low | 24 | testing | Q35: `Range.span` wrap not tested at u64 max | `range.zig:85-87` | — | ReleaseFast-gated wrap test; optional `overflowingSpan` | S | open |
| 22 | Low | 24 | docs | Q38: README test-count drift (230 vs 272) | `README.md:14` | — | Update text; optionally build-generate | S | open |
| 23 | Low | 24 | docs | Q39: No module-level README / ARCH doc | `docs/ARCHITECTURE.md` (missing) | — | Add one-screen architecture overview | S | open |
| 24 | Low | 24 | docs | Q41: "Why" comments missing on non-obvious code | `network.zig:483-499`, `range.zig:181-182` | — | 1–2 line rationale per site | S | open |
| 25 | Low | 16 | refactor (accept) | Q22: `Ipv4Addr.parse` hand-rolls digit accumulation | `network.zig:77-110` | — | Benchmark first; if within 10%, simplify; otherwise document perf intent | S | open |
| 26 | Low | 16 | docs | Q40: No ADRs capturing key decisions | `docs/adr/` (missing) | — | Add 2–3 ADRs (zero-alloc contract, hand-rolled parsers, overflow policy) | S | open |
| 27 | Low | 8 | refactor | Q21: Redundant error-mapping shim `mapParseError` | `range.zig:140-145` | — | Delete shim; use direct error propagation | S | open |
| 28 | Low | 4 | accept | Q24: Vector/Range "giant" comptime bodies | `vector.zig:30`, `range.zig:20` | — | Accept — idiomatic Zig generic factories | — | accepted |

---

## Findings by category

- **Refactor (8):** Q14, Q15, Q16, Q17, Q18, Q19, Q20, Q21
- **Accept-with-rationale (3):** Q22, Q23 (optional), Q24
- **Doc-only (10):** Q25, Q27, Q28, Q29, Q36, Q37, Q38, Q39, Q40, Q41
- **Fix / test (7):** Q26, Q30, Q31, Q32, Q33, Q34, Q35

---

## Roadmap

### Quick wins (< 1 day)

- Q36 version-drift reconciliation
- Q20 hex-digit shim cleanup
- Q21 `mapParseError` removal
- Q37 undocumented `pub` decls
- Q38 README test-count update
- Q25 lifetime-contract doc
- Q27 README overflow-semantics section

### Medium (1–5 days)

- Q26 + Q17 together (same Subnet surface)
- Q30 fuzz-suite port to Zig 0.16
- Q15 shared bracket-tokens iterator
- Q14, Q16, Q18, Q19 refactors
- Q33 edge-case test additions
- Q32 doctest migration

### Strategic (> 5 days)

- Q31 coverage instrumentation + 85% CI gate
- Q39 + Q40 architecture doc + ADR set
- Q34 + Q35 build-system and mode-specific test harness

---

## Reconciliation with security tracker

- **Q26** ≡ **SAST-01** (security-reviewer High/OOB panic). Issue [#28](https://gitlab.com/devnw/zig/advanced-types/-/work_items/28) is the primary ticket. Any SAST-01 record in the security tracker must cross-reference #28; do not file a duplicate.
- Both Q26 and SAST-01 closed by commit `503c1f5` on 2026-04-18 (`Subnet.init` validator + `containsV4`/`containsV6` defensive helpers).

## Issue-creation audit

Issues filed (PriorityScore ≥ 40):

| Q | URL | PriorityScore |
|---|-----|---------------|
| Q30 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/26> | 80 |
| Q26 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/28> | 64 |
| Q25 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/31> | 64 |
| Q36 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/34> | 64 |
| Q17 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/37> | 48 |
| Q15 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/38> | 48 |
| Q31 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/40> | 48 |
| Q33 | <https://gitlab.com/devnw/zig/advanced-types/-/work_items/41> | 48 |

Issues skipped (PriorityScore < 40, tracked in ledger only): Q14, Q16, Q18, Q19, Q20, Q21, Q22, Q23, Q24, Q27, Q28, Q29, Q32, Q34, Q35, Q37, Q38, Q39, Q40, Q41 — 20 items.

Duplicates deferred to another tracker: 0 (Q26/SAST-01 filed here as primary; security-reviewer to reference #28).
