#!/bin/sh

# TJC Job command handler.
# shellcheck disable=SC1091
. "${BASE_DIR}/job/jobs.sh"

tjc_job_command() {
  ACTION="${1:-}"
  case "$ACTION" in
    list)
      printf '%-20s %-12s %-8s %-22s %-22s\n' "ID" "STATUS" "ATTEMPTS" "CREATED" "UPDATED"
      printf '%s\n' '--------------------------------------------------------------------------------'
      tjc_job_list | while IFS='	' read -r ID STATUS ATTEMPTS CREATED UPDATED; do
        printf '%-20s %-12s %-8s %-22s %-22s\n' "$ID" "$STATUS" "$ATTEMPTS" "$CREATED" "$UPDATED"
      done
      ;;
    show)
      ID="${2:-}"
      if [ -z "$ID" ]; then
        tjc_error 'Usage: tjc job show <id>'
        return 1
      fi
      tjc_job_get "$ID" || { tjc_error "Job '$ID' not found or is invalid."; return 1; }
      ;;
    create)
      ID="${2:-}"
      DESCRIPTION="${3:-}"
      if [ -z "$ID" ]; then
        tjc_error 'Usage: tjc job create <id> [description]'
        return 1
      fi
      tjc_job_create "$ID" "$DESCRIPTION" || return 1
      tjc_info "Created Job '$ID'."
      ;;
    cancel)
      ID="${2:-}"
      [ -n "$ID" ] || { tjc_error 'Usage: tjc job cancel <id>'; return 1; }
      tjc_job_cancel "$ID" || return 1
      tjc_info "Cancelled Job '$ID'."
      ;;
    retry)
      ID="${2:-}"
      [ -n "$ID" ] || { tjc_error 'Usage: tjc job retry <id>'; return 1; }
      tjc_job_retry "$ID" || return 1
      tjc_info "Queued Job '$ID' for retry."
      ;;
    status)
      ID="${2:-}"
      [ -n "$ID" ] || { tjc_error 'Usage: tjc job status <id>'; return 1; }
      tjc_job_status "$ID" || return 1
      ;;
    *)
      tjc_error "Unknown job command: $ACTION"
      printf '%s\n' \
        'Usage:' \
        '  tjc job create <id> [description]' \
        '  tjc job list' \
        '  tjc job show <id>' \
        '  tjc job status <id>' \
        '  tjc job cancel <id>' \
        '  tjc job retry <id>'
      return 1
      ;;
  esac
}
