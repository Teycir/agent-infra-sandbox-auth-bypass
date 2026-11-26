# Disclosure timeline (UTC)

| Date/time (UTC) | Event | Evidence |
|---|---|---|
| 2026-11-21T20:13:30Z | Exploit start; first verified auth bypass against `1.11.0` | `evidence/00_timestamps.txt` |
| 2026-11-21T20:15:59Z | Container root verified (`sudo -n id` → `uid=0`) | `evidence/00_timestamps.txt`, `evidence/11_postexploit.txt` |
| 2026-11-21T20:18:10Z | Report sealed | `report_20261121_201810.md` |
| 2026-11-21T20:19:57Z | Final verification: 401 / 200 / WS 101 / Jupyter 200 / code-server 302 | `evidence/12_final_verification.txt` |
| 2026-11-21T21:03:02Z | Vendor notified by Proton Mail: To `songhaonan.773@bytedance.com`, Cc `zhangjingtian.oana@bytedance.com`, `chaolinjin@gmail.com`; full evidence zip attached | `VENDOR-CONTACT.md`, `evidence/disclosure/20261121T210302Z_vendor_email.eml` |
| 2026-11-21T21:03:09Z | One Cc bounced: `550 verify address failed, User not found` (zhangjingtian.oana) | `evidence/disclosure/20261121T210309Z_bounce_zhangjingtian_oana_at_bytedance_com.txt` |
| 2026-11-23T17:55:00Z | Upstream HEAD `7f1afaf` re-checked: docs-only commits after v1.11.0, no nginx/auth change, no fix | `cve-submission/advisory.md` § Fix verification |
| 2026-11-26T12:47:09Z | Fresh re-verification sweep start: control 401, bypass 200 (1176 B), `.txt` control 401, terminal-url 200 | `evidence/reverify-20261126/00_sweep.txt`, `01_matrix.txt` |
| 2026-11-26T12:47:14Z | WebSocket `101` with no Authorization header; `uid=1000(gem)` | `evidence/reverify-20261126/03_rce_ws.txt` |
| 2026-11-26T12:47:29Z | Sweep end; `sudo -n id` → `uid=0(root)`, `ROOTPROOF_0`; test container removed | `evidence/reverify-20261126/04_root.txt` |
| 2026-11-26T12:47:37Z | Upstream HEAD re-checked via `git ls-remote`: still `7f1afaf`, no fix | `evidence/reverify-20261126/00_sweep.txt` |
| 2026-11-26T12:49:53Z | VulnCheck submission package prepared; report archived | `submission/vulncheck/`, `~/BugBounty/agent-infra-sandbox/20261126/124953/` |
| 2026-11-26T12:55Z | This repository made public with vendor-contact proof and timeline | this file, `VENDOR-CONTACT.md` |
| _TBD_ | VulnCheck form submitted — record ticket/case ID here | — |
| _TBD_ | Vendor response / CVE assigned | — |

## Notes

- No vendor reply as of 2026-11-26T12:52Z, including spam folder.
- Upstream has no `SECURITY.md`, `isSecurityPolicyEnabled=false`, `contactLinks=[]` (re-verified
  2026-11-26), so notification used best-effort maintainer addresses.
- Vendor published no acknowledgement window. Timing is flexible and deferred to the vendor/CNA;
  no fixed-day embargo is proposed anywhere.
