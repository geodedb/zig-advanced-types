# Security Inventory — advanced-types

**Root:** `/home/benji/src/devnw/zig/advanced-types`
**Platform:** GitLab (`gitlab.com/devnw/zig/advanced-types`)
**Language:** Zig (minimum `0.15.1`, CI pinned to `0.16.0` — see `build.zig.zon:5`, `.gitlab-ci.yml:27`)
**Frameworks / deps:** None. `build.zig.zon:6` declares `.dependencies = .{}` — pure std library only.
**Artifact:** Library module `advanced_types` (`src/root.zig`) exported via `build.zig:11-15`. No executable, no network, no filesystem I/O, no allocator use on the parsing paths (all parsers are zero-alloc; `Url`/`Domain` store slices into caller-owned input).

## Trust Boundary (single)

Untrusted `[]const u8` crosses into the library at every `parse()` call. The library returns a validated value type or a typed error; it never panics on invalid input *by design* (fuzz-test invariant — `tests/fuzz.zig:6-8`). Consumers (callers such as a spatial DB, a network config loader, or a URL normalizer) decide what to do with the parsed value. The library has no I/O, no auth, no state, no secrets.

## Parser Entrypoints (attack surface)

Every function below accepts arbitrary bytes from an external source in a typical deployment. These are the 12 `parse` boundaries plus the non-byte `init`/`fromU32` constructors that perform validation.

| Entrypoint | Type | Auth Required | Input Validation | File:Line |
|-----------|------|---------------|------------------|-----------|
| `Ipv4Addr.parse(input: []const u8)` | dotted-decimal parser | n/a (library) | per-octet `<= 255`, digit cap, dot count | `src/types/network.zig:77` |
| `Ipv4Addr.init(a,b,c,d: u8)` | typed constructor | n/a | type system only | `src/types/network.zig:54` |
| `Ipv4Addr.fromU32(u32)` | endianness constructor | n/a | total function | `src/types/network.zig:59` |
| `Ipv6Addr.parse(input: []const u8)` | colon-hex + `::` shorthand | n/a | group count, `::` shorthand, 16-bit ceiling | `src/types/network.zig:190` |
| `Ipv6Addr.init(segs: [8]u16)` | typed constructor | n/a | type system only | `src/types/network.zig:171` |
| `IpAddr.parse(input: []const u8)` | auto-detect v4/v6 by `:` | n/a | delegates to v4/v6 | `src/types/network.zig:376` |
| `Subnet.parse(input: []const u8)` | CIDR | n/a | prefix in `[0..32]`/`[0..128]` by family | `src/types/network.zig:426` |
| `Mac.parse(input: []const u8)` | EUI-48 | n/a | fixed 17-char length, hex per octet, `:`/`-` sep | `src/types/network.zig:534` |
| `Url.parse(input: []const u8)` | scheme+authority+path+query+fragment | n/a | scheme charset, port `u16`, no percent-decode | `src/types/url.zig:161` |
| `Domain.parse(input: []const u8)` | RFC 952/1123 | n/a | label 1-63, total `<=253`, `[A-Za-z0-9-]`, no leading/trailing `-` | `src/types/url.zig:41` |
| `LatLon.parse(input: []const u8)` | `(lat, lon)` text | n/a | lat `[-90..90]`, lon `[-180..180]`, NaN rejected | `src/types/geographic.zig:106` |
| `LatLonAlt.parse(input: []const u8)` | `(lat, lon, alt)` text | n/a | same + alt finite | `src/types/geographic.zig:176` |
| `GeoPoint.parse(input: []const u8)` | dispatch on comma count | n/a | delegates | `src/types/geographic.zig:285` |
| `Range(T).parse(input: []const u8)` | `[lo, hi]` (int only) | n/a | `parseInt(T, 10)` + `init` guard | `src/types/range.zig:107` |
| `Range(T).init(lo, hi)` | typed constructor | n/a | `lo <= hi`; NaN/Inf rejected for floats | `src/types/range.zig:28` |
| `Vector(T,N).parse(input: []const u8)` | `[v0,..,vN-1]` | n/a | N elements exactly; NaN/Inf rejected | `src/types/vector.zig:211` |
| `Vector(T,N).at(index)` / `.get(index)` | indexed access | n/a | `at` panics on OOB (documented); `get` returns `?T` | `src/types/vector.zig:76, 84` |

