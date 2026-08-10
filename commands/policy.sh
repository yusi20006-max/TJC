#!/bin/sh
# shellcheck disable=SC1091
. "${BASE_DIR}/policy/policy.sh"

tjc_policy_command() {
  ACTION="${1:-show}"
  case "$ACTION" in
    init) tjc_policy_init; tjc_info "Policy file: $(tjc_policy_file)" ;;
    check)
      OP="${2:-}"; [ -n "$OP" ] || { tjc_error 'Usage: tjc policy check <operation>'; return 1; }
      if tjc_policy_allow "$OP"; then tjc_success "ALLOW $OP"; else tjc_error "DENY $OP"; return 1; fi
      ;;
    show)
      FILE=$(tjc_policy_file)
      if [ -f "$FILE" ]; then cat "$FILE"; else tjc_policy_init; cat "$FILE"; fi
      ;;
    *) tjc_error 'Usage: tjc policy [init|show|check <operation>]'; return 1 ;;
  esac
}
