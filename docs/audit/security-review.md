# Adversarial Security Review -- advanced-types

- **Date:** 2026-04-18
- **Reviewer:** Phase 3 of `/codepros:audit` (security-review agent)
- **Scope:** Full repo, `/home/benji/src/devnw/zig/advanced-types`
- **Inputs (fresh, this audit):** `docs/audit/security-inventory.md`, `docs/audit/security-scan.md`, `docs/SECURITY_GAP_ANALYSIS.md` (prior ledger), `docs/audit/security-review.md` (prior review, replaced by this file), source under `src/types/`, `.gitlab-ci.yml`, `build.zig`, `build.zig.zon`, `SECURITY.md`, `.pre-commit-config.yaml`, `CODEOWNERS`.
- **Method:** Checklist-driven manual review. Every item below cites file:line from the **current tree** (commits through `f3adc69`). No external network calls, no product-code modifications, no exploitation attempts.
- **Redaction:** Exploit PoC outputs and step-by-step attack mechanics for the three previously-confidential items (SAST-09, SAST-01, SAST-05) remain redacted per prior release protocol. Those items are closed on `main`; fixes cited inline. All other findings are public.
- **Preserved IDs:** SEC/SAST/CI/SC/S\*/NEW IDs carry forward from `docs/SECURITY_GAP_ANALYSIS.md` and the prior `security-review.md`. Scanner-phase IDs (`SAST-PANIC-01`, `SAST-DOS-01`, `SAST-OVERFLOW-01`, `CI-SUP-01`, `CI-SUP-02`) are carried in verbatim.

---

## TL;DR -- Risk-Ranked Findings (current tree)

Risk = Impact (1-5) x Likelihood (1-5) x 4, capped at 100. Impact/Likelihood anchored to CVSS-style language; library has no auth, no I/O, no runtime deps, so all findings are consumer-mediated, CI-mediated, or developer-ergonomic.

| Rank | ID | Finding | Risk | Conf. | State |
|-----:|----|---------|-----:|-------|-------|
| 1 | **SAST-PANIC-01** | `Vector.at(i)` `@panic` on caller-controlled index | 24 | confirmed | Open (documented; `get()` available) |
| 2 | **SAST-DOS-01** | 8 of 11 parsers accept arbitrarily long input (linear-time, no cap) | 16 | confirmed | Open (hardening) |
| 3 | **CI-SUP-01** | macOS runner `brew install zig \|\| true` -- no SHA verify, no version pin | 16 | suspected | Open |
| 4 | **CI-SUP-02** | Windows runner `iwr ... zig.zip; Expand-Archive` -- no SHA verify | 16 | suspected | Open |
| 5 | **SAST-OVERFLOW-01** | `Range.span` / `Vector.add/sub/scale/dot` wrap silently in `ReleaseFast`/`Small` | 12 | confirmed (documented) | Accepted (documented in `root.zig:21-26` + per-fn docs) |
| 6 | **CI-CAT-01 / SC-01** | ci-catalog components `@v1.7.1` / `@v1.2.1` are floating tags (not SHA-pinned) | 12 | confirmed | Accepted won't-do (platform controls, commit `152d0f8`) |
| 7 | **CI-FUZZ-01** | Fuzz job skipped on default MR pipelines (schedule/web-manual only) | 12 | confirmed | Accepted (rank 10, tracked) |
| 8 | **NEW-REL-01** | No release-artifact provenance: unsigned tags, no SLSA attestation, no SBOM-as-release-asset (SBOM lives in pipeline artifacts) | 8 | suspected | New informational |
| 9 | **OP-OWNER-01** | `CODEOWNERS` single-owner `@benjiv`; account-compromise == repo-write | 8 | confirmed | Accepted (documented) |
| 10 | **CI-SECRETS-01** | Pre-commit has `detect-private-key` only; no local `gitleaks` hook (CI catches) | 4 | confirmed | Accepted |
| -- | **SAST-09** | IP classification missed link-local / CGNAT / mapped-v6 loopback / 0.0.0.0 | -- | closed | **Closed** on `main` (commit `a178648`) |
| -- | **SAST-05** | `Url.host` included userinfo (`evil.com@trusted.com`) | -- | closed | **Closed** on `main` (commit `f175133`) |
| -- | **SAST-01** | `Subnet.contains` OOB-panic/wrong-answer on bad `prefix_len` | -- | closed | **Closed** on `main` (commit `503c1f5`) |
| -- | **SAST-07** | Host accepted NUL/TAB/SPACE/CTL | -- | closed | **Closed** on `main` (commit `f175133`) |
| -- | **SAST-04** | `Url`/`Domain` lifetime contract missing on `parse()` docs | -- | closed | **Closed** on `main` (commit `5c97228`) |
| -- | **NEW-01** | `:0000080` port accepted | -- | closed | **Closed** on `main` (commit `f175133`) |
| -- | **NEW-02** | `Domain` has no IDN/Punycode | -- | won't-do | **Scoped won't-do** (commit `df972dd`, see `SECURITY.md:55-81`) |
| -- | S1-S7 | Prior historical findings (Vector/Range NaN/Inf, panic docs, Zig SHA-256) | -- | closed | All closed (see `docs/SECURITY_GAP_ANALYSIS.md:28-34`) |

