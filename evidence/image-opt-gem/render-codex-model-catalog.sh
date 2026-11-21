#!/bin/bash

set -e

log() {
  printf '%s codex-model-catalog-render: %s\n' "$(date '+%Y-%m-%d %H:%M:%S,%3N')" "$*" >&2
}

codex_python() {
  local candidate
  for candidate in python3.12 python3.11 python3; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

new_catalog_file() {
  local catalog_file

  catalog_file="$(mktemp "${TMPDIR:-/tmp}/codex-model-catalog.XXXXXX")"
  chmod 644 "${catalog_file}"
  printf '%s\n' "${catalog_file}"
}

validate_json() {
  local python_bin
  python_bin="$(codex_python)" || return 1
  "${python_bin}" -c 'import json, sys; json.load(sys.stdin)'
}

main() {
  local catalog_file

  [ -n "${CODEX_MODEL_CATALOG_JSON:-}" ] || return 0

  catalog_file="$(new_catalog_file)"
  printf '%s' "${CODEX_MODEL_CATALOG_JSON}" > "${catalog_file}"
  if ! validate_json < "${catalog_file}" >/dev/null 2>&1; then
    log "CODEX_MODEL_CATALOG_JSON is not valid JSON"
    rm -f "${catalog_file}"
    return 1
  fi

  printf '%s\n' "${catalog_file}"
}

main "$@"
