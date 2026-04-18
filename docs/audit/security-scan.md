# Security Scan Report — advanced-types

**Date:** 2026-04-18
**Scope:** `/home/benji/src/devnw/zig/advanced-types` (full repo)
**Platform:** GitLab `gitlab.com/devnw/zig/advanced-types`
**Language:** Zig (min `0.15.1`, CI pinned `0.16.0`)
**Phase:** 2 of `/codepros:audit` (security-scanner)
**Prior handoff:** `docs/audit/security-inventory.md` (Phase 1)

## 1. Tool Availability

| Tool | Available | Version | Used |
|------|-----------|---------|------|
| gitleaks | yes (local download) | 8.24.0 | yes |
| semgrep | yes | 1.x | yes |
| trufflehog | no | — | skipped (gitleaks covers) |
| trivy / grype / syft / osv-scanner | no | — | skipped (no runtime deps anyway) |
| shellcheck / hadolint | yes / no | — | no shell or Dockerfile in repo |
| checkov | no | — | CI `trivy config` equivalent absent locally |
| govulncheck | yes | — | N/A (no Go code) |
| bandit / safety / cargo-audit / snyk | no | — | N/A (no Python/Rust code; Snyk not authenticated) |
| language fuzz | built-in `zig build test --fuzz` | 60s CI budget | scheduled only |

Telemetry: `semgrep --metrics=off` used. No external uploads.

## 2. Secret Detection (gitleaks 8.24.0)

Command: `gitleaks detect --source . --no-banner --redact --report-format json --report-path /tmp/gitleaks.json`

| Metric | Value |
|--------|-------|
| Commits scanned | 8 |
| Bytes scanned | ~252 KB |
| Findings | **0** |
| Exit code | 0 |

Local config at `.gitleaks.toml:1-22` extends default rules, allowlists `.zig-cache`, `zig-out`, `.git`.

**Confidence:** confirmed. No leaks.

## 3. SBOM / Dependency / Vulnerability

### 3.1 Runtime dependencies

- `build.zig.zon:6` — `.dependencies = .{}` (empty)
- No lockfile (none exists for Zig 0.15+ with empty deps)
- No transitive packages; library is `std`-only

**CVE surface:** 0 (confidence::confirmed)

### 3.2 Zig compiler (0.16.0 pinned via `ZIG_VERSION` at `.gitlab-ci.yml:27`)

As of 2026-04-18, no published CVEs against `ziglang/zig@0.16.0` were found in NVD
(offline check — no network in this scan run; confidence::suspected).
Caller should cross-check the Zig security advisories page before release.

SHA-256 verification is performed in CI (`.gitlab-ci.yml:39-77`) against the
upstream `ziglang.org/download/index.json` — note this is TOFU each run
(the index itself is fetched and trusted over HTTPS). This matches S7 status
in `docs/SECURITY_GAP_ANALYSIS.md:34` ("Won't Do") and is **mis-documented**:
the ledger says "HTTPS provides baseline protection; checksum verification
requires maintaining hash values per version" but the CI script **does**
verify SHA-256 from the index. The ledger should be updated to reflect the
implemented control.

### 3.3 CI catalog components (supply chain)

`.gitlab-ci.yml:10-24` imports:

| Component | Ref |
|-----------|-----|
| `security-sast` | `@v1.7.1` |
| `security-dependency-scanning` | `@v1.7.1` |
| `security-secrets` | `@v1.7.1` |
| `security-gitleaks` | `@v1.7.1` |
| `zig-format` | `@v1.2.1` |
| `sbom-generate` | `@v1.7.1` |
| `sbom-scan` | `@v1.7.1` |
| `release-semantic` | `@v1.7.1` |

All floating minor version refs (e.g., `@v1.7.1` can be re-tagged). Same GitLab group
(`devnw/ci-catalog`) — supply-chain risk = group-admin-compromise risk.
**Confidence:** suspected. No concrete CVE; documented as accepted risk.

### 3.4 Pre-commit hooks

`.pre-commit-config.yaml:9-80` pins hook versions at `rev: vX.Y.Z` (gitleaks hook
is **not** present locally — CI has it, dev box does not). Not a CVE, but
widens the detection window for leaked secrets introduced in a local commit.
**Severity:** Low. **CWE-noinfo / supply-chain convenience.** (confidence::confirmed)

