# Quality Review — advanced-types

Phase 3 of `/codepros:audit`. Deep readability / maintainability / API-contract /
reliability / documentation review. Read-only.

- **Repo:** `/home/benji/src/devnw/zig/advanced-types`
- **HEAD at review:** `f3adc69`
- **Zig floor:** `0.16.0` (`build.zig.zon:5`, `.gitlab-ci.yml:27`)
- **Inputs:** `docs/audit/quality-inventory.md`, `docs/audit/quality-scan.md`,
  `docs/QUALITY_GAP_ANALYSIS.md`
- **Prior closures honoured (not re-raised):** Q1–Q13, Q15, Q17, Q25, Q26, Q30,
  Q31, Q33, Q36, SAST-01
- **Not re-raised (accepted):** Q22, Q23, Q24
- **Scope:** `/src/**/*.zig`, `/tests/**/*.zig`, `/README.md`, `/docs/**/*.md`,
  public-surface and error-set consistency across modules.

Every finding carries a stable Q-ID. IDs reused from
`docs/QUALITY_GAP_ANALYSIS.md` when the defect is unchanged; new IDs (`Q42+`)
introduced for genuinely new findings. Confidence labelled per task brief.

---

## Executive Summary

Codebase is in a solid state post `f3adc69`. All Zig-toolchain gates are green;
the top-5 tracker risks are closed. Remaining work is bounded:

- **0 Critical.** No unresolved panics / UB / contract breaks.
- **0 High in product code.** The two High-severity issues raised here
  (Q42 README drift, Q44 `pretty-format-yaml` breakage) are docs / tooling.
- Medium-severity work centres on three clusters: **readability splits**
  (`network.zig` file size Q45 / ex-Q9, `Url.parse` Q16, `Ipv6Addr.parse/format`
  Q18/Q19), **code duplication cleanup** (Q20 hex shims, Q43 fuzz wrappers),
  and **doc-drift** (Q37 undocumented decls, Q40 ADRs, Q39 architecture).
- Reliability enablers are in good shape. All `@panic` / `catch unreachable`
  sites are either documented contracts (`Vector.at`, paired with `get`) or
  inside `test` blocks with trivially-sized buffers. `@intCast` sites are all
  range-guarded. `Subnet.contains` now has defensive out-of-range branches
  (Q26 / SAST-01 closed).

### Findings by severity (this pass)

| Tier | Count | Q-IDs |
|------|------:|-------|
| Critical | 0 | — |
| High | 2 | **Q42** (new — README stale-claim), **Q44** (new — `.cz.yaml` format) |
| Medium | 7 | Q16, Q18, Q19, Q20, **Q43** (new), **Q45** (new — ex-Q9 reopen), **Q46** (new) |
| Low | 11 | Q14, Q27, Q28, Q29, Q32, Q34, Q35, Q37, Q39, Q40, Q41 |

`Q42`, `Q43`, `Q44`, `Q45`, `Q46` are minted this review.

---

## Status Migrations Since `f3adc69`

| Q-ID | Prior status | New status (this review) | Reason |
|------|--------------|--------------------------|--------|
| Q9 | Won't Do (2024) | **Reopen as Q45** (file crossed 800-LOC guideline; extraction mechanical) | `src/types/network.zig` is 1,166 LOC per scan; Ipv4/Ipv6/Subnet/Mac are five orthogonal types with zero cross-coupling other than `hexDigitToInt` + `ParseError` (`quality-scan.md §3`). |
| Q16 | Open / Low (32) | Open / Medium (48) | Scan re-measured `Url.parse` at 108 LOC (prior estimate 86); now the single largest function in the codebase. |
| Q20 | Open / Low (24) | Open / Medium (40) | Paired with Q43 (shared "wrapper-that-wraps-nothing" pattern); remove together in one mechanical commit. |
| Q38 | Open / Low (24) | **Superseded by Q42 (High)** | README asserts "262 Tests" and "fuzz suite currently broken under Zig 0.16" — both stale (actual 302+; Q30 closed `c0e07ee`). Severity raised because the claim actively misdirects adopters. |
| Q30 | Closed 2026-04-18 | Closed — **verify README callout removed as part of Q42** | Close evidence in place; README callout must go. |
| Q31 | Closed (report-only) | Unchanged | Coverage wired; threshold gate explicitly deferred in `gap-close-blockers.md`. |

