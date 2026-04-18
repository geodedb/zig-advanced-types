# Adversarial Security Review — advanced-types

- **Date:** 2026-04-18
- **Reviewer:** Phase 3 of `/codepros:audit` (security-review agent)
- **Scope:** Full repo, `/home/benji/src/devnw/zig/advanced-types`
- **Inputs:** `docs/audit/security-inventory.md`, `docs/audit/security-scan.md`, `docs/SECURITY_GAP_ANALYSIS.md`, source under `src/types/`, `.gitlab-ci.yml`, `build.zig.zon`
- **Method:** Checklist-driven manual review + in-repo PoCs (`zig run`) against every SAST-NN finding. Nothing below is speculation; every "confirmed" line was produced by actual execution on the pre-fix tree.
- **Safety:** Zero external network calls. PoCs were temporary files removed after execution.
- **Redaction (2026-04-18):** Exploit PoC outputs and step-by-step attack scenarios for the confidential findings (SAST-09, SAST-01, SAST-05) have been redacted before committing this file to the public repository. Fixes landed on `main` in commits `a178648` (SAST-09), `503c1f5` (SAST-01), `f175133` (SAST-05). Structural analysis, code line citations, recommendations, and ledger reconciliation are preserved. The full unredacted review was retained locally outside the committed tree.

## TL;DR (Risk-Ranked Top Findings)

| ID | Finding | Risk | Confidence | Ownership |
|----|---------|------|------------|-----------|
| SAST-09 | IP classification missing link-local (cloud metadata), CGNAT, ULA, IPv4-mapped-v6 loopback, `0.0.0.0` | **Critical** (consumer-dependent) | confirmed (PoC) | API design + confidential candidate |
| SAST-01 | `Subnet.contains` panics (IPv6) / returns wrong answer (IPv4) when `prefix_len` is out of range | **High** | confirmed (OOB panic reproduced) | Fix + confidential candidate |
| SAST-05 | `Url.host` includes userinfo → `evil.com@trusted.com` spoofing | **High** | confirmed (PoC) | Fix + confidential candidate |
| SAST-07 | Host accepts NUL, TAB, SPACE, and other controls | **Medium** | confirmed (PoC) | Fix |
| NEW-01 | Port parser accepts leading zeros (`0000080` → 80) | Low | confirmed | Fix / documented behavior |
| NEW-02 | `Domain` has no IDN/Punycode/homograph handling | Medium | confirmed (design gap) | API note |
| SAST-04 | Caller-owned buffer lifetime not documented on `Url`/`Domain` | Medium | confirmed | Docs |
| SC-01 | CI-catalog components pinned to floating `@v1.7.1` tags | Medium | confirmed | SHA-pin or ledger-accept |
| S7 | Ledger says "Won't Do" for Zig SHA-256 verify; CI actually implements it | Doc-drift | confirmed | Ledger update |

Items keep the SAST-NN IDs from Phase-2 handoff. NEW-NN are emergent findings from this phase.

---

## Methodology

1. Re-read every SAST finding with the source open.
2. For each, wrote a minimum-viable PoC in the repo root and ran `zig run`.
3. Cross-checked parsers for classes Semgrep cannot analyze (Zig) — `Url.parse`, `Domain.parse`, `Ipv4Addr.parse`, `Ipv6Addr.parse`, `Subnet.parse`, `Vector.parse`, `Range.parse`, `LatLon.parse`, `LatLonAlt.parse`.
4. Reviewed `.gitlab-ci.yml` for supply-chain and integrity posture.
5. Reconciled `docs/SECURITY_GAP_ANALYSIS.md` against observed code.

---

## 1. Network classification: SAST-09 (Critical)

### 1.1 Confirmed gaps

PoC output redacted. Summary: four in-repo PoCs confirmed that pre-fix `Ipv4Addr.isPrivate`/`isLoopback` and `Ipv6Addr.isLoopback` returned `false` for representative link-local, CGNAT, IPv4-mapped-v6 loopback, and unspecified addresses. Fixed in commit `a178648`.

