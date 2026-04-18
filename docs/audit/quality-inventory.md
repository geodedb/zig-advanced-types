# Quality Inventory — advanced-types

Phase 1 of `/codepros:audit`. Read-only inventory. All paths absolute.
Generated: 2026-04-18 (fresh pass against HEAD `f3adc69`; supersedes prior file of same name).

## Repo Inventory

- **Root:** `/home/benji/src/devnw/zig/advanced-types`
- **Platform:** GitLab (`git@gitlab.com:devnw/zig/advanced-types.git`)
- **Primary language:** Zig (100% of source)
- **Language version floor:** Zig `0.16.0` (`/home/benji/src/devnw/zig/advanced-types/build.zig.zon:5`)
- **CI Zig version:** `0.16.0` (`/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml:27`)
- **Frameworks:** None — pure Zig standard library (`std.testing`, `std.testing.fuzz`, `std.Build`)
- **Package manager / deps:** Zig package manager; `.dependencies = .{}` → zero external runtime dependencies (`/home/benji/src/devnw/zig/advanced-types/build.zig.zon:6`)
- **Entrypoints:**
  - Library module root: `/home/benji/src/devnw/zig/advanced-types/src/root.zig` (exposed as module `advanced_types` from `build.zig:11`)
  - Build graph: `/home/benji/src/devnw/zig/advanced-types/build.zig`
  - Example binary: `/home/benji/src/devnw/zig/advanced-types/examples/basic.zig` (wired through `build.zig:107`)
  - Benchmark binary: `/home/benji/src/devnw/zig/advanced-types/bench/main.zig` (wired through `build.zig:125`)
- **License / compliance:** Apache-2.0 (`/home/benji/src/devnw/zig/advanced-types/LICENSE`, `/home/benji/src/devnw/zig/advanced-types/NOTICE`); SPDX headers on every `.zig` file

## File Inventory (git-tracked)

| Extension | Count |
|---|---|
| `.md` | 32 |
| `.zig` | 14 |
| no-ext (LICENSE, NOTICE, Makefile, CODEOWNERS) | 4 |
| `.yaml` | 2 |
| `.zon` | 1 |
| `.yml` | 1 |
| `.toml` | 1 |
| `.json` | 1 |
| `.gitignore` | 1 |
| `.editorconfig` | 1 |

Derived from `git ls-files`.

## Repo Shape

```text
advanced-types/
├── build.zig, build.zig.zon, Makefile
├── src/
│   ├── root.zig                 (95 LOC; aggregator + refAllDecls test hub)
│   └── types/
│       ├── network.zig          (1166 LOC, 38 tests)  — Ipv4Addr, Ipv6Addr, IpAddr, Subnet, Mac
│       ├── url.zig              (789 LOC, 67 tests)   — Url, Domain
│       ├── vector.zig           (634 LOC, 49 tests)   — Vector, VectorF32, VectorI32
│       ├── geographic.zig       (577 LOC, 38 tests)   — LatLon, LatLonAlt, GeoPoint
│       └── range.zig            (573 LOC, 55 tests)   — Range, IntRange, UintRange, FloatRange
├── tests/
│   ├── integration.zig          (172 LOC, 9 tests)
│   ├── type_extensions.zig      (206 LOC, 11 tests)
│   ├── performance.zig          (601 LOC, 9 tests)
│   ├── parser_edge_cases.zig    (156 LOC, 16 tests)
│   └── fuzz.zig                 (154 LOC, 10 fuzz targets)
├── bench/
│   └── main.zig                 (193 LOC; ReleaseFast micro-bench harness)
├── examples/
│   └── basic.zig                (54 LOC)
├── docs/                        (GAP_ANALYSIS, QUALITY/PERF/SECURITY gap docs, REQUIREMENTS, audit/*)
└── .gitlab/                     (issue templates only; no MR template)
```

**Module graph:** Star topology. `src/root.zig` imports all five modules under `src/types/` and re-exports public types. Files in `tests/` and `bench/` each import the whole library via the `advanced_types` module wired up by `build.zig`. No inter-module dependencies inside `src/types/`.

