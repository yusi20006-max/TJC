#!/bin/sh

# TJC Scheduler Storage Module
# Manages persistence of schedules and validates all inputs to prevent directory traversal or command injection.

# Public function: tjc_scheduler_dir
# Usage: tjc_scheduler_dir
# Description: Returns the directory path where scheduler configurations are stored.
# Returns: String directory path. Exit code 0.
tjc_scheduler_dir() {
  CONFIG_DIR=$(tjc_config_dir)
  printf '%s/schedules\n' "$CONFIG_DIR"
  return 0
}

# Public function: tjc_scheduler_history_dir
# Usage: tjc_scheduler_history_dir
# Description: Returns the directory path where scheduler execution histories are stored.
# Returns: String directory path. Exit code 0.
tjc_scheduler_history_dir() {
  DIR=$(tjc_scheduler_dir)
  printf '%s/history\n' "$DIR"
  return 0
}

# Public function: tjc_scheduler_init_dir
# Usage: tjc_scheduler_init_dir
# Description: Ensures the schedule and history storage directories exist.
# Returns: Exit code 0.
tjc_scheduler_init_dir() {
  # shellcheck disable=SC3043 # local is supported by all target POSIX shells in Termux and standard Linux
  local SCHED_DIR HIST_DIR
  # Ensure base config dir exists with secure permissions (chmod 700)
  tjc_ensure_config_dir

  SCHED_DIR=$(tjc_scheduler_dir)
  HIST_DIR=$(tjc_scheduler_history_dir)

  if [ ! -d "$SCHED_DIR" ]; then
    mkdir -p "$SCHED_DIR"
  fi
  chmod 700 "$SCHED_DIR"

  if [ ! -d "$HIST_DIR" ]; then
    mkdir -p "$HIST_DIR"
  fi
  chmod 700 "$HIST_DIR"
  return 0
}

# Public function: tjc_scheduler_add
# Usage: tjc_scheduler_add <id> <workflow_file> <schedule_expr>
# Description: Validates inputs and creates a new schedule persistent record.
#              Rejects directory traversals, command injections, and unknown fields.
# Returns: Exit code 0 on success, 1 on failure.
tjc_scheduler_add() {
  ID="$1"
  WORKFLOW_FILE="$2"
  SCHEDULE_EXPR="$3" # e.g. "every_minute", "every_5_minutes", "hourly", "daily" or minutes like "5"

  if [ -z "$ID" ] || [ -z "$WORKFLOW_FILE" ] || [ -z "$SCHEDULE_EXPR" ]; then
    tjc_error "Missing parameters for tjc_scheduler_add."
    return 1
  fi

  # Strictly validate schedule ID to prevent directory traversal or command injection
  if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
    tjc_error "Invalid schedule ID '$ID'. Only alphanumeric characters, dashes, and underscores are allowed."
    return 1
  fi

  # Validate schedule expression
  case "$SCHEDULE_EXPR" in
    every_minute|every_5_minutes|every_10_minutes|every_30_minutes|hourly|daily)
      # Valid built-in expressions
      ;;
    *)
      # Or positive integer representing minutes
      if ! echo "$SCHEDULE_EXPR" | grep -Eq '^[0-9]+$'; then
        tjc_error "Invalid schedule expression '$SCHEDULE_EXPR'. Must be a built-in interval or positive integer."
        return 1
      fi
      ;;
  esac

  # Validate workflow file path (prevent unsafe chars)
  if echo "$WORKFLOW_FILE" | grep -Eq '[;&|`$]'; then
    tjc_error "Security alert: Unsafe characters detected in workflow file path."
    return 1
  fi

  if [ ! -f "$WORKFLOW_FILE" ]; then
    tjc_error "Workflow file '$WORKFLOW_FILE' does not exist."
    return 1
  fi

  # Ensure the directory structure is initialized
  tjc_scheduler_init_dir
  SCHED_DIR=$(tjc_scheduler_dir)
  JOB_FILE="${SCHED_DIR}/${ID}.json"

  if [ -f "$JOB_FILE" ]; then
    tjc_error "Schedule with ID '$ID' already exists."
    return 1
  fi

  # Resolve to absolute path securely
  ABS_WF_FILE=$(cd "$(dirname "$WORKFLOW_FILE")" && pwd)/$(basename "$WORKFLOW_FILE")

  CREATED_AT=$(date +'%Y-%m-%d %H:%M:%S')

  # Create schedule record
  jq -n \
    --arg id "$ID" \
    --arg wf "$ABS_WF_FILE" \
    --arg expr "$SCHEDULE_EXPR" \
    --arg created "$CREATED_AT" \
    '{id: $id, workflow_file: $wf, schedule_expression: $expr, created_at: $created, last_run: null, last_status: null}' > "$JOB_FILE"
  chmod 600 "$JOB_FILE"

  tjc_success "Schedule '$ID' added successfully."
  return 0
}

# Public function: tjc_scheduler_remove
# Usage: tjc_scheduler_remove <id>
# Description: Removes a persistent schedule config if it exists.
# Returns: Exit code 0 on success, 1 on failure.
tjc_scheduler_remove() {
  ID="$1"

  if [ -z "$ID" ]; then
    tjc_error "Usage: tjc_scheduler_remove <id>"
    return 1
  fi

  if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
    tjc_error "Invalid schedule ID."
    return 1
  fi

  tjc_scheduler_init_dir
  SCHED_DIR=$(tjc_scheduler_dir)
  JOB_FILE="${SCHED_DIR}/${ID}.json"

  if [ ! -f "$JOB_FILE" ]; then
    tjc_error "Schedule with ID '$ID' not found."
    return 1
  fi

  rm -f "$JOB_FILE"
  tjc_success "Schedule '$ID' removed successfully."
  return 0
}

# Public function: tjc_scheduler_get
# Usage: tjc_scheduler_get <id>
# Description: Reads and outputs content of a schedule config.
# Returns: Exit code 0 on success, 1 on failure.
tjc_scheduler_get() {
  ID="$1"

  if [ -z "$ID" ]; then
    return 1
  fi

  if ! echo "$ID" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
    return 1
  fi

  SCHED_DIR=$(tjc_scheduler_dir)
  JOB_FILE="${SCHED_DIR}/${ID}.json"

  if [ -f "$JOB_FILE" ]; then
    cat "$JOB_FILE"
    return 0
  fi
  return 1
}
