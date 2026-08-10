#!/bin/sh
# shellcheck disable=SC1091
. "${BASE_DIR}/lib/audit.sh"

tjc_audit_command() {
  ACTION="${1:-list}"
  case "$ACTION" in
    list) tjc_audit_list ;;
    tail) tjc_audit_tail "${2:-50}" ;;
    *) tjc_error 'Usage: tjc audit [list|tail] [count]'; return 1 ;;
  esac
}
