#!/bin/sh

# TJC Scheduler Command Handler
# Handles user interface for adding, listing, removing, running, and displaying execution history of schedules.

# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/scheduler/scheduler.sh"

# Public function: tjc_schedule
# Usage: tjc_schedule <action> [arguments]
# Description: Dispatches scheduler CLI commands: add, list, remove, run, run-pending, history.
# Returns: Exit code 0 on success, non-zero on failure.
tjc_schedule() {
  ACTION="${1:-}"

  case "$ACTION" in
    add)
      ID="${2:-}"
      FILE="${3:-}"
      EXPR="${4:-hourly}"

      if [ -z "$ID" ] || [ -z "$FILE" ]; then
        tjc_error "Usage: tjc schedule add <id> <workflow_file.yml> [schedule_expression]"
        return 1
      fi

      if ! tjc_scheduler_add "$ID" "$FILE" "$EXPR"; then
        return 1
      fi
      ;;
    list)
      SCHED_DIR=$(tjc_scheduler_dir)
      if [ ! -d "$SCHED_DIR" ] || [ -z "$(ls -A "$SCHED_DIR"/*.json 2>/dev/null)" ]; then
        tjc_info "No schedules configured."
        return 0
      fi

      tjc_info "Active Schedules:"
      printf '%-15s %-30s %-15s %-20s %-12s\n' "ID" "WORKFLOW FILE" "INTERVAL" "LAST RUN" "LAST STATUS"
      printf '%s\n' "--------------------------------------------------------------------------------------------------"

      for JOB_FILE in "$SCHED_DIR"/*.json; do
        if [ -f "$JOB_FILE" ]; then
          ID=$(jq -r '.id' "$JOB_FILE")
          WF_FILE=$(jq -r '.workflow_file' "$JOB_FILE")
          EXPR=$(jq -r '.schedule_expression' "$JOB_FILE")
          LAST_RUN=$(jq -r '.last_run // "Never"' "$JOB_FILE")
          LAST_STATUS=$(jq -r '.last_status // "Never"' "$JOB_FILE")

          # Shorten filepath for display
          SHORT_WF=$(basename "$WF_FILE")

          case "$LAST_STATUS" in
            COMPLETED) STATUS_COLOR="${TJC_COLOR_GREEN}${LAST_STATUS}${TJC_COLOR_RESET}" ;;
            FAILED) STATUS_COLOR="${TJC_COLOR_RED}${LAST_STATUS}${TJC_COLOR_RESET}" ;;
            *) STATUS_COLOR="${TJC_COLOR_YELLOW}${LAST_STATUS}${TJC_COLOR_RESET}" ;;
          esac

          printf '%-15s %-30s %-15s %-20s %-12b\n' "$ID" "$SHORT_WF" "$EXPR" "$LAST_RUN" "$STATUS_COLOR"
        fi
      done
      ;;
    remove)
      ID="${2:-}"
      if [ -z "$ID" ]; then
        tjc_error "Usage: tjc schedule remove <id>"
        return 1
      fi

      if ! tjc_scheduler_remove "$ID"; then
        return 1
      fi
      ;;
    run-pending)
      # Run any scheduled workflows that are due (automatic execution mode)
      if ! tjc_scheduler_run_pending; then
        return 1
      fi
      ;;
    run)
      ID="${2:-}"
      SCHED_DIR=$(tjc_scheduler_dir)

      if [ -z "$ID" ]; then
        # Run all jobs immediately
        if [ -z "$(ls -A "$SCHED_DIR"/*.json 2>/dev/null)" ]; then
          tjc_info "No schedules found to run."
          return 0
        fi

        RET=0
        for JOB_FILE in "$SCHED_DIR"/*.json; do
          if [ -f "$JOB_FILE" ]; then
            J_ID=$(jq -r '.id' "$JOB_FILE")
            WF_FILE=$(jq -r '.workflow_file' "$JOB_FILE")
            tjc_info "Manually triggering job: $J_ID ($WF_FILE)"
            if tjc_workflow_execute "$WF_FILE"; then
              tjc_scheduler_record_execution "$J_ID" "COMPLETED"
            else
              tjc_scheduler_record_execution "$J_ID" "FAILED" "Manual run failed"
              RET=1
            fi
          fi
        done
        return "$RET"
      else
        # Run specific job immediately
        if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
          tjc_error "Invalid schedule ID format."
          return 1
        fi

        JOB_FILE="${SCHED_DIR}/${ID}.json"
        if [ ! -f "$JOB_FILE" ]; then
          tjc_error "Schedule '$ID' not found."
          return 1
        fi

        WF_FILE=$(jq -r '.workflow_file' "$JOB_FILE")
        tjc_info "Manually triggering job: $ID ($WF_FILE)"
        if tjc_workflow_execute "$WF_FILE"; then
          tjc_scheduler_record_execution "$ID" "COMPLETED"
        else
          tjc_scheduler_record_execution "$ID" "FAILED" "Manual run failed"
          return 1
        fi
      fi
      ;;
    history)
      ID="${2:-}"
      if [ -z "$ID" ]; then
        tjc_error "Usage: tjc schedule history <id>"
        return 1
      fi

      if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
        tjc_error "Invalid schedule ID format."
        return 1
      fi

      HIST_DIR=$(tjc_scheduler_history_dir)
      HIST_FILE="${HIST_DIR}/history_${ID}.json"

      if [ ! -f "$HIST_FILE" ]; then
        tjc_info "No execution history found for schedule '$ID'."
        return 0
      fi

      tjc_info "Execution History for '$ID':"
      printf '%-25s %-15s %-30s\n' "TIMESTAMP" "STATUS" "ERROR/MESSAGE"
      printf '%s\n' "--------------------------------------------------------------------------------"

      jq -c '.[]' "$HIST_FILE" 2>/dev/null | while read -r HIST_ROW; do
        TIMESTAMP=$(echo "$HIST_ROW" | jq -r '.timestamp')
        STATUS=$(echo "$HIST_ROW" | jq -r '.status')
        ERROR=$(echo "$HIST_ROW" | jq -r '.error // ""')

        case "$STATUS" in
          COMPLETED) STATUS_COLOR="${TJC_COLOR_GREEN}${STATUS}${TJC_COLOR_RESET}" ;;
          FAILED) STATUS_COLOR="${TJC_COLOR_RED}${STATUS}${TJC_COLOR_RESET}" ;;
          *) STATUS_COLOR="${TJC_COLOR_YELLOW}${STATUS}${TJC_COLOR_RESET}" ;;
        esac

        printf '%-25s %-15b %-30s\n' "$TIMESTAMP" "$STATUS_COLOR" "$ERROR"
      done
      ;;
    *)
      tjc_error "Unknown schedule command: $ACTION"
      echo "Usage:"
      echo "  tjc schedule add <id> <workflow_file.yml> [expr]   Add a scheduled workflow"
      echo "  tjc schedule list                                   List active schedules"
      echo "  tjc schedule remove <id>                            Remove a schedule"
      echo "  tjc schedule run [id]                               Run schedule(s) immediately"
      echo "  tjc schedule run-pending                            Run pending/due schedules"
      echo "  tjc schedule history <id>                           Show job execution history"
      return 1
      ;;
  esac
  return 0
}
