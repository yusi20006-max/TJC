#!/bin/sh

# TJC Workflow Parser
# Read-only helpers for YAML/JSON workflow definitions.

tjc_workflow_get_name() {
  FILE="${1:-}"
  [ -n "$FILE" ] || return 1
  yq -r '.name // ""' "$FILE" 2>/dev/null
}

tjc_workflow_get_description() {
  FILE="${1:-}"
  [ -n "$FILE" ] || return 1
  yq -r '.description // ""' "$FILE" 2>/dev/null
}

tjc_workflow_get_steps_count() {
  FILE="${1:-}"
  [ -f "$FILE" ] || { printf '0\n'; return 1; }
  yq '.steps | length' "$FILE" 2>/dev/null
}

tjc_workflow_get_step_type() {
  FILE="${1:-}"
  INDEX="${2:-}"
  [ -n "$FILE" ] && [ -n "$INDEX" ] || return 1
  yq -r ".steps[$INDEX].type // \"\"" "$FILE" 2>/dev/null
}

tjc_workflow_get_step_params() {
  FILE="${1:-}"
  INDEX="${2:-}"
  [ -n "$FILE" ] && [ -n "$INDEX" ] || return 1
  yq -c ".steps[$INDEX] // {}" "$FILE" 2>/dev/null
}

tjc_workflow_get_step_dependencies() {
  FILE="${1:-}"
  INDEX="${2:-}"
  yq -r ".steps[$INDEX].depends_on // [] | .[]" "$FILE" 2>/dev/null
}

tjc_workflow_get_step_condition() {
  FILE="${1:-}"
  INDEX="${2:-}"
  yq -r ".steps[$INDEX].condition // \"on_success\"" "$FILE" 2>/dev/null
}

tjc_workflow_get_step_retry_attempts() {
  FILE="${1:-}"
  INDEX="${2:-}"
  VALUE=$(yq -r ".steps[$INDEX].retry.attempts // 0" "$FILE" 2>/dev/null)
  case "$VALUE" in
    *[!0-9]*|'') printf '0\n' ;;
    *) printf '%s\n' "$VALUE" ;;
  esac
}

tjc_workflow_get_step_timeout() {
  FILE="${1:-}"
  INDEX="${2:-}"
  VALUE=$(yq -r ".steps[$INDEX].timeout.seconds // 0" "$FILE" 2>/dev/null)
  case "$VALUE" in
    *[!0-9]*|'') printf '0\n' ;;
    *) printf '%s\n' "$VALUE" ;;
  esac
}

tjc_workflow_get_variables() {
  FILE="${1:-}"
  yq -c '.variables // {}' "$FILE" 2>/dev/null
}
