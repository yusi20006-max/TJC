#!/bin/sh
# TJC Queue CLI
# shellcheck disable=SC1091
. "${BASE_DIR}/queue/queue.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/policy/policy.sh"

tjc_queue_command() {
  ACTION="${1:-}"
  case "$ACTION" in
    init) tjc_queue_init ;;
    add)
      tjc_policy_require job.mutate || return 1
      WORKFLOW="${2:-}"; PRIORITY="${3:-50}"; ID="${4:-}"
      [ -n "$WORKFLOW" ] || { tjc_error 'Usage: tjc queue add <workflow.yml> [priority] [id]'; return 1; }
      ID_RESULT=$(tjc_queue_add_workflow "$WORKFLOW" "$PRIORITY" "$ID") || return 1
      tjc_success "Queued Job: $ID_RESULT"
      ;;
    list)
      tjc_policy_require job.read || return 1
      printf '%-22s %-22s %-10s %-8s %-24s %s\n' ID JOB STATUS PRIORITY CREATED WORKFLOW
      tjc_queue_list
      ;;
    remove)
      tjc_policy_require job.mutate || return 1
      ID="${2:-}"; [ -n "$ID" ] || { tjc_error 'Usage: tjc queue remove <id>'; return 1; }
      tjc_queue_remove "$ID"
      ;;
    run)
      tjc_policy_require queue.run || return 1
      WORKERS="${2:-${TJC_MAX_WORKERS:-2}}"
      tjc_queue_run "$WORKERS"
      ;;
    *)
      tjc_error "Unknown queue command: $ACTION"
      printf '%s\n' \
        'Usage:' \
        '  tjc queue init' \
        '  tjc queue add <workflow.yml> [priority] [id]' \
        '  tjc queue list' \
        '  tjc queue remove <id>' \
        '  tjc queue run [workers]'
      return 1
      ;;
  esac
}
