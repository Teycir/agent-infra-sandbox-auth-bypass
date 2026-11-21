#!/bin/bash
#
# Shared no-side-effect environment defaults for the two-stage entrypoints.
# This file must not create files, render configs, or start processes.

gem_env_normalize_bool() {
  local value
  value="$(echo -n "${1:-}" | xargs | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    1|true|yes|on) echo "true" ;;
    *) echo "false" ;;
  esac
}

gem_env_prepare_defaults() {
  export USER="${AIO_USER:-${USER:-gem}}"
  export USER_UID="${USER_UID:-1000}"
  export USER_GID="${USER_GID:-1000}"
  export LOG_DIR="${LOG_DIR:-/var/log/gem}"
  export DISPLAY="${DISPLAY:-:99.0}"
  export DISPLAY_DEPTH="${DISPLAY_DEPTH:-24}"
  export DISPLAY_WIDTH="${DISPLAY_WIDTH:-1280}"
  export DISPLAY_HEIGHT="${DISPLAY_HEIGHT:-1024}"
  export BROWSER_EXECUTABLE_PATH="${BROWSER_EXECUTABLE_PATH:-/usr/local/bin/browser}"
  export BROWSER_REMOTE_DEBUGGING_PORT="${BROWSER_REMOTE_DEBUGGING_PORT:-9222}"
  export BROWSER_COMMANDLINE_ARGS="${BROWSER_COMMANDLINE_ARGS:-}"
  export BROWSER_EXTRA_ARGS="${BROWSER_EXTRA_ARGS:-}"
  export BROWSER_LANG="${BROWSER_LANG:-en-US}"
  export BROWSER_NO_SANDBOX="${BROWSER_NO_SANDBOX:-}"
  export HOMEPAGE="${HOMEPAGE:-}"
  export TZ="${TZ:-Asia/Singapore}"
  export DISABLE_BROWSER="$(gem_env_normalize_bool "${DISABLE_BROWSER:-false}")"

  if [ "${DISABLE_BROWSER}" = "true" ]; then
    export AUTOSTART_BROWSER="false"
  else
    export AUTOSTART_BROWSER="true"
  fi
}
