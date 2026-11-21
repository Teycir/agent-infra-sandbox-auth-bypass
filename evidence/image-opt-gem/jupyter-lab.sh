#!/bin/bash

set -e

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S,%3N') INFO $@"
}

# Yield CPU to python-server during its import-heavy startup. On 1c2g a
# parallel jupyter spawn was stealing ~1-2s from python-server import.
# Wait until python-server's port is up (or a generous timeout fires) so
# we don't gate jupyter forever if python-server is broken.
wait_seconds=${JUPYTER_WAIT_PYTHON_SERVER_TIMEOUT:-60}
deadline=$(( $(date +%s) + wait_seconds ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if (echo > /dev/tcp/127.0.0.1/${SANDBOX_SRV_PORT:-8091}) 2>/dev/null; then
    log "python-server is ready, starting Jupyter Lab"
    break
  fi
  sleep 0.5
done

log "Starting Jupyter Lab..."
exec /opt/python3.12/bin/jupyter lab \
  --notebook-dir=${WORKSPACE:-/tmp} \
  --ip=127.0.0.1 \
  --port=${JUPYTER_LAB_PORT} \
  --no-browser \
  --allow-root \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_remote_access=True \
  --ServerApp.allow_origin='*' \
  --ServerApp.disable_check_xsrf=True \
  --ServerApp.base_url='/jupyter' \
  --ServerApp.tornado_settings='{"headers":{"Access-Control-Allow-Origin":"*","Content-Security-Policy":"frame-ancestors *"}}'
