#!/bin/sh

# TJC v2 Policy Engine
# Central, human-readable authorization boundary with restrictive defaults.

tjc_policy_file() {
  if [ -n "${TJC_POLICY_FILE:-}" ]; then printf '%s\n' "$TJC_POLICY_FILE"; else printf '%s/policy.yml\n' "$(tjc_config_dir)"; fi
}

tjc_policy_valid_path() {
  PATH_VALUE=$(tjc_policy_file)
  case "$PATH_VALUE" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) return 1;; esac
  return 0
}

tjc_policy_default() {
  OP="$1"
  case "$OP" in
    workflow.validate|job.read|provider.read|mcp.read|filesystem.read) return 0;;
    *) return 1;;
  esac
}

tjc_policy_allow() {
  OP="${1:-}"
  [ -n "$OP" ] || return 1
  tjc_policy_valid_path || return 1
  FILE=$(tjc_policy_file)
  [ -f "$FILE" ] || { tjc_policy_default "$OP"; return $?; }
  yq . "$FILE" >/dev/null 2>&1 || return 1
  DECISION=$(yq -r --arg op "$OP" '.operations[$op] // .defaults[$op] // .defaults.default // "deny"' "$FILE" 2>/dev/null)
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
  FILE=$(tjc_policy_file)
  [ -f "$FILE" ] && return 0
  cat >"$FILE" <<'YAML'
version: 1
defaults:
  default: deny
operations:
  workflow.validate: allow
  job.read: allow
  provider.read: allow
  mcp.read: allow
  filesystem.read: allow
  workflow.run: deny
  job.mutate: deny
  provider.execute: deny
  mcp.execute: deny
  queue.run: deny
  plugin.execute: deny
YAML
  chmod 600 "$FILE"
}