**Blockers for release:** none confirmed. Every Critical/High class finding already landed a fix on `main`. Remaining items are hardening, CI-hygiene, or scoped-accepted.

---

## 1. Authentication & Authorization (N/A -- confirmed)

The artifact is a pure value-type parsing library. It has:

- no login / session / token issuance
- no tenancy concept; all types are stateless value structs
- no admin endpoints, no background workers, no message queues
- no filesystem, no allocator, no network (every parse path is zero-alloc; the only references to `std.mem.Allocator` are doc comments at `src/types/url.zig:47, 170` telling callers how to `dupe` if they want to own the bytes)
- `CODEOWNERS:3` `* @benjiv` -- single owner on GitLab; that is a **repository-admin** boundary, not a library-runtime one. Captured as **OP-OWNER-01** below.

All the "Auth/AuthZ" checklist items (missing middleware, BOLA/IDOR, multi-tenant leakage, admin priv-esc, session rotation, JWT validation) therefore have no applicable surface. Confirmed N/A.

## 2. Web / API Security (N/A -- confirmed)

No HTTP server, no RPC, no CORS/CSRF/TLS stack, no rate-limiter; nothing listens. The library exports value types and `parse()` helpers. Its **consumers** may use `Url.parse` + `IpAddr.parse` + `*.isSafeForOutboundFetch` as their SSRF gate -- the contract correctness of those predicates is reviewed in Section 3.

Confirmed N/A at the library layer; consumer obligations captured in Section 3.

## 3. Input Handling (per parser)

### 3.1 Findings table