All other prior IDs retain their state in the tracker.

---

## Readability & Maintainability

| Q-ID | Finding | File:Line | Root Cause | Impact | Severity | Confidence |
|------|---------|-----------|------------|--------|----------|------------|
| **Q45** (reopens Q9) | `network.zig` is 1,166 LOC; Ipv4Addr / Ipv6Addr / IpAddr / Subnet / Mac are five independent types sharing only `hexDigitToInt` and `ParseError`. | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:1-1166` (section banners at :37, :174, :426, :476, :603) | Historical one-file-per-domain policy; types are now independently evolvable. | Reviewer burden, unnecessary recompile churn, git-blame noise, hot-spot concentration (top-2 churn after `.gitlab-ci.yml`). | Medium | confidence::confirmed |
| **Q16** | `Url.parse` is 108 lines of sequential stages (scheme → fragment → query → authority → userinfo → host/port → validation) in one function. | `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig:190-297` | Parser grew stage-by-stage during hardening (SAST-05, SAST-07, NEW-01) without being split. | High per-stage review burden; any new rule (IDN etc.) will push past 120 LOC; boundaries already commented, so extraction is low-risk. | Medium | confidence::confirmed |
| **Q18** | `Ipv6Addr.format` is 45 LOC with a 5-deep nested loop for longest-zero-run inlined into the serializer. | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:311-355` | RFC-5952 canonicalisation requires a 2-pass algorithm; both inlined. | Readability only. Extracting `longestZeroRun(segs) -> ?struct{start, len}` reduces the write loop to ~8 lines. | Medium | confidence::confirmed |
| **Q19** | `Ipv6Addr.parse` mixes left/right split, per-side parsing, and offset-placement in one 45-LOC function. | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:214-258` | Original expedient flow. | Moderate. `parseSides(input)` + `placeRight(right_octets, right_count, into)` flattens to ~18 LOC. | Medium | confidence::confirmed |
| **Q20** | `hexDigitValue` (`network.zig:305`, returns `?u32`) and `Mac.hexVal` (`network.zig:643`, returns `?u8`) each wrap `hexDigitToInt` with nothing more than a cast / identity. Dead-weight shims. | `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig:305-308,643-645` | Leftover after Q5 extraction; caller-site types were never widened. | No functional impact but adds cognitive load ("why are there three hex decoders?") and lint false-positives in future static analysers. | Medium | confidence::confirmed |
| **Q43** (new) | `tests/fuzz.zig` has **ten** near-identical wrapper functions, each 3 lines of body (`takeSlice`, `_ = Type.parse(input) catch return`). | `/home/benji/src/devnw/zig/advanced-types/tests/fuzz.zig:44-154` | Each parser exported as a distinct fuzz target; boilerplate not deduplicated. | Every new parser doubles this pattern. A `comptime` generic cuts the file from 154 → ~60 LOC. | Medium | confidence::confirmed |
| **Q46** (new) | `Url.parse` constructs an empty path via `input[scheme_end + 3 + rest.len .. scheme_end + 3 + rest.len]` (line 231). Opaque slicing. | `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig:229-232` | Preserves "slice-into-input" invariant against the Q25 lifetime contract — a legitimate but unexplained reason. | Readability-only; the expression is correct. A 1-line "why" comment or a named helper `emptyAt(input, pos)` would make intent obvious. | Low | confidence::suspected |
| Q14 | Magic literals (`180.0`, `-180.0`, `90.0`, `-90.0`, `math.pi / 180.0`) recur across geographic validators and haversine math. `earth_radius_m` is a named constant but degree bounds / deg-to-rad factor are not. | `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig:100,103,128,180,183,328,379` | Local-scope pragmatism. | Readability; a single `deg_to_rad` constant removes a minor foot-gun if the factor is ever "optimised". | Low | confidence::suspected |
| Q41 | "Why" comments missing on non-obvious sites. `range.zig:181-182` still lacks a rationale for the `a.upper < math.maxInt(T)` overflow-guard. | `/home/benji/src/devnw/zig/advanced-types/src/types/range.zig:181-184` | Iterative refactors didn't re-comment invariants. | Small readability gain; not a defect. | Low | confidence::suspected |
| Q28 | Five modules each define their own error set (`ParseError` in network/url/vector, `RangeError`, `GeoError`). Cross-module `catch \|err\|` cannot be polymorphic. | `network.zig:29`, `url.zig:16`, `vector.zig:26`, `range.zig:14`, `geographic.zig:17` | Intentional per-module error set (good taste); undocumented cross-module. | Moderate consumer friction. Either (a) doc comment in `root.zig` listing all five sets, or (b) `root.zig` re-export group `pub const errors = struct { ... };`. | Low | confidence::suspected |

### Root-cause Analyses and Remediation Sketches

**Q45 (network.zig split).** Move each of Ipv4Addr / Ipv6Addr / Subnet / Mac
into its own file under `src/types/network/`; keep `network.zig` as a 30-LOC
aggregator that re-exports and owns `hexDigitToInt` + `ParseError`. Tests move
with their type. Verify: `zig build test --summary all`, `zig build check`,
`zig fmt --check`. No public-surface change because `root.zig` imports via
`types/network.zig`.

**Q16 (Url.parse split).** Extract in-place while keeping the outer function as
the pipeline:

```zig
fn parseScheme(input) !struct{ scheme, rest };
fn splitFragmentQuery(rest) struct{ rest, query, fragment };
fn splitAuthorityPath(rest, scheme_end, input) struct{ authority, path };
fn parseHostPort(host_part) !struct{ host, port };
fn validateHost(host) !void;
```

Verify: existing test suite; `Url.parse` should shrink to ~25 LOC.

**Q18 / Q19 (Ipv6Addr).** Straight factoring; helpers remain `fn`-private.
No behaviour change.

**Q20 (hex shims).** Update the two call sites (`network.zig:285`, `:635-636`)
to call `hexDigitToInt` directly. For `Ipv6Addr.parseGroups`, widen the capture
type inline (`const val = hexDigitToInt(ch) orelse return error.InvalidCharacter;`).
Delete `hexDigitValue` (line 305) and `hexVal` (line 643). Net: -10 LOC.

**Q43 (fuzz wrappers).** Replace the ten wrapper-pairs with:

```zig
fn parserFuzzer(comptime Parser: type) fn(void, *std.testing.Smith) anyerror!void {
    return struct {
        fn run(_: void, smith: *std.testing.Smith) !void {
            var buf: [max_input_len]u8 = undefined;
            const input = takeSlice(smith, &buf);
            _ = Parser.parse(input) catch return;
        }
    }.run;
}
test "fuzz Ipv4Addr.parse" { try std.testing.fuzz({}, parserFuzzer(types.Ipv4Addr), .{}); }
// ... nine more one-line tests
```

Verify: `zig build test --summary all`; ten targets still enumerated.

---

## API & Contract Consistency

| Q-ID | Finding | File:Line | Root Cause | Impact | Severity | Confidence |
|------|---------|-----------|------------|--------|----------|------------|
| Q29 | `Vector.at` panics on OOB while `Vector.get` returns `?T`. Contract is in the method doc comment (`vector.zig:75`) but the panic path is not mentioned in the top-level module header. | `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig:76-81,84-87` | Historical pair of access methods. | Release-mode loops picking `at` may panic in prod. Recommend a top-of-file "Panics" table in the `//!` header. | Low | confidence::confirmed |
| Q28 | See readability table — also a contract concern. | — | — | — | Low | confidence::suspected |
| Q37 | Undocumented `pub` decls: `DomainLabelIterator` (`url.zig:133`), `DomainLabelIterator.next` (`url.zig:138`), `Range.initUnchecked` (`range.zig:40`), `LatLon.initUnchecked` / `LatLonAlt.initUnchecked` (`geographic.zig:110,191`). | 3 files | Q2 pass added doc comments to the majority but missed `*Unchecked` constructors and the public iterator type. | Adopter confusion; silent drift once doc HTML is generated. | Low | confidence::confirmed |
| Q35 | `Range.span` documents wrap-in-ReleaseFast but there is no `ReleaseFast`-gated test at `u64` max (or any integer boundary). | `/home/benji/src/devnw/zig/advanced-types/src/types/range.zig:85-87` | Overflow behaviour depends on build mode; default test runs are Debug/ReleaseSafe. | Contract is asserted in prose but never exercised. Add a test guarded by `@import("builtin").mode == .ReleaseFast`, or provide an `overflowingSpan` variant. | Low | confidence::suspected |

