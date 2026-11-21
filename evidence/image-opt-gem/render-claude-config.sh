#!/bin/bash
set -e

DEFAULT_CLAUDE_BASE_URL="https://ark.cn-beijing.volces.com/api/compatible"
DEFAULT_CLAUDE_MODEL="deepseek-v4-flash-260425"

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ] && [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  return 0 2>/dev/null || exit 0
fi

if [ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  model="${ANTHROPIC_MODEL:-${DEFAULT_CLAUDE_MODEL}}"
  base_url="${ANTHROPIC_BASE_URL:-${DEFAULT_CLAUDE_BASE_URL}}"
else
  model="${ANTHROPIC_MODEL:-}"
  base_url="${ANTHROPIC_BASE_URL:-}"
fi

config_file="$(mktemp "${TMPDIR:-/tmp}/claude-config.XXXXXX")"
chmod 600 "${config_file}"

jq -n \
  --arg auth_token "${ANTHROPIC_AUTH_TOKEN:-}" \
  --arg api_key "${ANTHROPIC_API_KEY:-}" \
  --arg base_url "${base_url}" \
  --arg model "${model}" \
  '{
    env: (
      {}
      + (if $auth_token != "" then {ANTHROPIC_AUTH_TOKEN: $auth_token} else {} end)
      + (if $api_key != "" then {ANTHROPIC_API_KEY: $api_key} else {} end)
      + (if $base_url != "" then {ANTHROPIC_BASE_URL: $base_url} else {} end)
      + (if $model != "" then {ANTHROPIC_MODEL: $model} else {} end)
    )
  }' > "${config_file}"

printf '%s\n' "${config_file}"