| Finding | Severity | File:Line | Attack Scenario | CWE/OWASP | Confidence |
|---------|----------|-----------|------------------|-----------|-----------|
| **SAST-PANIC-01** `Vector.at(i)` panics on OOB | Medium (Risk 24) | `src/types/vector.zig:76-80` | Consumer forwards untrusted `usize` to `at()`. Any `i >= N` aborts the process (documented, but subtle -- `get()` is the safe variant). DoS primitive whenever the index is attacker-controlled. | CWE-248 (Uncaught Exception); CWE-754 | confirmed |
| **SAST-DOS-01** Unbounded parser input length | Low-Medium (Risk 16) | `Ipv4Addr.parse` `network.zig:78`, `Ipv6Addr.parse` `network.zig:214`, `IpAddr.parse` `network.zig:438`, `Subnet.parse` `network.zig:503`, `Url.parse` `url.zig:190`, `LatLon.parse` `geographic.zig:158`, `LatLonAlt.parse` `geographic.zig:211`, `GeoPoint.parse` `geographic.zig:296`, `Range(T).parse` `range.zig:107` | All linear-time (no quadratic blow-up), but no upper cap. Attacker who controls 10MB of input to `Url.parse` causes 10MB of scans across `indexOfScalar` / `validateHostChars` / etc. Not algorithmic DoS; memory/CPU amplification the library hands off to the caller. | CWE-400 (Uncontrolled Resource Consumption); OWASP A04:2021 | confirmed |
| **SAST-OVERFLOW-01** Integer wrap in `ReleaseFast` | Medium (Risk 12, documented) | `Range(T).span` `range.zig:85-87`; `Vector.add/sub/scale/dot/magnitudeSquared` `vector.zig:106-144` | Build-mode-dependent semantics. Consumer compiled `ReleaseSafe` sees panic; same bytes on `ReleaseFast` silently wrap. Downstream invariants (e.g. "`span` is non-negative") can be violated in prod. | CWE-190 (Integer Overflow) | confirmed, documented |
| **SSRF allowlist correctness** `Ipv4Addr.isSafeForOutboundFetch` + `Ipv6Addr.isSafeForOutboundFetch` | n/a (gate, not a bug) | `network.zig:155-171, 394-403` | Covers loopback, RFC 1918, 169.254/16, 100.64/10, 224/4, 240/4, 0/8, 255.255.255.255 (via 240/4), unspecified, link-local, ULA, multicast; v6 predicate re-delegates via `toIpv4` for `::ffff:*` smuggling. Tests at `network.zig:807-873` exercise 169.254.169.254, `::ffff:7f00:1`, etc. | CWE-918 (mitigation) | confirmed correct |
| **URL authority confusion** -- `evil.com@trusted.com` | Closed | `src/types/url.zig:242-246` | `lastIndexOfScalar('@')` splits userinfo (WHATWG last-`@` wins); host-only fed into allow-list decisions. Regression suite in `tests/parser_edge_cases.zig`. | CWE-601, CWE-918 | **closed** (SAST-05) |
| **Host control-byte rejection** | Closed | `url.zig:302-307` `validateHostChars` | Rejects bytes `< 0x21`, `0x7F`, and `< > " \`. Log-injection, request-smuggling, allow-list CTL-splitter bypass -- all closed. | CWE-93, CWE-20 | **closed** (SAST-07) |
| **Subnet prefix validation** | Closed | `network.zig:493-500, 541-589` | `Subnet.init(..) !Subnet` enforces family max; `contains` defensively returns `false` when a struct-literal caller bypasses `init`. Regression `Subnet.contains defends against out-of-range prefix_len` at `network.zig:1060-1074`. | CWE-1284, CWE-125, CWE-400 | **closed** (SAST-01) |
| **Port leading-zero rejection** | Closed | `url.zig:364-374` | `parsePortStrict` rejects `:01`, `:007` (single `:0` still allowed as bind wildcard). Cache-key divergence class closed. | CWE-20 | **closed** (NEW-01) |
| **IPv4-leading-zero semantics** | Accepted (documented) | `src/types/network.zig:77-110`; regression `tests/parser_edge_cases.zig:23-43` | `010.0.0.1` parses decimal `10.0.0.1` -- NOT octal. Documented to pin the decimal-only interpretation against CVE-2021-29921 / CVE-2021-29923 classes. Consumer must know the library never emulates libc octal. | CWE-20 (documented) | confirmed correct |
| **IPv6 `::` placement / duplication** | OK | `network.zig:221-258, 260-268` | `findDoubleColon` returns the first `::`; a second `::` produces a second group with `digit_count == 0` -> `error.InvalidFormat`. Boundary tests at `network.zig:797-805`. | -- | confirmed correct |
| **IPv4-mapped-v6 (`::ffff:a.b.c.d`) smuggling** | Closed | `network.zig:394-403, 407-423` | `Ipv6Addr.isSafeForOutboundFetch` calls `toIpv4()` and re-delegates; `::ffff:169.254.169.254` / `::ffff:7f00:1` / `::ffff:0:0` all rejected. Note: `Ipv6Addr.parse` does **not** accept dotted-quad form inside a v6 literal (only hex groups), so the mapped form must arrive as `::ffff:<hi>:<lo>` -- this is the mapped form that real stacks produce, covered by tests at `network.zig:858-867`. | CWE-918 | confirmed correct |
| **Domain IDN / Punycode** | Won't-do (scoped) | `url.zig:112-124`; `SECURITY.md:55-81` | ASCII-only by design. Consumers must pre-encode to `xn--` before `Domain.parse`. Homograph/confusables defense is explicitly an application-layer concern. | CWE-1007 | closed-as-wontdo (NEW-02) |
| **Slice-lifetime UAF on `Url`/`Domain`** | Closed | `url.zig:40-47, 163-170` | Dedicated "# Lifetime" doc block on both `Domain` and `Url` states caller must keep `input` alive; `dupe` to transfer ownership. No runtime guard (Zig library contract). | CWE-416 (mitigation via docs) | **closed** (SAST-04) |
| **Range empty vs single-element** | OK | `range.zig:28-37, 89-92` | `Range.init(5, 5)` is legal (`isPoint`); `Range.init(10, 1)` -> `InvalidBounds`. Empty ranges are not representable (intentional). Consumer confusion risk is ergonomic, not security. | -- | confirmed correct |
| **LatLon pole / Inf / NaN** | OK (with caveat) | `geographic.zig:99-107, 179-188` | NaN rejected explicitly; `+Inf > 90.0` triggers `LatitudeOutOfRange` incidentally. `LatLonAlt.init` has explicit `isInf(alt)` check. Prior review suggested adding explicit `isInf(lat/lon)` for clarity -- low priority; behaviour is correct. | CWE-20 | confirmed correct |
| **`Vector.parse` Inf/NaN reject** | OK | `vector.zig:239-245` `parseElement` | `isNan(val) or isInf(val)` -> `error.InvalidCharacter`. | CWE-20 | confirmed correct |

### 3.2 Spot-checks against the adversarial prompt list

- **Oversized input (every parser)** -- see SAST-DOS-01 above.
- **Malformed UTF-8 in `Domain`** -- `Domain.isValidDomainChar` at `url.zig:123-125` is `std.ascii.isAlphanumeric` plus `-`. Any byte `>= 0x80` is rejected as `InvalidCharacter`. UTF-8 smuggling is impossible; consumer must pre-encode per NEW-02.
- **IPv4-in-IPv6 edge cases (`::ffff:1.2.3.4`)** -- `Ipv6Addr.parse` accepts only hex groups (it does not honour dotted-quad inside a v6 literal). Any real-world dotted-quad mapped form must be pre-converted by the caller or arrive as hex (`::ffff:a9fe:a9fe`). `toIpv4()` detects mapped form correctly. `isSafeForOutboundFetch` re-delegates. Smuggling attempts are closed.
- **URL authority confusion** (userinfo, bracketed v6, port) -- SAST-05 closed; bracketed-v6 handled at `url.zig:253-262`; port strictness at `url.zig:364-374`; multi-`@` WHATWG at `url.zig:242-246` with test at `url.zig:742-746`.
- **Subnet mask off-by-one** -- `Subnet.init` rejects `prefix_len > max_prefix`; `containsV4` explicitly branches on `== 0`, `== 32`, and in-range cases; `containsV6` caps `full_bytes = prefix_len / 8` after guarding `prefix_len <= 128` (the prior OOB-slice bug is fixed, `SAST-01`).
- **LatLon pole math** -- `haversineDistance` at `geographic.zig:127-144` uses `atan2(sqrt(a), sqrt(1-a))`, stable at poles. No `acos(1)` domain issue.
- **Range empty vs single-element** -- see table row. `isPoint` documents the semantic.
- **Vector NaN / Inf** -- `parseElement` rejects both; `init()` does not (compile-time array literal, the caller controls), which is fine for trusted construction.

### 3.3 SAST-PANIC-01 -- deeper look (why it stays rank 1)

`Vector.at(i)` calls `@panic("Vector index out of bounds")` when `i >= N`. The panic is explicit, documented, and `get(i) ?T` is offered as the safe alternative. But:

1. The panic is **reachable from a caller** with a trivial `vec.at(user_supplied_index)`. That is a DoS primitive end-to-end once any consumer does that, and the panic message is the only diagnostic.
2. Zig has no exception mechanism that would let downstream code recover; the process aborts.
3. The fuzz harness at `tests/fuzz.zig` does not exercise `at()` with attacker indices (fuzz targets are parsers, not random indices into parsed vectors). The invariant "no parser panics on bad input" is upheld; the invariant "no API panics on legal-input / legal-index" is enforced at the type-system level (indices are `usize`), but `Vector.at` breaks it by design for the `>= N` branch.

**Remediation options** (pick one):

- **A. Change `at` signature** to return `T` with `std.debug.assert(i < N)` (safety-check; still panics under ReleaseSafe, but documented as a precondition). Cleaner contract.
- **B. Keep `@panic` but downgrade the doc** to name the panic as a bug-class (precondition violation); leave `get()` as the untrusted-index path. Requires callers to audit every `at()`.
- **C. Remove `at` entirely** in favour of `get()`; the `?T` rethrow is noisy for trusted code.

Option A is the smallest behavioural delta with the best safety posture (safety-check in Debug/ReleaseSafe, undefined-behaviour in ReleaseFast -- but Zig programmers expect that). Recommend **A**.

### 3.4 SAST-DOS-01 -- deeper look

No algorithmic DoS (linear scans throughout; `std.mem.indexOf*` is bounded). The concern is consumer-side: a library parser is typically called from a request handler that hands in `body.len` bytes. With no cap:

- 10MB URL through `Url.parse` does 6-8 linear scans of 10MB (find `://`, `#`, `?`, `/`, `lastIndexOfScalar('@')`, `validateHostChars`). Tens-of-milliseconds per request per core.
- 10MB into `Ipv4Addr.parse` is rejected on the first non-digit but still scans until it finds it.
- Only `Mac.parse` (exact `== 17`), `Domain.parse` (`<= 253`), and `Vector(T,N).parse` (bounded by `N`) enforce a structural cap.

