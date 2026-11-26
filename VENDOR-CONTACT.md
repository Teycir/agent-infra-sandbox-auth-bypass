# Vendor contact — proof of notification

The upstream project publishes **no security policy and no private vulnerability-reporting
channel**. Notification therefore used best-effort maintainer addresses found in public project
metadata. This page is the human-readable index of that contact; the raw artifacts are in
`evidence/disclosure/`.

## 1. No upstream security channel (verified 2026-11-26)

```bash
gh api graphql -f query='query{repository(owner:"agent-infra",name:"sandbox"){isSecurityPolicyEnabled securityPolicyUrl contactLinks{about url}}}'
# {"data":{"repository":{"isSecurityPolicyEnabled":false,"securityPolicyUrl":null,"contactLinks":[]}}}
```

- `SECURITY.md`: absent (`https://github.com/agent-infra/sandbox/security/policy` → no policy).
- GitHub private vulnerability reporting: disabled.
- `CONTACT_RESEARCH.txt` records how the addresses below were selected.

## 2. Notification sent

| Field | Value |
|---|---|
| Sent (UTC) | **2026-11-21T21:03:02Z** (scheduled-send time 21:02:50Z) |
| Channel | Proton Mail (encrypted at rest, `X-Pm-Content-Encryption: on-compose`) |
| From | `teycir <teycir@protonmail.com>` |
| To | `songhaonan.773@bytedance.com` |
| Cc | `zhangjingtian.oana@bytedance.com`, `chaolinjin@gmail.com` |
| Subject | `[Security] Critical auth bypass in agent-infra/sandbox 1.11.0 — unauthenticated file download + container-root RCE` |
| Message-ID | `<jpAy0C6IXxtOtu8j4Kqu9L-j6VTA8au-BNrgO-HwvgQamD6IbNYKleWkTWxrA4aAkF9thHjRpSn1T3Y7av9FLb4jA8o6US9TtC6U1iWFrH4=@protonmail.com>` |
| Attachment | `agent-infra-sandbox-auth-bypass.zip` (full evidence package) |
| Raw message | [`evidence/disclosure/20261121T210302Z_vendor_email.eml`](evidence/disclosure/20261121T210302Z_vendor_email.eml) (646,764 bytes) |
| Rendered copy (viewable in browser) | [`evidence/disclosure/20261121T210302Z_vendor_email.eml.txt`](evidence/disclosure/20261121T210302Z_vendor_email.eml.txt) — byte-identical, text/plain |
| sha256 | `cb5ce17ad601152adc1465a3f4ff2a647ca70f5c0dd6bc9087d4ebb87787fb11` |

Verbatim headers from the raw message:

```text
Subject: =?utf-8?Q?[Security]_Critical_auth_bypass_in_agent-infra/sandbox_1.11.0_=E2=80=94_unauthenticated_file_download_+_container-root_RCE?=
From: teycir <teycir@protonmail.com>
Date: Sat, 21 Nov 2026 21:03:02 +0000
To: songhaonan.773@bytedance.com <songhaonan.773@bytedance.com>
Cc: zhangjingtian.oana@bytedance.com <zhangjingtian.oana@bytedance.com>,
 chaolinjin@gmail.com <chaolinjin@gmail.com>
Message-Id: <jpAy0C6IXxtOtu8j4Kqu9L-j6VTA8au-BNrgO-HwvgQamD6IbNYKleWkTWxrA4aAkF9thHjRpSn1T3Y7av9FLb4jA8o6US9TtC6U1iWFrH4=@protonmail.com>
X-Pm-Scheduled-Sent-Original-Time: Sat, 21 Nov 2026 21:02:50 +0000
X-Attached: agent-infra-sandbox-auth-bypass.zip
```

Body text (decoded from the HTML part):

