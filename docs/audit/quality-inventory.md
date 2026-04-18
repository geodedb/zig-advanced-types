# Quality Inventory — advanced-types

Phase 1 of `/codepros:audit`. Read-only inventory. All paths absolute.

## Repo Inventory

- **Root:** `/home/benji/src/devnw/zig/advanced-types`
- **Platform:** GitLab (`gitlab.com:devnw/zig/advanced-types`)
- **Languages:** Zig (100% of source)
- **Language version floor:** Zig `0.15.1` (`/home/benji/src/devnw/zig/advanced-types/build.zig.zon:5`)
- **CI Zig version:** `0.16.0` (`/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml:27`)
- **Frameworks:** None — pure standard library (`std.testing`, `std.Build`)
- **Package manager / deps:** Zig package manager; `dependencies = .{}` → zero external runtime deps (`/home/benji/src/devnw/zig/advanced-types/build.zig.zon:6`)
- **Entrypoints:**
  - Library root: `/home/benji/src/devnw/zig/advanced-types/src/root.zig` (module name `advanced_types`)
  - Build graph: `/home/benji/src/devnw/zig/advanced-types/build.zig`
  - Example binary: `/home/benji/src/devnw/zig/advanced-types/examples/basic.zig`
- **License / compliance:** Apache-2.0 (`/home/benji/src/devnw/zig/advanced-types/LICENSE`, `/home/benji/src/devnw/zig/advanced-types/NOTICE`); SPDX headers on every `.zig` file

## Repo Shape

```text
advanced-types/
├── build.zig, build.zig.zon, Makefile
├── src/
│   ├── root.zig                 (87 LOC, 17 public re-exports, refAllDecls test hub)
│   └── types/
│       ├── network.zig          (965 LOC, 33 tests)   — Ipv4Addr, Ipv6Addr, IpAddr, Subnet, Mac
│       ├── vector.zig           (634 LOC, 49 tests)   — Vector, VectorF32, VectorI32
│       ├── url.zig              (638 LOC, 57 tests)   — Url, Domain
│       ├── range.zig            (573 LOC, 55 tests)   — Range, IntRange, UintRange, FloatRange
│       └── geographic.zig       (564 LOC, 38 tests)   — LatLon, LatLonAlt, GeoPoint
├── tests/
│   ├── integration.zig          (172 LOC, 9 tests)
│   ├── type_extensions.zig      (206 LOC, 11 tests)
│   ├── fuzz.zig                 (115 LOC, 10 fuzz targets)
│   └── performance.zig          (601 LOC, 9 tests)
├── examples/basic.zig           (54 LOC)
├── docs/                        (GAP_ANALYSIS, QUALITY/PERF/SECURITY gap docs, REQUIREMENTS)
└── .gitlab/ (issue templates)
```

**Module graph (flat, star topology):** `src/root.zig` imports each of the 5 type modules under `src/types/`. The 4 test files under `tests/` each import the whole library via the `advanced_types` module name supplied by `build.zig`. No inter-module dependencies inside `src/types/`.

**Scale:** 4,609 lines of Zig total, 232 source-level `test` blocks + 39 in `tests/` = **271 test declarations**. Library surface: 46 `pub fn/const` in `src/` (17 public types per brief).

## Quality Tooling

