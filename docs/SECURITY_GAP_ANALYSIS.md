# Security Gap Analysis

Last updated: 2026-03-23

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

| # | Finding | Severity | CWE | Status | Resolution |
|---|---------|----------|-----|--------|-----------|
| S1 | Vector.parse accepts Inf/NaN | Medium | CWE-20 | **Closed** | Added `isNan`/`isInf` check after `parseFloat` in `parseElement` |
| S2 | FloatRange accepts NaN bounds | Medium | CWE-20 | **Closed** | Added NaN/Inf check in `Range.init()` for float types |
| S3 | Vector.at() panics on OOB index | Low | CWE-248 | **Closed** | Added `get()` method returning `?T` as safe alternative; documented `at()` panic behavior |
| S4 | Integer overflow in Vector arithmetic | Low | CWE-190 | **Closed** | Added doc comments to `add`/`sub`/`scale`/`dot` documenting overflow behavior per build mode |
| S5 | LatLonAlt altitude accepts NaN/Inf | Low | CWE-20 | **Closed** | Added `isNan`/`isInf` check for altitude in `LatLonAlt.init()` |
| S6 | Range.span() overflow at type boundaries | Low | CWE-190 | **Closed** | Added doc comment warning about overflow for integer ranges spanning full type width |
| S7 | CI downloads Zig without checksum | Low | CWE-829 | **Won't Do** | HTTPS provides baseline protection; checksum verification requires maintaining hash values per version |

## Summary

| Status | Count |
|--------|-------|
| Closed | 6 |
| Won't Do | 1 |
| **Total** | **7** |

## Immediate Actions Required

None. All medium-severity findings are closed.
