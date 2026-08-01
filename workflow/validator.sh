#!/bin/sh

# TJC Workflow Validator
# Validates workflow schemas, keys, types, and protects against directory traversal and command injection.

# Public function: tjc_workflow_validate
# Usage: tjc_workflow_validate <workflow_file>
# Description: Performs thorough validation of a workflow file.
# Returns: Exit code 0 if valid, non-zero (1) if invalid with descriptive error messages.
tjc_workflow_validate() {
  FILE="$1"

  if [ -z "$FILE" ]; then
    tjc_error "Usage: tjc_workflow_validate <workflow_file>"
    return 1
  fi

  # Prevent directory traversal or shell injection in the filename/path
  # Allow standard characters: alphanumeric, dots, slashes, dashes, underscores
  if echo "$FILE" | grep -Eq '[;&|`$]'; then
    tjc_error "Security alert: Unsafe characters detected in workflow file path."
    return 1
  fi

  if [ ! -f "$FILE" ]; then
    tjc_error "Workflow file does not exist: $FILE"
    return 1
  fi

  # Check if valid YAML/JSON
  if ! yq . "$FILE" >/dev/null 2>&1; then
    tjc_error "Workflow file is not valid YAML or JSON: $FILE"
    return 1
  fi

  # Check for unknown fields at the top-level
  # Allowed top-level fields are name, description, steps
  TOP_KEYS=$(yq -r 'keys[]' "$FILE" 2>/dev/null)
  for KEY in $TOP_KEYS; do
    case "$KEY" in
      name|description|steps)
        # Allowed
        ;;
      *)
        tjc_error "Workflow validation failed: Unknown top-level field '$KEY' is not allowed."
        return 1
        ;;
    esac
  done

  # Validate Name
  NAME=$(tjc_workflow_get_name "$FILE")
  if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
    tjc_error "Workflow validation failed: 'name' is required and cannot be empty."
    return 1
  fi

  # Check for unsafe characters in workflow name to prevent log injection
  NL='
'
  CR=$(printf '\r')
  case "$NAME" in
    *"$NL"*|*"$CR"*)
      tjc_error "Workflow validation failed: Name contains invalid newline characters."
      return 1
      ;;
  esac

  # Validate Steps structure
  STEPS_COUNT=$(tjc_workflow_get_steps_count "$FILE")
  if [ "$STEPS_COUNT" -eq 0 ]; then
    tjc_error "Workflow validation failed: 'steps' must be a non-empty array."
    return 1
  fi

  # Validate each step type
  INDEX=0
  while [ "$INDEX" -lt "$STEPS_COUNT" ]; do
    TYPE=$(tjc_workflow_get_step_type "$FILE" "$INDEX")
    if [ -z "$TYPE" ] || [ "$TYPE" = "null" ]; then
      tjc_error "Workflow validation failed: Step $INDEX is missing 'type'."
      return 1
    fi

    # Check if type is one of the strictly allowed step types
    case "$TYPE" in
      create_session)
        # Check create_session parameters
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        # Allowed keys for create_session: type, session_name
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type|session_name) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for create_session."
              return 1
              ;;
          esac
        done

        SESS_NAME=$(echo "$PARAMS" | jq -r '.session_name // ""')
        if [ -n "$SESS_NAME" ] && [ "$SESS_NAME" != "null" ]; then
          if ! echo "$SESS_NAME" | grep -Eq '^[a-zA-Z0-9_-]+$'; then
            tjc_error "Workflow validation failed: Step $INDEX session_name is unsafe. Must be alphanumeric, dashes, and underscores only."
            return 1
          fi
        fi
        ;;
      watch_session)
        # Check watch_session parameters
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        # Allowed keys for watch_session: type, session_id
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type|session_id) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for watch_session."
              return 1
              ;;
          esac
        done

        SESS_ID=$(echo "$PARAMS" | jq -r '.session_id // ""')
        if [ -n "$SESS_ID" ] && [ "$SESS_ID" != "null" ]; then
          if ! echo "$SESS_ID" | grep -Eq '^[a-zA-Z0-9_.-]+$'; then
            tjc_error "Workflow validation failed: Step $INDEX session_id is unsafe."
            return 1
          fi
        fi
        ;;
      list_activities)
        # Check list_activities parameters
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for list_activities."
              return 1
              ;;
          esac
        done
        ;;
      get_pr)
        # Check get_pr parameters
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        # Allowed keys for get_pr: type, pr_number
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type|pr_number) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for get_pr."
              return 1
              ;;
          esac
        done

        PR_NUM=$(echo "$PARAMS" | jq -r '.pr_number // ""')
        if [ -n "$PR_NUM" ] && [ "$PR_NUM" != "null" ]; then
          if ! echo "$PR_NUM" | grep -Eq '^[0-9]+$'; then
            tjc_error "Workflow validation failed: Step $INDEX pr_number is invalid. Must be a positive integer."
            return 1
          fi
        fi
        ;;
      doctor)
        # Check doctor parameters
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for doctor."
              return 1
              ;;
          esac
        done
        ;;
      *)
        tjc_error "Workflow validation failed: Step $INDEX has invalid or forbidden type '$TYPE'."
        tjc_error "Allowed step types are: create_session, watch_session, list_activities, get_pr, doctor."
        return 1
        ;;
    esac

    INDEX=$((INDEX + 1))
  done

  return 0
}
