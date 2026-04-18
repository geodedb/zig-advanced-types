# Security Gap Analysis

Last updated: 2026-04-18 (post 5th Gap Closure Pass, HEAD `5df73d3`)

## Threat Model Summary

- **Nature:** Pure value-type parsing library, zero dependencies, no I/O.
- **Attack surface:** 12 `parse()` functions accepting untrusted `[]const u8`.
- **Trust boundary:** Untrusted string input -> parse() -> validated value types.
- **Consumer:** Geode database (spatial/vector DB).

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

## Summary — current state (post 5th pass)

| State | Count |
|------|------:|
| Closed this pass | 5 |
| Accepted (documented, tracker-closed) | 4 |
| Won't-do | 1 (CI-CAT-01 / SC-01) |
| **Total current** | **10** |

All items from the prior "Open" column are now Closed or Accepted; every corresponding GitLab issue is `state=closed`.

### Top 5 risks (all now Closed / Accepted)

1. `SAST-PANIC-01` (Risk 24) — **Closed** (`630a9c8`).
2. `SAST-DOS-01` (Risk 16) — **Closed** (`154c8f0`).
3. `CI-SUP-01` (Risk 16) — **Closed** (`aa31b0d`).
4. `CI-SUP-02` (Risk 16) — **Closed** (`7431a67`).
5. `SAST-OVERFLOW-01` (Risk 12) — **Accepted** (`f11bcc5` finalised status).

## Closed this pass (5th Gap Closure Pass)

