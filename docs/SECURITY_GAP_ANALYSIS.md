# Security Gap Analysis

Last updated: 2026-04-18

## Threat Model Summary

- **Nature:** Pure value-type parsing library, zero dependencies, no I/O
- **Attack surface:** 12 `parse()` functions accepting untrusted `[]const u8`
- **Trust boundary:** Untrusted string input -> parse() -> validated value types
- **Consumer:** Geode database (spatial/vector DB)

## Automated Scan Results

| Tool | Findings |
|------|----------|
| gitleaks | 0 |
| trufflehog | 0 |
| trivy (fs + config) | 0 |
| grype | 0 |
| semgrep | 0 |
| checkov | 0 failed (8 passed) |
| **Total automated** | **0** |

## Manual Findings

| # | Finding | Severity | Risk | CWE | Status | Issue | Resolution / Action |
|---|---------|----------|------|-----|--------|-------|---------------------|
| S1 | Vector.parse accepts Inf/NaN | Medium | 32 | CWE-20 | **Closed** | — | Added `isNan`/`isInf` check after `parseFloat` in `parseElement` |
| S2 | FloatRange accepts NaN bounds | Medium | 32 | CWE-20 | **Closed** | — | Added NaN/Inf check in `Range.init()` for float types |
| S3 | Vector.at() panics on OOB index | Low | 12 | CWE-248 | **Closed** | — | Added `get()` method returning `?T`; documented `at()` panic behavior |
| S4 | Integer overflow in Vector arithmetic | Low | 8 | CWE-190 | **Closed** | — | Added doc comments to `add`/`sub`/`scale`/`dot` documenting overflow behavior per build mode |
| S5 | LatLonAlt altitude accepts NaN/Inf | Low | 12 | CWE-20 | **Closed** | — | Added `isNan`/`isInf` check for altitude in `LatLonAlt.init()` |
| S6 | Range.span() overflow at type boundaries | Low | 8 | CWE-190 | **Closed** | — | Added doc comment warning about overflow for integer ranges spanning full type width |
| S7 | CI downloads Zig without checksum | Low | 16 | CWE-829 | **Closed** | — | SHA-256 verified against `index.json` in `.gitlab-ci.yml:39-77` (verified 2026-04-18; ledger previously said "Won't Do" — drift corrected in Phase 4 review) |
| SAST-09 | IP classification misses SSRF ranges (cloud metadata 169.254.169.254, CGNAT 100.64/10, IPv4-mapped-v6 loopback, 0.0.0.0) | **Critical** | 80 | CWE-918, CWE-1327 | **Closed 2026-04-18** (a178648) | [#35 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/35) | `isSafeForOutboundFetch(self)` shipped on v4/v6 covering link-local, CGNAT, ULA, multicast, reserved, broadcast; v6 delegates via `toIpv4()` for `::ffff:` mapped. Tests in `src/types/network.zig:818-860`. |
| SAST-05 | `Url.parse` accepts userinfo as part of host (`evil.com@trusted.com`) | **High** | 64 | CWE-601, CWE-918, CWE-20 | **Closed 2026-04-18** (f175133) | [#42 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/42) | `lastIndexOfScalar(u8, authority, '@')` splits userinfo from host at `src/types/url.zig:242-246` (WHATWG last-@-wins); parser-edges regression suite covers `evil.com@trusted.com`. |
| SAST-01 | `Subnet.contains` panics (v6) / wrong-answer (v4) on out-of-range `prefix_len` | **High** | 48 | CWE-1284, CWE-125, CWE-400 | **Closed 2026-04-18** (503c1f5) | [#39 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/39) | `Subnet.init(net, prefix_len) !Subnet` validator + defensive returns in `containsV4`/`containsV6`; linked to quality **Q26** (same fix). Tests in `src/types/network.zig:1042-1056`. |
| SAST-07 | `Url.parse` accepts NUL/TAB/SPACE/control chars in host | Medium | 36 | CWE-93, CWE-20 | **Closed 2026-04-18** (f175133) | [#43](https://gitlab.com/devnw/zig/advanced-types/-/work_items/43) | `validateHostChars` rejects bytes `< 0x21`, `0x7F`, `< > " \` at `src/types/url.zig:302-307`. |
| SC-01 | CI-catalog components pinned to floating `@v1.7.1` tags | Medium | 32 | CWE-829 | **Won't Do 2026-04-18** (152d0f8) | [#47](https://gitlab.com/devnw/zig/advanced-types/-/work_items/47) | System-policy override: CI/CD hash and Docker tag pinning handled via different controls (platform-team supply-chain). See `docs/audit/gap-close-blockers.md`. |
| SAST-04 | `Url`/`Domain` lifetime obligation not documented on `parse()` | Medium | 24 | CWE-416 | **Closed 2026-04-18** (5c97228) | [#44](https://gitlab.com/devnw/zig/advanced-types/-/work_items/44) | Explicit slice-lifetime contract doc block added to `Url`/`Domain` parse APIs; linked to quality **Q25** (same fix). |
| NEW-02 | `Domain` has no IDN/Punycode/homograph handling (ASCII-only validation) | Medium | 24 | CWE-1007 | **Won't Do 2026-04-18** (df972dd) | [#45](https://gitlab.com/devnw/zig/advanced-types/-/work_items/45) | Scoped won't-do: Domain is ASCII-only by design; IDN/Punycode is a feature, not a fix. Documented in SECURITY.md. |
| NEW-01 | Port parser accepts leading zeros (`0000080` -> 80) | Low | 8 | CWE-20 | **Closed 2026-04-18** (f175133) | [#46](https://gitlab.com/devnw/zig/advanced-types/-/work_items/46) | Leading-zero guard added at `src/types/url.zig:368` — `if (s.len > 1 and s[0] == '0') return InvalidPort`. |

## Summary

| Status | Count |
|--------|-------|
| Closed (S1–S7 historical) | 7 |
| Closed 2026-04-18 (SAST-01, SAST-04, SAST-05, SAST-07, SAST-09, NEW-01) | 6 |
| Won't Do 2026-04-18 (SC-01, NEW-02) | 2 |
| **Total** | **15** |

## Immediate Actions Required

**All three pre-release patches landed on 2026-04-18.**

1. **SAST-09** (Critical, Risk 80) — **Closed** (a178648): `isSafeForOutboundFetch` API shipped. [#35 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/35)
2. **SAST-05** (High, Risk 64) — **Closed** (f175133): userinfo split via `lastIndexOfScalar`. [#42 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/42)
3. **SAST-01** (High, Risk 48) — **Closed** (503c1f5): `Subnet.init` validator + defensive containsV4/V6 returns. [#39 (confidential)](https://gitlab.com/devnw/zig/advanced-types/-/work_items/39); coordinated with quality **Q26** (same fix).

**Secret rotations required:** None. No leaked credentials detected (`gitleaks` and `trufflehog` both 0).

## Risk Score Formula

`Risk = Impact (1-5) x Likelihood (1-5) x 4`, capped at 100.

- Impact: 5 RCE/privesc/cross-tenant - 4 PII/credential leak/authn bypass - 3 data tampering - 2 info leak - 1 hardening
- Likelihood: 5 pre-auth remote trivial - 4 remote constrained - 3 requires auth - 2 rare misconfig - 1 theoretical