### 1.2 Code

- `src/types/network.zig:128-130` — `Ipv4Addr.isLoopback` checks only `octets[0] == 127`. Correct for 127/8 literal form, **but loopback can also arrive as `::ffff:7f00:0001`** after an `Ipv6Addr.toIpv4` downcast; any consumer that checks v6 first will miss it.
- `src/types/network.zig:132-141` — `Ipv4Addr.isPrivate` covers only RFC 1918 (10/8, 172.16/12, 192.168/16). Missing:
  - `127.0.0.0/8` loopback (deliberately split but consumers usually want a single "do not fetch" gate)
  - `169.254.0.0/16` link-local — **AWS/GCP/Azure cloud metadata endpoint `169.254.169.254`**
  - `100.64.0.0/10` CGNAT (RFC 6598)
  - `0.0.0.0/8` "this host on this network" (RFC 1122 §3.2.1.3) — host software typically treats `0.0.0.0` as loopback on Linux TCP connect
  - `192.0.0.0/24`, `192.0.2.0/24`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24` (reserved / documentation)
  - `224.0.0.0/4` multicast (has `isMulticast` but not combined into a safety predicate)
  - `240.0.0.0/4` reserved / future use
  - `255.255.255.255/32` limited broadcast
- `src/types/network.zig:339-341` — `Ipv6Addr.isLoopback` only matches `::1` exactly. Missing:
  - `::ffff:0:0/96` IPv4-mapped with embedded v4 loopback (`::ffff:127.0.0.1`)
- `Ipv6Addr` has **no** `isPrivate` / `isLinkLocal` / `isUniqueLocal` / `isMulticast` / `isUnspecified`. Missing ranges:
  - `fe80::/10` link-local (the v6 analogue of 169.254)
  - `fc00::/7` ULA (the v6 analogue of RFC 1918)
  - `ff00::/8` multicast
  - `::/128` unspecified
  - `2001:db8::/32` documentation
  - `64:ff9b::/96` NAT64

### 1.3 Attack scenario (SSRF, consumer-side)

Attack walkthrough redacted. Class: CWE-918 (SSRF) exploiting a consumer-side deny-list built on the pre-fix predicates. Fix in `a178648` introduces `isSafeForOutboundFetch` on both `Ipv4Addr` and `Ipv6Addr` with IPv4-mapped-v6 downcast, closing all four bypass classes.

### 1.4 Recommendation (API design)

Two options, pick one and document:

**Option A — Keep primitives narrow, add safety predicate.** Preferred; avoids breaking current semantics:

```zig
/// Returns true if this address is in a range that should not be reachable
/// from the public Internet. Covers loopback, RFC1918 private, link-local
/// (incl. cloud metadata 169.254.169.254), CGNAT, multicast, broadcast,
/// and all reserved/documentation/unspecified ranges. Use this as the
/// SSRF deny-list for outbound fetches from user-supplied URLs.
pub fn isSafeForOutboundFetch(self: Ipv4Addr) bool { ... }
```

And an equivalent `Ipv6Addr.isSafeForOutboundFetch` that also downcasts `::ffff:` to `Ipv4Addr` before delegating. Then `IpAddr.isSafeForOutboundFetch` unwraps the union.

**Option B — Expand `isPrivate` + add missing predicates.** Rename existing `isPrivate` to `isRfc1918` (or leave + document narrow scope), and add:

- `isLinkLocal`, `isCgnat`, `isReserved`, `isDocumentation`, `isUnspecified`, `isBroadcast`
- `Ipv6Addr.isUniqueLocal`, `isLinkLocal`, `isMulticast`, `isUnspecified`, `isDocumentation`, `isMapped4` (plus `toIpv4` already exists)

Option A is smaller, safer-by-default, and communicates intent. Recommend **A** with the word "SSRF" in the doc so future consumers find it via grep. The renaming discussed in the user's prompt (`isPrivate` → `isLoopbackOrPrivate`) is less preferred — it still doesn't convey "safe to fetch from the Internet-exposed service" and ties two concerns together.

**Must also:** when `Ipv6Addr.isSafeForOutboundFetch` is added, it must call `toIpv4()` first and delegate, so `::ffff:169.254.169.254` is caught.

### 1.5 Confidentiality

Confidential candidate — SSRF exploit path should be filed privately until patched.

---

## 2. Subnet.contains mis-handles out-of-range prefix_len: SAST-01 (High)

### 2.1 Confirmed behavior

PoC output redacted. Summary: three in-repo PoCs confirmed that a `Subnet` struct-literal constructed with an out-of-range `prefix_len` (two IPv4 variants and one IPv6 variant) produced either a silently-wrong `contains` answer or an OOB slice panic on the IPv6 path. Fixed in commit `503c1f5` via `Subnet.init(..) !Subnet` with per-family validation and defensive `contains` behavior.

### 2.2 Why it matters

- `Subnet` is `pub` with `pub` fields (no hidden invariants). `Subnet.parse` validates, but nothing prevents a caller from building a `Subnet{...}` literal (tests do this too) with arbitrary `prefix_len`.
- IPv4 path: `src/types/network.zig:467` uses `if (self.prefix_len >= 32) return net4.eql(addr4);`, swallowing any `prefix_len > 32` and returning a plausible-looking answer that silently masks the bug.
- IPv6 path: `network.zig:482-487` computes `full_bytes = prefix_len / 8` unbounded and slices `octets[0..full_bytes]` → panic in Debug/ReleaseSafe; UB in ReleaseFast. Remote-triggerable crash if any consumer ever exposes a "build Subnet programmatically" API.

### 2.3 Attack scenario

Attack walkthrough redacted. Class: DoS (CWE-125/400 — remote-triggerable panic on IPv6 path) and logic-bypass (CWE-1284 — silent wrong answer on IPv4 path) when untrusted code paths can influence `prefix_len`. Fix in `503c1f5` eliminates both.

### 2.4 Recommendation

Three concrete fixes, recommend all:

- Make `Subnet` fields `const` and require construction via `init(network: IpAddr, prefix_len: u8) !Subnet` that validates family-specific max prefix (32 for v4, 128 for v6).
- Alternatively keep public fields but clamp in `contains`: `if (self.prefix_len > max_for_family) return false;` (but this lies to the caller and loses the error; prefer the constructor).
- Add a `Subnet.validate(self) !void` helper for callers that hand-build.

**Severity upgrade**: The Phase-2 handoff lists this as "Low" (CWE-1284/190 suspected). Based on the confirmed OOB panic reproducible in 5 lines, the correct rating is **High**.

### 2.5 Confidentiality

Confidential candidate — panic + silent-wrong-answer combo is a denial-of-service and logic-bypass path.

---

## 3. URL parser: userinfo not stripped (SAST-05) — High

### 3.1 Confirmed

PoC output redacted. Summary: in-repo PoC confirmed that `Url.parse` on an authority containing userinfo (`user@host`) left the `@`-bearing composite in `Url.host`, violating the RFC 3986 §3.2 split. Fixed in commit `f175133` via last-`@`-wins userinfo handling in `Url.parse`.

### 3.2 Code

`src/types/url.zig:207-230`. The authority-splitting logic takes everything left of the rightmost `:` (for the port) or the whole authority (if none) as `host`. RFC 3986 §3.2 defines `authority = [userinfo "@"] host [":" port]`. This parser has no userinfo branch.

### 3.3 Impact

Impact classes (exploit detail redacted): allowlist bypass when consumer code inspects `Url.host`/`Url.raw` directly; open-redirect divergence between parser view and browser view; CWE-601 (open redirect), CWE-918 (SSRF lateral), CWE-20.

### 3.4 Recommendation

Strip userinfo during parse, do **not** store it silently:

```zig
// After authority is isolated:
if (std.mem.indexOfScalar(u8, authority, '@')) |at| {
    // Option A: reject (strict)
    return ParseError.InvalidFormat;
    // Option B: capture separately and expose as u.userinfo: ?[]const u8
    // (with a loud doc comment that userinfo MUST NOT be used for auth decisions)
    _ = at;
}
```

Prefer **Option A** unless userinfo is a real use case. If B, rename to mirror `port: ?u16` style and document the security caveat in the same comment.

### 3.5 Confidentiality

Confidential candidate — concrete SSRF/phishing bypass.

---

## 4. URL parser: no CTL/whitespace rejection in host (SAST-07) — Medium

### 4.1 Confirmed

PoC output redacted. Summary: pre-fix `Url.parse` accepted NUL, TAB, SPACE in the host segment (three PoCs); CRLF was incidentally rejected but through the wrong error code. Fixed in commit `f175133` by adding an explicit reg-name char validation loop (rejects bytes `< 0x21`, `0x7F`, and `< > " \`).