### Error-set Audit (Checklist Item)

Reviewed each module's error set for consistency and implementation-detail
leakage:

| Module | Error set | Names | Concerns |
|--------|-----------|-------|----------|
| `network.zig:29` | `ParseError` | `InvalidCharacter`, `InvalidFormat`, `InvalidLength`, `InvalidPrefix`, `Overflow` | Clean. |
| `url.zig:16` | `ParseError` | `InvalidCharacter`, `InvalidFormat`, `EmptyInput`, `InvalidScheme`, `InvalidPort`, `InvalidHostChar`, `InvalidDomain`, `MissingHost` | `EmptyInput` is the only "kind" mismatch (other modules return `InvalidFormat` for empty input). Consider aligning across modules. Low-churn, high-value consistency fix — tracked under Q28. |
| `vector.zig:26` | `ParseError` | `InvalidCharacter`, `InvalidFormat`, `InvalidDimension`, `Overflow` | Clean. |
| `range.zig:14` | `RangeError` | `InvalidBounds`, `InvalidFormat`, `InvalidCharacter`, `Overflow` | Clean; `RangeError` naming intentional to keep init errors ≠ parse errors. |
| `geographic.zig:17` | `GeoError` | `LatitudeOutOfRange`, `LongitudeOutOfRange`, `InvalidFormat`, `InvalidCharacter` | Clean. |

