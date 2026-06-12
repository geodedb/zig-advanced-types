# GAP Analysis

Last updated: 2026-06-11 (post audit-iteration-1 fixes, branch `audit/iteration-1-fixes`)

Repository status: types implemented from spec; Geode source not yet wired as consumer. Open gaps below; closed items live in [GAP_ANALYSIS_RESOLVED.md](GAP_ANALYSIS_RESOLVED.md).

## Goal

Create one reusable package for portable value types currently embedded in Geode:

- network types
- vector types
- geographic types
- URL/domain types
- generic ranges

## Intended Boundary

Move into this library:

| Geode source | Why it belongs here |
|---|---|
| `src/types/network.zig:5`, `:6`, `:7`, `:21`, `:70`, `:140` | Reusable IP/subnet/MAC types and helpers |
| `src/types/vector.zig:8`, `:19`, `:50`, `:67`, `:315`, `:374` | Portable vector value types and distance operations |
| `src/types/geographic.zig:8`, `:22`, `:69`, `:167`, `:277`, `:380`, `:511`, `:552`, `:688` | Core geographic values plus useful spatial helpers |
| `src/types/url.zig:3`, `:16`, `:88`, `:151`, `:159` | Generic URL and domain parsing/formatting |
| `src/types/range.zig:3`, `:40`, `:57`, `:73`, `:124`, `:125` | Generic range support and common aliases |

Keep in Geode for now:

| Geode source | Why it stays |
|---|---|
| `src/types/hash.zig:4`, `:5`, `:6`, `:18` | This file aliases storage/heap-defined hash types and is not yet cleanly independent |

## Concrete Gaps

| Gap | Status | Decision / Resolution |
|---|---|---|
| URL/domain logic overlaps the existing external `uri` dependency | **Closed** | `Url` and `Domain` stay in `advanced-types` as standalone value types. `uri` remains the RFC 3986 parser — no overlap. `Url` provides simplified parsing for the value-type use case; `Domain` validates domain names. No dependency on `uri`. |
| `hash.zig` is still tied to Geode internals | **Won't Do** | Left in Geode. Not a portable value type — aliases heap/storage types. May be split into a dedicated package later. |
| Geographic file mixes simple value types with a large helper surface | **Closed** | Core types only: `LatLon`, `LatLonAlt`, `GeoPoint` with essential ops (haversine, validation, parsing). `st_*` query helpers are query-layer concerns — staged for a later release. |
| `range.zig` depends on local date support | **Closed** | `DateRange` trimmed. Ships `Range(T)` generic plus `IntRange`, `UintRange`, `FloatRange` aliases. `DateRange` can be added when a date/datetime package is available. |

## Implemented Public API

All types are exported from `src/root.zig`:

| Type | Module | Description |
|---|---|---|
| `Ipv4Addr` | `network` | IPv4 address (parse, format, classify, u32 roundtrip) |
| `Ipv6Addr` | `network` | IPv6 address (parse with `::`, format, classify, v4-mapped detection) |
| `IpAddr` | `network` | Tagged union of v4/v6 with auto-detecting parse |
| `Subnet` | `network` | CIDR notation with `contains` check |
| `Mac` | `network` | MAC address (colon/hyphen parse, classify) |
| `VectorF32` | `vector` | 3D f32 vector (add/sub/scale/dot/magnitude/normalize/distance/cosine) |
| `VectorI32` | `vector` | 3D i32 vector (add/sub/scale/dot) |
| `Vector(T, N)` | `vector` | Generic N-dimensional vector |
| `LatLon` | `geographic` | 2D coordinate with haversine distance |
| `LatLonAlt` | `geographic` | 3D coordinate (lat/lon/altitude) |
| `GeoPoint` | `geographic` | Tagged union of 2D/3D |
| `Url` | `url` | Parsed URL components (scheme, host, port, path, query, fragment) |
| `Domain` | `url` | Validated domain name with label iteration |
| `Range(T)` | `range` | Generic inclusive range with contains/overlaps/intersection |
| `IntRange` | `range` | `Range(i64)` |
| `UintRange` | `range` | `Range(u64)` |
| `FloatRange` | `range` | `Range(f64)` |

