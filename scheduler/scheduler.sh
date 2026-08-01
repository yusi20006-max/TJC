#!/bin/sh

# TJC Scheduler Core Engine
# Manages checking and executing scheduled/pending jobs automatically and safely.

# Ensure dependencies are loaded
# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/lib/logger.sh"
# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/scheduler/storage.sh"
# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/scheduler/jobs.sh"
# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/workflow/engine.sh"

# Public function: tjc_get_epoch
# Usage: tjc_get_epoch <date_str>
# Description: Converts a date/time string "YYYY-MM-DD HH:MM:SS" to epoch seconds.
#              Supports both GNU date and BSD/macOS date formats.
# Returns: Non-negative integer epoch seconds. Exit code 0.
tjc_get_epoch() {
  DATE_STR="$1"
  if [ -z "$DATE_STR" ] || [ "$DATE_STR" = "null" ]; then
    printf '0\n'
    return 0
  fi

  # GNU date format
  EPOCH=$(date -d "$DATE_STR" +%s 2>/dev/null)
  if [ -n "$EPOCH" ]; then
    printf '%s\n' "$EPOCH"
    return 0
  fi

  # BSD/macOS date format
  EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_STR" "+%s" 2>/dev/null)
  if [ -n "$EPOCH" ]; then
    printf '%s\n' "$EPOCH"
    return 0
  fi

  # Fallback
  printf '0\n'
  return 0
}

# Public function: tjc_scheduler_expression_to_minutes
# Usage: tjc_scheduler_expression_to_minutes <expression>
# Description: Translates interval descriptors into integer values of minutes.
# Returns: String representing positive integer minutes. Exit code 0.
tjc_scheduler_expression_to_minutes() {
  EXPR="$1"
  case "$EXPR" in
    every_minute|1) printf '1\n' ;;
    every_5_minutes|5) printf '5\n' ;;
    every_10_minutes|10) printf '10\n' ;;
    every_30_minutes|30) printf '30\n' ;;
    hourly|60) printf '60\n' ;;
    daily|1440) printf '1440\n' ;;
    *)
      # Check if it is an integer
      if echo "$EXPR" | grep -Eq '^[0-9]+$'; then
        printf '%s\n' "$EXPR"
      else
        # Default to 60 minutes
        printf '60\n'
      fi
      ;;
  esac
  return 0
}

# Public function: tjc_scheduler_run_pending
# Usage: tjc_scheduler_run_pending
# Description: Scans scheduled configurations, determines if they are due based on last execution time,
#              runs the due workflows, and records outcomes in their history files.
# Returns: Exit code 0 on success, non-zero on error.
tjc_scheduler_run_pending() {
  tjc_scheduler_init_dir
  SCHED_DIR=$(tjc_scheduler_dir)

  if [ -z "$(ls -A "$SCHED_DIR"/*.json 2>/dev/null)" ]; then
    tjc_log_info "No scheduled jobs to run."
    tjc_info "No scheduled jobs to run."
    return 0
  fi

  NOW_EPOCH=$(date +%s)

  for JOB_FILE in "$SCHED_DIR"/*.json; do
    if [ -f "$JOB_FILE" ]; then
      ID=$(jq -r '.id' "$JOB_FILE")
      WORKFLOW_FILE=$(jq -r '.workflow_file' "$JOB_FILE")
      EXPR=$(jq -r '.schedule_expression' "$JOB_FILE")
      LAST_RUN=$(jq -r '.last_run' "$JOB_FILE")

      REQUIRED_MINUTES=$(tjc_scheduler_expression_to_minutes "$EXPR")

      RUN_JOB=0
      if [ -z "$LAST_RUN" ] || [ "$LAST_RUN" = "null" ]; then
        RUN_JOB=1
      else
        LAST_EPOCH=$(tjc_get_epoch "$LAST_RUN")
        ELAPSED_SECONDS=$((NOW_EPOCH - LAST_EPOCH))
        ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))

        if [ "$ELAPSED_MINUTES" -ge "$REQUIRED_MINUTES" ]; then
          RUN_JOB=1
        fi
      fi

      if [ "$RUN_JOB" -eq 1 ]; then
        tjc_log_info "Executing pending scheduled job: $ID ($WORKFLOW_FILE)"
        tjc_info "Running scheduled job: $ID..."

        # Execute workflow
        if tjc_workflow_execute "$WORKFLOW_FILE"; then
          tjc_scheduler_record_execution "$ID" "COMPLETED"
          tjc_success "Scheduled job '$ID' completed successfully."
        else
          tjc_scheduler_record_execution "$ID" "FAILED" "Workflow execution failed"
          tjc_error "Scheduled job '$ID' failed."
        fi
      else
        tjc_log_debug "Job '$ID' is not due yet. Last run: $LAST_RUN, Interval: $REQUIRED_MINUTES min"
      fi
    fi
  done

  return 0
}