**Scale:** 14 Zig files, **5,370 lines total**. Source-level `test` blocks: 247 in `src/types/*.zig`. Separate test files under `tests/`: 55 tests (+10 fuzz targets). **Total: 302 test declarations.** Library public surface: 17 re-exported types in `src/root.zig:50-86` plus the 5 submodule namespaces.

## Quality Tooling

| Category | Tool | Config File | Command |
|---|---|---|---|
| Formatter | `zig fmt` (built-in) | n/a (enforced via pre-commit) | `zig fmt --check src/ tests/ build.zig` (`/home/benji/src/devnw/zig/advanced-types/.pre-commit-config.yaml:63`) |
| Build / compile check | Zig build system | `/home/benji/src/devnw/zig/advanced-types/build.zig` (step `check`, line 140) | `zig build check` |
| Unit tests | `std.testing` via `refAllDecls` | `build.zig:18` | `zig build test --summary all` |
| Integration tests | `std.testing` | `build.zig:30` | `zig build test-integration` |
| Type-extension tests | `std.testing` | `build.zig:45` | `zig build test-extensions` |
| Parser edge-case regressions | `std.testing` | `build.zig:76` | `zig build test-parser-edges` |
| Performance tests | `std.testing` | `build.zig:91` | `zig build test-performance` |
| Fuzz harness | `std.testing.fuzz` (coverage-guided) | `build.zig:60`; CI job `fuzz` at `.gitlab-ci.yml:341` | `zig build test --fuzz` (60s timeout in CI) |
| Example smoke | `b.addExecutable` | `build.zig:107` | `zig build example` |
| Benchmark harness | `b.addExecutable` (ReleaseFast) | `build.zig:125`; CI job `bench` at `.gitlab-ci.yml:203` | `zig build bench -Doptimize=ReleaseFast` |
| Coverage (line, HTML) | `kcov` (debian package) | `.gitlab-ci.yml:307-332` | CI-only; emits `coverage/` artifact, no threshold gate |
| Multi-optimization test matrix | CI | `.gitlab-ci.yml:117-223` | ReleaseSafe, ReleaseFast, ReleaseSmall × {unit, integration} |
| Cross-OS / cross-arch matrix | CI (manual/scheduled) | `.gitlab-ci.yml:238-297` | `test-macos`, `test-windows`, `test-linux-aarch64`; all `allow_failure: true` |
| Secrets scan | gitleaks | `/home/benji/src/devnw/zig/advanced-types/.gitleaks.toml` + `ci-catalog/security-gitleaks@v1.7.1` | pipeline component |
| SAST | GitLab SAST | `ci-catalog/security-sast@v1.7.1` | pipeline component |
| Dependency scan | GitLab DS | `ci-catalog/security-dependency-scanning@v1.7.1` | pipeline component (no-op: zero deps) |
| Secret detection (GL) | GitLab secret-detection | `ci-catalog/security-secrets@v1.7.1` | pipeline component |
| SBOM generate + scan | GitLab SBOM | `ci-catalog/sbom-{generate,scan}@v1.7.1` | pipeline component |
| Release automation | semantic-release component | `ci-catalog/release-semantic@v1.7.1` | pipeline component |
| Commit-message lint | commitizen (conventional commits) | `/home/benji/src/devnw/zig/advanced-types/.cz.yaml`, `.pre-commit-config.yaml:54` | pre-commit `commit-msg` hook |
| Markdown lint | markdownlint-cli | `/home/benji/src/devnw/zig/advanced-types/.markdownlint.json` | pre-commit |
| Shell lint | shellcheck (`--severity=error`) | `.pre-commit-config.yaml:31` | pre-commit |
| YAML autoformat | language-formatters-pre-commit-hooks | `.pre-commit-config.yaml:46` | pre-commit (excludes `.gitlab-ci.yml`) |
| General hygiene | pre-commit-hooks (trailing ws, EOL, large-file, merge-conflict, private-key) | `.pre-commit-config.yaml:9` | pre-commit |
| Editor consistency | EditorConfig | `/home/benji/src/devnw/zig/advanced-types/.editorconfig` | editor-side |
| Dev convenience | Makefile (`dev`, `ci`, `test-all-optimizations`, `fuzz`, `coverage`) | `/home/benji/src/devnw/zig/advanced-types/Makefile` | `make <target>` |