**Remediation**: add a `const MAX_INPUT` per parser, or a single `root.MAX_PARSE_INPUT = 8192` that `parse()` checks up-front. RFC-derived caps:

- `Ipv4Addr`: 15 bytes (`255.255.255.255`)
- `Ipv6Addr`: 45 bytes (longest canonical form with embedded v4)
- `Subnet`: 49 bytes (IPv6 + `/128`)
- `Mac`: 17 (already)
- `Domain`: 253 (already)
- `Url`: 8192 (common proxy cap)
- `LatLon/LatLonAlt/GeoPoint`: 64-128 bytes
- `Range/Vector`: sensible caller cap (Vector is already structurally bounded; Range is a small-text integer parse)

Fixing this is a 10-line defensive patch. Low-Medium severity because any well-behaved HTTP server already caps body size; the library cannot assume that.

### 3.5 What would confirm the remaining suspected items

- `SAST-DOS-01`: benchmark run on a 10MB `Url.parse` input measuring real ns/op; quantify the amplification factor. Scanner says "linear"; a ns/op number converts that into a concrete ops/sec DoS ceiling.

## 4. Supply Chain

| Finding | Severity | File:Line | Attack Scenario | CWE | Confidence |
|---------|----------|-----------|-----------------|-----|-----------|
| **CI-CAT-01 / SC-01** floating `@v1.7.1` ci-catalog components | Medium (Risk 12, accepted) | `.gitlab-ci.yml:10-24` | Owner of `gitlab.com/devnw/ci-catalog` (same org) force-pushes to tag `v1.7.1`; every downstream pipeline runs new code on next execution. Platform-team policy applies platform controls instead of per-repo SHA pinning (commit `152d0f8`). Accept risk. | CWE-829 | confirmed, accepted |
| **NEW-REL-01** Zig tarball TOFU per run | Low-Medium (Risk 8) | `.gitlab-ci.yml:39-77` | `index.json` and the tarball are both served from `ziglang.org` HTTPS. `sha256sum --check` verifies the tarball against a shasum **from the same fetch chain**. Compromise of the ziglang CDN could taint both simultaneously. Mitigation: mirror Zig tarballs to an internal artifact store with out-of-band known-good hashes; or monitor the Zig signing key (if ever published). Acceptable for now given `ziglang.org` is a well-known, HTTPS-pinned origin and CI uses company-tagged runners. | CWE-494, CWE-829 | suspected |
| **CI-SUP-01** macOS `brew install zig \|\| true` | Medium (Risk 16) | `.gitlab-ci.yml:242-243` | No SHA verify, no version pin, `\|\| true` swallows brew errors so a corrupted download falls through to `zig version`. A brew-tap compromise or a transient brew failure both result in "unknown Zig runs the tests on macOS." Only mitigation today is that the job is allow-failure + rules-manual + runs on company-tagged runners -- but a malicious `brew` path would still execute real code on those runners. | CWE-829, CWE-494 | suspected |
| **CI-SUP-02** Windows `iwr ... zig.zip; Expand-Archive` | Medium (Risk 16) | `.gitlab-ci.yml:259-276` | No SHA verify on the Windows tarball; pulls directly from `ziglang.org` without comparing against `index.json`. Diverges from the audited Linux install path. Same runner-execution concern as CI-SUP-01. | CWE-494 | suspected |
| `build.zig.zon` runtime deps | N/A (clean) | `build.zig.zon:6` | `.dependencies = .{}` -- nothing to verify. Confirmed by manual read and by `build.zig` having zero `b.dependency` / `b.lazyDependency` calls. | -- | confirmed |
| `zig-format@v1.2.1` | Medium (grouped under SC-01) | `.gitlab-ci.yml:17` | Same floating-tag concern as SC-01. | CWE-829 | accepted |

