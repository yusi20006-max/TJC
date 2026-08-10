#!/bin/sh

# TJC Provider Loader
# Loads exactly one configured provider implementation.

# shellcheck disable=SC1091
. "${BASE_DIR}/providers/base.sh"

TJC_PROVIDER_LOADED="${TJC_PROVIDER_LOADED:-false}"

tjc_provider_load() {
  [ "$TJC_PROVIDER_LOADED" = true ] && return 0
  PROVIDER=$(tjc_provider_name)
  case "$PROVIDER" in
    jules)
      # shellcheck disable=SC1091
      . "${BASE_DIR}/providers/jules.sh"
      ;;
    *) echo "Unsupported TJC provider: $PROVIDER" >&2; return 1;;
  esac
  TJC_PROVIDER_LOADED=true
  export TJC_PROVIDER_LOADED
}

tjc_provider_init() {
  tjc_provider_load || return 1
  tjc_provider_authenticate
}
