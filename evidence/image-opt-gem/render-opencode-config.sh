#!/bin/bash
#
# Render opencode config from environment variables.
#
# Priority (highest first):
#   1. OPENCODE_JSON              — full config JSON, used verbatim.
#   2. OPENCODE_API_KEY + OPENCODE_MODEL — render from template via jq.
#   3. (none)                     — print nothing; opencode falls back to its
#                                   bundled defaults (e.g. opencode/big-pickle).
#
# On success: prints the absolute path of a rendered temp file to stdout.
# On no-op or failure: prints nothing to stdout. Diagnostics go to stderr.
#
# Notes
#   * Stdout is reserved for the file path so the caller can `read` it.
#   * The rendered file is `chmod 644` and (best-effort) `chown` to $USER so
#     it can be consumed after `su - $USER`.

set -e

DEFAULT_OPENCODE_PROVIDER="ark"
DEFAULT_OPENCODE_BASE_URL="https://ark.cn-beijing.volces.com/api/v3"
OPENCODE_TPL="${OPENCODE_TPL:-/opt/gem/opencode/config.json}"

log() {
  printf '%s opencode-render: %s\n' "$(date '+%Y-%m-%d %H:%M:%S,%3N')" "$*" >&2
}

new_config_file() {
  local config_file
  config_file="$(mktemp "${TMPDIR:-/tmp}/opencode-config.XXXXXX")"
  chmod 644 "${config_file}"
  printf '%s\n' "${config_file}"
}

handoff_to_user() {
  local config_file="$1"
  if [ -n "${USER:-}" ]; then
    chown "${USER}:${USER}" "${config_file}" 2>/dev/null || true
  fi
}

detect_provider_npm() {
  local base_url="$1"
  if [ -n "${OPENCODE_PROVIDER_NPM:-}" ]; then
    printf '%s\n' "${OPENCODE_PROVIDER_NPM}"
    return
  fi
  case "${base_url}" in
    *anthropic*) printf '@ai-sdk/anthropic\n' ;;
    *)           printf '@ai-sdk/openai-compatible\n' ;;
  esac
}

render_from_full_json() {
  local config_file
  config_file="$(new_config_file)"
  printf '%s\n' "${OPENCODE_JSON}" > "${config_file}"
  if ! jq -e . "${config_file}" >/dev/null 2>&1; then
    log "OPENCODE_JSON is not valid JSON, ignoring"
    rm -f "${config_file}"
    return 1
  fi
  handoff_to_user "${config_file}"
  log "rendered config from OPENCODE_JSON"
  printf '%s\n' "${config_file}"
}

render_from_env_vars() {
  if [ ! -f "${OPENCODE_TPL}" ]; then
    log "template missing at ${OPENCODE_TPL}, skipping render"
    return 1
  fi

  local provider="${OPENCODE_PROVIDER:-${DEFAULT_OPENCODE_PROVIDER}}"
  local base_url="${OPENCODE_BASE_URL:-${DEFAULT_OPENCODE_BASE_URL}}"
  local npm
  npm="$(detect_provider_npm "${base_url}")"

  local config_file tmp
  config_file="$(new_config_file)"
  tmp="${config_file}.tmp"

  if ! jq --arg provider "${provider}" \
          --arg model "${provider}/${OPENCODE_MODEL}" \
          --arg url "${base_url}" \
          --arg key "${OPENCODE_API_KEY}" \
          --arg mid "${OPENCODE_MODEL}" \
          --arg npm "${npm}" \
          '.model = $model
           | .provider[$provider].npm = $npm
           | .provider[$provider].name = $provider
           | .provider[$provider].options.baseURL = $url
           | .provider[$provider].options.apiKey = $key
           | .provider[$provider].models[$mid] = {}' \
          "${OPENCODE_TPL}" > "${tmp}" \
     || [ ! -s "${tmp}" ]; then
    log "failed to render config from OPENCODE_* env vars"
    rm -f "${tmp}" "${config_file}"
    return 1
  fi

  mv "${tmp}" "${config_file}"
  handoff_to_user "${config_file}"
  log "rendered config (provider=${provider}, model=${OPENCODE_MODEL}, npm=${npm})"
  printf '%s\n' "${config_file}"
}

main() {
  if [ -n "${OPENCODE_JSON:-}" ]; then
    render_from_full_json || return 0
    return 0
  fi
  if [ -n "${OPENCODE_API_KEY:-}" ] && [ -n "${OPENCODE_MODEL:-}" ]; then
    render_from_env_vars || return 0
    return 0
  fi
  log "OPENCODE_API_KEY/OPENCODE_MODEL not set, leaving opencode to bundled defaults"
}

main "$@"