No implementation-detail leakage observed across any module. Zero mappings to
`std.fmt.ParseFloatError` or `std.fs.File.OpenError` escape through public
surface.

### Public-type Docstring Completeness

| Type | Docstring | Examples in `//!`? |
|------|-----------|---------------------|
| `Ipv4Addr`, `Ipv6Addr`, `IpAddr`, `Subnet`, `Mac` | Present on all `pub fn` and `pub const`. | No per-type examples; module header has none. |
| `Url`, `Domain` | `Url` has a full lifetime + security block (Q25 close); `Domain` has lifetime block. | No. |
| `DomainLabelIterator` | **Undocumented struct + `next`** (Q37). | No. |
| `Vector`, `VectorF32`, `VectorI32` | Doc comments per method; module header has a usable Quick-Start code fence. | Yes, but fence is **not compiled** (Q32). |
| `LatLon`, `LatLonAlt`, `GeoPoint` | Doc comments per method; `initUnchecked` undocumented (Q37). | No. |
| `Range`, `IntRange`, `UintRange`, `FloatRange` | Doc comments on all `pub`; `initUnchecked` undocumented (Q37). | No. |

Recommend pairing a `test "doc-example-<type>"` block per Quick-Start fence to
lock documentation against code drift. Tracked under Q32.

---

## Reliability Enablers

| Q-ID | Finding | File:Line | Root Cause | Impact | Severity | Confidence |
|------|---------|-----------|------------|--------|----------|------------|
| Q32 | `//!` doc-comment code examples in `root.zig:11-17` and in every module header are never compiled. README fences likewise. | `/home/benji/src/devnw/zig/advanced-types/src/root.zig:11-17`, `src/types/vector.zig:13-21`, `README.md` | Zig has no built-in doctest; examples live only as markdown. | Silent drift. Proven risk — Q38 / Q42 shows docs *can* lag reality. | Low | confidence::confirmed |
| Q34 | No `-Dtest-filter` forwarding and no `test-quick` convenience target. Contributors run the full matrix per iteration. | `/home/benji/src/devnw/zig/advanced-types/build.zig:18-87` | Build graph exposes test steps but no filter option. | Developer ergonomics only — not a defect. | Low | confidence::confirmed |
| Q35 | See API section — reliability lens. | — | — | — | Low | confidence::suspected |