### 4.2 Impact

- **Log injection / dashboard spoofing.** Host strings are commonly written to structured logs; NUL/TAB embedded in the host name can truncate or mis-render them.
- **Request-smuggling-adjacent.** If the host is reserialized into a new HTTP request (e.g., reverse-proxy rewrite), embedded SP/TAB breaks header framing — CWE-93 class.
- **Auth bypass via CTL-splitter confusion.** Combined with SAST-05, a CTL-byte-bearing host string could slip past allow-list matchers that treat CTL bytes as terminators (exploit string redacted).

### 4.3 Recommendation

Between `host = authority[0..colon]` (or the bracketed v6 block) and the `host.len == 0` check at `url.zig:232`, add:

```zig
for (host) |c| {
    // RFC 3986 host = IP-literal / IPv4address / reg-name.
    // reg-name is unreserved + sub-delims + pct-encoded. Never control or space.
    if (c < 0x21 or c == 0x7F or c == ' ' or c == '<' or c == '>' or c == '"' or c == '\\') {
        return ParseError.InvalidCharacter;
    }
}
```

Similar sweep should run on the full input after `://` (before splitting) for CRLF/NUL, to close log-injection everywhere, not just in `host`.

### 4.4 Confidence: confirmed. CWE-93 / CWE-20