### 4.1 Proposed remediation for CI-SUP-01 / CI-SUP-02

Bring both platforms to parity with Linux's install pattern. For macOS (assuming bash-compatible shell on the runner):

```sh
# same scheme as Linux: fetch index.json, extract shasum, verify tarball
curl -fsSL "https://ziglang.org/download/index.json" -o /tmp/zig-index.json
EXPECTED=$(python3 -c 'import json,os; idx=json.load(open("/tmp/zig-index.json")); print(idx["'"$ZIG_VERSION"'"]["'"$ZIG_ARCH"'-macos"]["shasum"])')
curl -fsSL "https://ziglang.org/download/$ZIG_VERSION/zig-$ZIG_ARCH-macos-$ZIG_VERSION.tar.xz" -o zig.tar.xz
echo "$EXPECTED  zig.tar.xz" | shasum -a 256 -c -
tar -xJf zig.tar.xz
export PATH="$PWD/zig-$ZIG_ARCH-macos-$ZIG_VERSION:$PATH"
```

Windows (PowerShell):

```powershell
$idx = Invoke-RestMethod "https://ziglang.org/download/index.json"
$expected = $idx."$env:ZIG_VERSION"."x86_64-windows".shasum
Invoke-WebRequest "https://ziglang.org/download/$env:ZIG_VERSION/zig-x86_64-windows-$env:ZIG_VERSION.zip" -OutFile zig.zip
$actual = (Get-FileHash zig.zip -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { throw "Zig SHA mismatch: $actual != $expected" }
Expand-Archive zig.zip -DestinationPath . -Force
$env:PATH = "$PWD\zig-x86_64-windows-$env:ZIG_VERSION;$env:PATH"
```