### Invariants & Panics Checklist

- `@panic`: only `Vector.at` (`vector.zig:78`), contract documented, paired
  with non-panicking `get` sibling. Confirmed acceptable.
- `catch unreachable`: 22 occurrences, all inside `test` blocks with 17 to
  512-byte buffers against format strings that demonstrably fit. Confirmed
  via `quality-scan.md §5`.
- `std.debug.assert`: single occurrence at `network.zig:563`; invariant
  documented inline (Q26 close).
- `@intCast`: 16 call sites in `network.zig`, each preceded by an explicit
  range guard (mask, modulo, or prior validation). Confirmed safe.
- `@truncate` / `@ptrCast` / `@alignCast` / `@bitCast`: **none** in `src/`.
  Library is free of unsafe reinterpretation.
- `Subnet.contains` defensive out-of-range branches (Q26 / SAST-01 close).
  Reviewed both family branches; neither touches `@intCast` after the guard.
  Test at `network.zig:1060-1074` covers both families.
- `Url.parse` rejects leading-zero ports, userinfo-smuggling, control bytes,
  and angle-bracket / quote / backslash bytes. Tests at `url.zig:714-783`
  confirm green.

### Test-quality Flags (from scan — not re-raised as new IDs)

- `tests/fuzz.zig` has no `testing.expect*` by design (crash-only invariant).
  Acceptable; one-sentence explainer would help. Absorbed into Q43.
- `tests/integration.zig:20-47` is compile-time smoke (`_ = lib.Type;` × 17);
  documented shallow. Recommend pairing with one real call per type.
- `tests/performance.zig` is mis-named (a large-table parser regression
  suite, not a timing suite). Rename to `tests/parser_bulk.zig` or add
  real timing assertions. Absorbed into Q34.

---

## Documentation Gaps

| Q-ID | Finding | File:Line | What's Missing | Impact | Severity | Confidence |
|------|---------|-----------|----------------|--------|----------|------------|
| **Q42** (new — supersedes Q38) | `README.md` line 14 claims "**262 Tests**" and "fuzz suite currently broken under Zig 0.16 -- see GAP-0020". Both stale: actual is 302+ declarations; Q30 / GAP-0020 closed in `c0e07ee`. | `/home/benji/src/devnw/zig/advanced-types/README.md:14` | Update count; remove the fuzz-broken warning. Add CI check to flag the stale string. | **High** — actively misleads adopters evaluating the library. | High | confidence::confirmed |
| **Q44** (new) | `.cz.yaml` disagrees with `pretty-format-yaml` hook; `pre-commit run --all-files` modifies 14 lines on every clean checkout (`quality-scan.md §1`). | `/home/benji/src/devnw/zig/advanced-types/.cz.yaml` | Land the hook's diff **or** add `.cz.yaml` to the hook's exclude list with a rationale. Current state blocks pre-commit from ever being green. | **High** for contributor ergonomics. | High | confidence::confirmed |
| Q27 | Integer-overflow semantics documented in `root.zig:19-25` and `README.md:69-89` but per-method doc comments on `Vector.add/sub/scale/dot` only mention the semantics in a shared sentence, and `Range.span` references only "README.md" without an inline summary. | `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig:106-138` | Per-method "see README" would be enough, or a single `//! Panics / Overflow` block per module header. | Users reading only the method doc will miss the contract. | Low | confidence::confirmed |
| Q37 | Undocumented `pub` decls (see API table above). | 3 files | 1–3 line `///` per symbol. | Doc HTML drift. | Low | confidence::confirmed |
| Q39 | No `docs/ARCHITECTURE.md` or module-level README under `src/types/`. | `docs/ARCHITECTURE.md` missing | Module graph, zero-allocation contract, overflow-semantics policy, fuzz policy. | Onboarding friction. | Low | confidence::confirmed |
| Q40 | No ADRs capturing zero-allocation contract, hand-rolled parsers decision, overflow policy, or the deliberate overlap with `uri` (AT-REQ-004). `docs/adr/` absent. | `docs/adr/` missing | 3 short ADRs. | Decisions are recoverable from commit history but not discoverable. | Low | confidence::confirmed |
| Q41 | See readability — same finding. | — | — | — | Low | confidence::suspected |
| — | `markdownlint` 7 issues (quality-scan §2) — 4 × MD034 bare URLs, 2 × MD040 missing fenced language, 1 × MD032 list-blankline, 1 × MD056 table-column-count. Trivial; absorb into Q42 / Q44 docs-cleanup pass. | See `quality-scan.md §2` | — | Low | — | confidence::confirmed |