---

## 5. Caller-owned buffer lifetime (SAST-04) — Medium

### 5.1 Observation

`Url` and `Domain` store `[]const u8` slices directly into caller input:

- `src/types/url.zig:37-38` — `Domain.raw`
- `src/types/url.zig:147-158` — `Url` fields (`raw`, `scheme`, `host`, `path`, `query`, `fragment`)

The module-level doc at `url.zig:5-8` states "standalone value types that store slices into the original input (no allocation for parsing)". **However**, no per-method doc on `parse()` spells out the lifetime obligation: the input must outlive every field of the returned value. A caller using a stack buffer or a short-lived arena will produce dangling slices without any compile or runtime diagnostic.

### 5.2 Impact

Use-after-free. CWE-416. In Zig this typically manifests as reading garbage (or the next heap allocation), not a crash — easy to miss in testing. Consumer code that parses a URL from an HTTP body, drops the buffer, then reads `u.host` is a silent bug waiting to happen.

### 5.3 Recommendation

Add an explicit doc block on `Url.parse` and `Domain.parse`:

```zig
/// IMPORTANT: The returned value stores slices into `input`. The caller
/// MUST ensure `input` outlives every use of the returned value. To make
/// a Url or Domain owned, copy the bytes into your own allocator and
/// call parse on the copy.
```

Optionally offer `parseOwned(allocator, input)` that dupes the string internally.

### 5.4 Confidence: confirmed (API contract gap)

---

## 6. NEW-01: Port parser quirks — Low

### 6.1 Confirmed

```text
Url.parse("http://a.com:0000000000000000080/p") -> port = 80 (accepted)
Url.parse("http://a.com:+80/p")                  -> error.InvalidPort (rejected — good)
```

