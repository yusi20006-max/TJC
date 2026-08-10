#!/bin/sh

# TJC Provider Interface
# Provider-neutral capability dispatch. Provider implementations must expose
# the functions declared here without leaking credentials into callers.

tjc_provider_name() {
  printf '%s\n' "${TJC_PROVIDER:-jules}"
}

tjc_provider_require() {
  CAPABILITY="${1:-}"
  PROVIDER=$(tjc_provider_name)
  case "$PROVIDER" in
    jules)
      case "$CAPABILITY" in
        authenticate|list_sources|create_session|get_session|list_activities|get_pull_request|cancel_operation) return 0;;
      esac
      ;;
  esac
  echo "Unsupported provider capability: $CAPABILITY" >&2
  return 1
}