## Tests

| Test suite | Count | Status |
|---|---|---|
| Unit tests (`zig build test`) | 265 | Passing (264 pass, 1 skip) |
| Integration tests (`zig build test-integration`) | 9 | Passing |
| Type-extension tests (`zig build test-extensions`) | 11 | Passing |
| Performance tests (`zig build test-performance`) | 9 | Passing |
| Parser-edges tests (`zig build test-parser-edges`) | 16 | Passing (Q33) |
| Fuzz tests (`zig build test-fuzz`) | 12 | Passing (Zig 0.16 Smith API; GAP-0020; +2 Range targets, ATX-06) |
| **Total runnable** | **322** | **All passing (1 skip)** |

## Open Gaps (as of 2026-06-11, post audit-iteration-1)

Open count: **4** (0 Critical, 1 High, 1 Medium, 2 Low). Closed items are in
[GAP_ANALYSIS_RESOLVED.md](GAP_ANALYSIS_RESOLVED.md). Every remaining item is
**Blocked on an external dependency** (downstream repo or runner provisioning).
GAP-0019's tracker issue [#23](https://gitlab.com/devnw/zig/advanced-types/-/issues/23)
was closed on GitLab 2026-04-18 as infra-blocked; the row below is retained
for the record because the CI matrix jobs remain `when: manual` until runners
are provisioned.

