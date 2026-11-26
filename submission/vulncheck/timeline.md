# Disclosure timeline (UTC)

| Date/time (UTC) | Event | Evidence |
|---|---|---|
| 2026-11-21T20:13:30Z | Exploit start; first verified bypass against `1.11.0` | `evidence/00_timestamps.txt` |
| 2026-11-21T20:15:59Z | Root RCE verified (`sudo -n id` → 0) | `evidence/00_timestamps.txt`, `evidence/11_postexploit.txt` |
| 2026-11-21T20:19:57Z | Final verification: 401 / 200 / WS 101 / Jupyter 200 / code-server 302 | `evidence/12_final_verification.txt` |
| 2026-11-21T20:18:10Z | Report sealed | `report_20261121_201810.md` |
| 2026-11-21T21:03:02Z | Vendor notified by Proton Mail (`songhaonan.773@bytedance.com`; Cc `chaolinjin@gmail.com`, `zhangjingtian.oana@bytedance.com`) | `evidence/disclosure/20261121T210302Z_vendor_email.eml` |
| 2026-11-21T21:03:09Z | Bounce for one Cc only (`550 user not found`) | `evidence/disclosure/20261121T210309Z_bounce_*.txt` |
| 2026-11-23T17:55:00Z | Upstream HEAD `7f1afaf` re-checked: v1.11.0 ancestor, 10 docs-only commits, no nginx/auth change, no fix | `cve-submission/advisory.md` § Fix verification |
| 2026-11-26T12:47:09Z | Re-verification sweep start: control 401, bypass 200 (1176 B), `.txt` control 401, terminal-url 200 | `evidence/reverify-20261126/00_sweep.txt`, `01_matrix.txt` |
| 2026-11-26T12:47:14Z | WebSocket `101` with no auth header; `uid=1000(gem)` | `evidence/reverify-20261126/03_rce_ws.txt` |
| 2026-11-26T12:47:37Z | `sudo -n id` → `uid=0(root)`, `ROOTPROOF_0` | `evidence/reverify-20261126/04_root.txt` |
| 2026-11-26T12:47:29Z | Sweep end; test container removed | `evidence/reverify-20261126/00_sweep.txt` |
| 2026-11-26T12:49Z | VulnCheck submission package prepared | this directory |
| 2026-11-26T12:55Z | Report repo made public; `VENDOR-CONTACT.md` + `TIMELINE.md` added as contact proof | repo HTTP 200 |
| 2026-11-26T13:05:50Z | VulnCheck report submitted — ID `3fd9874f-480e-49c5-868a-2b0bf24d1a6b` | `https://vulncheck.com/advisories/report` |
| _TBD_ | CVE assigned / vendor response | — |

## Notes

- Vendor published **no** acknowledgement window and has no `SECURITY.md` or GitHub private
  reporting. Timing is framed as flexible and deferred to the vendor/CNA; no fixed-day embargo is
  proposed.
- Report repo `https://github.com/Teycir/agent-infra-sandbox-auth-bypass` is public (HTTP 200,
  verified 2026-11-26T12:55Z) with vendor-contact proof and this timeline.
