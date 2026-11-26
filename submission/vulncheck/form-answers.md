# VulnCheck form — paste-ready answers

Form: <https://vulncheck.com/advisories/report>
One vulnerability per submission. Captcha is completed by the reporter.

| Form field | Value |
|---|---|
| Name to Credit | `Teycir` |
| Email | `teycir@protonmail.com` (confirmed: From header of the archived vendor email) |
| GitHub Username | `Teycir` |
| On behalf of someone else? | `No, I discovered this myself` |
| Vendor name | `agent-infra (ByteDance)` |
| Product name | `agent-infra/sandbox container image — nginx gateway (ghcr.io/agent-infra/sandbox)` |
| Product URL | `https://github.com/agent-infra/sandbox` |
| Tested Version(s) | `ghcr.io/agent-infra/sandbox:1.11.0` — tag digest `sha256:6328d7fd2f0ff0b4c147c3d05b3df1ce331f4a482eb6e550ecd64ed1fcf906e7` (identical to `latest` at test time), image ID `sha256:c8c90673082b6d4bf6517bda004cbf8b6059fd17a0866d1971e17cce3da18ee9`; upstream HEAD `7f1afaf8d82bd30531a19caeb1a24dfebbc97d8c` re-checked 2026-11-26, still vulnerable |
| Vulnerability Details | paste all of `details-RT-01.md` |
| Coordinate disclosure? | `Yes — VulnCheck handles vendor outreach` (vendor unresponsive since 2026-11-21; no security policy exists) |
| Already reported to supplier? | `Yes — email to best-effort maintainer addresses on 2026-11-21T21:03:02Z (Proton Mail). Message-ID <jpAy0C6IXxtOtu8j4Kqu9L-j6VTA8au-BNrgO-HwvgQamD6IbNYKleWkTWxrA4aAkF9thHjRpSn1T3Y7av9FLb4jA8o6US9TtC6U1iWFrH4=@protonmail.com>. No SECURITY.md / no GitHub private advisory available. No reply; one Cc bounced 550.` |
| Previously requested CVE from MITRE w/o response? | `No` |
| Already publicly disclosed? | `Yes — reproduction package at https://github.com/Teycir/agent-infra-sandbox-auth-bypass (vendor-contact proof + timeline included; no vendor advisory)` |
| Generated with AI? | `Yes — LLM-assisted analysis and drafting; the reporter executed and verified every PoC step against the live image.` |
| Validated on production code? | `Yes — tested against the published release image ghcr.io/agent-infra/sandbox:1.11.0, not a mock.` |
| Shodan/Fofa query | `N/A — self-hosted OCI image, no reliable public fingerprint.` |
| Plan to publish on/after coordinated date? | `Yes` |

## Values that are NOT form fields

Put these at the top of the Vulnerability Details text (already in `details-RT-01.md`):

- Severity: Critical
- CVSS 3.1: `9.8` — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`
  <https://www.first.org/cvss/calculator/3.1#CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H>
- CWE-288 (Authentication Bypass Using an Alternate Path or Channel)
- CWE-306 (Missing Authentication for Critical Function)