| Gap-ID | Finding | Severity | Status | Category | Issue |
|--------|---------|----------|--------|----------|-------|
| GAP-0014 | Wire Geode to consume types from this package | High | Blocked (external — Geode repo) | Requirement | [#13](https://gitlab.com/devnw/zig/advanced-types/-/issues/13) |
| GAP-0015 | DateRange deferred — blocked on datetime package | Low | Blocked (external — datetime package) | Feature | [#8](https://gitlab.com/devnw/zig/advanced-types/-/issues/8) |
| GAP-0016 | Geographic `st_*` helpers staged for future release | Low | Blocked (feature-scope decision; query layer) | Feature | [#14](https://gitlab.com/devnw/zig/advanced-types/-/issues/14) |
| GAP-0017 | Port Geode integration tests for type consumption | Medium | Blocked (external — Geode repo; GAP-0014 precedes) | Test | [#16](https://gitlab.com/devnw/zig/advanced-types/-/issues/16) |
| GAP-0019 | AT-NFR-003 — CI cross-platform runners dormant | High | Closed on GitLab (infra-blocked; CI matrix jobs remain `when: manual`) — issue #23 closed 2026-04-18 | CI/CD | [#23](https://gitlab.com/devnw/zig/advanced-types/-/issues/23) |

### GAP-0014: Wire Geode to consume types from this package

- **Issue:** [#13](https://gitlab.com/devnw/zig/advanced-types/-/issues/13)
- **Category:** Requirement / Feature
- **Severity:** High
- **Requirement source:** `docs/audit/gap-requirements.md` AT-PKG-003; project goal stated above.
- **Current state (evidence):** Library is ready for consumption; no downstream Geode MR references this package. Not actionable inside this repo.
- **Why this is a gap:** Library's reason-for-being is Geode consumption; downstream wiring is the acceptance criterion for the whole extraction.
- **Blocker:** External — requires MR in `devnw/zig/geode`. Cannot be closed in this repo.
- **Unblock steps:** Open an MR in the Geode repo depending on `devnw/zig/advanced-types`, replacing in-tree type copies.
- **Acceptance criteria:** Geode `build.zig.zon` declares `advanced-types` as a dependency; in-tree duplicates removed.

### GAP-0015: DateRange deferred — blocked on datetime package

- **Issue:** [#8](https://gitlab.com/devnw/zig/advanced-types/-/issues/8)
- **Category:** Feature
- **Severity:** Low
- **Requirement source:** `docs/audit/gap-requirements.md` AT-PKG-002.
- **Current state (evidence):** `src/types/range.zig` ships `Range(T)` + `IntRange`/`UintRange`/`FloatRange`; `DateRange` intentionally absent. Decision documented above in "Concrete Gaps".
- **Blocker:** External — no shared Zig datetime package exists yet.
- **Unblock steps:** When a shared datetime package lands, add `DateRange = Range(<datetime>)` alias plus tests.
- **Acceptance criteria:** `DateRange` type with tests; documented in public API.

### GAP-0016: Geographic `st_*` helpers staged for future release

- **Issue:** [#14](https://gitlab.com/devnw/zig/advanced-types/-/issues/14)
- **Category:** Feature
- **Severity:** Low
- **Requirement source:** "Intended Boundary" section above.
- **Current state (evidence):** `src/types/geographic.zig` exports `LatLon`, `LatLonAlt`, `GeoPoint`; `st_*` query helpers explicitly staged for later.
- **Blocker:** Feature-scope decision — `st_*` helpers are query-layer concerns that belong with a spatial-query package, not in the value-type layer.
- **Unblock steps:** Add `st_*` helpers in a follow-up release when a query-layer consumer materialises, OR reclassify as Won't-Do.
- **Acceptance criteria:** `st_*` helpers exposed with tests OR explicit Won't-Do decision.

### GAP-0017: Port Geode integration tests for type consumption

- **Issue:** [#16](https://gitlab.com/devnw/zig/advanced-types/-/issues/16)
- **Category:** Test
- **Severity:** Medium
- **Requirement source:** `docs/audit/gap-requirements.md`.
- **Current state (evidence):** No Geode-side integration tests exist here; blocked on GAP-0014.
- **Blocker:** External — waits on GAP-0014.
- **Unblock steps:** Port integration tests to Geode once GAP-0014 lands.
- **Acceptance criteria:** Geode CI exercises types from this package end-to-end.

### GAP-0019: AT-NFR-003 — cross-platform CI runners dormant

- **Issue:** [#23](https://gitlab.com/devnw/zig/advanced-types/-/issues/23) (closed on GitLab as infra-blocked)
- **Category:** CI/CD
- **Severity:** High
- **Requirement source:** `docs/audit/gap-requirements.md` AT-NFR-003; README cross-platform claim.
- **Current state (evidence):** `.gitlab-ci.yml` carries macOS / Windows / aarch64 jobs with `rules: when: manual` and `allow_failure: true` (commits `505fe43`, `aa31b0d`, `7431a67`); SHA-256 verification parity with Linux now in place. No runners provisioned.
- **Blocker:** Infra — the pool's `macos` runners are stale and there is no Windows runner with the toolchain; ARM Linux runners exist (tagged `arm64` — the job now targets that tag per CI-SCHED-02). This is a platform-ops task, not a repository change.
- **Unblock steps:**
  1. Provision/refresh runners tagged `macos`, `windows`, `arm64` in the group runner pool.
  2. Verify Zig 0.16.0 install paths per target.
  3. Remove `rules: when: manual` once green; drop `allow_failure: true` once stable.
- **Acceptance criteria:** Cross-platform jobs pass on main without `allow_failure`.

## Related Audit Documents

- [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md) — 47 closed/resolved (incl. 6 Q + 5 N closed 6th pass), 4 accepted, 4 open ledger-only (Q14, Q28, Q39, Q40)
- [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md) — all closed (incl. P1–P6 on 2026-06-11); 0 open Fix, 0 open Monitor
- [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md) — all closed/accepted; 2026-06-11 appsec pass ATX-02..08 closed, ATX-01 accepted

## Acceptance Criteria

- [x] This repo builds without importing Geode storage or planner code.
- [ ] Geode consumes these types externally for vector/spatial/network features. (GAP-0014)
- [x] URL ownership is decided clearly so `advanced-types` and `uri` do not overlap indefinitely.