Both scripts close the divergence and leave only the shared TOFU-on-ziglang.org risk (already captured as NEW-REL-01).

## 5. Infrastructure (`.gitlab-ci.yml` review)

| Finding | Severity | File:Line | Attack Scenario | CWE/OWASP | Confidence |
|---------|----------|-----------|-----------------|-----------|-----------|
| **CI-FUZZ-01** Fuzz skipped on MR default pipelines | Medium (Risk 12, accepted) | `.gitlab-ci.yml:341-360` | `rules:` is `schedule` or `web (manual)` only; a forked MR crafted to pass default triggers skips fuzz. A regression that introduces a parser panic could merge. Accept risk because fuzz is 60s budget and runs nightly on schedule; `test-parser-edges` (`.gitlab-ci.yml:192-200`) covers the specific regressions. | OWASP A05:2021 | confirmed accepted |
| **Secrets in CI YAML** | None | whole file | No `$GITLAB_TOKEN`, no `$CI_JOB_TOKEN` reference, no user-declared secrets in `variables:`. Only variable is `ZIG_VERSION: "0.16.0"` (`.gitlab-ci.yml:26-27`). | -- | confirmed clean |
| **Runner tagging** | Informational | `.gitlab-ci.yml:5-7` | All jobs default to `company` tag -- trusted runner pool. macOS / Windows / aarch64 jobs use their own platform tags. Untagged public runners are never used. | -- | confirmed |
| **Job permissions** | N/A | entire file | GitLab CI does not have `permissions:` blocks in the GitHub Actions sense. Job tokens are scoped by GitLab's default protected-branch + tag-signing controls, which rely on group-level settings (not in-repo). Treat as "inherit from project". | -- | confirmed |
| **Python inline in install template** | Low | `.gitlab-ci.yml:61-69` | 9-line `python3 -c` extracts shasum from `index.json`. No `pip install`. Python is installed via `apt-get install -y python3` one line above. Debian package pin trust. Acceptable. | -- | confirmed |
| **Coverage job** | Informational | `.gitlab-ci.yml:307-332` | `allow_failure: true`, report-only (per Q31 / GAP-0011). Not a gate; accepted. | -- | confirmed |
| **Pre-commit** | Informational | `.pre-commit-config.yaml:28` | Only `detect-private-key` hook for secrets; CI has the full `security-gitleaks@v1.7.1` component. Defense-in-depth gap (CI-SECRETS-01), not exploitable. | -- | confirmed |

## 6. Ops / Release

| Finding | Severity | File:Line | Attack Scenario | CWE | Confidence |
|---------|----------|-----------|-----------------|-----|-----------|
| **NEW-REL-01** No release-artifact provenance | Low (Risk 8) | whole repo | Released via `release-semantic@v1.7.1` (`.gitlab-ci.yml:24`). Tags are not GPG- or Sigstore-signed (not visible in `.gitlab-ci.yml`; no Git notes block in repo config). SBOM is generated (`sbom-generate@v1.7.1`) and scanned (`sbom-scan@v1.7.1`) but only exposed as pipeline artifacts, not attached to tagged releases. No SLSA provenance, no in-toto attestation. Consumer has no cryptographic anchor to verify "this `.tar.gz` from `tag vX.Y.Z` is what CI produced." Mitigation: (1) GPG-sign tags, (2) attach SBOM as a release asset, (3) add a SLSA-L2 provenance doc (GitLab has a first-party generator). | CWE-345 (Insufficient Verification of Data Authenticity), OWASP A08:2021 | suspected |
| **OP-OWNER-01** Single code owner | Low (Risk 8) | `CODEOWNERS:3` | `* @benjiv` -- single reviewer, single approver. Account-compromise boundary == repo-write boundary. No 2-person review rule for security-sensitive areas (`src/types/url.zig`, `src/types/network.zig`, `.gitlab-ci.yml`). Accepted for a small OSS library today; revisit when contributor base grows. | CWE-653 | confirmed |
| **SECURITY.md disclosure policy** | OK | `SECURITY.md:9-36` | Email contact, 48h ack SLA, severity-bound resolution SLAs. Meets minimum bar. | -- | confirmed |
| **Audit logging / alerting / IR** | N/A | -- | Library has no runtime surface to log. GitLab pipeline logs cover CI events. No application-layer ops to alert on. | -- | confirmed N/A |

