#!/bin/bash

set -e

DEFAULT_CODEX_BASE_URL="https://ark.cn-beijing.volces.com/api/v3"
DEFAULT_CODEX_MODEL="deepseek-v4-flash-260425"

log() {
  printf '%s codex-render: %s\n' "$(date '+%Y-%m-%d %H:%M:%S,%3N')" "$*" >&2
}

toml_quote() {
  jq -Rn --arg value "$1" '$value'
}

# tomllib is only available on Python >= 3.11. The image's default `python3`
# is 3.10, so prefer the bundled 3.12/3.11 interpreters for validation.
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

select_api_key_env() {
  if [ -n "${CODEX_API_KEY:-}" ]; then
    printf '%s\n' "CODEX_API_KEY"
  elif [ -n "${ARK_API_KEY:-}" ]; then
    printf '%s\n' "ARK_API_KEY"
  elif [ -n "${OPENAI_API_KEY:-}" ]; then
    printf '%s\n' "OPENAI_API_KEY"
  fi
}

api_key_is_set() {
  local api_key

  api_key="$(printenv "$1" 2>/dev/null || true)"
  [ -n "${api_key}" ]
}

new_config_file() {
  local config_file

  config_file="$(mktemp "${TMPDIR:-/tmp}/codex-config.XXXXXX")"
  chmod 644 "${config_file}"
  printf '%s\n' "${config_file}"
}

validate_toml() {
  local python_bin
  python_bin="$(codex_python)" || return 1
  "${python_bin}" -c 'import sys, tomllib; tomllib.loads(sys.stdin.read())'
}

render_full_config_toml() {
  local config_file="$1"

  printf '%s' "${CODEX_CONFIG_TOML}" > "${config_file}"
  if ! validate_toml < "${config_file}" >/dev/null 2>&1; then
    log "CODEX_CONFIG_TOML is not valid TOML"
    rm -f "${config_file}"
    return 1
  fi
}

render_openai_config() {
  local config_file="$1"

  {
    if [ -n "${CODEX_MODEL:-}" ]; then
      printf 'model = %s\n' "$(toml_quote "${CODEX_MODEL}")"
      printf 'review_model = %s\n' "$(toml_quote "${CODEX_MODEL}")"
    fi
    if [ -n "${CODEX_BASE_URL:-}" ]; then
      printf 'openai_base_url = %s\n' "$(toml_quote "${CODEX_BASE_URL}")"
    fi
    cat <<'EOF'
approval_policy = "never"
sandbox_mode = "danger-full-access"
model_reasoning_effort = "medium"
personality = "pragmatic"
EOF
  } > "${config_file}"
}

render_custom_provider_config() {
  local config_file="$1"
  local env_key="$2"
  local model="${CODEX_MODEL:-${DEFAULT_CODEX_MODEL}}"
  local base_url="${CODEX_BASE_URL:-${DEFAULT_CODEX_BASE_URL}}"

  cat > "${config_file}" <<EOF
model_provider = "codex"
model = $(toml_quote "${model}")
review_model = $(toml_quote "${model}")
approval_policy = "never"
sandbox_mode = "danger-full-access"
model_reasoning_effort = "medium"
personality = "pragmatic"

[model_providers.codex]
name = "codex"
base_url = $(toml_quote "${base_url}")
wire_api = "responses"
env_key = $(toml_quote "${env_key}")
EOF
}

main() {
  local env_key
  local config_file

  if [ -n "${CODEX_CONFIG_TOML:-}" ]; then
    config_file="$(new_config_file)"
    render_full_config_toml "${config_file}"
    printf '%s\n' "${config_file}"
    return 0
  fi

  env_key="$(select_api_key_env)"
  [ -n "${env_key}" ] || return 0
  api_key_is_set "${env_key}" || return 0

  config_file="$(new_config_file)"
  if [ "${env_key}" = "OPENAI_API_KEY" ]; then
    render_openai_config "${config_file}"
  else
    render_custom_provider_config "${config_file}" "${env_key}"
  fi

  printf '%s\n' "${config_file}"
}

main "$@"
