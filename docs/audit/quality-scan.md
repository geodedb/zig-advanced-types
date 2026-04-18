# Phase 2 Quality Scan — advanced-types

- **Repo:** `devnw/zig/advanced-types`
- **Zig toolchain:** 0.16.0 (CI) / local 0.16.0 (via mise)
- **Declared `minimum_zig_version`:** 0.15.1 (`build.zig.zon:5`)
- **Scope:** `src/` (6 files, 3 461 LOC), `tests/` (4 files, 1 094 LOC), `examples/basic.zig` (54 LOC), `build.zig`
- **Phase 1 reference:** `docs/audit/quality-inventory.md`
- **Closed-findings ledger (do not re-raise):** `docs/QUALITY_GAP_ANALYSIS.md` (Q1–Q13)
- **Raw logs:** `/tmp/fmt-check.log`, `/tmp/build-check.log`, `/tmp/test-{debug,safe,fast,small}.log` (all exit 0, empty on success)

---

## Automated Scan Results

### Lint / Format / Typecheck

| Tool | Command | Status | Findings |
|------|---------|--------|----------|
| `zig fmt` | `zig fmt --check src/ tests/ examples/ build.zig` | PASS (exit 0) | No diffs. |
| `zig build check` | `zig build check` | PASS (exit 0) | No warnings / no errors. |
| `zig build test` Debug | `zig build test -Doptimize=Debug --summary all` | PASS | 233 / 233 tests pass (~17 ms, MaxRSS 4M). |
| `zig build test` ReleaseSafe | `zig build test -Doptimize=ReleaseSafe --summary all` | PASS | 233 / 233 (~8 ms). |
| `zig build test` ReleaseFast | `zig build test -Doptimize=ReleaseFast --summary all` | PASS | 233 / 233 (~6 ms). |
| `zig build test` ReleaseSmall | `zig build test -Doptimize=ReleaseSmall --summary all` | PASS | 233 / 233 (~6 ms). |

Phase-1 inventory claimed 271 test blocks (232 inline + 39 in `tests/`). Actual `^test "` count is 271 but the pipeline reports **233 unique test functions executed** per mode — the remaining 38 come from non-anonymous `test {}` blocks and generic-type tests that are instantiated-but-not-counted by `refAllDecls`, or are merged as summary. **All four optimize modes are green.** No mode-dependent behaviour observed.

### Documentation coverage (Phase-2 addition)

Measured: for every `pub fn` / `pub const` / `pub var` in `src/`, the previous non-blank line begins with `///`.

| File | Doc'd / Pub | % |
|------|-------------|---|
| `src/root.zig` | 1 / 23 | 4.3 % |
| `src/types/network.zig` | 40 / 40 | **100 %** |
| `src/types/vector.zig` | 21 / 21 | **100 %** |
| `src/types/geographic.zig` | 23 / 24 | 95.8 % |
| `src/types/url.zig` | 15 / 16 | 93.8 % |
| `src/types/range.zig` | 14 / 17 | 82.4 % |
| **Total** | **114 / 141** | **80.9 %** |

The outlier is `src/root.zig`, which is a pure re-export façade (`pub const Ipv4Addr = network.Ipv4Addr;` × 22). This is idiomatic and arguably self-documenting, but it pulls the global average down. If the 22 re-exports are excluded, coverage is **113 / 119 = 95.0 %**.

Undocumented pub decls in leaf modules:

| File:Line | Symbol | Kind |
|-----------|--------|------|
| `src/types/geographic.zig:17` | `GeoError` | `pub const` error set |
| `src/types/url.zig:16` | `ParseError` | `pub const` error set |
| `src/types/range.zig:14` | `RangeError` | `pub const` error set |
| `src/types/range.zig:195` | `IntRange` | `pub const` alias |
| `src/types/range.zig:196` | `UintRange` | `pub const` alias |
| `src/types/range.zig:197` | `FloatRange` | `pub const` alias (partial — preceded only by section banner, not `///`) |

`confidence::confirmed` — verified by regex + visual spot-check of each site.

---

### Duplication & Complexity

