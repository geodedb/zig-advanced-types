# advanced-types Documentation

## Overview

Portable value types for network addresses, vectors, geographic coordinates, URLs, and generic ranges.

## Contents

- [Requirements](REQUIREMENTS.md) - Functional, packaging, and test requirements
- [Gap Analysis](GAP_ANALYSIS.md) - Requirements-to-implementation tracing and open gaps
- [Quality Gap Analysis](QUALITY_GAP_ANALYSIS.md) - Code quality findings
- [Performance Gap Analysis](PERF_GAP_ANALYSIS.md) - Performance findings
- [Security Gap Analysis](SECURITY_GAP_ANALYSIS.md) - Security findings
- [Resolved Gaps](GAP_ANALYSIS_RESOLVED.md) - Closed and won't-do items

## Quick Links

- [Installation](../README.md#installation)
- [Contributing](../CONTRIBUTING.md)
- [Security](../SECURITY.md)
- [Changelog](../CHANGELOG.md)

## API Reference

All public types are exported from `src/root.zig`. Each `src/types/*.zig` file contains module-level doc comments with usage examples. Run `zig build-lib` to generate documentation.