| Category | Tool | Config File | Command |
|---|---|---|---|
| Formatter | `zig fmt` (built-in) | n/a | `zig fmt --check src/ tests/ build.zig` (pre-commit local hook `/home/benji/src/devnw/zig/advanced-types/.pre-commit-config.yaml:63`) |
| Build / compile check | Zig build system | `/home/benji/src/devnw/zig/advanced-types/build.zig` | `zig build check` |
| Unit tests | `std.testing` (embedded in source via `refAllDecls`) | `build.zig` step `test` | `zig build test --summary all` |
| Integration tests | `std.testing` | `build.zig` step `test-integration` | `zig build test-integration` |
| Type-extension tests | `std.testing` | `build.zig` step `test-extensions` | `zig build test-extensions` |
| Performance tests | `std.testing` | `build.zig` step `test-performance` | `zig build test-performance` |
| Fuzz harness | `std.testing.fuzz` (coverage-guided) | `build.zig` step `test-fuzz`, CI job `fuzz` | `zig build test --fuzz` (60s timeout in CI) |
| Example smoke | `b.addExecutable` | `build.zig` step `example` | `zig build example` |
| Multi-optimization test matrix | CI | `.gitlab-ci.yml:117-167` | ReleaseSafe, ReleaseFast, ReleaseSmall × {unit, integration} |
| Secrets scan | gitleaks | `/home/benji/src/devnw/zig/advanced-types/.gitleaks.toml` + `ci-catalog/security-gitleaks@v1.7.1` | pipeline component |
| SAST | GitLab SAST | `ci-catalog/security-sast@v1.7.1` | pipeline component |
| Dependency scan | GitLab DS | `ci-catalog/security-dependency-scanning@v1.7.1` | pipeline component (no-op: zero deps) |
| Secret detection (GL) | GitLab secret-detection | `ci-catalog/security-secrets@v1.7.1` | pipeline component |
| SBOM generate + scan | GitLab SBOM | `ci-catalog/sbom-{generate,scan}@v1.7.1` | pipeline component |
| Release automation | semantic-release component | `ci-catalog/release-semantic@v1.7.1` | pipeline component |
| Commit-message lint | commitizen (conventional commits) | `/home/benji/src/devnw/zig/advanced-types/.cz.yaml`, `.pre-commit-config.yaml:54` | pre-commit `commit-msg` hook |
| Markdown lint | markdownlint | `/home/benji/src/devnw/zig/advanced-types/.markdownlint.json` | pre-commit |
| Shell lint | shellcheck (`--severity=error`) | `.pre-commit-config.yaml:31` | pre-commit |
| YAML autoformat | language-formatters-pre-commit-hooks | `.pre-commit-config.yaml:46` | pre-commit (excludes `.gitlab-ci.yml`) |
| General hygiene | pre-commit-hooks (trailing ws, EOL, large files, merge-conflict, private-key detection) | `.pre-commit-config.yaml:9` | pre-commit |
| Editor consistency | EditorConfig | `/home/benji/src/devnw/zig/advanced-types/.editorconfig` | editor-side |
| Dev convenience | Makefile (`dev`, `ci`, `test-all-optimizations`, `fuzz`, `coverage`) | `/home/benji/src/devnw/zig/advanced-types/Makefile` | `make <target>` |

**Type checking, linting beyond `zig fmt`:** Zig has no separate linter/type-checker distinct from the compiler. `zig build check` IS the type/semantic check. There is no `ziglint` or equivalent configured.

## CI Pipeline Stages (`/home/benji/src/devnw/zig/advanced-types/.gitlab-ci.yml`)

`lint → build → test → fuzz → security → sbom → release`

- All Linux jobs pinned to `tags: [company]` runners (`.gitlab-ci.yml:5-7`)
- Zig install uses SHA-256 verification against `ziglang.org/download/index.json` (`.gitlab-ci.yml:39-77`) — supply-chain hardening present
- Fuzz job runs on schedules + manual web trigger only, `allow_failure: true`, 60s timeout, artifacts `zig-out/fuzz/` on failure
- Release + integration tests run across **Debug, ReleaseSafe, ReleaseFast, ReleaseSmall** — broad optimization-level coverage

## High-Risk Areas

- `/home/benji/src/devnw/zig/advanced-types/src/types/network.zig` — largest module (965 LOC), parsers for IPv4/IPv6/MAC/Subnet = highest attack surface for malformed input; fuzzed in `tests/fuzz.zig`. Previously flagged at 919 LOC in `docs/QUALITY_GAP_ANALYSIS.md:17` (Q9: "Won't Do").
- `/home/benji/src/devnw/zig/advanced-types/src/types/url.zig` — user-controlled string parsing; 638 LOC, 57 tests. Overlap with external `uri` library was explicitly called out in `docs/REQUIREMENTS.md` (AT-REQ-004, AT-PKG-001).
- `/home/benji/src/devnw/zig/advanced-types/src/types/geographic.zig` — floating-point distance math (haversine etc.); correctness-sensitive under Release optimizations.

## High-Churn Areas

Repo is young (8 total commits). Churn signal is weak. `.zig` file-touches-per-commit tied at ~2 for `tests/integration.zig`, `src/root.zig`, `examples/basic.zig`, `build.zig`; everything else touched once. No meaningful hotspots yet.

## API Contracts

- **Source of truth:** `/home/benji/src/devnw/zig/advanced-types/src/root.zig` — aggregates + re-exports all public types. Library-style repo, so the "contract" is the exported type/function set plus doc comments.
- **Consumers:** external Zig packages; contract is tested end-to-end via `tests/integration.zig` (`_ = lib.<Type>` smoke tests on lines 22-41) and `tests/type_extensions.zig`.
- **Drift risk:** `examples/basic.zig` is compiled and run in CI (`build.zig:91`) → catches "example silently broken" drift. `docs/README.md` and doc-comment examples in `src/root.zig:11` are **not** compiled; risk they drift from real API.
- **Version pinning risk:** local developer Zig vs CI Zig was an explicit gap (Q11 in `docs/QUALITY_GAP_ANALYSIS.md`); CI is now `0.16.0` (`.gitlab-ci.yml:27`) while `build.zig.zon` demands `>= 0.15.1`. Any 0.15→0.16 breaking change lands in CI first.

