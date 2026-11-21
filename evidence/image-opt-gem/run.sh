#!/bin/bash
#
# Compatibility entrypoint for ordinary Docker startup. Platforms that need a
# split bootstrap can call /opt/gem/gem_init.sh followed by /opt/gem/gem.sh.

set -euo pipefail

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S,%3N') INFO run: $*"
}

log "starting trusted init stage"
/opt/gem/gem_init.sh

log "starting runtime stage"
exec /opt/gem/gem.sh