`std.fmt.parseInt(u16, "00000...80", 10)` accepts leading zeros. Zero-length port was already handled (`parsePort` returns `null` for empty, mapped to `InvalidPort`).

### 6.2 Impact

Low. Tools that canonicalize URLs for dedup keys (e.g., a URL cache, a CDN origin hash) will see `...:80/` and `...:0000080/` as distinct by `u.raw` but equal by `u.port`. Depending on direction of comparison, cache poisoning or cache miss. Not exploitable in isolation.

### 6.3 Recommendation

Reject leading zeros or ensure `Url.raw` is normalized. Low priority; document or fix during next URL pass.

---

## 7. NEW-02: Missing IDN/Punycode handling in `Domain` — Medium

### 7.1 Observation

`Domain.isValidDomainChar` at `url.zig:112-114` accepts only ASCII alphanumeric + hyphen. This **correctly** rejects raw UTF-8 bytes in domain labels — good. But it **does not** validate or decode Punycode (`xn--...`). Consumers relying on `Domain` for UI display or security comparison are vulnerable to:

- **Homograph attacks** via labels like `xn--80ak6aa92e.com` (аррӏе.com) looking like `apple.com` when decoded for display.
- **Mixed-script or confusable label** detection is entirely outside this library's scope; consumers need to know that.

### 7.2 Impact

Medium. Phishing-style deception when the library is used to validate domains that are later displayed to users. CWE-1007 (visually distinct but identifying information).

### 7.3 Recommendation

Add a doc caveat on `Domain`:

```zig
/// Domain labels are validated as ASCII (letters/digits/hyphen). Internationalized
/// Domain Names (IDN) must already be Punycode-encoded (xn--...). This type does
/// NOT decode Punycode, does NOT detect homograph/confusable-script attacks, and
/// should not be trusted for UI display of external domain strings. Consumers
/// that show domains to users should apply a separate confusables check.
```

Consider an optional `Domain.isIDN(self) bool` helper that detects `xn--` labels, to let callers route those to a richer decoder.

---

## 8. Parsers: DoS and malformed-input review

Every parser against the length/DoS/trailing-data checklist:

| Parser | Trailing data | Length DoS | NaN/Inf | Notes |
|--------|---------------|-----------|---------|-------|
| `Vector.parse` (`src/types/vector.zig:211-236`) | split-on-comma; blank trailing token rejected via `tok.len == 0` | O(n) single-pass, bounded by `N` elements | Rejected (vector.zig:244) | Good |
| `Range.parse` (`src/types/range.zig:107-125`) | trimmed; commas counted; only integer types | O(n); `parseInt` is bounded by T width | Guarded at `Range.init` for floats | Good |
| `LatLon.parse` / `LatLonAlt.parse` (`geographic.zig:106-206`) | rejects non-parentheses, validates ranges | O(n); `parseFloat` is bounded | NaN for lat/lon rejected via `init`; Inf checked for altitude; **lat/lon Inf is not explicitly rejected** — but `Inf > 90.0` is true so `LatitudeOutOfRange` fires, caught incidentally. Worth an explicit check for clarity. | Suggest adding `isInf` to lat/lon guards |
| `Ipv4Addr.parse` (`network.zig:77-110`) | `digit_count > 3` overflow guard | bounded | — | Good |
| `Ipv6Addr.parse` (`network.zig:190-234`) | No explicit max length; theoretically a 1M-char input scans linearly. Inner loops bounded by `max_groups`; pre-scan for `::` is O(n). 5000-char PoC returns in microseconds — not a practical DoS. | Linear, not quadratic | — | Hardening: add `if (input.len > 45) return error.InvalidFormat;` (longest valid IPv6 with embedded v4 is 45 chars) |
| `Subnet.parse` (`network.zig:426-458`) | validated | — | — | Good |
| `Mac.parse` (`network.zig:534-558`) | exact 17-char requirement | — | — | Good |
| `Domain.parse` (`url.zig:41-62`) | 253-char cap, 63-char label cap | bounded | — | Good |
| `Url.parse` (`url.zig:161-246`) | No max input length; linear scan. Not a practical DoS at <1MB. | linear | — | Consider documenting that inputs over ~8KB are the caller's problem |

