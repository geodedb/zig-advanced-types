# Security Inventory -- advanced-types

**Root:** `/home/benji/src/devnw/zig/advanced-types`
**Platform:** GitLab (`git@gitlab.com:devnw/zig/advanced-types.git`)
**Language:** Zig `0.16.0` (declared `.minimum_zig_version` in `build.zig.zon:5`; CI pins `ZIG_VERSION: "0.16.0"` in `.gitlab-ci.yml:27`)
**Frameworks / deps:** None at runtime. `build.zig.zon:6` declares `.dependencies = .{}`. Zero external packages.
**Artifact:** Library module `advanced_types` declared at `build.zig:11-15`, root `src/root.zig`. No executable shipped; `bench/main.zig` and `examples/basic.zig` are local-only.

This is a single-boundary library: one `[]const u8 -> ValidatedValueType | TypedError` surface per type. No network, no filesystem, no allocator on parse paths (all parsers are zero-alloc -- `Url` and `Domain` alias caller-owned input).

## Public API Attack Surface

Every function in this table accepts caller-controlled bytes (or caller-controlled values for `init`) that may come from untrusted sources in a typical deployment.

| Entrypoint | Kind | Input Validation | File:Line |
|-----------|------|------------------|-----------|
| `Ipv4Addr.parse(input)` | dotted-decimal parser | `<=255` per octet, digit-cap `<=3`, dot-count exact | `src/types/network.zig:78` |
| `Ipv4Addr.init(a,b,c,d)` | typed constructor | type system | `src/types/network.zig:55` |
| `Ipv4Addr.fromU32(v)` | pure function | total | `src/types/network.zig:60` |
| `Ipv6Addr.parse(input)` | colon-hex + `::` shorthand | group count, hex digit cap, 0xFFFF ceiling | `src/types/network.zig:214` |
| `Ipv6Addr.init(segs)` | typed constructor | type system | `src/types/network.zig:195` |
| `IpAddr.parse(input)` | auto-detect via `':'` | delegates | `src/types/network.zig:438` |
| `Subnet.init(addr, prefix_len)` | checked constructor | prefix `<=32`/`<=128` by family | `src/types/network.zig:493` |
| `Subnet.parse(input)` | CIDR | prefix `<=128` u16 cap, per-family re-check | `src/types/network.zig:503` |
| `Mac.parse(input)` | EUI-48 | length `==17`, hex per octet, `':'`/`'-'` separator | `src/types/network.zig:617` |
| `Domain.parse(input)` | RFC 952 / 1123 | total `<=253`, label 1..63, `[A-Za-z0-9-]`, no leading/trailing `-` | `src/types/url.zig:52` |
| `Url.parse(input)` | scheme + authority + path + query + fragment | scheme charset, host charset, strict port, userinfo stripped | `src/types/url.zig:190` |
| `LatLon.init(lat, lon)` | float constructor | `[-90,90]`/`[-180,180]`, NaN rejected | `src/types/geographic.zig:99` |
| `LatLon.parse(input)` | `(lat, lon)` | `parseFloat` + `init` | `src/types/geographic.zig:158` |
| `LatLonAlt.init(lat, lon, alt)` | float constructor | lat/lon ranges, `alt` finite (NaN/Inf rejected) | `src/types/geographic.zig:179` |
| `LatLonAlt.parse(input)` | `(lat, lon, alt)` | delegates | `src/types/geographic.zig:211` |
| `GeoPoint.parse(input)` | dispatch on comma count | delegates | `src/types/geographic.zig:296` |
| `Range(T).init(lo, hi)` | typed constructor | `lo<=hi`; NaN/Inf rejected for floats | `src/types/range.zig:28` |
| `Range(T).parse(input)` | `[lo, hi]` | `parseInt` + `init`; integer types only | `src/types/range.zig:107` |
| `Vector(T,N).parse(input)` | `[v0,...,vN-1]` | dimension exact; floats reject NaN/Inf via `parseElement` | `src/types/vector.zig:211, 239` |
| `Vector(T,N).at(i)` | indexed access | panics on OOB (documented) | `src/types/vector.zig:76` |
| `Vector(T,N).get(i)` | safe index | returns `?T` | `src/types/vector.zig:84` |
| `Subnet.contains(addr)` | predicate | prefix-family bounds defensively re-checked | `src/types/network.zig:541` |

**Note on "StrictFloat":** there is no type named `StrictFloat`. The strict-float *behavior* lives inside `parseElement` for `Vector` (rejects `NaN`/`Inf` at `src/types/vector.zig:244`) and inside `LatLon.init` / `LatLonAlt.init` (rejects `NaN` for lat/lon, `NaN`/`Inf` for alt, at `src/types/geographic.zig:101-105, 181-186`).