## 4. SAST — Semgrep

Command: `semgrep scan --config p/security-audit --config p/secrets --config p/owasp-top-ten --config p/r2c-security-audit --metrics=off --json -o /tmp/semgrep-scoped.json .`

| Metric | Value |
|--------|-------|
| Rules run | 64 |
| Targets scanned | 40 |
| Parsed | ~100% |
| Findings | **0 (0 blocking)** |

Zig is not in Semgrep's supported language set for registry rules, so the 40
targets are limited to YAML/TOML/Markdown/config. The Zig code (`src/**/*.zig`,
`tests/**/*.zig`, `build.zig`) was **not statically analyzed by Semgrep**.
**Confidence:** confirmed for the files Semgrep parsed; **gap** for Zig code.

## 5. Manual SAST — Zig-Specific (high-recall grep + reasoning)

Zig has no mainstream external SAST. The following is a manual pass that covers
the patterns flagged in `docs/audit/security-inventory.md:139-143`.

### 5.1 `@intCast` sites (CWE-190, CWE-681)

Total: **12 `@intCast` sites** across `src/types/network.zig`. All audited by hand.

| # | File:Line | Expression | Pre-guard | Verdict |
|---|-----------|------------|-----------|---------|
| A1 | `src/types/network.zig:61-64` | `fromU32` right-shifts masked with `0xFF` -> `u8` | `& 0xFF` caps to u8 | safe (confirmed) |
| A2 | `src/types/network.zig:90` | `octets[i] = @intCast(current_value)` in `Ipv4Addr.parse` | `current_value > 255` checked at line 89 | safe (confirmed) |
| A3 | `src/types/network.zig:107` | same, last octet | checked at line 106 | safe (confirmed) |
| A4 | `src/types/network.zig:174-175` | `Ipv6Addr.init` segment split | input is `[8]u16`, mask with `0xFF` | safe (confirmed) |
| A5 | `src/types/network.zig:256-257` | `parseGroups` per-colon write | `current_value > 0xFFFF` checked line 255 | safe (confirmed) |
| A6 | `src/types/network.zig:274-275` | `parseGroups` final write | checked line 273 | safe (confirmed) |
| A7 | `src/types/network.zig:456` | `Subnet.parse` prefix_len widen `u16` -> `u8` | `prefix_len > 128` capped line 444 | safe (confirmed) |
| A8 | `src/types/network.zig:469` | `shift: u5 = @intCast(32 - self.prefix_len)` in `Subnet.contains` | **guarded only if parsed via `Subnet.parse`**; a consumer using struct literal `{ .network=..., .prefix_len=200 }` would panic here. CWE-1284 (indirect). | **suspected** (confidence::suspected) |
| A9 | `src/types/network.zig:483` | `remaining_bits: u3 = @intCast(self.prefix_len % 8)` | `% 8` always fits `u3` | safe (confirmed) |
| A10 | `src/types/network.zig:494` | `shift: u3 = @intCast(@as(u4, 8) - @as(u4, remaining_bits))` | reached only when `remaining_bits > 0`, so `8-[1..7]` in `[1..7]` | safe (confirmed) |

**Finding SAST-01 (low, `confidence::suspected`, CWE-1284 / CWE-190):** `Subnet`
struct has public fields `network: IpAddr, prefix_len: u8` (`src/types/network.zig:419-422`)
and a public constructor-free value type. A caller that bypasses `Subnet.parse`
and sets `prefix_len` to an invalid value (e.g., `200`) will hit the `@intCast`
at `src/types/network.zig:469` and panic in `ReleaseSafe`, or compute an
undefined mask in `ReleaseFast`. Mitigation: make the struct pack-constructed via
`init()` with range check, or defensively clamp in `contains`.

### 5.2 `@panic` and `unreachable` on untrusted paths (CWE-248)

- `src/types/vector.zig:78` — `Vector.at()` panics on OOB. **Documented** in docstring
  (`src/types/vector.zig:75`) and alternative `get()` returning `?T` is provided
  (`src/types/vector.zig:84`). Matches S3 "Closed" in `docs/SECURITY_GAP_ANALYSIS.md:30`.
  (confidence::confirmed, **informational**)
- All other `catch unreachable` occurrences are in test code (`std.fmt.bufPrint` with
  statically sized buffers) — no production path. (confidence::confirmed)

