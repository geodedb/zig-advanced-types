# Security Scan Report -- advanced-types

**Date:** 2026-04-18
**Scope:** `/home/benji/src/devnw/zig/advanced-types` (full repo, 26 commits)
**Platform:** GitLab `gitlab.com/devnw/zig/advanced-types` (no `.github/workflows`)
**Language:** Zig (min `0.16.0` per `build.zig.zon:5`; CI pins `ZIG_VERSION: "0.16.0"` per `.gitlab-ci.yml:27`)
**Phase:** 2 of `/codepros:audit` (security-scanner)
**Prior handoff:** `docs/audit/security-inventory.md`
**Consumer:** `docs/audit/security-review.md` (Phase 3)

## 1. Tool Availability

| Tool | Available | Version | Used | Notes |
|------|-----------|---------|------|-------|
| gitleaks | yes (local build) | `zricethezav/gitleaks/v8@latest` | yes | Replicates `security-gitleaks@v1.7.1` CI job |
| semgrep | yes | 1.159.0 | yes | Scoped to `src/ build.zig build.zig.zon .gitlab-ci.yml`; `--metrics=off` |
| govulncheck | yes | v1.2.0 | N/A | No Go code |
| trufflehog | no | -- | skipped | gitleaks covers secrets path |
| osv-scanner / trivy / grype / syft | no | -- | skipped | `.dependencies = .{}` -- nothing to resolve |
| shellcheck / hadolint / checkov | no | -- | skipped | No Dockerfile, no shell scripts in repo; `.gitlab-ci.yml` inline shell audited manually |
| bandit / safety / cargo-audit / snyk | no | -- | N/A | No Python / Rust; Snyk unauthenticated |
| zig-native fuzzer | yes | `zig build test --fuzz` | out-of-scope for scanner phase | 60s CI budget, manual/scheduled only (`.gitlab-ci.yml:341-358`) |

Telemetry disabled (`semgrep --metrics=off`). No external uploads. Gitleaks installed via `go install github.com/zricethezav/gitleaks/v8@latest` into `/home/benji/go/bin/gitleaks`.

## 2. Secret Detection (gitleaks)

Command (replicates CI): `gitleaks detect --no-banner --redact --report-format json --report-path /tmp/gitleaks.json`

| Metric | Value |
|--------|-------|
| Commits scanned | 26 |
| Bytes scanned | ~579.7 KB |
| Findings | **0** |
| Exit code | 0 |
| Report | `/tmp/gitleaks.json` (`[]`) |

Local config: `.gitleaks.toml:1-22` extends default rules; allowlists `.zig-cache`, `zig-out`, `.git`. No custom rules, no per-finding allowlist entries -> no false-positive suppression is in play.

**Confidence:** `confidence::confirmed`. No leaks.

| Tool | Findings | Types | Files Affected | Confidence |
|------|----------|-------|----------------|------------|
| gitleaks 8 (latest) | 0 | -- | -- | `confidence::confirmed` |

## 3. Dependency / Supply-Chain Scan

### Package graph

`build.zig.zon:6` declares `.dependencies = .{}`. Full contents verified:

```zig
.{
    .name = .advanced_types,
    .version = "0.1.0",
    .fingerprint = 0x7bf641380ae7b1a5,
    .minimum_zig_version = "0.16.0",
    .dependencies = .{},
    .paths = .{ "build.zig", "build.zig.zon", "src", "LICENSE", "README.md" },
}
```

No `b.dependency(...)` / `b.lazyDependency(...)` in `build.zig`. Zero transitive library dependencies. Nothing for osv-scanner / trivy / grype to resolve.

