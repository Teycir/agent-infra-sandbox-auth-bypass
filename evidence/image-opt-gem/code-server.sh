#!/bin/bash

set -e

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S,%3N') INFO $@"
}

# Yield CPU to python-server during its import-heavy startup. On 1c2g a
# parallel code-server spawn was stealing ~1-2s from python-server import.
wait_seconds=${CODE_SERVER_WAIT_PYTHON_SERVER_TIMEOUT:-60}
deadline=$(( $(date +%s) + wait_seconds ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if (echo > /dev/tcp/127.0.0.1/${SANDBOX_SRV_PORT:-8091}) 2>/dev/null; then
    log "python-server is ready, starting code-server"
    break
  fi
  sleep 0.5
done

log "Starting code-server..."
exec /usr/bin/code-server \
  --port ${CODE_SERVER_PORT} \
  --bind-addr=127.0.0.1:${CODE_SERVER_PORT} \
  --disable-update-check \
  --disable-getting-started-override \
  --trusted-origins "*" \
  --auth=none \
  --user-data-dir=/home/${USER}/.config/code-server/vscode \
  --disable-telemetry \
  --disable-workspace-trust \
  ${WORKSPACE:-/home/${USER}}