### 5.3 `undefined` memory (CWE-457, CWE-908)

All `undefined` uses in production code (not tests) are **write-before-read**:

| File:Line | Variable | Initialized at |
|-----------|----------|----------------|
| `src/types/network.zig:80` | `octets: [4]u8 = undefined` | written in the `parse` loop; invariant protected by `octet_index != 3` guard (line 105) before read |
| `src/types/network.zig:172` | `octets: [16]u8 = undefined` | all 16 bytes written before return |
| `src/types/network.zig:182` | `segs: [8]u16 = undefined` | loop `for (0..8)` writes all |
| `src/types/network.zig:542` | `octets: [6]u8 = undefined` | loop `for (0..6)` writes all |
| `src/types/url.zig:195-196, 209` | `authority/path/host: []const u8 = undefined` | all paths assign before read; verified |
| `src/types/vector.zig:107, 116, 125, 218` | `result: [N]T = undefined` | `for` loops iterate all N |

**Verdict:** no UB (confidence::confirmed). However, `src/types/vector.zig:218`
in `Vector(T,N).parse` has a weaker guarantee: if `count != N` the function
returns `InvalidDimension` **before** using `result` (line 234 check, line 235
return). Safe today. (confidence::confirmed)

### 5.4 Integer overflow in arithmetic (CWE-190)

- `src/types/range.zig:85-87` `Range(T).span = upper - lower` — documented S6
  in `docs/SECURITY_GAP_ANALYSIS.md:33`. `ReleaseSafe` panic, `ReleaseFast` wrap.
  No guard today. **Finding SAST-02** (low, `confidence::confirmed`, CWE-190).
- `src/types/vector.zig:106-139` `add/sub/scale/dot` on integer element types —
  documented S4 in `docs/SECURITY_GAP_ANALYSIS.md:31`. **Finding SAST-03** (low,
  `confidence::confirmed`, CWE-190).
- `src/types/network.zig:82,97` `current_value: u16 = 0 ... current_value * 10 + (ch - '0')` —
  bounded by `digit_count > 3` cap (line 96) so max <= 9999, fits u16. safe.

### 5.5 Slice-lifetime UAF risk (CWE-416)

`Url.raw`, `Url.scheme/host/path/query/fragment`, `Domain.raw` all store slices
into the caller-owned `input` buffer.

**Finding SAST-04** (medium, `confidence::confirmed`, CWE-416): `src/types/url.zig:37-38, 151-158`
and `src/types/url.zig:161`, `src/types/url.zig:41`. If a consumer frees or mutates
the input buffer while a `Url`/`Domain` value is still live, reads through the
stored slices are use-after-free or inconsistent-read. The library contract is
**not documented** in the public docstrings as a requirement ("Caller must keep
input alive for as long as any returned slice is in use"). The `Url` doc at
`src/types/url.zig:147-149` mentions "stored as slices into the original input
string" but does not explicitly state the lifetime obligation. **Action:**
docstring warning + an adversarial test that deliberately reuses the input
buffer post-parse.

Mentioned as rank 6 in the threat model (`docs/audit/security-inventory.md:124`).

### 5.6 Url userinfo / host parsing (CWE-601, CWE-918)

`src/types/url.zig:161-246`:

- **No `@` (userinfo) stripping.** Passing `http://evil.com@trusted.com/` sets
  `u.host = "evil.com@trusted.com"` because `lastIndexOfScalar(u8, authority, ':')`
  doesn't see the `@`, and nothing else splits on `@` (lines 222-229). A downstream
  HTTP client using `u.host` for TLS SNI/host header vs. a caller-readable "display"
  would see different hosts — classic **open-redirect / SSRF pivot**.
  **Finding SAST-05** (medium, `confidence::confirmed`, CWE-601/CWE-918).
  Mentioned in the threat model rank 3 (`docs/audit/security-inventory.md:121`) and
  in "Unknowns & Assumptions" (`docs/audit/security-inventory.md:134`).

- **No percent-decode / no normalization.** `%2e%2e/` in path passes through
  verbatim. Not a library bug by itself (library is decode-free by design), but
  worth a doctring note so callers know not to trust `url.path` for
  path-traversal checks without normalization.
  **Finding SAST-06** (low, `confidence::confirmed`, CWE-22 adjacent).

- **IPv6 without brackets.** `src/types/url.zig:224-226` uses
  `lastIndexOfScalar(u8, authority, ':')` so a bare `http://2001:db8::1/`
  is mis-parsed into `host="2001:db8:"` + `port=":1"` -> `InvalidPort`. Matches
  RFC 3986. Already documented in inventory (line 42). (confidence::confirmed,
  **informational**)

- **Control chars / whitespace in host.** No explicit reject of bytes like `\t`,
  `\n`, space. Scheme chars are validated (line 169-173) but the authority loop
  only enforces structure, not byte whitelist. A crafted host `evil.com\rGET /`
  would pass if a caller didn't also validate. **Finding SAST-07** (medium,
  `confidence::suspected`, CWE-93 / HTTP-request-smuggling precursor).
  Needs a fuzz input to confirm (the existing fuzz harness targets parser
  correctness; response-splitting is a consumer concern).