### Remediation Sketches (docs)

- **Q42:** single-commit fix.
  - `README.md:14` → replace with an accurate line (e.g. `**302+ Tests**`)
    and remove the GAP-0020 warning.
  - Optional CI check: `grep -q 'currently broken' README.md && exit 1`.
  - Verify: `pre-commit run --all-files`; open `README.md` and confirm both
    strings are gone.
- **Q44:** run `pre-commit run pretty-format-yaml --all-files` and commit the
  result, **or** add `.cz.yaml` to the hook's `exclude` list with rationale.
  Prefer the former; the diff is mechanical.
- **Q37 / Q40:** batched docstring pass; three ADRs
  (`adr/0001-zero-alloc.md`, `adr/0002-hand-rolled-parsers.md`,
  `adr/0003-overflow-policy.md`).

---

## Findings Summary Table

| Rank | Q-ID | Severity | Category | Status |
|-----:|------|----------|----------|--------|
| 1 | **Q42** | High | docs | new — file issue |
| 2 | **Q44** | High | tooling | new — file issue |
| 3 | **Q45** (reopens Q9) | Medium | refactor | migrated — file issue |
| 4 | Q16 | Medium | refactor | elevated |
| 5 | **Q43** | Medium | tests/refactor | new |
| 6 | Q20 | Medium | refactor | elevated |
| 7 | Q18 | Medium | refactor | open |
| 8 | Q19 | Medium | refactor | open |
| 9 | **Q46** | Low | readability | new |
| 10 | Q32 | Low | testing | open |
| 11 | Q27 | Low | docs | open |
| 12 | Q37 | Low | docs | open |
| 13 | Q39 | Low | docs | open |
| 14 | Q40 | Low | docs | open |
| 15 | Q28 | Low | docs | open |
| 16 | Q29 | Low | api | open |
| 17 | Q35 | Low | testing | open |
| 18 | Q14 | Low | refactor | open |
| 19 | Q34 | Low | tooling | open |
| 20 | Q41 | Low | docs | open |

### Verification Steps Per Cluster

| Cluster | Q-IDs | Commands |
|---------|-------|----------|
| Refactor `network.zig` split | Q45, Q18, Q19, Q20 | `zig fmt --check src/`, `zig build check`, `zig build test --summary all`, `zig build test-integration`, `zig build test-parser-edges`, `zig build test-performance`, `zig build example` |
| Refactor `Url.parse` | Q16, Q46 | same as above (parser tests cover all stages) |
| Fuzz dedup | Q43 | `zig build test --summary all`; ensure 10 fuzz test names still enumerated |
| Docs cleanup | Q42, Q44, Q37, Q27, Q39, Q40 | `pre-commit run --all-files`; `zig build` (docs examples, once Q32 is closed) |

---

## Handoff Notes

- **quality-issue-tracker:** file **Q42** and **Q44** as High
  (PriorityScore ≥ 60) — both are user- or contributor-facing drift. File
  **Q45** as Medium (PriorityScore 48) with explicit "reopens Q9" link.
  **Q43** and **Q46** are Medium / Low ledger-only.
- **gap-sync:** status-migration table above is authoritative for this pass.
  Q38 should be marked **superseded-by-Q42** rather than closed.
- **unified-audit-summary:** top blockers are doc-drift (Q42) and
  `.cz.yaml` / pre-commit disagreement (Q44). Both fix in under 30 minutes.
  After that, the codebase has no gating quality defects.

---

## Confidence Summary

Every finding carries an explicit `confidence::confirmed` or
`confidence::suspected` tag against its row. Confirmed items are directly
observable in source or in tool output captured in `quality-scan.md`;
suspected items are stylistic / ergonomics calls where remediation is
opinionated.