| Dependency surface | Source | Pinning | Integrity | Confidence |
|--------------------|--------|---------|-----------|------------|
| Runtime library deps | `build.zig.zon` | `.dependencies = .{}` | n/a (empty) | `confidence::confirmed` |
| Zig toolchain | `ziglang.org/download/index.json` + tarball (same request chain) | `ZIG_VERSION: "0.16.0"` variable | SHA-256 via `sha256sum --check --strict` against shasum extracted from `index.json` same run (`.gitlab-ci.yml:59-77`) -- TOFU | `confidence::suspected` (TOFU; already tracked as `S7`) |
| ci-catalog components (SAST, DS, secrets, gitleaks, SBOM gen/scan, release-semantic) | `gitlab.com/devnw/ci-catalog/*@v1.7.1` | floating minor tag (not a commit SHA) | tag re-point possible upstream; same-group trust | `confidence::suspected` (already tracked as `SC-01`; closed as won't-do via platform controls per `docs/audit/gap-close-plan.md`) |
| zig-format component | `gitlab.com/devnw/ci-catalog/zig-format@v1.2.1` | floating minor tag | same as above | `confidence::suspected` |

No transitive third-party package concerns. Supply-chain surface is entirely upstream Zig + ci-catalog.

## 4. SAST (Pattern + Semgrep-assisted)

No mainstream SAST tool supports Zig. Primary evidence is direct pattern audit; `semgrep` was run with `p/security-audit`, `p/secrets`, `p/ci` rule packs scoped to repo source (47 rules, 9 files) -- **0 findings**. An unscoped `--config auto` run surfaced 4 hits (`Dockerfile:57`, `Dockerfile:58`, `e2e/Dockerfile:11`, `gen/pkg/wsx/ws.go:410`) -- verified FALSE POSITIVES from semgrep's cache of other projects: none of those paths exist in this repo (`ls` confirms absence). Scoped run is authoritative.

### 4.1 `@intCast` / narrowing-cast sites (range-check audit)

16 `@intCast` sites -- zero `@truncate`, `@bitCast`, `@ptrCast`, `@alignCast` anywhere under `src/`. All casts are in `src/types/network.zig`:

| File:Line | Cast | Target | Guard | Verdict | Confidence |
|-----------|------|--------|-------|---------|------------|
| `network.zig:62-65` | `@intCast((value >> k) & 0xFF)` | `u8` | `& 0xFF` masks to `[0,255]` | total | `confidence::confirmed` |
| `network.zig:91` | `@intCast(current_value)` | `u8` | `current_value > 255` check on line 90 | safe | `confidence::confirmed` |
| `network.zig:108` | `@intCast(current_value)` | `u8` | `current_value > 255` check on line 107 | safe | `confidence::confirmed` |
| `network.zig:198-199` | `@intCast((seg >> 8) & 0xFF)` / `& 0xFF` | `u8` | mask | total | `confidence::confirmed` |
| `network.zig:280-281, 298-299` | `@intCast((current_value >> 8) & 0xFF)` / `& 0xFF` | `u8` | `current_value > 0xFFFF` check on preceding lines | safe | `confidence::confirmed` |
| `network.zig:533` | `@intCast(prefix_len)` | `u8` | `prefix_len > max_prefix` (max=128) on line 529 | safe | `confidence::confirmed` |
| `network.zig:564` | `@intCast(@as(u8, 32) - prefix_len)` | `u5` | branches handle `prefix_len==0` and `prefix_len==32` before the cast (lines 555-557) plus `std.debug.assert(prefix_len > 0 and prefix_len < 32)` on line 563 | safe; assert elided in `ReleaseFast` but branches remain | `confidence::confirmed` |
| `network.zig:574` | `@intCast(prefix_len % 8)` | `u3` | `prefix_len % 8` is in `[0,7]`, total for `u3` | total | `confidence::confirmed` |
| `network.zig:581` | `@intCast(@as(u4, 8) - @as(u4, remaining_bits))` | `u3` | gated by `remaining_bits > 0` on line 580 -> `(8 - remaining_bits)` in `[1,7]` fits `u3` | safe | `confidence::confirmed` |

No narrowing cast is reachable without a preceding range check (or mask, or `comptime`-sized value). No `@setRuntimeSafety(false)` anywhere.

### 4.2 `unreachable` / `@panic` sites (caller-reachability audit)

| File:Line | Kind | Reachable from untrusted caller? | Confidence |
|-----------|------|----------------------------------|------------|
| `src/types/vector.zig:78` | `@panic("Vector index out of bounds")` inside `Vector(T,N).at(index)` | **Yes** -- `at(i)` is public and panics when `index >= N`. Documented (`src/types/vector.zig:75`). `get(i)` is the safe alternative. Any caller passing an attacker-controlled `usize` to `at()` aborts the process. Mark **SAST-PANIC-01**. | `confidence::confirmed` |
| `src/types/network.zig:563` | `std.debug.assert(prefix_len > 0 and prefix_len < 32)` in `containsV4` | `Subnet.init` / `.parse` reject out-of-range `prefix_len`. Struct-literal construction with a bad prefix is defensively caught on lines 555-557 (returns `false` or equality check) before the assert. Assert is belt-and-suspenders; elided in `ReleaseFast`. | `confidence::confirmed` not-reachable-from-caller |
| `std.fmt.bufPrint(...) catch unreachable` x22 sites (geographic.zig:386, 393, 466, 553, 560; network.zig:712, 891, 895, 901, 962, 966, 1079, 1083, 1135; range.zig:452, 459, 466, 513; vector.zig:504, 511, 532, 542) | `catch unreachable` | Every site is inside a `test ".."` block with a compile-time-sized stack buffer sized for the fixed-format output. Not reachable from library callers -- tests only. | `confidence::confirmed` not-reachable |

**Finding SAST-PANIC-01 (confirmed):** `Vector.at(index)` panics on OOB. This is documented API, but a consumer forwarding untrusted indices directly to `at()` yields a DoS primitive. Matches inventory rank-1. Mitigations: `get(i)` exists and returns `?T`. Review-phase will decide whether to downgrade `at`'s panic, add explicit caller-facing guidance, or leave as-is.

### 4.3 Parser DoS -- loops keyed on input length without cap

`grep input\.len\s*>\s*\d+` yields exactly **one** explicit length cap in `src/`:

| File:Line | Cap |
|-----------|-----|
| `src/types/url.zig:54` | `if (input.len > 253) return ParseError.InvalidDomain;` |

That is the only hard length cap outside `Mac.parse` (exact `==17`). The following parsers walk the full input with no upper bound:

| Parser | File:Line | Per-iteration work | DoS posture | Confidence |
|--------|-----------|--------------------|-------------|------------|
| `Ipv4Addr.parse` | `network.zig:86-108` | O(1) per byte; digit cap 3, early overflow exit | O(n) with tiny constant; unbounded input accepted | `confidence::confirmed` -- tracked rank 5 |
| `Ipv6Addr.parseGroups` + `Ipv6Addr.parse` | `network.zig:260-303, 214-258` | `findDoubleColon` walks to end (O(n)); `parseGroups` O(1) per byte | two passes, both O(n); unbounded input accepted | `confidence::confirmed` |
| `IpAddr.parse` | `network.zig:438-451` | extra O(n) scan for `':'` before delegating | three-pass worst case for v6 input | `confidence::suspected` (minor, predictable-linear) |
| `Subnet.parse` | `network.zig:503-535` | O(n) scan for `'/'`, then O(n) per-family parse, then O(len(prefix_part)) prefix digit loop | unbounded; prefix loop bails at `> 128` | `confidence::confirmed` |
| `Url.parse` | `url.zig:190-297` | multiple `indexOf*` scans (O(n)), `validateHostChars` O(n) | unbounded; all passes linear -- no quadratic blow-up, but no cap | `confidence::confirmed` |
| `Mac.parse` | `network.zig:617-641` | `input.len != 17` early exit | safe -- single-value length gate | `confidence::confirmed` not-a-DoS |
| `LatLon.parse` / `LatLonAlt.parse` | `geographic.zig:158, 211`, via `parseTupleInParens` (`geographic.zig:45-...`) | O(n) split on `,` then `parseFloat` per field | unbounded; field count bound by commas | `confidence::confirmed` |
| `GeoPoint.parse` | `geographic.zig:296-313` | `std.mem.count(inner, ",")` then delegation | two passes, both O(n) | `confidence::confirmed` |
| `Range(T).parse` | `range.zig:107-125` | O(n) `indexOf` for `,` then two `parseInt` | unbounded | `confidence::confirmed` |
| `Vector(T,N).parse` | `vector.zig:211-236` | `splitScalar(',')`; bails early when `count >= N` via `InvalidDimension` | bounded by `N`: attacker cannot drive more than `N+1` iterations before error -- **actually capped** | `confidence::confirmed` bounded |
| `Domain.parse` | `url.zig:52-73` | 253-byte hard cap | safe | `confidence::confirmed` |

**Finding SAST-DOS-01 (confirmed):** Every parse path except `Domain.parse`, `Mac.parse`, and `Vector.parse` accepts arbitrarily long input. Each is linear-time, so this is not algorithmic-complexity DoS; the concern is memory/CPU amplification from a caller that trusts the library to bound `input.len`. Matches inventory rank 5. Suggested mitigation: per-type `MAX_INPUT` cap (e.g., `Ipv4Addr <= 15`, `Ipv6Addr <= 45`, `Subnet <= 49`, `Url <= 8192`).

### 4.4 Off-by-one / boundary bugs in parsers

| Site | File:Line | Analysis | Verdict | Confidence |
|------|-----------|----------|---------|------------|
| IPv4 octet cap | `network.zig:88-90, 95-98, 105-107` | `current_value: u16` accumulates; `> 255` check before `@intCast(u8)`; `digit_count > 3` check prevents `u16` overflow (max 3 digits = `999 < 65535`) | correct | `confidence::confirmed` |
| IPv4 dot placement | `network.zig:88, 89, 106` | empty-octet `digit_count == 0`, max-octets `octet_index >= 3`, final `octet_index != 3` -- all guarded | correct | `confidence::confirmed` |
| IPv6 `::` position | `network.zig:221-258` | `findDoubleColon` walks `0..input.len-1`; `right_start = dc_pos + 2` with `right = if (right_start <= input.len) input[right_start..] else ""` -- handles trailing `::` | correct | `confidence::confirmed` |
| IPv6 group copy-to-right | `network.zig:244-247` | `right_offset = (8 - right_count) * 2`; writes `right_count * 2` bytes from `right_octets[0..]` into `octets[right_offset..]` -- terminates inside `octets[16]` | correct | `confidence::confirmed` |
| Subnet prefix digit accumulation | `network.zig:517-521` | `u16` accumulator capped at 128 before `@intCast(u8)`; `> 128` check triggers `error.Overflow` | correct | `confidence::confirmed` |
| Port parsing strict | `url.zig:362-374` | leading-zero rejected when `len > 1`; single `"0"` allowed (port 0 is valid); delegates to `std.fmt.parseInt(u16, ...)` for range | correct; matches `NEW-01` | `confidence::confirmed` |
| IPv6 literal in URL | `url.zig:253-262` | `host_part[0] == '['` -> `indexOfScalar(']')` or `InvalidFormat`; port after `']'` requires explicit `':'` | correct | `confidence::confirmed` |
| Multi-`@` authority (userinfo) | `url.zig:242-245` | `lastIndexOfScalar(authority, '@')` -- WHATWG "last `@` wins"; `evil.com@trusted.com` parses `host=trusted.com`, `userinfo=evil.com` | correct | `confidence::confirmed` |
| `host_part[0]` read | `url.zig:253` | preceded by `if (host_part.len == 0) return MissingHost;` on line 246 -- no underflow | correct | `confidence::confirmed` |
| URL path empty-slice construction | `url.zig:231` | `input[scheme_end + 3 + rest.len .. scheme_end + 3 + rest.len]` creates a zero-length slice at the authority end -- valid Zig slice | correct | `confidence::confirmed` |
| Domain trailing-dot | `url.zig:58-70` | `input[label_start..]` for last label; `label.len == 0` triggers `InvalidDomain`, so trailing `.` is rejected | correct | `confidence::confirmed` |
| Vector dimension | `vector.zig:219-234` | `count >= N -> InvalidDimension`; final `count != N -> InvalidDimension` | correct | `confidence::confirmed` |
| Range span overflow | `range.zig:85-87` | Deliberately unchecked; documented rank 3 | known-risk | `confidence::confirmed` |

No new off-by-one or boundary-bug finding. `confidence::confirmed` across the table.

### 4.5 Allocator usage (should be absent)

| Hit | File:Line | Verdict |
|-----|-----------|---------|
| `std.mem.Allocator` (text match) | `url.zig:47, 170` | **doc comment only** -- points callers at `Allocator.dupe` to transfer ownership |
| `.alloc(` / `.free(` / `.dupe(` / `.create(` / `.destroy(` | none under `src/` | **none** |

`confidence::confirmed`. Library is allocator-free. Matches inventory line 42.

### 4.6 Semgrep (scoped)

Command: `semgrep scan --config p/security-audit --config p/secrets --config p/ci --metrics=off --json -o /tmp/semgrep-scoped.json src build.zig build.zig.zon .gitlab-ci.yml`

| Metric | Value |
|--------|-------|
| Rules | 47 |
| Files scanned | 9 |
| Results | 0 |
| Errors | 0 |

Auto-config unscoped run (`/tmp/semgrep.json`) produced 4 results, all on paths not in this repo (`Dockerfile:57`, `Dockerfile:58`, `e2e/Dockerfile:11`, `gen/pkg/wsx/ws.go:410`) -- cache contamination from prior scans; `ls` confirms absence. **Marked false positive.**

## 5. Infra / Ops Scan (`.gitlab-ci.yml`)

| Control | Observation | File:Line | Severity | Confidence |
|---------|-------------|-----------|----------|------------|
| Component pinning | All security & SBOM components `@v1.7.1` (floating tag, not commit SHA) | `.gitlab-ci.yml:11-14, 20-21, 24` | Medium | `confidence::confirmed` -- matches `SC-01` (closed won't-do, platform controls) |
| `zig-format` pin | `@v1.2.1` (floating) | `.gitlab-ci.yml:17` | Medium | `confidence::confirmed` |
| Runner tagging | `default.tags: [company]` -- trusted runner pool | `.gitlab-ci.yml:5-7` | Informational | `confidence::confirmed` |
| Stored secrets in YAML | None: no `$VAR` reference to user secrets; no explicit `variables` block holding tokens | `.gitlab-ci.yml:26-27` (only `ZIG_VERSION`) | N/A | `confidence::confirmed` |
| Zig toolchain integrity | SHA-256 compared against shasum from `index.json` fetched same job -> TOFU | `.gitlab-ci.yml:59-72` | Medium | `confidence::confirmed` -- tracked `S7` |
| Python inline | Inline `python3 -c` block reads `index.json` to extract shasum; pins no Python packages | `.gitlab-ci.yml:61-69` | Low (no pip install) | `confidence::confirmed` |
| Fuzz coverage on MR | Fuzz job rules: `$CI_PIPELINE_SOURCE == "schedule"` auto, `"web"` manual, default MR push skips | `.gitlab-ci.yml:341-358` | Medium | `confidence::confirmed` -- tracked rank 10 |
| Fuzz timeout | `timeout 60 zig build test --fuzz; rc=$?; ...` -- 60s budget, `rc=124` treated as pass | `.gitlab-ci.yml:347` | Informational | `confidence::confirmed` |
| Coverage gate | `coverage: job.allow_failure: true`; report-only | `.gitlab-ci.yml:307-332` | Informational | `confidence::confirmed` (per `Q31` / `GAP-0011`) |
| Cross-arch jobs | macOS/Windows/aarch64 all `allow_failure: true` + manual; any dispatch failure doesn't block pipeline | `.gitlab-ci.yml:238-297` | Low (quality, not security) | `confidence::confirmed` |
| macOS `brew install zig` (unpinned, with error-swallow) | Uses unpinned Homebrew formula; no SHA check on the brew path | `.gitlab-ci.yml:243` | Medium (supply chain) | `confidence::suspected` -- divergence from Linux TOFU+SHA path |
| Windows install | `iwr` then `Expand-Archive` -- no hash check of the downloaded `zig.zip` | `.gitlab-ci.yml:264` | Medium (supply chain) | `confidence::suspected` -- only Linux path SHA-verifies the tarball |
| CODEOWNERS | Single owner `@benjiv` | `CODEOWNERS:3` | Medium | `confidence::confirmed` (documented repeatedly) |
| Pre-commit local hook | `detect-private-key`, `zig fmt`, `zig build check/test` -- no gitleaks hook in pre-commit | `.pre-commit-config.yaml:28` (only `detect-private-key`) | Low -- CI catches secrets | `confidence::confirmed` |

**Findings from infra scan:**

- **CI-SUP-01 (suspected):** `test-macos` uses `brew install zig || true` (`.gitlab-ci.yml:243`). No SHA verification, no version pinning. Diverges from the Linux path's verified `ziglang.org/index.json` -> `sha256sum --check` pipeline.
- **CI-SUP-02 (suspected):** `test-windows` `iwr` + `Expand-Archive` of `zig.zip` (`.gitlab-ci.yml:264`) -- no SHA verification.
- **CI-CAT-01 (confirmed, previously accepted):** ci-catalog components pinned to floating `@v1.7.1` / `@v1.2.1`. Remediation already closed as won't-do (`SC-01`) with platform-control rationale.
- **CI-FUZZ-01 (confirmed, previously tracked):** Fuzz skipped on MR pipelines. Rank 10 in inventory. Not a new finding.
- **CI-SECRETS-01 (informational):** `gitleaks` runs in CI (component `security-gitleaks@v1.7.1`) but not in `.pre-commit-config.yaml` -- the pre-commit only has `detect-private-key`. Defense-in-depth gap, not a live issue.

## 6. Findings Summary

### Secret Detection

| Tool | Findings | Types | Files Affected | Confidence |
|------|----------|-------|----------------|------------|
| gitleaks v8 (26 commits, 579.7 KB) | 0 | -- | -- | `confidence::confirmed` |

### Dependency Vulnerabilities

| CVE/ID | Severity | Package | Version | Fixed In | File | Confidence |
|--------|----------|---------|---------|----------|------|------------|
| *none* | -- | -- | -- | -- | `build.zig.zon:6` (empty deps) | `confidence::confirmed` |

### SAST Findings

| ID | Rule | Severity | File:Line | Description | Confidence |
|----|------|----------|-----------|-------------|------------|
| SAST-PANIC-01 | documented-panic-on-untrusted-index | Medium | `src/types/vector.zig:76-80` | `Vector.at()` `@panic` on caller-controlled index; `get()` is the safe alternative | `confidence::confirmed` |
| SAST-DOS-01 | unbounded-parser-input | Low-Medium | `network.zig:78, 214, 438, 503`, `url.zig:190`, `geographic.zig:158, 211, 296`, `range.zig:107` | parse paths accept arbitrarily long input (linear-time but no cap); only `Domain.parse` (253), `Mac.parse` (==17), and `Vector.parse` (N-bounded) are bounded | `confidence::confirmed` |
| SAST-OVERFLOW-01 | documented-integer-overflow | Medium | `src/types/range.zig:85-87`, `src/types/vector.zig:106-144` | `Range.span`, `Vector.add/sub/scale/dot` wrap silently in `ReleaseFast`/`ReleaseSmall`; documented | `confidence::confirmed` (known, documented) |
| SAST-NARROW-01 | narrowing-cast-all-guarded | Informational | `src/types/network.zig:62-65, 91, 108, 198-199, 280-281, 298-299, 533, 564, 574, 581` | all `@intCast` sites preceded by range check or mask | `confidence::confirmed` (negative finding) |

### IaC / Config Issues

| ID | Tool | Severity | File:Line | Check | Description | Confidence |
|----|------|----------|-----------|-------|-------------|------------|
| CI-SUP-01 | manual | Medium | `.gitlab-ci.yml:242-243` | unpinned brew zig | macOS `brew install zig` with no hash check; diverges from Linux SHA verify path | `confidence::suspected` |
| CI-SUP-02 | manual | Medium | `.gitlab-ci.yml:264` | unverified Windows zip | `iwr ... zig.zip; Expand-Archive` with no hash verification | `confidence::suspected` |
| CI-CAT-01 | manual | Medium | `.gitlab-ci.yml:11-24` | floating-tag components | ci-catalog `@v1.7.1` / `@v1.2.1` (not SHA-pinned); previously closed won't-do (`SC-01`) | `confidence::confirmed` accepted-risk |
| CI-FUZZ-01 | manual | Medium | `.gitlab-ci.yml:341-358` | fuzz-not-on-MR | Fuzz job only on schedule/web (manual); MR pushes skip fuzz | `confidence::confirmed` already-tracked |
| CI-SECRETS-01 | manual | Informational | `.pre-commit-config.yaml:28` | no pre-commit gitleaks | Only `detect-private-key` present; CI catches | `confidence::confirmed` |

### Shell / Dockerfile Issues

| Tool | Severity | File:Line | Code | Description | Confidence |
|------|----------|-----------|------|-------------|------------|
| shellcheck / hadolint | N/A | -- | -- | No shell scripts or Dockerfile in repo | `confidence::confirmed` |

### Language Audit Results

| Tool | Findings | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| govulncheck (Go) | N/A | -- | -- | -- | -- |
| bandit (Python) | N/A | -- | -- | -- | -- |
| cargo audit (Rust) | N/A | -- | -- | -- | -- |
| npm audit / snyk | N/A | -- | -- | -- | -- |

## 7. Tools Not Available (gaps)

| Tool | Why Missing | Impact |
|------|-------------|--------|
| trufflehog | not installed | low -- gitleaks covers the secrets path with the same rule base |
| osv-scanner / trivy / grype / syft | not installed | none -- `.dependencies = .{}` leaves nothing to resolve; SBOM is generated in CI via `sbom-generate@v1.7.1` |
| shellcheck / hadolint | not installed | low -- no shell scripts, no `Dockerfile`; only inline shell is `.gitlab-ci.yml` install block, audited manually |
| checkov | not installed | low -- `.gitlab-ci.yml` audited manually (section 5) |
| snyk | not authenticated | low -- no runtime deps to surface |
| Zig-native SAST | **does not exist** | high -- cannot run a rule-based scanner against Zig; compensated by targeted pattern audit (sections 4.1-4.4) plus coverage-guided fuzz in CI (section 5) |

## 8. Blockers

- **Zig SAST**: no mainstream SAST tool supports Zig. `semgrep` generic rules run but cover Python/Go/JS/Java/C -- they produced no Zig findings. Compensating controls: targeted pattern audit above + coverage-guided fuzz (`zig build test --fuzz`) + `ReleaseSafe` matrix in CI (`.gitlab-ci.yml:118-167`).
- **No root access to install packages**: `shellcheck`, `hadolint`, `trivy`, `osv-scanner` not available; workarounds applied.
- **Snyk**: unauthenticated. Policy-blocked for ad-hoc scan.
- **GitLab platform access**: CI-side `sbom-generate@v1.7.1` / `sbom-scan@v1.7.1` results live in GitLab pipeline artifacts; not replicated locally.

## 9. Deliverables

- `/tmp/gitleaks.json` -- gitleaks report (`[]`, 0 findings)
- `/tmp/semgrep.json` -- semgrep auto-config unscoped (4 false positives on non-existent paths)
- `/tmp/semgrep-scoped.json` -- semgrep scoped to repo paths (0 findings, 47 rules, 9 files)

## 10. Handoff to security-reviewer

Reviewer should focus on:

1. **SAST-PANIC-01** -- decide: downgrade `Vector.at()` panic to safety-checked index, leave as documented, or emit a typed error.
2. **SAST-DOS-01** -- decide: add per-parser `MAX_INPUT` cap(s). Options: universal `const MAX_INPUT = 8192` in `src/root.zig`, or per-type caps that match RFC maxes (`Ipv4Addr <= 15`, `Ipv6Addr <= 45`, `Subnet <= 49`, `Url <= 8192`).
3. **CI-SUP-01 / CI-SUP-02** -- cross-OS Zig installs on macOS/Windows lack SHA verification. Decide: bring parity with Linux (fetch `index.json`, `shasum`, verify) or accept risk because jobs are `allow_failure: true` and manual.
4. **CI-CAT-01** / **SC-01** -- confirm the won't-do posture given `@v1.7.1` floating-tag remains.
5. **CI-SECRETS-01** -- confirm intentional that gitleaks is CI-only (no pre-commit hook).

Deep-analysis inputs unchanged from inventory: rank-1 (parser panic), rank-2 (IP/URL confusion), rank-3 (integer overflow), rank-4 (slice UAF docs), rank-8/9/10 (supply-chain + fuzz-on-MR).