### 5.7 Domain — IDN / Punycode / homograph (CWE-1007)

`src/types/url.zig:112-114` — `isValidDomainChar` accepts ASCII alphanumeric + `-`.
Non-ASCII bytes are rejected. A caller that receives a Unicode domain name
must Punycode-encode it themselves (`xn--...`) before calling `Domain.parse`.
If a caller encodes and another caller does not, two logically identical
domains appear different. **Finding SAST-08** (low, `confidence::confirmed`, CWE-1007).
Mentioned in inventory rank 4 (`docs/audit/security-inventory.md:122`) and
assumption line 133. **Action:** docstring explicitly stating "ASCII-only;
callers are responsible for Punycode conversion of IDNs".

### 5.8 `Ipv4Addr.isPrivate` / `isLoopback` — SSRF semantics (CWE-918)

`src/types/network.zig:128-147`:

- `isLoopback` only checks `octets[0] == 127` — correct for `127.0.0.0/8`.
- `isPrivate` covers `10/8`, `172.16/12`, `192.168/16` — RFC 1918 correct.
- **Missing classes that a naive SSRF guard would also want:**
  - `169.254.0.0/16` — link-local (includes AWS/GCP metadata `169.254.169.254`). **CWE-918 CRITICAL for cloud deployments.**
  - `100.64.0.0/10` — carrier-grade NAT (RFC 6598)
  - `0.0.0.0/8` — "this host" (Linux accepts `0.0.0.0` -> localhost on some stacks)
  - `192.0.0.0/24`, `192.0.2.0/24`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`, `224.0.0.0/4`, `240.0.0.0/4`, `255.255.255.255/32` — reserved / benchmark / multicast / broadcast
- `Ipv6Addr` has only `isLoopback`; no `isPrivate`, no `isUniqueLocal` (fc00::/7),
  no `isLinkLocal` (fe80::/10). `toIpv4` returns mapped `::ffff:x.x.x.x` but
  does **not** flag `::ffff:127.0.0.1` or `::ffff:169.254.169.254` as loopback/link-local.
  A consumer using `IpAddr` as an SSRF gate can be pivoted by supplying
  `::ffff:169.254.169.254`.

**Finding SAST-09** (**high for consumers using this as an SSRF gate**,
`confidence::confirmed`, CWE-918). Consumers like a spatial DB or URL normalizer
that accept a domain-name input and resolve it, then check `.isPrivate()` /
`.isLoopback()`, are missing the metadata-service class, the IPv4-mapped IPv6
bypass, and the IPv6 private/link-local classes.

**Action:** add `isLinkLocal`, `isReserved`, `isUnspecified`, `isDocumentation`,
`isCgnat` (Ipv4Addr); add `isUniqueLocal`, `isLinkLocal`, `isMulticast`,
`isUnspecified`, and a unified `IpAddr.isPrivate` (including mapped v4);
and document that this set is **not** a drop-in SSRF allowlist — callers
must opt into the classes they care about. Alternatively, provide a
`isGloballyRoutable()` convenience that negates the union of dangerous classes.

### 5.9 Parser DoS / performance (CWE-400)

Every `parse()` is O(n) in input length but has **no input-length cap** (except
`Domain.parse` at `src/types/url.zig:43` which caps 253, and `Mac.parse` at
`src/types/network.zig:536` which requires exact 17). `Ipv4Addr.parse`,
`Ipv6Addr.parse`, `IpAddr.parse`, `Url.parse`, `Range.parse`, `Vector.parse`,
`LatLon.parse`, `LatLonAlt.parse`, `GeoPoint.parse`, `Subnet.parse` all walk
the full input. A 100 MB input to `Ipv4Addr.parse` walks 100 MB.

**Finding SAST-10** (low, `confidence::confirmed`, CWE-400): no library-side
length cap. Matches inventory rank 10 (line 128). The library's position
(caller enforces a cap) is reasonable; **action:** document in the top-level
docstring of each module: "callers should enforce a maximum input length
appropriate for their use case."

### 5.10 Wildcard / root namespace exposure

`src/root.zig:32-78` re-exports every public symbol by name (no
`pub usingnamespace`, no `@refAllDecls` leaking privates). Well-scoped.
(confidence::confirmed, **informational**)

### 5.11 Exported-but-undocumented invariants

| Symbol | File:Line | Missing invariant doc |
|--------|-----------|------------------------|
| `Url` fields | `src/types/url.zig:152-158` | Lifetime = caller's input buffer. See SAST-04. |
| `Domain.raw` | `src/types/url.zig:38` | Same as above. |
| `Subnet` fields | `src/types/network.zig:420-421` | `prefix_len` must be <= 32 (v4) / <= 128 (v6) — enforced only in `parse`, not when struct is built directly. See SAST-01. |
| `Range.initUnchecked` | `src/types/range.zig:40` | Doc says "without validating bounds ordering"; says nothing about NaN/Inf for floats. `contains`/`span`/`overlaps` behavior on NaN is unspecified (comparisons return false). Worth explicit doc. |
| `LatLon.initUnchecked` | `src/types/geographic.zig:58` | Same — accepts NaN/Inf; `haversineDistance` on NaN returns NaN. |
| `Vector.at` | `src/types/vector.zig:76` | Panic behavior documented. good. |

**Finding SAST-11** (low, `confidence::confirmed`, CWE-1053).

## 6. Language Audit — Zig-Specific

| Pattern | Instances | Verdict |
|---------|-----------|---------|
| Improper `undefined` on read paths | 0 in production code | safe (confidence::confirmed) |
| `unreachable` on untrusted input | 0 in production code | safe (confidence::confirmed) |
| `catch unreachable` in production | 0 (only in tests where buffer size is statically sufficient) | safe (confidence::confirmed) |
| `@panic` on untrusted input | 1 (`Vector.at`) — opt-in via documented OOB contract; safe alternative (`get`) provided | documented (confidence::confirmed) |
| Unchecked arithmetic on untrusted input | 2 (`Range.span`, `Vector.add/sub/scale/dot`) — both documented | tracked (confidence::confirmed) |
| `unsafe`/inline-asm blocks | 0 | safe (confidence::confirmed) |
| Wildcard imports in `root.zig` | 0 (explicit re-exports only) | safe (confidence::confirmed) |
| Allocator footprint in parsers | 0 (all parsers zero-alloc) | safe (confidence::confirmed) |
| FFI / `extern` boundaries | 0 | safe (confidence::confirmed) |

## 7. Shell / Dockerfile / IaC

No shell scripts (`*.sh`), no Dockerfiles, no Terraform/K8s manifests in this repo.
`.gitlab-ci.yml` has inline `bash` + `python3` in the install-zig template
(`.gitlab-ci.yml:39-77`). A manual review:

- Uses `curl -fsSL` + `sha256sum --check --strict` — good.
- Uses `${INDEX_FILE}` variable with `mktemp` — not a secret exposure.
- Python3 inline script reads env, prints hash. No code-injection surface (the
  env vars are set by the job, not user input).

No findings. (confidence::confirmed)

## 8. Findings Roll-up

| ID | Severity | File:Line | CWE | Confidence | Status vs ledger |
|----|----------|-----------|-----|------------|------------------|
| SAST-01 | Low | `src/types/network.zig:419-422, 469` | CWE-1284, CWE-190 | suspected | **new** (direct struct construction bypasses validation) |
| SAST-02 | Low | `src/types/range.zig:85-87` | CWE-190 | confirmed | duplicate of ledger S6 (closed via docstring) |
| SAST-03 | Low | `src/types/vector.zig:106-139` | CWE-190 | confirmed | duplicate of ledger S4 (closed via docstring) |
| SAST-04 | Medium | `src/types/url.zig:37-38, 147-158, 161` | CWE-416 | confirmed | **new** (slice-lifetime contract undocumented) |
| SAST-05 | Medium | `src/types/url.zig:161-246` | CWE-601, CWE-918 | confirmed | **new** (userinfo / `@` in authority) |
| SAST-06 | Low | `src/types/url.zig:161-246` | CWE-22 adj. | confirmed | **new** (no percent-decode; caller contract undocumented) |
| SAST-07 | Medium | `src/types/url.zig:209-230` | CWE-93 | suspected | **new** (no CTL-char reject in host) |
| SAST-08 | Low | `src/types/url.zig:41, 112-114` | CWE-1007 | confirmed | **new** (IDN/Punycode docstring gap) |
| SAST-09 | **High** (for SSRF-gate consumers) | `src/types/network.zig:128-147, 339, 345-361` | CWE-918 | confirmed | **new** (missing link-local, unique-local, mapped-v4 classes) |
| SAST-10 | Low | all `parse()` in `src/types/*.zig` | CWE-400 | confirmed | duplicate of inventory rank 10 |
| SAST-11 | Low | various (see Sec 5.11) | CWE-1053 | confirmed | **new** (invariant docstring gaps) |
| SUPPLY-01 | Low | `docs/SECURITY_GAP_ANALYSIS.md:34` vs `.gitlab-ci.yml:39-77` | CWE-829 | confirmed | ledger out-of-sync with implemented control |
| SUPPLY-02 | Informational | `.pre-commit-config.yaml` | — | confirmed | gitleaks absent from local hooks (CI only) |

### Severity counts

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 1 (SAST-09, conditional on consumer usage) |
| Medium | 3 (SAST-04, SAST-05, SAST-07) |
| Low | 7 |
| Informational | 2 |

## 9. Tools Not Available (gaps)

| Tool | Why missing | Impact |
|------|-------------|--------|
| trivy / grype / syft | not installed in environment | low — no runtime deps to scan |
| osv-scanner | not installed | low — no lockfile |
| checkov | not installed | low — no IaC |
| native Zig SAST | **none exist** | **medium** — relies on `zig build test` safety-check mode, fuzz, and manual review |
| SBOM generation | done by CI `sbom-generate@v1.7.1` | covered in CI |

## 10. Blockers

None for this run. Items a human reviewer should decide:

1. Whether to update `docs/SECURITY_GAP_ANALYSIS.md` S7 from "Won't Do" to "Closed via CI SHA-256 verify" (SUPPLY-01).
2. Whether to promote SAST-09 (SSRF semantics) to a P0 consumer-facing advisory now, before `Geode` (the stated consumer) adopts `.isPrivate()` as a gate.

## 11. Focus for security-reviewer (Phase 3)

Priority-ordered adversarial probes:

1. **SAST-09 / rank 2** — craft `Ipv4Addr.parse("169.254.169.254")`, `IpAddr.parse("::ffff:169.254.169.254")`, `IpAddr.parse("::ffff:127.0.0.1")`, feed each to a hypothetical `isSafeForOutboundRequest(ip)` and show the library helpers return `false` (i.e., "private=no, loopback=no") while the target is an SSRF-critical address. Draft an explicit allowlist API, not a deny-list.
2. **SAST-05 / rank 3** — `Url.parse("http://evil.com@trusted.com/api")` and confirm `u.host == "evil.com@trusted.com"`. Draft a `hasUserinfo()` helper and a `reject_userinfo: bool` parse option, or always split on the rightmost `@`.
3. **SAST-07** — fuzz `Url.parse` specifically for host bytes in `[0..0x1f] U { ' ', 0x7f }`. Confirm/deny whether a response-splitting payload survives.
4. **SAST-04 / rank 6** — write a deliberately adversarial "parse then free buffer then read host" test in `ReleaseSafe` to prove the documentation gap matters.
5. **SAST-01** — direct struct literal `Subnet{ .network=..., .prefix_len=200 }` + `.contains(addr)` and measure panic behavior in `ReleaseSafe` vs `ReleaseFast`.
6. **SAST-08** — cross-compare `Domain.parse("xn--e1afmkfd.xn--p1ai")` vs `Domain.parse("пример.рф")` — second rejects (good), first accepts (good) — but document the homograph pair `example.com` vs `еxample.com` (Cyrillic e) as a caller obligation.
