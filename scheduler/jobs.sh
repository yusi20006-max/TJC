#!/bin/sh

# TJC Scheduler Job Management Module
# Tracks scheduled job execution history and state changes securely.

# Public function: tjc_scheduler_record_execution
# Usage: tjc_scheduler_record_execution <id> <status> [error_msg]
# Description: Updates schedule file state and records history of execution.
# Returns: Exit code 0 on success, 1 on failure.
tjc_scheduler_record_execution() {
  ID="$1"
  STATUS="$2"
  ERROR_MSG="${3:-}"

  if [ -z "$ID" ] || [ -z "$STATUS" ]; then
    tjc_error "Missing parameters for tjc_scheduler_record_execution."
    return 1
  fi

  if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
    tjc_error "Invalid schedule ID for recording execution."
    return 1
  fi

  tjc_scheduler_init_dir
  SCHED_DIR=$(tjc_scheduler_dir)
  HIST_DIR=$(tjc_scheduler_history_dir)

  JOB_FILE="${SCHED_DIR}/${ID}.json"
  HIST_FILE="${HIST_DIR}/history_${ID}.json"

  if [ ! -f "$JOB_FILE" ]; then
    tjc_error "Job file not found for recording execution: $ID"
    return 1
  fi

  RUN_TIME=$(date +'%Y-%m-%d %H:%M:%S')

  # Update main job file
  TEMP_JOB=$(mktemp)
  jq --arg run "$RUN_TIME" \
     --arg stat "$STATUS" \
     '.last_run = $run | .last_status = $stat' \
     "$JOB_FILE" > "$TEMP_JOB"
  mv "$TEMP_JOB" "$JOB_FILE"

  # Initialize history file as an array if it doesn't exist
  if [ ! -f "$HIST_FILE" ]; then
    echo "[]" > "$HIST_FILE"
  fi

  # Append execution record
  TEMP_HIST=$(mktemp)
  jq --arg time "$RUN_TIME" \
     --arg status "$STATUS" \
     --arg err "$ERROR_MSG" \
     '. += [{timestamp: $time, status: $status, error: $err}]' \
     "$HIST_FILE" > "$TEMP_HIST"
  mv "$TEMP_HIST" "$HIST_FILE"

  return 0
}
