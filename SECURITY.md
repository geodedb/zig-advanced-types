# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: <security@codepros.dev>

Please include:

1. **Description** of the vulnerability
2. **Steps to reproduce** the issue
3. **Potential impact** assessment
4. **Suggested fix** (if you have one)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Resolution Timeline**: Depends on severity
  - Critical: 24-72 hours
  - High: 1-2 weeks
  - Medium: 2-4 weeks
  - Low: Next release cycle

### Disclosure Policy

- We follow responsible disclosure practices
- Security advisories will be published after fixes are available
- Credit will be given to reporters (unless anonymity is requested)

## Security Measures

This project implements:

- **Memory Safety**: Zig's compile-time memory safety checks
- **No Undefined Behavior**: Strict adherence to defined semantics
- **Dependency Scanning**: Automated security scanning in CI
- **Secret Detection**: Gitleaks scanning for leaked credentials
- **SSRF Defense**: `Ipv4Addr.isSafeForOutboundFetch` and
  `Ipv6Addr.isSafeForOutboundFetch` reject loopback / private /
  link-local / CGNAT / multicast / reserved ranges; IPv4-mapped
  IPv6 addresses are downcast and re-checked.
- **URL Parsing Hardening**: `Url.parse` strips `userinfo@`
  authorities (so `evil.com@trusted.com` yields `host=trusted.com`),
  rejects control bytes and HTML-breaking characters in the host,
  and rejects leading-zero ports.

## Scope: Domain Names are ASCII-Only (NEW-02)

`Domain` is validated per RFC 952 / RFC 1123: alphanumeric ASCII plus
hyphen, no leading or trailing hyphens per label, labels up to 63
bytes, total length up to 253 bytes. Internationalised Domain Names
(IDN) and their Punycode (`xn--`) encoding per RFC 3492 / UTS-46 are
**out of scope** for this library (closed as scoped won't-do /
NEW-02).

Rationale:

- IDN / Punycode is a multi-hundred-line compliance-driven feature,
  not a bug fix. It requires full Unicode case-folding, NFC
  normalisation, script-mixing checks, and the UTS-46 mapping table.
- Homograph-spoofing defenses (e.g. `pаypal.com` with Cyrillic 'а')
  are an application-layer concern that depends on the caller's
  allowlist / script-policy; baking one choice into this library
  would be unhelpful in other contexts.
- Consumers needing IDN-aware behaviour can pre-convert to ASCII via
  a dedicated IDN library (e.g. libidn2), pass the encoded
  `xn--<...>.tld` form to `Domain.parse`, and keep the full
  internationalised form separately.

If your threat model requires IDN / Punycode support, treat
`Domain.parse` as a hard ASCII gate: reject any input whose bytes
are not in the validated ASCII character class, convert externally,
and pass the ASCII-encoded label to this library.

## Security Best Practices

When using this library:

1. Keep dependencies updated
2. Review security advisories regularly
3. Report any suspicious behavior
4. Follow secure coding guidelines

## Contact

For non-security issues, see [SUPPORT.md](SUPPORT.md).