**Verdict:** no practical DoS. Ipv6 and Url parsers could add a sanity-cap on input length as hardening (low priority).

---

## 9. Supply chain (Phase 2 validated + expanded)

### 9.1 CI-catalog component pinning

`.gitlab-ci.yml:10-24` uses `@v1.7.1` floating tags across 7 components from the `devnw/ci-catalog` group:

| Component | Ref | Notes |
|-----------|-----|-------|
| `security-sast` | `@v1.7.1` | mutable tag |
| `security-dependency-scanning` | `@v1.7.1` | mutable tag |
| `security-secrets` | `@v1.7.1` | mutable tag |
| `security-gitleaks` | `@v1.7.1` | mutable tag |
| `zig-format` | `@v1.2.1` | mutable tag |
| `sbom-generate` | `@v1.7.1` | mutable tag |
| `sbom-scan` | `@v1.7.1` | mutable tag |
| `release-semantic` | `@v1.7.1` | mutable tag |

**Risk:** any owner/maintainer of `gitlab.com/devnw/ci-catalog` can re-tag `v1.7.1` post-hoc; every downstream pipeline runs new code on next execution. Standard tag-mutability supply-chain risk (CWE-829).

**Recommendation:** pin to commit SHA (`@<40-char-sha>`) or a signed release. If SHA-pinning is rejected for maintenance burden, document the risk in the ledger as accepted with rationale (same-org trust boundary).

### 9.2 Zig install SHA-256 verification

`.gitlab-ci.yml:39-77` downloads `index.json` from `ziglang.org` over HTTPS, extracts `shasum`, downloads the tarball, verifies SHA-256. Solid TOFU-per-run: trust rooted in `ziglang.org`'s HTTPS cert. Recommend noting that the `index.json` fetch is itself TOFU.

### 9.3 Zig 0.16.0 advisory check

Offline — no CVE database locally. Phase-2 note (suspected-clean) stands. **Recommendation**: before each release, run `gh api /repos/ziglang/zig/security-advisories` (or subscribe to the Zig security mailing list) and record the check in release notes.

### 9.4 pre-commit hooks

`.pre-commit-config.yaml` pins hooks to specific `rev: vX.Y.Z`, but no gitleaks hook is registered locally (only in CI). Low priority — see Phase-2 note.

---

## 10. Ledger reconciliation (`docs/SECURITY_GAP_ANALYSIS.md`)

| Ledger entry | Current state | Action |
|--------------|--------------|--------|
| S1 Vector.parse Inf/NaN | closed — confirmed at `vector.zig:244` | **keep closed** |
| S2 FloatRange NaN bounds | closed — confirmed at `range.zig:30-34` | **keep closed** |
| S3 Vector.at OOB panic | closed — `get()` added as safe alternative | **keep closed** |
| S4 integer overflow docs | closed — documented | **keep closed** |
| S5 LatLonAlt NaN/Inf alt | closed — confirmed at `geographic.zig:151` | **keep closed** |
| S6 Range.span overflow docs | closed — documented at `range.zig:83-87` | **keep closed** |
| S7 CI download checksum | listed "Won't Do" — **actually implemented** at `.gitlab-ci.yml:39-77` | **update ledger**: Closed, verified SHA-256 via upstream index |
| — | — | **Add** SAST-01, severity High (upgraded from Low) |
| — | — | **Add** SAST-05, severity High |
| — | — | **Add** SAST-07, severity Medium |
| — | — | **Add** SAST-09, severity Critical (consumer-dependent) |
| — | — | **Add** SAST-04, severity Medium (docs) |
| — | — | **Add** NEW-02 (Domain IDN), severity Medium |
| — | — | **Add** SC-01 (CI-catalog SHA pinning), severity Medium |

