# VulnCheck submission — agent-infra/sandbox nginx auth bypass

Status: **READY FOR MANUAL SUBMIT** (user fills the web form; no automated submission).

Channel: <https://vulncheck.com/advisories/report> (fallback `disclosure@vulncheck.com`).
The form has a Turnstile captcha — the reporter must complete it.

## Send gate

- [x] Vendor contacted: 2026-11-21T21:03:02Z, Proton Mail, Message-ID
      `<jpAy0C6IXxtOtu8j4Kqu9L-j6VTA8au-BNrgO-HwvgQamD6IbNYKleWkTWxrA4aAkF9thHjRpSn1T3Y7av9FLb4jA8o6US9TtC6U1iWFrH4=@protonmail.com>`.
      No `SECURITY.md`, no GitHub private reporting (`isSecurityPolicyEnabled=false`).
- [x] No vendor response as of 2026-11-26; upstream HEAD unchanged (`7f1afaf`), no fix.
      Vendor published **no** acknowledgement window → timing framed as flexible, deferred to vendor/CNA.
      No fixed-day embargo is proposed anywhere.
- [x] Report repo is **public** (HTTP 200, verified 2026-11-26T12:55Z):
      `https://github.com/Teycir/agent-infra-sandbox-auth-bypass`
      Vendor-contact proof: `VENDOR-CONTACT.md`; disclosure history: `TIMELINE.md`.
- [ ] `sha256sum -c SHA256SUMS` passes in this directory.
- [ ] One form submission for this one CVE.

## File map

| File | Purpose |
|---|---|
| `form-answers.md` | Paste-ready value for every field on the VulnCheck form |
| `details-RT-01.md` | Full text for the "Vulnerability Details" field |
| `RT-01.cve.json` | CVE 5.1 record draft (IDs/dates are placeholders) |
| `email-to-disclosure.txt` | Fallback email body if the form fails |
| `timeline.md` | UTC disclosure timeline; add the VulnCheck ticket ID here after sending |
| `SHA256SUMS` | Integrity of this directory |

## Evidence pointers (in the report repo)

- `report_20261121_201810.md` — full report, CVSS/CWE, request/response pairs.
- `evidence/reverify-20261126/` — fresh re-verification sweep, 2026-11-26T12:47Z:
  `401 → 200` bypass, `/etc/passwd` sha256, WS `101`, `uid=1000(gem)` → `uid=0(root)`.
- `evidence/pinned-1.11.0/` — pinned-tag matrix and WS trace.
- `cve-submission/root-cause/` — nginx configs + `gem.sh` auth selection.
- `pocs/poc.sh`, `pocs/rce_ws.py` — runnable reproduction.