### Hot spots observed during inventory

- `src/types/network.zig:469-470` — `@as(u8, 32) - self.prefix_len` then `@intCast` to `u5`. `Subnet.parse` enforces `prefix_len <= 32` for v4 (lines 448-452) before `contains` runs, so the shift is well-defined, but the invariant is split across constructor and method. Worth a scanner pass.
- `src/types/network.zig:494` — `@as(u4, 8) - @as(u4, remaining_bits)` with `remaining_bits: u3`. Only reached when `remaining_bits > 0`, so `8 - [1..7]` is safe, but noisy to verify by eye.
- `src/types/url.zig:202` — zero-length slice `input[scheme_end + 3 + rest.len .. scheme_end + 3 + rest.len]` used when the authority has no path. Correct but fragile indexing; slice lifetime pins to caller-owned buffer.
- `src/types/url.zig:224-226` — `lastIndexOfScalar(u8, authority, ':')`. A bare IPv6 literal without brackets will be misparsed as `host = "2001"`, `port = ":db8::1"` → `InvalidPort`. Matches RFC 3986 (IPv6 requires brackets), diverges from WHATWG — document.
- `src/types/range.zig:85-87` — `span()` returns `upper - lower` without overflow guard. Documented (S6 in `docs/SECURITY_GAP_ANALYSIS.md`), but still a footgun in `ReleaseFast`.
- `src/types/vector.zig:106-137` — `add`/`sub`/`scale`/`dot` on integer vectors use plain `+`/`-`/`*`. Documented (S4).
- `src/types/url.zig:41` checks `input.len > 253` before per-label validation. Good. No IDN / Punycode normalization and no homograph detection — policy decision, not a bug.

## Tenant Isolation

N/A. Pure library; no tenants.

## External Integrations

N/A. Zero runtime deps. Build-time integrations are CI catalog components — see "Build/Deploy" below.

## Datastores & Queues

N/A.

## Admin Surfaces

N/A.

## Build / Deploy & Secret Management

| Component | Type | Handling | File:Line |
|-----------|------|----------|-----------|
| `build.zig` | Zig build | No env reads, no secrets | `build.zig:1-115` |
| `build.zig.zon` | package manifest | `.dependencies = .{}`, no hashes to verify | `build.zig.zon:6` |
| `.gitlab-ci.yml` Zig install | shell | Downloads `zig-${ZIG_VERSION}` over HTTPS, fetches `index.json`, extracts `shasum`, `sha256sum --check --strict` | `.gitlab-ci.yml:39-77` |
| `.gitlab-ci.yml` components | remote includes | Pinned to `v1.7.1` / `v1.2.1` refs of `gitlab.com/devnw/ci-catalog/*` | `.gitlab-ci.yml:10-24` |
| Fuzz job | CI | 60s budget, treats rc=124 as pass, uploads crash corpus `zig-out/fuzz/` on failure | `.gitlab-ci.yml:176-195` |
| SBOM | CI | `sbom-generate@v1.7.1`, `sbom-scan@v1.7.1` | `.gitlab-ci.yml:20-21` |
| Secrets scan | CI | `security-secrets@v1.7.1`, `security-gitleaks@v1.7.1` + local `.gitleaks.toml` | `.gitlab-ci.yml:13-14`, `.gitleaks.toml:1-22` |
| SAST / DS | CI | `security-sast@v1.7.1`, `security-dependency-scanning@v1.7.1` | `.gitlab-ci.yml:11-12` |
| Release | CI | `release-semantic@v1.7.1` | `.gitlab-ci.yml:24` |
| pre-commit | local | gitleaks hook absent; `detect-private-key` on by default, `zig fmt --check`, `zig build check`, `zig build test` | `.pre-commit-config.yaml:28, 63-84` |
| CODEOWNERS | access | `* @benjiv` — single-reviewer bottleneck | `CODEOWNERS:3` |
| `SECURITY.md` | policy | email `security@codepros.dev`, disclosure SLAs documented | `SECURITY.md:9-36` |