**Allocator interactions:** none on parse or math paths. The only references to `Allocator` in `src/` are doc comments pointing callers at `std.mem.Allocator.dupe` to transfer slice ownership (`src/types/url.zig:47, 170`), plus a note that `network.zig` types are plain value types (`src/types/network.zig:6`). No `Allocator.alloc` / `free` / `dupe` / `create` call anywhere under `src/`. The library is allocator-free by contract.

**`@intCast` / narrowing cast sites** (all concentrated in `src/types/network.zig`):

- `src/types/network.zig:62-65` -- `fromU32` splits a `u32` to four `u8` octets via `@intCast` after masking with `& 0xFF`. Narrowing is total.
- `src/types/network.zig:91, 108` -- IPv4 octet emit after `current_value > 255` guard on the preceding line.
- `src/types/network.zig:198-199, 280-281, 298-299` -- IPv6 segment emit after `current_value > 0xFFFF` guard.
- `src/types/network.zig:533` -- `Subnet.parse` emits `prefix_len: u8` after the `u16` accumulator is capped at `128` (line 521) and re-checked (line 529).
- `src/types/network.zig:564` -- `containsV4` computes `@as(u8, 32) - prefix_len` then `@intCast` to `u5`. `Subnet.init` and `parse` enforce `prefix_len <= 32` for v4; `containsV4` additionally asserts `prefix_len > 0 and prefix_len < 32` at line 563 before the cast (branches for `0`/`32` handled earlier).
- `src/types/network.zig:574, 581` -- `containsV6`: `remaining_bits: u3 = @intCast(prefix_len % 8)` is total; `@intCast(@as(u4, 8) - @as(u4, remaining_bits))` to `u3` is reached only when `remaining_bits > 0`.

No `@truncate`, `@bitCast`, `@ptrCast`, or `@alignCast` occurs in `src/`.

**Integer-overflow-prone ops** (all documented in the module header `src/root.zig:21-26`):

- `Range(T).span`: `self.upper - self.lower` at `src/types/range.zig:86`. Panics in Debug/ReleaseSafe, wraps in ReleaseFast/Small.
- `Vector(T,N).add`, `.sub`, `.scale`, `.dot`, `.magnitudeSquared` at `src/types/vector.zig:106-144`. Same mode-dependent semantics.
- `Range.adjacent` at `src/types/range.zig:181-183` explicitly guards `a.upper + 1` with `a.upper < math.maxInt(T)` before the addition.

No explicit wrapping (`+%`, `-%`, `*%`) or saturating (`+|`, `-|`, `*|`) operators are used; no `@addWithOverflow` / `@subWithOverflow` / `@mulWithOverflow`.

**Panic / `unreachable` / `@panic` sites:**

- `src/types/vector.zig:78` -- `at()` calls `@panic("Vector index out of bounds")`. Documented; `get()` returns `?T` as the safe alternative.
- `src/types/network.zig:563` -- `std.debug.assert` in `containsV4`. Elided in ReleaseFast.
- `std.fmt.bufPrint(...) catch unreachable` appears ~18 times (e.g., `src/types/network.zig:712, 891, 895, 901, 962, 966, 1079, 1083, 1135`, `src/types/range.zig:452, 459, 466, 513`, `src/types/vector.zig:504, 511, 532, 542`, `src/types/geographic.zig:386, 393, 466, 553, 560`). Every occurrence is inside a `test` function with a compile-time-sized stack buffer -- not reachable from library callers.
- No `@setRuntimeSafety(false)`.

## Trust Boundaries