## 7. Confidential findings (private issue tracker)

The three items below were filed as confidential issues and are already patched on `main`. No new confidential findings emerged in this review. Kept here only for completeness so the tracker can re-verify references:

| ID | Issue | Commit | Status |
|----|-------|--------|--------|
| SAST-09 | SSRF gap: missing link-local / CGNAT / mapped-v6 loopback / 0.0.0.0 | `a178648` | Closed; public API doc lives in `SECURITY.md:46-53` |
| SAST-05 | `Url.host` included userinfo | `f175133` | Closed |
| SAST-01 | `Subnet.contains` bad-prefix panic/wrong-answer | `503c1f5` | Closed |

No new finding in this pass requires a confidential private issue. `SAST-PANIC-01`, `SAST-DOS-01`, `CI-SUP-01/02`, `NEW-REL-01`, `OP-OWNER-01` are all safe to file publicly because: (a) they are hardening, not bypasses; (b) the panic paths are documented API contract; (c) the supply-chain items concern the development pipeline, not consumer exploitation.

## 8. Ledger reconciliation (`docs/SECURITY_GAP_ANALYSIS.md`)

| Ledger row | Current state | Action |
|-----------|---------------|--------|
| S1 Vector.parse Inf/NaN | Closed (`vector.zig:244`) | keep closed |
| S2 FloatRange NaN bounds | Closed (`range.zig:29-34`) | keep closed |
| S3 Vector.at OOB panic | "Closed: `get()` added" -- but the `at()` panic itself remains the rank-1 finding of this review (SAST-PANIC-01). The safe alternative exists; the panic remains. | **Update ledger**: split into S3 (closed, `get()` added) and SAST-PANIC-01 (open, panic contract) |
| S4 Int overflow docs | Closed | keep closed |
| S5 LatLonAlt NaN/Inf alt | Closed (`geographic.zig:186`) | keep closed |
| S6 Range.span overflow docs | Closed (`range.zig:82-87`) | keep closed |
| S7 CI SHA-256 verify | Closed (ledger drift already corrected) | keep closed |
| SAST-09 | Closed (`a178648`) | keep closed |
| SAST-05 | Closed (`f175133`) | keep closed |
| SAST-01 | Closed (`503c1f5`) | keep closed |
| SAST-07 | Closed (`f175133`) | keep closed |
| SAST-04 | Closed (`5c97228`) | keep closed |
| NEW-01 | Closed (`f175133`) | keep closed |
| NEW-02 | Won't-do (scoped) | keep |
| SC-01 / CI-CAT-01 | Won't-do (`152d0f8`, platform controls) | keep |
| -- | -- | **Add** SAST-PANIC-01 (Medium, Risk 24) -- currently in scanner report only |
| -- | -- | **Add** SAST-DOS-01 (Low-Medium, Risk 16) -- currently in scanner report only |
| -- | -- | **Add** SAST-OVERFLOW-01 (documented, Risk 12) -- currently in scanner report only |
| -- | -- | **Add** CI-SUP-01 (Medium, Risk 16) |
| -- | -- | **Add** CI-SUP-02 (Medium, Risk 16) |
| -- | -- | **Add** CI-FUZZ-01 (Medium, Risk 12, accepted) -- inventory rank 10 |
| -- | -- | **Add** NEW-REL-01 (Low, Risk 8) -- new |
| -- | -- | **Add** OP-OWNER-01 (Low, Risk 8) -- new |

## 9. Inputs for security-issue-tracker (Phase 4)