Supply-chain observations:

- No `minisign`/PGP verification of the Zig tarball. The hash is sourced from the official `index.json` fetched over HTTPS in the same job — TOFU on every run. `docs/SECURITY_GAP_ANALYSIS.md` S7 marks this "Won't Do"; pinning a known-good `index.json` SHA or mirroring to an internal artifact store would close the loop.
- Zig version pinned via the `ZIG_VERSION` variable. Major upgrades can land in a single-line MR.
- CI catalog components (`ci-catalog/*@v1.7.1`) live in the same GitLab group — supply-chain trust = group trust. Floating minor versions (`@v1.7.1`) protect against patch-tag repoint but not against a force-push or a compromised group member.

## Threat Model

## Assets

| Asset | Sensitivity | Location |
|-------|------------|----------|
| Parser correctness | High (library contract) | `src/types/*.zig` |
| Release artifacts (git tags + future ziglang package) | High | GitLab group `devnw/zig` |
| CI pipeline integrity | High | `.gitlab-ci.yml`, ci-catalog components |
| Consumer trust (downstream DB / network code) | High | Transitive |

No runtime secrets, no PII, no credentials, no money flow, no cloud IAM.

## Trust Boundaries

| Boundary | From | To | Controls |
|----------|------|-----|----------|
| Parse API | arbitrary bytes | validated value type | typed errors, fuzz invariant, range checks |
| Build ingress | upstream Zig tarball | CI runner filesystem | SHA-256 from `index.json`, HTTPS |
| CI includes | GitLab catalog | pipeline | pinned refs, group membership |
| Git push | developer | `main` | pre-commit (local) + GitLab protected branch rules + CODEOWNERS |

## Attacker Types (in scope)

1. **Attacker controlling library input** — supplies crafted strings to `parse()` to induce DoS, OOB, or semantic-confusion output that tricks a caller.
2. **Supply-chain attacker** — compromises upstream Zig release, a ci-catalog component, or the `devnw` GitLab group.
3. **Downstream integrator error** — consumer misuses the library (e.g., accepts `isPrivate() == false` as a safe SSRF signal). Not a vuln in the library, but doc clarity reduces real-world risk.

Out of scope: authenticated user, insider with repo write, cross-tenant access (no tenants).

## Top Abuse Cases (Prioritized)