> Hello agent-infra maintainers,
>
> I'm reporting a critical authentication bypass in the AIO Sandbox container image.
>
> Affected:
> - Image: ghcr.io/agent-infra/sandbox:1.11.0
> - Manifest digest: sha256:6328d7fd2f0ff0b4c147c3d05b3df1ce331f4a482eb6e550ecd64ed1fcf906e7 (same as latest at test time)
> - Image ID: sha256:c8c90673082b6d4bf6517bda004cbf8b6059fd17a0866d1971e17cce3da18ee9
> - Verified: 2026-11-21 UTC against a live container with SANDBOX_API_KEY set
> - Proposed CVSS 3.1: 9.8 AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H
>
> Root cause:
> nginx routes on $request_method:$request_uri. Because $request_uri includes the query string, appending ?x=.json to a protected GET endpoint matches the static-asset regex and selects @proxy_without_auth, skipping auth_request. aiod does not independently enforce the API key.
>
> Demonstrated impact, no credentials:
> - GET /v1/file/download?path=/etc/passwd&x=.json → 200 and file bytes, byte-for-byte match.
> - GET /v1/shell/terminal-url?x=.json → 200 and mints a shell session.
> - WebSocket /v1/shell/ws?...&x=.json → 101 with no Authorization header.
> - Commands run as uid=1000(gem); sudo -n id → uid=0(root) inside the container.
> - Controls: same requests without ?x=.json → 401; POST /v1/shell/exec → 401.
>
> Scope note: demonstrated impact is container compromise. Host-level compromise, cloud metadata access, and lateral movement are deployment-dependent and not claimed.
>
> I have a complete evidence package: report, advisory, PoCs, nginx/gem.sh root cause, SHA-256 manifest, and pinned-tag rerun. It is attached to this email.
>
> Reporter: Teycir (github.com/Teycir)

Reproduce the headers locally:

```bash
grep -m1 '^Message-Id:' evidence/disclosure/20261121T210302Z_vendor_email.eml
sha256sum evidence/disclosure/20261121T210302Z_vendor_email.eml
```

## 3. Delivery result

The primary recipient (`songhaonan.773@bytedance.com`) did not bounce; Proton returned no
delivery failure for it. One **Cc** bounced:

```text
<zhangjingtian.oana@bytedance.com>: host mx1.bytedance.com[35.172.32.95] said:
    550 verify address failed, User not found zhangjingtian.oana@bytedance.com
Status: 5.0.0
Arrival-Date: Sat, 21 Nov 2026 21:03:09 +0000 (UTC)
Queue-ID: 4jX4Rf5rgjzMqTqG
```

Raw bounce: `evidence/disclosure/20261121T210309Z_bounce_zhangjingtian_oana_at_bytedance_com.txt`,
sha256 `00bdc45ae24664540e5a92ebb518a1042e9b3b3366d09d0d0018eb12c0372803`.

## 4. Response status

**No reply from any recipient as of 2026-11-26T12:52Z** (checked in the sending mailbox, including
spam). Upstream HEAD `7f1afaf8d82bd30531a19caeb1a24dfebbc97d8c` was re-checked the same day: the
ten commits after `v1.11.0` are documentation-only and contain no nginx/auth change, i.e. no fix.

No acknowledgement window was published by the vendor, so disclosure timing is framed as flexible
and deferred to the vendor/CNA; no fixed-day embargo is proposed.

## 5. Artifact hashes

| Artifact | sha256 |
|---|---|
| `20261121T210302Z_vendor_email.eml` | `cb5ce17ad601152adc1465a3f4ff2a647ca70f5c0dd6bc9087d4ebb87787fb11` |
| `20261121T210302Z_vendor_email.eml.txt` | `cb5ce17ad601152adc1465a3f4ff2a647ca70f5c0dd6bc9087d4ebb87787fb11` (byte-identical copy) |
| `20261121T210309Z_bounce_zhangjingtian_oana_at_bytedance_com.txt` | `00bdc45ae24664540e5a92ebb518a1042e9b3b3366d09d0d0018eb12c0372803` |
| `CONTACT_RESEARCH.txt` | `4bfe67c8ff6f91a24b7af7413dda3f5684ecb972bfa8300821a371ff127aeb31` |

## 6. Later disclosure step

VulnCheck submission package prepared 2026-11-26 (`submission/vulncheck/`); the form submission is
pending (manual captcha). Ticket ID will be recorded in `TIMELINE.md`.