| # | Finding | State | Evidence | Commit | Issue |
|---|--------|------|----------|--------|-------|
| SAST-PANIC-01 | `Vector.at(i)` `@panic` on OOB caller-controlled index | **Closed** | `src/types/vector.zig:84` (`std.debug.assert`); regression test at `:354` | `630a9c8` | [#65](https://gitlab.com/devnw/zig/advanced-types/-/issues/65) |
| SAST-DOS-01 | 8 parsers accept arbitrarily long input | **Closed** | `MAX_INPUT` caps (Url=8192, Ipv4=45, Ipv6=45, IpAddr=45, Subnet=49, Mac=17, Geo=128, Range=128); `InputTooLong` error; 9 regression tests | `154c8f0` | [#66](https://gitlab.com/devnw/zig/advanced-types/-/issues/66) |
| CI-SUP-01 | macOS Zig install no SHA verify | **Closed** | `.gitlab-ci.yml:39-72, 251-302` — `index.json` fetch + `shasum -a 256 --check --strict` | `aa31b0d` | [#67](https://gitlab.com/devnw/zig/advanced-types/-/issues/67) |
| CI-SUP-02 | Windows Zig install no SHA verify | **Closed** | `.gitlab-ci.yml:311-331` — PowerShell `Get-FileHash -Algorithm SHA256` | `7431a67` | [#68](https://gitlab.com/devnw/zig/advanced-types/-/issues/68) |
| NEW-REL-01 | No release-artifact provenance (unsigned tags, SBOM not attached) | **Closed (configuration-gated)** | `.gitlab-ci.yml:486-523` — `release-sign-tag` + `release-attach-sbom` jobs guarded by `$CI_COMMIT_TAG`. Requires `RELEASE_GPG_PRIVATE_KEY` + `RELEASE_GPG_FINGERPRINT` platform-ops variables to emit signed output. | `c949582` | [#71](https://gitlab.com/devnw/zig/advanced-types/-/issues/71) |

### Configuration-gated note (NEW-REL-01)

The repository-side implementation is complete: tag-pipeline jobs land signed git tags (`git tag -s`) and attach the `gl-sbom-*.cdx.json` CycloneDX SBOM to the GitLab release assets. Branch/MR pipelines stay green until the signing key is provisioned because the jobs are gated on `$CI_COMMIT_TAG` and fail-fast if `$RELEASE_GPG_PRIVATE_KEY` is missing. **Platform-ops ask:** provision the two masked CI variables (`RELEASE_GPG_PRIVATE_KEY`, `RELEASE_GPG_FINGERPRINT`) before cutting the first signed release.

## Accepted (tracker-closed, documented)

These items were graded `status::accepted` in `docs/audit/security-review.md`. Commit `f11bcc5` finalises the tracker state (previously `state=open` with `status::accepted` label). No code change.

| # | Finding | State | Evidence | Issue |
|---|--------|------|----------|-------|
| SAST-OVERFLOW-01 | `Range.span` / `Vector` arithmetic wrap in ReleaseFast/Small | Accepted | `src/root.zig:21-26` (mode-behaviour doc); `src/types/range.zig:85-87`; `src/types/vector.zig:106-144` | [#69](https://gitlab.com/devnw/zig/advanced-types/-/issues/69) |
| CI-FUZZ-01 | Fuzz job schedule/manual only | Accepted | `.gitlab-ci.yml:341-360` | [#70](https://gitlab.com/devnw/zig/advanced-types/-/issues/70) |
| OP-OWNER-01 | Single CODEOWNERS | Accepted | `CODEOWNERS:3` | [#72](https://gitlab.com/devnw/zig/advanced-types/-/issues/72) |
| CI-SECRETS-01 | No pre-commit gitleaks hook | Accepted (CI coverage) | `.pre-commit-config.yaml:28` | [#73](https://gitlab.com/devnw/zig/advanced-types/-/issues/73) |

## Won't-Do (unchanged)

| # | Finding | Reason | Issue |
|---|--------|--------|-------|
| CI-CAT-01 / SC-01 | ci-catalog `@v1.7.1` floating tags | Platform-controls decision — supply-chain pinning handled at the ci-catalog layer by platform-team, not per-consumer repo. Documented in `docs/audit/gap-close-blockers.md`. | [#47](https://gitlab.com/devnw/zig/advanced-types/-/issues/47) |

## Closed — Historical (pre-5th pass)

| # | Finding | Severity | Risk | CWE | Closed | Issue | Fix |
|---|---------|----------|-----:|-----|--------|-------|-----|
| SAST-09 | IP classification misses SSRF ranges (169.254.169.254, CGNAT 100.64/10, IPv4-mapped-v6 loopback, 0.0.0.0) | Critical | 80 | CWE-918, CWE-1327 | 2026-04-18 (`a178648`) | [#35](https://gitlab.com/devnw/zig/advanced-types/-/issues/35) (confidential) | `isSafeForOutboundFetch(self)` on v4/v6; tests in `src/types/network.zig:818-860` |
| SAST-05 | `Url.parse` accepts userinfo as part of host | High | 64 | CWE-601, CWE-918, CWE-20 | 2026-04-18 (`f175133`) | [#42](https://gitlab.com/devnw/zig/advanced-types/-/issues/42) (confidential) | `lastIndexOfScalar(u8, authority, '@')` WHATWG last-@-wins split |
| SAST-01 | `Subnet.contains` panics / wrong-answer on OOB `prefix_len` | High | 48 | CWE-1284, CWE-125, CWE-400 | 2026-04-18 (`503c1f5`) | [#39](https://gitlab.com/devnw/zig/advanced-types/-/issues/39) (confidential) | `Subnet.init(net, prefix_len) !Subnet` validator + defensive containsV4/V6 |
| SAST-07 | `Url.parse` accepts NUL/TAB/SPACE/control chars in host | Medium | 36 | CWE-93, CWE-20 | 2026-04-18 (`f175133`) | [#43](https://gitlab.com/devnw/zig/advanced-types/-/issues/43) | `validateHostChars` |
| SAST-04 | `Url`/`Domain` lifetime obligation undocumented | Medium | 24 | CWE-416 | 2026-04-18 (`5c97228`) | [#44](https://gitlab.com/devnw/zig/advanced-types/-/issues/44) | Lifetime-contract doc block |
| NEW-01 | Port parser accepts leading zeros | Low | 8 | CWE-20 | 2026-04-18 (`f175133`) | [#46](https://gitlab.com/devnw/zig/advanced-types/-/issues/46) | Leading-zero guard at `url.zig:368` |
| NEW-02 | Domain has no IDN/Punycode/homograph handling | Medium | 24 | CWE-1007 | 2026-04-18 (`df972dd`) | [#45](https://gitlab.com/devnw/zig/advanced-types/-/issues/45) | Won't-Do: ASCII-only by design; documented in `SECURITY.md` |
| S1 | Vector.parse accepts Inf/NaN | Medium | 32 | CWE-20 | Closed | — | `isNan`/`isInf` check after `parseFloat` |
| S2 | FloatRange accepts NaN bounds | Medium | 32 | CWE-20 | Closed | — | NaN/Inf check in `Range.init()` for float types |
| S3 | Vector.at() safe alternative | Low | 12 | CWE-248 | Closed (safe alternative) | — | `get()` method returning `?T` (the `at()` panic itself tracked as SAST-PANIC-01 — now closed) |
| S4 | Integer overflow in Vector arithmetic | Low | 8 | CWE-190 | Closed | — | Doc comments on `add`/`sub`/`scale`/`dot` per build mode |
| S5 | LatLonAlt altitude accepts NaN/Inf | Low | 12 | CWE-20 | Closed | — | `isNan`/`isInf` check in `LatLonAlt.init()` |
| S6 | Range.span() overflow at type boundaries | Low | 8 | CWE-190 | Closed | — | Doc comment warning |
| S7 | CI downloads Zig without checksum | Low | 16 | CWE-829 | Closed | — | SHA-256 verified against `index.json` in `.gitlab-ci.yml:39-77` (Linux template; macOS/Windows parity landed this pass via CI-SUP-01/02) |

## Immediate Actions Required

**No Critical findings this pass.** Every open Medium/Low item from the 5th-pass plan closed this session:

1. SAST-PANIC-01, SAST-DOS-01, CI-SUP-01, CI-SUP-02, NEW-REL-01 all fixed and tracker-closed.
2. SAST-OVERFLOW-01, CI-FUZZ-01, OP-OWNER-01, CI-SECRETS-01 finalised as Accepted on the tracker.

**Secret rotations required:** None. `gitleaks` and `trufflehog` baseline scans both 0.

**Release-blocker summary:** None. Tagged releases will be signed + SBOM-attached once platform-ops provisions `RELEASE_GPG_PRIVATE_KEY` and `RELEASE_GPG_FINGERPRINT`.

## Risk Score Formula

`Risk = Impact (1-5) × Likelihood (1-5) × 4`, capped at 100.

- Impact: 5 RCE/privesc/cross-tenant; 4 PII/credential leak/authn bypass; 3 data tampering; 2 info leak; 1 hardening.
- Likelihood: 5 pre-auth remote trivial; 4 remote constrained; 3 requires auth; 2 rare misconfig; 1 theoretical.