| Rank | Abuse Case | Attacker | Likelihood | Impact | Entry Points |
|------|-----------|----------|------------|--------|-------------|
| 1 | **Parser DoS / panic** — crafted input triggers `unreachable`, `@panic`, integer-overflow trap, unchecked `@intCast`, or pathological loop | External input | Medium | High for callers (process crash in ReleaseSafe) | all `parse()` in network/url/geographic/range/vector |
| 2 | **IP confusion** — IPv4-in-IPv6 (`::ffff:10.0.0.1`), leading-zero octets, mixed bracketed host in URL authority; downstream uses `isPrivate`/`isLoopback` as a security gate and misses a class | External input | Medium | High (SSRF, ACL bypass, metadata-service access) | `Ipv4Addr.parse`, `Ipv6Addr.parse`/`toIpv4`, `IpAddr.parse`, `Subnet.contains`, `Url.parse` host |
| 3 | **URL host ambiguity → SSRF-adjacent** — `Url.parse` returns raw host bytes; callers forwarding `url.host` into HTTP clients can hit internal services. Library does not resolve, does not strip or parse userinfo, does not normalize percent encoding | External input | Medium | High (for consumers) | `Url.parse` (`src/types/url.zig:161`) |
| 4 | **Domain homograph / confusable** — `Domain.parse` accepts only ASCII per RFC 1123 (good) but callers feeding Unicode must punycode first; a mismatch between caller normalization and library validation creates confusables | External input | Low-Medium | Medium | `Domain.parse` (`src/types/url.zig:41`) |
| 5 | **Integer overflow in Range/Vector arithmetic** — `Range.span()` and `Vector.add/sub/scale/dot` wrap in `ReleaseFast`, panic in `ReleaseSafe` (documented S4/S6). Attacker-controlled contents can select worst-case mode | External input | Medium | Medium (crash in safe, silent wrap in fast) | `Range(T).span` (`src/types/range.zig:85`), `Vector(T,N).add/sub/scale/dot` (`src/types/vector.zig:106-137`) |
| 6 | **Slice lifetime misuse** — `Url`/`Domain` store slices into caller input; if caller frees/mutates the buffer, downstream reads of `url.host` are UAF. Contract worth enforcing in docs | Downstream error | Medium | High | `Url`, `Domain` |
| 7 | **CIDR edge — prefix boundary shifts** — `Subnet.contains` uses `@intCast` to `u5`/`u3`; guarded by validation at `parse`, but direct struct construction bypasses it | Intra-process | Low | Low | `Subnet.contains` (`src/types/network.zig:461`) |
| 8 | **Supply-chain: Zig tarball poisoning** — `index.json` + tarball TOFU-fetched per CI run; single upstream compromise taints every build. S7 accepted risk | Supply chain | Low | Critical | `.gitlab-ci.yml:39-77` |
| 9 | **Supply-chain: ci-catalog component** — pinned to `@v1.7.1` (floating minor) within same GitLab group | Supply chain | Low | High | `.gitlab-ci.yml:10-24` |
| 10 | **Parser performance DoS** — very long inputs (e.g., 10 MB of digits to `Ipv4Addr.parse`) walk the whole buffer; caller-side length caps are the only mitigation today | External input | Low | Low | every `parse()` |

## Unknowns & Assumptions

- Consumer set: README says "Consumed by network/db code" — not enumerated. A per-consumer mental model would sharpen ranks 2-3 (if a consumer uses `isPrivate` as an SSRF gate, rank 2 jumps to Critical).
- No IDN/Punycode is implemented. Assumption: callers pre-normalize non-ASCII domains. Worth a docstring warning in `Domain.parse`.
- `Url.parse` does not parse userinfo (`user:pass@host`). Passing `http://evil.com@trusted.com/` returns `host == "evil.com@trusted.com"`. Known divergence from WHATWG; worth a regression test plus doc note.
- CI runs fuzz for 60s per job on `schedule`/`web` triggers only — MR pipelines do not fuzz. A malicious MR crafted to pass only default triggers can bypass fuzz coverage.
- Zig compiler pinned in `build.zig.zon` to `0.15.1` minimum, CI uses `0.16.0`. Consumers on `0.15.1` may see different `@intCast` safety semantics — document the supported minor.
- `CODEOWNERS` has a single owner (`@benjiv`). Single-reviewer bottleneck means account compromise lands changes directly; not a vuln today, but scanners should flag it.

## Focus Areas for Downstream Phases

- **security-scanner**: parser panics (CWE-248), integer overflow paths (CWE-190) in `range.zig:85`, `vector.zig:106-137`, `network.zig:469-494`; unbounded input lengths; `@intCast` sites in `src/types/network.zig` lines 90, 107, 174, 175, 256, 257, 274, 275, 456, 469, 483, 494.
- **security-reviewer**: IP/URL confusion (ranks 2-3), domain homograph (rank 4), slice-lifetime contract for `Url`/`Domain` (rank 6), userinfo handling in `Url.parse`, `isPrivate`/`isLoopback` semantics vs. caller SSRF expectations.
- **security-issue-tracker**: open confidential issues for rank 2 (IP confusion, confidential: yes — exploit class), rank 3 (URL host → SSRF, confidential: yes), rank 6 (slice-lifetime doc, confidential: no), rank 8-9 (supply chain, confidential: no — extends accepted S7 conversation).