---

## 11. Confidential-issue candidates (do not file publicly)

| ID | Reason |
|----|--------|
| SAST-09 | Concrete SSRF bypass to cloud metadata; describe exploit privately until patched |
| SAST-01 | Remote-triggerable OOB panic + silent-wrong-answer |
| SAST-05 | Concrete bypass of authority allowlists |

Non-confidential (can be public issues): SAST-04, SAST-07, NEW-01, NEW-02, SC-01, and the S7 ledger drift.

---

## 12. Inputs for security-issue-tracker (Phase 4)

```yaml
issues:
  - id: SEC-SAST-09
    title: "Ipv4Addr.isPrivate/isLoopback and Ipv6Addr.isLoopback miss critical SSRF ranges"
    severity: critical
    confidential: true
    cwe: [918, 1327]
    files:
      - src/types/network.zig:128-147
      - src/types/network.zig:339-361
    recommendation: add isSafeForOutboundFetch() that covers link-local, CGNAT, ULA, multicast, reserved, broadcast, IPv4-mapped-v6 loopback, 0.0.0.0

  - id: SEC-SAST-01
    title: "Subnet.contains panics (v6) / returns wrong answer (v4) on out-of-range prefix_len"
    severity: high
    confidential: true
    cwe: [1284, 125, 400]
    files:
      - src/types/network.zig:461-506
      - src/types/network.zig:419-422
    recommendation: validate prefix_len on construction; require init(); reject > 32 for v4 and > 128 for v6 at field-set time.

  - id: SEC-SAST-05
    title: "Url.parse accepts userinfo as part of host (allowlist bypass)"
    severity: high
    confidential: true
    cwe: [601, 918, 20]
    files:
      - src/types/url.zig:207-230
    recommendation: strip or reject userinfo in authority.

  - id: SEC-SAST-07
    title: "Url.parse accepts NUL, TAB, SPACE in host"
    severity: medium
    confidential: false
    cwe: [93, 20]
    files:
      - src/types/url.zig:209-230
    recommendation: reject bytes < 0x21, 0x7F, and disallowed reg-name chars in host.

  - id: SEC-SAST-04
    title: "Url/Domain lifetime obligation not documented on parse()"
    severity: medium
    confidential: false
    cwe: [416]
    files:
      - src/types/url.zig:41
      - src/types/url.zig:161
    recommendation: add explicit lifetime doc on parse(); consider parseOwned(allocator, input).

  - id: SEC-NEW-02
    title: "Domain has no IDN/Punycode/homograph handling"
    severity: medium
    confidential: false
    cwe: [1007]
    files:
      - src/types/url.zig:37-115
    recommendation: document non-IDN scope; consider isIDN helper.

  - id: SEC-SC-01
    title: "CI-catalog components pinned to floating @v1.7.1 tags"
    severity: medium
    confidential: false
    cwe: [829]
    files:
      - .gitlab-ci.yml:10-24
    recommendation: pin to commit SHA or sign releases.

  - id: SEC-S7-DRIFT
    title: "SECURITY_GAP_ANALYSIS.md lists S7 as Won't Do; CI implements SHA-256 verify"
    severity: low
    confidential: false
    files:
      - docs/SECURITY_GAP_ANALYSIS.md:34
      - .gitlab-ci.yml:39-77
    recommendation: mark S7 Closed with implementation reference.
```

---

## 13. What would confirm the remaining suspected items

Every SAST-NN above is now **confirmed** by in-repo PoCs. The two residual suspected-only items are:

- **Zig 0.16.0 CVE clean.** Confirm via `gh api /repos/ziglang/zig/security-advisories` (or similar) in a networked environment before release.
- **CI-catalog component integrity.** Confirm by comparing the current content of `v1.7.1` against a known-good commit; or switch to SHA pinning to make the question moot.
