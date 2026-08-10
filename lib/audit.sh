#!/bin/sh

# TJC structured audit/event layer.
# JSONL storage; sensitive fields are redacted before persistence.

tjc_audit_dir() {
  if command -v tjc_config_dir >/dev/null 2>&1; then printf '%s/audit\n' "$(tjc_config_dir)"; else printf '%s/.config/tjc/audit\n' "$HOME"; fi
}

tjc_audit_init() {
  DIR=$(tjc_audit_dir)
  mkdir -p "$DIR" || return 1
  chmod 700 "$DIR" 2>/dev/null || true
  FILE="$DIR/events.jsonl"
  [ -f "$FILE" ] || : >"$FILE"
  chmod 600 "$FILE" 2>/dev/null || true
}

tjc_audit_correlation_id() {
  if [ -n "${TJC_CORRELATION_ID:-}" ]; then printf '%s\n' "$TJC_CORRELATION_ID"; return 0; fi
  printf 'corr_%s_%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$"
}

tjc_audit_redact() {
  VALUE="$1"
  printf '%s' "$VALUE" | sed -E 's/([A-Za-z0-9_]*(key|token|secret|password|authorization)[A-Za-z0-9_]*[=:])[[:space:]]*[^[:space:],;]+/\1[REDACTED]/Ig'
}

tjc_audit_event() {
  EVENT="${1:-event}"; shift || true
  tjc_audit_init || return 1
  CORR="$(tjc_audit_correlation_id)"
  TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  JSON=$(jq -cn --arg timestamp "$TS" --arg event "$EVENT" --arg correlation_id "$CORR" '{timestamp:$timestamp,event:$event,correlation_id:$correlation_id}') || return 1
  for FIELD in "$@"; do
    KEY=${FIELD%%=*}; VALUE=${FIELD#*=}
    echo "$KEY" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' || continue
    case "$KEY" in
      *key*|*token*|*secret*|*password*|*authorization*) SAFE='[REDACTED]' ;;
      *) SAFE=$(tjc_audit_redact "$VALUE") ;;
    esac
    JSON=$(printf '%s' "$JSON" | jq --arg key "$KEY" --arg value "$SAFE" '. + {($key):$value}') || return 1
  done
  printf '%s\n' "$JSON" >>"$(tjc_audit_dir)/events.jsonl"
}

tjc_audit_list() {
  FILE="$(tjc_audit_dir)/events.jsonl"
  [ -f "$FILE" ] || return 0
  jq -c . "$FILE" 2>/dev/null || true
}

tjc_audit_tail() {
  LIMIT="${1:-50}"
  echo "$LIMIT" | grep -Eq '^[1-9][0-9]*$' || return 1
  tail -n "$LIMIT" "$(tjc_audit_dir)/events.jsonl" 2>/dev/null | jq -c . 2>/dev/null || true
}
