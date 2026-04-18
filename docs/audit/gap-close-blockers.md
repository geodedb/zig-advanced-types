# Gap Closure Blockers

This file tracks items that are implemented-as-specified but depend on
external infrastructure to become fully active. Each entry lists the
gap ID, what was implemented, what is required to unblock, and the
carried-forward risk.

---

## GAP-0019 -- Multi-OS unit-test matrix

**Status:** Landed (YAML added) but jobs are dormant pending runners.

**Implementation:** `.gitlab-ci.yml` gains `test-macos`, `test-windows`,
`test-linux-aarch64` jobs that run `zig build test` and
`zig build test-integration` on their respective targets. They carry
`allow_failure: true` and `rules: when: manual` so they do not gate
merges or execute on every push.

**Blocker:** The project tags its runners with `company` and those
runners are Linux-x86_64. No `macos`, `windows`, or `aarch64` tagged
runners are currently provisioned. Until runners with those tags come
online, the three jobs will sit in `pending` state when triggered.

**Unblock:**

1. Register at least one runner per tag (`macos`, `windows`, `aarch64`)
   with the project or the parent group.
2. Verify Zig 0.16.0 install paths -- macOS: `brew install zig`;
   Windows: archive from ziglang.org; aarch64 Linux: existing
   `.install-zig` template already detects `aarch64` arch.
3. Once green on a scheduled pipeline, promote the jobs from
   `rules: when: manual` to run on merge requests.

**Risk carried forward:** README claims cross-platform support but
Linux x86_64 is the only platform currently validated per push. Any
platform-specific regression (for example `clock_gettime` availability
on macOS, Windows path handling, or `@Vector` alignment on aarch64)
will only surface on manual trigger until runners are provisioned.

---

## GAP-0011 / Q31 -- Coverage reporting

**Status:** Landed as report-only.

**Implementation:** A `coverage` CI job runs kcov against the main test
binary and publishes the HTML report as an artifact. No percentage
threshold gates the pipeline; the plan explicitly authorizes
report-only because the ledger called for "reopen *or* explicit
won't-do" and an arbitrary percent threshold can regress unexpectedly
on refactors.

**Unblock for percentage gate:** collect one week of coverage runs,
determine a realistic floor (expected: 85%+), then add a second job
that parses the kcov summary and exits non-zero below the threshold.
Track as a follow-up issue.

---

## SC-01 -- Pin ci-catalog components to commit SHAs

**Status:** Won't Do (scoped).

**Rationale:** The project's gap-close policy explicitly carves out
"CI/CD hash and Docker tag pinning" as handled via different controls
(supply-chain controls owned by the platform team / ci-catalog
project itself, not by each consumer repository). Pinning every
`component:` include to a commit SHA in this repo would invert that
ownership: every ci-catalog bugfix would require a manual SHA bump
here, and the consumer wouldn't learn about component CVEs until
someone rebuilt the dependency graph.

The existing `@v1.7.1` tag-pin already prevents surprise-major
upgrades while letting the catalog ship patch-level fixes under the
same tag (the catalog's tag-protection rules prevent retag of a
published minor).

**Tracked-elsewhere unblock:** if the platform-team control changes
(for example a move to mandatory digest-pinning across the org), this
file's "Won't Do" status should be revisited. Until then no CI change
is warranted in this repo.