```yaml
issues:
  - id: SEC-SAST-PANIC-01
    title: "Vector.at(i) panics on out-of-bounds caller-controlled index"
    severity: medium
    risk: 24
    confidential: false
    cwe: [248, 754]
    files:
      - src/types/vector.zig:76-80
    recommendation: replace @panic with std.debug.assert(i < N) (option A); document precondition; prefer get() in untrusted-index contexts.

  - id: SEC-SAST-DOS-01
    title: "8 parsers accept arbitrarily long input (linear-time, no cap)"
    severity: low-medium
    risk: 16
    confidential: false
    cwe: [400]
    files:
      - src/types/network.zig:78,214,438,503
      - src/types/url.zig:190
      - src/types/geographic.zig:158,211,296
      - src/types/range.zig:107
    recommendation: add per-parser MAX_INPUT (RFC-derived caps); or a single root.MAX_PARSE_INPUT.

  - id: SEC-SAST-OVERFLOW-01
    title: "Range.span / Vector arithmetic wrap in ReleaseFast/Small"
    severity: medium
    risk: 12
    confidential: false
    cwe: [190]
    files:
      - src/types/range.zig:85-87
      - src/types/vector.zig:106-144
    state: accepted-documented
    recommendation: keep documented; optional: add checked-variant helpers for callers who want overflow-safe arithmetic across all build modes.

  - id: SEC-CI-SUP-01
    title: "macOS runner installs Zig via 'brew install zig || true' with no SHA verify"
    severity: medium
    risk: 16
    confidential: false
    cwe: [829, 494]
    files:
      - .gitlab-ci.yml:242-243
    recommendation: install Zig by fetching ziglang.org/index.json + tarball + SHA-256 verify (parity with Linux install template).

  - id: SEC-CI-SUP-02
    title: "Windows runner installs Zig via iwr+Expand-Archive with no SHA verify"
    severity: medium
    risk: 16
    confidential: false
    cwe: [494]
    files:
      - .gitlab-ci.yml:259-276
    recommendation: verify SHA-256 against ziglang.org/index.json before Expand-Archive (parity with Linux install template).

  - id: SEC-NEW-REL-01
    title: "No release provenance: unsigned tags, no SLSA attestation, SBOM not attached to releases"
    severity: low
    risk: 8
    confidential: false
    cwe: [345]
    files:
      - .gitlab-ci.yml:24 (release-semantic)
      - .gitlab-ci.yml:20-21 (sbom-generate / sbom-scan)
    recommendation: (1) GPG- or Sigstore-sign tags, (2) attach SBOM as release asset, (3) add SLSA-L2 provenance job.

  - id: SEC-OP-OWNER-01
    title: "Single CODEOWNERS owner -- account-compromise == repo-write"
    severity: low
    risk: 8
    confidential: false
    cwe: [653]
    files:
      - CODEOWNERS:3
    recommendation: add a second reviewer for security-sensitive paths (src/types/url.zig, src/types/network.zig, .gitlab-ci.yml).

  - id: SEC-CI-FUZZ-01
    title: "Fuzz job skipped on default MR pipelines"
    severity: medium
    risk: 12
    confidential: false
    state: accepted
    files:
      - .gitlab-ci.yml:341-360
    recommendation: consider promoting fuzz to a 30s auto-run on MR (current 60s on schedule is fine).

  - id: SEC-CI-SECRETS-01
    title: "No pre-commit gitleaks hook (CI-only coverage)"
    severity: informational
    risk: 4
    confidential: false
    files:
      - .pre-commit-config.yaml
    recommendation: add a gitleaks hook to .pre-commit-config.yaml for local-loop defense in depth.
```

## 10. What would confirm the remaining suspected items

| ID | How to confirm |
|----|----------------|
| SAST-DOS-01 | Benchmark `Url.parse` with 10MB input in `ReleaseSafe`; record ns/byte and ops/sec. If ops/sec for a 10MB input drops below a defensible floor, promote to Medium. |
| CI-SUP-01 / CI-SUP-02 | Actually dispatch a macOS / Windows pipeline and inspect the captured Zig tarball's SHA-256. If tarballs do ship with any out-of-band hash validation we missed, downgrade or close. |
| NEW-REL-01 | Inspect a produced GitLab release asset tree after the next `release-semantic` run; verify whether tags are signed and whether SBOM/provenance are attached. |
| NEW-REL-01 (Zig upstream advisory) | Before next release, query Zig's advisory channel (GitHub `/repos/ziglang/zig/security-advisories` or the Zig mailing list) and record the check in release notes. |

## 11. Non-findings explicitly cleared this pass

- No allocator misuse (no allocator crosses the library boundary at all; doc comments only at `url.zig:47, 170`).
- No `@truncate`, `@bitCast`, `@ptrCast`, `@alignCast` anywhere under `src/` -- 16 `@intCast` sites all range-checked (scanner Section 4.1).
- No `@setRuntimeSafety(false)`.
- No secrets in the tree (`gitleaks` 0 findings across 26 commits, 579.7 KB).
- No Go / Python / Rust / JS runtime deps (`.dependencies = .{}` in `build.zig.zon:6`; no `go.mod`, no `requirements.txt`, no `Cargo.toml`, no `package.json`).
- No Dockerfile, no shell scripts, no network listener.
- No `semgrep` finding in the scoped run (47 rules, 9 files, 0 findings).