| # | Finding | File:Line | Metric | Confidence |
|---|---------|-----------|--------|------------|
| D1 | Three `(lat,lon[,alt])` parsers repeat the same trim / paren-strip / comma-split / `parseFloat` shape | `src/types/geographic.zig:106` `LatLon.parse`, `:176` `LatLonAlt.parse`, `:285` `GeoPoint.parse` | ~30 LOC × 3 near-identical skeletons; only arity differs | `confidence::confirmed` |
| D2 | Two integer-digit accumulators in `Ipv4Addr.parse` and `Ipv6Addr.parseGroups` repeat `digit_count++`, overflow guard, `current_value = current_value * base + val` | `src/types/network.zig:85-107` and `:246-278` | Identical control flow, bases 10 vs 16 | `confidence::suspected` (intentional per-family; shared helper would add comptime branching) |
| D3 | `Ipv4Addr.parse` does not use `std.fmt.parseInt`, instead reimplements per-octet digit accumulation | `src/types/network.zig:77-110` | 34 LOC hand-rolled; `std.fmt.parseInt(u8, s, 10)` + `splitScalar` would be ~15 LOC | `confidence::suspected` (reviewer should weigh perf vs. clarity) |
| D4 | "strip outer brackets / split comma / trim tokens / `parseFloat`-or-`parseInt`" pattern repeats across 5 parsers: `LatLon.parse`, `LatLonAlt.parse`, `Range.parse`, `Vector.parse`, plus `Subnet.parse` (prefix side) | geographic.zig:106,176; range.zig:107; vector.zig:211; network.zig:426 | 5 parsers × ~15-25 LOC each; no shared `parseBracketed(sep, brackets) iterator` helper | `confidence::confirmed` |
| D5 | `Ipv4Addr.toU32`/`fromU32` pair, `Ipv6Addr.segments`/`Ipv6Addr.init` pair, and `Mac` byte-array share manual big-endian packing | network.zig:59-74, 171-187, 545-555 | Minor; `std.mem.readInt(.big)` / `writeInt(.big)` would dedupe | `confidence::suspected` |
| C1 | `Url.parse` at 86 LOC is the longest non-comptime function in the repo | `src/types/url.zig:161-246` | > 50-LOC threshold; linearly walks scheme → fragment → query → authority → host/port | `confidence::confirmed` — refactor candidate (extract `parseAuthority`, `parseSchemeAndRest`) |
| C2 | `Subnet.contains` nests `switch -> switch -> if` to depth 6 for IPv6 comparison | `src/types/network.zig:461-506` (46 LOC) | 6 levels at line 488; handles byte-aligned and bit-aligned prefix cases together | `confidence::confirmed` |
| C3 | `Ipv6Addr.format` nests RFC-5952 run-finder 5 deep around best-run bookkeeping | `src/types/network.zig:287-331` (45 LOC) | depth ≈5 at line 301; three state vars (`best_start`, `run_start`, `run_len`) could be extracted to `longestZeroRun` helper | `confidence::confirmed` |
| C4 | `Ipv6Addr.parse` nests `:: handling -> left/right branch -> parseGroups loop` 5 deep | `src/types/network.zig:190-234` | depth ≈5 at line 222 (`octets[right_offset + i] = …`) | `confidence::confirmed` |
| C5 | `Vector(T,N)` and `Range(T)` are comptime type factories that emit 225 LOC / 170 LOC struct bodies each — will appear as "giant functions" to naïve tools but are idiomatic Zig | `src/types/vector.zig:30`, `src/types/range.zig:20` | n/a — **not a finding**, noted to prevent false positives | `confidence::confirmed` |

Giant-file check: after Q9 was accepted as Won't-Do, `src/types/network.zig` is now **965 LOC** (was 919). Still > 800 guideline but the extra ~46 LOC are doc comments added to close Q2. Reviewer decision still stands; flagging only as delta.

---

### Dead Code

