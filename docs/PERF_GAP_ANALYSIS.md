# Performance Gap Analysis

Last updated: 2026-03-23

## Findings

| # | Finding | PerfSeverity | Status | Resolution |
|---|---------|-------------|--------|-----------|
| P1 | No benchmark suite exists | P1 | **Won't Do** | Significant new work; tracked as future enhancement. Not a gap-closure item. |
| P2 | CI lacks ReleaseFast test target | P1 | **Closed** | Added `test-release-fast` job to `.gitlab-ci.yml` |
| P3 | cosineDistance makes 3 independent O(N) passes | P2 | **Closed** | Fused into single-pass loop in vector.zig |
| P4 | CI installs Zig in every job (~2.5 min wasted) | P2 | **Won't Do** | Requires custom Docker image; out of scope |
| P5 | No `@Vector` SIMD intrinsics | P2 | **Won't Do** | Compiler handles N=3 via auto-vectorization. Would require internal representation change for marginal gain at default dimensions. |
| P6 | distance() creates unnecessary intermediate array | P3 | **Won't Do** | Compiler elides at N=3 in ReleaseFast. Not worth code complexity. |
| P7 | Url.parse multi-pass (up to 5 scans) | P3 | **Won't Do** | Sub-microsecond for typical URLs. |
| P8 | VectorF32 hardcodes N=3 (SIMD alignment) | P3 | **Won't Do** | Design choice — 3D spatial vector is semantically correct. |
| P9 | Haversine uses 6 transcendental calls | P3 | **Won't Do** | Mathematically unavoidable. |
| P10 | GeoPoint.parse re-parses input | P3 | **Won't Do** | Negligible for ~30 byte inputs. |

## Summary

| Status | Count |
|--------|-------|
| Closed | 2 |
| Won't Do | 8 |
| **Total** | **10** |
