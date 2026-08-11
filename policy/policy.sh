#!/bin/sh

# TJC v2 Policy Engine
# Central, human-readable authorization boundary with explicit operation rules.

tjc_policy_file() {
  if [ -n "${TJC_POLICY_FILE:-}" ]; then printf '%s\n' "$TJC_POLICY_FILE"; else printf '%s/policy.yml\n' "$(tjc_config_dir)"; fi
}

tjc_policy_valid_path() {
  POLICY_PATH=$(tjc_policy_file)
  case "$POLICY_PATH" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) return 1;; esac
}

tjc_policy_default() {
  OP="$1"
  case "$OP" in
    workflow.validate|workflow.run|job.read|job.mutate|provider.read|provider.execute|queue.run|mcp.read|filesystem.read) return 0;;
    mcp.execute|plugin.execute|filesystem.write) return 1;;
    *) return 1;;
  esac
}

tjc_policy_allow() {
  OP="${1:-}"; [ -n "$OP" ] || return 1
  tjc_policy_valid_path || return 1
  POLICY_FILE_PATH=$(tjc_policy_file)
  [ -f "$POLICY_FILE_PATH" ] || { tjc_policy_default "$OP"; return $?; }
  yq . "$POLICY_FILE_PATH" >/dev/null 2>&1 || return 1
  DECISION=$(yq -r --arg op "$OP" '.operations[$op] // .defaults[$op] // .defaults.default // "deny"' "$POLICY_FILE_PATH" 2>/dev/null)
  [ "$DECISION" = allow ]
}

tjc_policy_require() {
  OP="$1"
  tjc_policy_allow "$OP" && return 0
  echo "Policy denied operation: $OP" >&2
  return 1
}

tjc_policy_init() {
  tjc_ensure_config_dir || return 1
  POLICY_FILE_PATH=$(tjc_policy_file)
  [ -f "$POLICY_FILE_PATH" ] && return 0
  cat >"$POLICY_FILE_PATH" <<'YAML'
version: 1
defaults:
  default: deny
operations:
  workflow.validate: allow
  workflow.run: allow
  job.read: allow
  job.mutate: allow
  provider.read: allow
  provider.execute: allow
  queue.run: allow
  mcp.read: allow
  mcp.execute: deny
  filesystem.read: allow
  filesystem.write: deny
  plugin.execute: deny
YAML
  chmod 600 "$POLICY_FILE_PATH"
}