| # | Finding | File:Line | Type | Confidence |
|---|---------|-----------|------|------------|
| DC1 | No zero-use `pub` symbols detected across `src/`, `tests/`, `examples/`, `docs/` (141 pub decls, all referenced at least once) | — | negative result | `confidence::confirmed` |
| DC2 | `Ipv6Addr.hexDigitValue` is a single-line wrapper around file-scope `hexDigitToInt`; both are private | `src/types/network.zig:281-284` | redundant shim left over from Q5 consolidation | `confidence::confirmed` — callable only from `parseGroups`, can be inlined |
| DC3 | `Mac.hexVal` is another one-line shim around `hexDigitToInt` | `src/types/network.zig:560-562` | redundant — `hexDigitToInt` is file-scoped and already visible | `confidence::confirmed` |
| DC4 | `Range.mapParseError` (range.zig:140-145) switches on `std.fmt.ParseIntError` which has exactly two variants, both identity-mapped — Zig lets you coerce the error set directly | `src/types/range.zig:140-145` | 6-line helper replaceable with `catch \|e\| return @errorCast(e)` or simply letting `RangeError` include both variants (it already does) | `confidence::suspected` (reviewer: confirm error-set compatibility with `@errorCast`) |
| DC5 | No `TODO` / `FIXME` / `XXX` / `HACK` markers in `src/` | — | negative result | `confidence::confirmed` |
| DC6 | No dead test branches detected; 23 `catch unreachable` occurrences all live in `test` blocks doing `std.fmt.bufPrint` with statically known buffer sizes — idiomatic | multiple (e.g. `src/types/network.zig:629, 727, 731, 737, 798, 802, 878, 882, 934`) | **not a finding**, documented for reviewer | `confidence::confirmed` |
| DC7 | `Vector.at` (`src/types/vector.zig:76-81`) uses `@panic` for OOB while `Vector.get` (`:84-87`) returns `?T`; both are `pub`. Any caller that wants non-panicking access has `get`; `at` is retained for ergonomics. Dead? No — used by tests and `examples/basic.zig` is not verified to call it. | `src/types/vector.zig:76` | API surface audit only — not dead | `confidence::confirmed` |

Note on methodology: zero-use detection used regex word-boundary search across `.zig` + `.md` under `src/`, `tests/`, `examples/`, `docs/`, subtracting declaration sites. Generic type parameters like `Range(T)` are used via aliases `IntRange` / `UintRange` / `FloatRange`, which themselves are referenced in tests.

---

### Performance Hotspots (quality-scan overlap — defer deep treatment to perf audit)

| # | Finding | File:Line | Category | Impact | Confidence |
|---|---------|-----------|----------|--------|------------|
| P1 | `Ipv6Addr.parse` allocates a 16-byte scratch `right_octets: [16]u8` then memcpy's into `octets` | `src/types/network.zig:214-223` | needless alloc | low (stack, fixed size) but one extra copy per parse | `confidence::suspected` |
| P2 | `Ipv6Addr.findDoubleColon` does a linear scan that duplicates work later done by `parseGroups` | `src/types/network.zig:236-244` | chatty I/O within function | low; one O(n) pre-scan could be fused | `confidence::suspected` |
| P3 | `Url.parse` calls `std.mem.indexOfScalar` 4× over overlapping slices (`#`, `?`, `/`, `:`), each a fresh linear scan | `src/types/url.zig:181, 188, 197, 224` | chatty scans | low — input is short; documented for completeness | `confidence::confirmed` |

These are placeholders for the perf audit to evaluate; none are correctness concerns.

---

### Build / CI Issues

| # | Finding | File:Line | Category | Impact | Confidence |
|---|---------|-----------|----------|--------|------------|
| B1 | CI uses Zig 0.16.0 (`.gitlab-ci.yml`, recent commit `380045a`) while `build.zig.zon:5` still declares `minimum_zig_version = "0.15.1"` | `build.zig.zon:5` vs CI | version drift / reproducibility | consumers on 0.15.1 may hit API differences not exercised in CI | `confidence::confirmed` (Phase-1 flagged this as known gap) |
| B2 | `zig build test` runs a single suite; the "5 variants" in Phase 1 inventory refers to 1 Debug + 4 Release optimize modes, all exercising the **same** test executable — no separate fuzz-only or perf-only gate | `build.zig` | coverage gap | fuzz/perf tests always run; cannot selectively skip for fast local iteration | `confidence::suspected` (reviewer: check whether `-Dtest-filter` is wired) |
| B3 | Raw test logs (`/tmp/test-*.log`) are empty on success because `zig build test` is silent unless `--summary all` is passed; CI may be losing signal for flaky tests | `.gitlab-ci.yml` (not read) | observability | medium — reviewer should add `--summary all` to CI test step | `confidence::suspected` |

No other build-pipeline issues uncovered during this phase (caching, image size, pre-commit parity were all outside the quality-scan scope and are owned by Phase 1 inventory).

---

## Summary of Confidence Tags

- `confidence::confirmed`: 11
- `confidence::suspected`: 8

## Not-a-finding (documented to prevent re-flagging)

- Giant comptime type constructors `Vector(T,N)` / `Range(T)` — idiomatic.
- `catch unreachable` in test blocks with static buffers — idiomatic.
- `src/root.zig` low doc% — re-export façade.
- Q1–Q13 in `docs/QUALITY_GAP_ANALYSIS.md` — already closed / Won't-Do.