**Type checking / lint beyond `zig fmt`:** Zig has no linter distinct from the compiler — `zig build check` is the semantic/type check. No `ziglint` or AST-level linter is configured.

## CI Pipeline Stages (`/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml`)

`lint → build → test → fuzz → coverage → security → sbom → release`

- All Linux jobs pinned to `tags: [company]` runners (`.gitlab-ci.yml:5-7`)
- Zig install uses SHA-256 verification against `ziglang.org/download/index.json` (`.gitlab-ci.yml:39-78`) — supply-chain hardening present
- Fuzz job runs on schedules + manual web trigger only, `allow_failure: true`, 60s timeout, artifacts `zig-out/fuzz/` on failure
- Release + integration tests run across **Debug, ReleaseSafe, ReleaseFast, ReleaseSmall** — broad optimization-level coverage
- Cross-platform jobs (`test-macos`, `test-windows`, `test-linux-aarch64`) are manual/scheduled with `allow_failure: true`; no auto-MR coverage for non-Linux-x86_64 targets
- Coverage job runs `kcov --include-path=src` over the debug unit-test binary discovered via `find .zig-cache/o -name test -type f -executable`; publishes HTML artifact and parses `Total ... %` via `coverage` regex. **Threshold gate is intentionally absent** — report-only until baseline stabilizes

## High-Risk Areas

- `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig` — largest module (1,166 LOC), parsers for IPv4/IPv6/MAC/Subnet; highest attack surface for malformed input. Fuzzed in `tests/fuzz.zig`, regression-tested in `tests/parser_edge_cases.zig`.
- `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig` — user-controlled string parsing (789 LOC, 67 tests). Overlap with external `uri` library is an explicit design decision (AT-REQ-004 / AT-PKG-001 in `docs/REQUIREMENTS.md`).
- `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig` — floating-point distance math (haversine etc.); correctness-sensitive under Release optimizations.
- `/home/benji/src/devnw/zig/advanced-types/src/types/vector.zig` + `range.zig` — integer overflow semantics differ by build mode (documented in `src/root.zig:19-25` and README). Behavior divergence between Debug/ReleaseSafe (panic) and ReleaseFast/ReleaseSmall (wrap) is a latent foot-gun for consumers.

## High-Churn Areas

Repo is young (26 commits on `main`). Per-path file touches since inception:

- `.gitlab-ci.yml` — 10
- `src/types/network.zig` — 4
- `build.zig` — 4
- `README.md` — 4
- `src/types/url.zig` — 3
- `src/root.zig` — 3
- `docs/GAP_ANALYSIS.md` — 3

Signal is still weak; no stable hotspots yet. CI config dominates churn while the codebase matures.

## API Contracts

- **Source of truth:** `/home/benji/src/devnw/zig/advanced-types/src/root.zig` — aggregates and re-exports all public types. Library-style repo, so the "contract" is the exported type/function set plus doc comments.
- **Consumers:** external Zig packages. Contract is exercised end-to-end via `tests/integration.zig` (`_ = lib.<Type>` smoke tests) and `tests/type_extensions.zig`.
- **Drift guards present:**
  - `examples/basic.zig` is compiled and run in CI (`build.zig:106`) — catches "example silently broken" drift.
  - `bench/main.zig` is compiled and run in CI (`.gitlab-ci.yml:203`, `allow_failure: true`) — catches "bench harness silently broken" drift.
  - Parser regressions locked in via `tests/parser_edge_cases.zig` (Q33).
- **Drift risks remaining:** doc-comment code examples in `src/root.zig:11-17` and in `README.md` are **not compiled** as doctests. Drift is silent.
- **Version pinning:** `build.zig.zon` and CI both require Zig `0.16.0`; no split between local floor and CI any longer (prior Q11 gap closed).

## Missing Tooling (Gaps)