| # | Boundary | From | To | Controls |
|---|---------|------|----|----------|
| 1 | Parse surface | Arbitrary caller bytes (`[]const u8`) | Validated value type or typed error | Typed `ParseError` / `GeoError` / `RangeError`; explicit length caps; NaN/Inf rejection; fuzz invariant "no panics on bad input" (`tests/fuzz.zig`) |
| 2 | Std-lib | `std.fmt.parseInt`, `std.fmt.parseFloat`, `std.mem.indexOf*`, `std.ascii.*` | Library parsers | Errors caught and mapped to library-owned error sets (e.g., `src/types/range.zig:140`, `src/types/vector.zig:227-230`, `src/types/url.zig:372`) |
| 3 | Allocator | caller-supplied | library | **Not crossed.** Library takes no allocator; it only documents that callers must `dupe` slices to transfer ownership of `Url`/`Domain`-aliased bytes (`src/types/url.zig:44-47, 166-170`). |
| 4 | Build system | `build.zig` + `build.zig.zon` | compiler | No env vars, no external sources declared in `.paths` (`build.zig.zon:7-13`). No `b.lazyDependency` / `b.dependency` calls in `build.zig`. |
| 5 | CI ingress (Zig toolchain) | `ziglang.org/download/index.json` (HTTPS) | runner filesystem | `index.json` -> `shasum` extract -> `sha256sum --check --strict` against the tarball (`.gitlab-ci.yml:59-72`). TOFU per run. |
| 6 | CI ingress (components) | `gitlab.com/devnw/ci-catalog/*@v1.7.1` etc. | pipeline | Same-group trust; pinned to floating minor tag. |
| 7 | Release | developer push -> `main` | GitLab tag + `release-semantic` | Pre-commit (local only) `detect-private-key`, `zig fmt --check`, `zig build check`, `zig build test` (`.pre-commit-config.yaml`); CODEOWNERS `* @benjiv` (single owner, `CODEOWNERS:3`). |

## Library-Specific Threat Model

**Assets:**

| Asset | Sensitivity | Where |
|-------|-------------|-------|
| Parser correctness (contract with downstream) | High | `src/types/*.zig` |
| Release artifact integrity | High | GitLab group `devnw/zig` |
| CI pipeline integrity | High | `.gitlab-ci.yml`, ci-catalog |
| Consumer trust -- SSRF-safe predicates used correctly | High (transitive) | `isSafeForOutboundFetch`, `isPrivate`, `isLoopback` |

No runtime secrets, PII, money flow, auth, or cloud IAM in the library. Supply chain handles the tarball and CI components.

**Attacker types in scope:**

1. Caller supplying crafted bytes to a `parse()` -- induce panic, semantic confusion, or overflow in downstream arithmetic.
2. Supply-chain actor controlling upstream Zig, the `ci-catalog` components, or the `devnw` GitLab group.
3. Downstream integrator misreading library semantics (e.g., treating `!isPrivate()` as "SSRF-safe" rather than the complete `isSafeForOutboundFetch`).

Out of scope: authenticated user, tenant isolation (N/A), admin panels (N/A), datastores (N/A).

**Top abuse cases to investigate (ranked):**

| Rank | Case | Why | Entry points |
|------|------|-----|--------------|
| 1 | **Parser DoS / panic** on crafted input (unreachable, `@intCast` narrowing, overflow trap, pathological loop) | Breaks the fuzz invariant, crashes consumers in ReleaseSafe | all `parse()` listed above; `@intCast` sites in `network.zig` |
| 2 | **IP/URL confusion -> SSRF-adjacent** (IPv4-mapped v6 smuggling, userinfo-in-authority, leading-zero octet/port, bracketed host) | `isSafeForOutboundFetch` and `Url.parse` are the de facto SSRF gate; a confusion here bypasses downstream policy | `Ipv4Addr.parse`, `Ipv6Addr.parse`/`toIpv4` (`network.zig:407`), `IpAddr.parse`, `Url.parse` (`url.zig:190`), `validateHostChars` (`url.zig:302`), `parsePortStrict` (`url.zig:364`) |
| 3 | **Integer overflow in library math** under ReleaseFast/ReleaseSmall | Silent wrap; consumer builds that flip optimization can see different results from the same input | `Range(T).span` (`range.zig:85`), `Vector` arithmetic (`vector.zig:106-144`) |
| 4 | **Slice-lifetime UAF** in `Url`/`Domain` | `raw`/`host`/`path`/etc. alias caller input; consumers who free or mutate the buffer after parse get dangling reads | `Url` / `Domain` field docs (`url.zig:40-47, 163-170`) |
| 5 | **Parser performance DoS** via very long inputs | No upper bound beyond RFC caps on `Domain` (`<=253`) and `Mac` (`==17`). `Ipv4Addr.parse` / `Ipv6Addr.parse` / `Subnet.parse` / `Url.parse` / `LatLon.parse` walk the whole buffer | all length-unbounded `parse()` |
| 6 | **Domain homograph / IDN gap** -- ASCII-only by policy, callers must pre-punycode | Mismatch between caller normalization and library ASCII gate yields confusables | `Domain.parse` (`url.zig:52`); policy documented in `SECURITY.md:55-81` |
| 7 | **CIDR edge -- struct-literal `Subnet` with bad prefix** | Bypasses `init`/`parse`; `contains` defensively returns `false` and asserts `1 <= prefix_len <= 31` in v4 case | `Subnet` struct-literal construction; `containsV4` (`network.zig:554`), `containsV6` (`network.zig:569`) |
| 8 | **Supply chain -- Zig tarball TOFU** | Shasum comes from the same request chain as the tarball (`index.json` then download); any upstream compromise taints a single run and propagates via cache | `.gitlab-ci.yml:39-77` |
| 9 | **Supply chain -- ci-catalog floating tag** | `@v1.7.1` is a tag; re-point is possible without SHA pinning | `.gitlab-ci.yml:10-24` |
| 10 | **Fuzz coverage gap on MR** | Fuzz job is `manual` + scheduled only (`.gitlab-ci.yml:353-358`); an MR crafted to pass default triggers skips fuzz | `.gitlab-ci.yml:341-360` |