## Missing Tooling (Gaps)

1. **Code coverage reporting is not wired up.** `Makefile:72-81` has a `coverage` target that explicitly documents llvm-cov instrumentation is "not yet stabilized in 0.15". No coverage number is published; claim of 230 tests vs 17 types is unverified coverage.
2. **No dedicated Zig linter.** Only `zig fmt` + compiler; no `ziglint`, no custom AST checks. Doc-comment coverage enforcement (previously flagged ~7% in Q2) has no automated guard against regression.
3. **Doc examples are not doctested.** Triple-slash examples in `src/root.zig:11-17` are markdown inside `//!`, not compiled. Drift silent.
4. **No benchmarking harness in CI.** `tests/performance.zig` exists (601 LOC, 9 tests) but runs only as part of the `test-performance` step (not invoked by any CI job in `.gitlab-ci.yml`). No regression tracking.
5. **Fuzz runs gated to schedules/manual only** (`.gitlab-ci.yml:188-193`). MR pipelines do not fuzz.
6. **Pre-commit hooks are local-only.** Project does not use `pre-commit.ci` (config has `ci: skip: [zig-fmt, zig-build, zig-test]` at `.pre-commit-config.yaml:98`). Contributors who don't install pre-commit bypass zig-fmt/zig-build/zig-test client-side checks — CI re-runs them, but feedback loop is longer.
7. **Single code owner.** `CODEOWNERS` is just `* @benjiv` — bus-factor 1, no review pool.
8. **No MR template found** under `/home/benji/src/devnw/zig/advanced-types/.gitlab/` (only issue templates present).
9. **No ADRs.** `docs/` has gap analyses and REQUIREMENTS but no architectural decisions directory.
10. **`docs/QUALITY_GAP_ANALYSIS.md` metadata is stale** — CI Zig reference (Q11) now reads `0.15.2` but CI has advanced to `0.16.0`. Gap tracker drifts from CI state.

## Unusual / Noteworthy

- **Zero-dependency posture** is strict: `build.zig.zon` dependencies block is empty; zero vendored code; no `vendor/` directory.
- No generated code, no build-time codegen steps.
- Tests live in two places by design: per-module `test` blocks inside `src/types/*.zig` (pulled in via `std.testing.refAllDecls(@This())` at `src/root.zig:85`) **plus** four separate files under `tests/`. The scanner should treat both as "unit-adjacent" — the `tests/` files are not exclusively integration; `type_extensions.zig` and `performance.zig` exercise single types.
- Pipeline re-installs Zig in every job via a YAML anchor (`.gitlab-ci.yml:39`). Previously flagged as Q12 "Won't Do". Runtime cost per pipeline is non-trivial.
- `.gitignore` entry `test_*` (line 20) is broad — would ignore files named `test_*` anywhere. The exemption `!tests/` keeps the directory, but any file matching `test_*` inside `tests/` would be ignored. No such files exist today but this is a footgun for contributors.
- `.cz.yaml` drives semver bumps off commit-type patterns (`feat→MINOR`, `fix/perf/refactor→PATCH`); release automation is wired in via the `ci-catalog/release-semantic` component.
- All jobs tagged `company` — cannot run on shared GitLab runners.

## Handoff Notes for Downstream Agents

- **quality-scanner:** 271 test blocks exist; use `zig build test --summary all` + `zig build test-integration --summary all` + `zig build test-extensions --summary all` to validate runtime. Multi-optimization matrix already covered by CI — reuse `-Doptimize=ReleaseSafe|ReleaseFast|ReleaseSmall`. No coverage numbers — do not cite "coverage %" without instrumenting.
- **quality-reviewer:** Previous closures in `docs/QUALITY_GAP_ANALYSIS.md` flag what has already been reviewed; start from `network.zig` (largest, highest parse surface) and `url.zig` (overlap with external `uri` library is an explicit design decision, AT-PKG-001). Doc-comment-coverage regressions (post-Q2) and any `@panic`/UB in parser paths are top priorities (fuzz invariant: "no parser may panic on any input", `tests/fuzz.zig:7-8`).
- **quality-issue-tracker:** Gap docs already exist — `docs/QUALITY_GAP_ANALYSIS.md`, `docs/SECURITY_GAP_ANALYSIS.md`, `docs/PERF_GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS.md`, `docs/GAP_ANALYSIS_RESOLVED.md`. New findings should reference these and avoid duplicating closed items (Q1-Q8, Q11, Q13).