1. **No coverage threshold gate.** The kcov job (`.gitlab-ci.yml:307`) is `allow_failure: true` and has no minimum %. A regression to 0% would not fail the pipeline; only the trend line in GitLab's UI would show it.
2. **No dedicated Zig linter.** Only `zig fmt` + compiler. There is no `ziglint` or AST-level check; doc-comment-coverage enforcement (previously flagged in Q2) has no automated guard against regression.
3. **Doc-comment examples are not doctested.** The `//!` examples in `src/root.zig:11-17` and all README Zig fences are markdown, never compiled. Silent drift risk.
4. **Bench harness does not track regressions.** The CI `bench` job exists (`.gitlab-ci.yml:203`) but only gates exit-0; no numeric baseline is stored or compared MR-over-MR.
5. **Fuzz runs gated to schedules/manual.** MR pipelines do not fuzz — only `$CI_PIPELINE_SOURCE == "schedule"` or manual web triggers run the `fuzz` job (`.gitlab-ci.yml:353-357`).
6. **Cross-platform matrix unverified.** `test-macos`, `test-windows`, `test-linux-aarch64` are all `allow_failure: true` and manual/scheduled. README claims platform support that MR CI does not validate.
7. **Pre-commit hooks are local-only** for Zig tools. `.pre-commit-config.yaml:98` skips `zig-fmt`, `zig-build`, `zig-test` in `pre-commit.ci` — contributors who don't install pre-commit bypass client-side Zig checks (CI re-runs them, but the loop is longer).
8. **Single code owner.** `CODEOWNERS` is `* @benjiv` — bus-factor 1.
9. **No MR template.** `/home/benji/src/devnw/zig/advanced-types/.gitlab/` contains only `issue_templates/`.
10. **No ADRs directory.** `docs/` has gap analyses and REQUIREMENTS but no `docs/adr/`.
11. **`.gitignore` has a broad `test_*` rule** (line 20). The `!tests/` exemption keeps the directory, but any file literally named `test_*` inside `tests/` would be ignored — footgun for contributors.

## Unusual / Noteworthy

- **Zero-dependency posture** is strict: `build.zig.zon` dependencies block is empty; no `vendor/`, no generated code, no build-time codegen.
- Tests live in two places by design: per-module `test` blocks in `src/types/*.zig` (pulled in via `std.testing.refAllDecls(@This())` at `src/root.zig:92`), **plus** five separate files under `tests/`. `type_extensions.zig`, `performance.zig`, and `parser_edge_cases.zig` are not purely "integration" — they exercise single types as well.
- Pipeline re-installs Zig in every Linux job via a YAML anchor (`.gitlab-ci.yml:40`). Runtime cost per pipeline is non-trivial; previously flagged as Q12 "Won't Do".
- `.cz.yaml` drives semver bumps off commit-type patterns (`feat→MINOR`, `fix|perf|refactor→PATCH`); release automation is wired in via the `ci-catalog/release-semantic` component.
- Kcov job parses a `Total.*\s(\d+\.\d+)%` coverage regex (`.gitlab-ci.yml:323`) — GitLab will surface a coverage badge once baseline runs land.
- All Linux jobs require `tags: [company]` — cannot fall back to shared GitLab runners.

## Handoff Notes for Downstream Agents

- **quality-scanner:** 302 test declarations exist. Validate runtime via `zig build test --summary all`, `zig build test-integration`, `zig build test-extensions`, `zig build test-performance`, and `zig build test-parser-edges`. Multi-optimization matrix is already covered by CI — reuse `-Doptimize=ReleaseSafe|ReleaseFast|ReleaseSmall`. Coverage numbers are now available via the kcov job artifact; do not cite coverage % without pulling from that artifact.
- **quality-reviewer:** Start from `src/types/network.zig` (largest + highest parse surface) and `src/types/url.zig` (explicit overlap with external `uri` library). Doc-comment-coverage regressions (post-Q2) and any `@panic`/UB in parser paths are top priorities; fuzz invariant is "no parser may panic on any input" (`tests/fuzz.zig:7-8`). Vector/Range overflow semantics divergence between optimization modes is an explicit contract — verify `README.md` "Build Modes and Overflow Semantics" still matches code.
- **quality-issue-tracker:** Gap docs already exist — `docs/QUALITY_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS_RESOLVED.md`, plus the full `docs/audit/` tree. New findings should reference these and avoid duplicating closed items; kcov (Q31/GAP-0011) is now wired in.