## Build / CI Surface

GitLab CI only -- no `.github/workflows/*.yml` exists in this repo.

| Component | Secret handling | Pinning | File:Line |
|-----------|-----------------|---------|-----------|
| `build.zig` | none | n/a | `build.zig:1-149` |
| `build.zig.zon` | none | `.dependencies = .{}` -- nothing to verify | `build.zig.zon:6` |
| Zig install template | downloads `ziglang.org/.../tarball`, sha256-verifies from `index.json` fetched same job | `ZIG_VERSION` variable (TOFU) | `.gitlab-ci.yml:39-77` |
| Security SAST / DS / secrets / gitleaks | pipeline only | `@v1.7.1` | `.gitlab-ci.yml:11-14` |
| `zig-format` component | override `before_script` to match project Zig | `@v1.2.1` | `.gitlab-ci.yml:17, 80-84` |
| SBOM generate/scan | pipeline only | `@v1.7.1` | `.gitlab-ci.yml:20-21` |
| `release-semantic` | signs tags via catalog | `@v1.7.1` | `.gitlab-ci.yml:24` |
| Coverage (kcov) | report-only, no gate | pipeline only | `.gitlab-ci.yml:307-332` |
| Fuzz | `--fuzz` w/ 60s timeout, `rc==124` is pass | manual/scheduled only | `.gitlab-ci.yml:341-360` |
| Secrets scan local | gitleaks present, hook not in pre-commit | n/a | `.gitleaks.toml`, `.pre-commit-config.yaml` |
| Access | single code owner | `@benjiv` | `CODEOWNERS:3` |
| Disclosure policy | email, SLAs | | `SECURITY.md:9-36` |

**Permissions / secrets:** no `GITLAB_TOKEN`, `CI_JOB_TOKEN`, or user-declared secret appears in `.gitlab-ci.yml`. Pipelines rely on the default token only where a catalog component needs it internally. No custom `variables:` holding secrets. Runners carry the `company` tag by default (`.gitlab-ci.yml:5-7`), so jobs are dispatched to trusted infrastructure.

## Focus Areas for Downstream Phases

- **security-scanner**: parser panics (CWE-248), integer overflow (CWE-190) at `range.zig:86` and `vector.zig:106-144`, unbounded input lengths on most `parse()` calls, all `@intCast` sites in `src/types/network.zig`.
- **security-reviewer**: IP/URL confusion (rank 2), slice-lifetime contract docs (rank 4), `parsePortStrict` and `validateHostChars` coverage, `Subnet` struct-literal bypass (rank 7), IDN policy (rank 6).
- **supply-chain**: document accepted risks for Zig tarball TOFU (rank 8) and ci-catalog floating tag (rank 9); consider commit-SHA pinning the components or mirroring the Zig tarball to an internal artifact store. Already tracked as `SC-01` / `S7`.
- **CI**: consider making fuzz non-optional on MR pipelines (current coverage gap, rank 10). Already tracked.

## Unknowns & Assumptions

- Consumer set not enumerated -- README says "network/db code"; SSRF-relevance of `isPrivate` / `isLoopback` / `isSafeForOutboundFetch` depends on whether any consumer treats them as the *only* gate.
- No IDN / Punycode in `Domain`; assumption is callers pre-normalize (documented in `SECURITY.md:55-81`, closed as scoped won't-do NEW-02).
- `Url.parse` strips userinfo via "last `@` wins" WHATWG-style (`url.zig:236-245`); RFC 3986 parsers behave identically here. Regression coverage referenced in `tests/parser_edge_cases.zig`.
- CI pins Zig `0.16.0` and `build.zig.zon` declares the same minimum. Consumers on newer `0.16.x` patch releases inherit whatever safety-check semantics that release ships.
- Single-owner `CODEOWNERS` -- account-compromise boundary equals repo-write boundary.
