#!/bin/sh

# TJC Workflow Validator
# Strict schema validation for safe, deterministic workflow execution.

tjc_workflow_validate() {
  FILE="${1:-}"

  [ -n "$FILE" ] || { tjc_error 'Usage: tjc_workflow_validate <workflow_file>'; return 1; }
  case "$FILE" in *';'*|*'&'*|*'|'*|*'`'*|*'$'*) tjc_error 'Security alert: unsafe workflow path.'; return 1;; esac
  [ -f "$FILE" ] || { tjc_error "Workflow file does not exist: $FILE"; return 1; }
  yq . "$FILE" >/dev/null 2>&1 || { tjc_error 'Workflow file is not valid YAML or JSON.'; return 1; }

  TOP_KEYS=$(yq -r 'keys[]' "$FILE" 2>/dev/null)
  for KEY in $TOP_KEYS; do
    case "$KEY" in name|description|variables|steps) ;; *) tjc_error "Unknown top-level field '$KEY'."; return 1;; esac
  done

  NAME=$(tjc_workflow_get_name "$FILE")
  if [ -z "$NAME" ] || [ "$NAME" = null ]; then
    tjc_error "'name' is required."; return 1
  fi
  case "$NAME" in *'\n'*|*'\r'*) tjc_error 'Workflow name contains a newline.'; return 1;; esac

  if ! yq -e '.steps | type == "array" and length > 0' "$FILE" >/dev/null 2>&1; then
    tjc_error "'steps' must be a non-empty array."; return 1
  fi
  if ! yq -e '.variables // {} | type == "object"' "$FILE" >/dev/null 2>&1; then
    tjc_error "'variables' must be a mapping."; return 1
  fi

  STEPS_COUNT=$(tjc_workflow_get_steps_count "$FILE")
  INDEX=0
  while [ "$INDEX" -lt "$STEPS_COUNT" ]; do
    PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
    TYPE=$(tjc_workflow_get_step_type "$FILE" "$INDEX")
    if [ -z "$TYPE" ] || [ "$TYPE" = null ]; then
      tjc_error "Step $INDEX is missing 'type'."; return 1
    fi

    case "$TYPE" in
      create_session) ALLOWED='type session_name' ;;
      watch_session) ALLOWED='type session_id' ;;
      list_activities|doctor) ALLOWED='type' ;;
      get_pr) ALLOWED='type pr_number' ;;
      *) tjc_error "Step $INDEX has invalid type '$TYPE'."; return 1 ;;
    esac

    STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
    for KEY in $STEP_KEYS; do
      case " $ALLOWED depends_on condition retry timeout " in
        *" $KEY "*) ;;
        *) tjc_error "Step $INDEX has unknown parameter '$KEY'."; return 1;;
      esac
    done

    if ! echo "$PARAMS" | jq -e '.depends_on // [] | type == "array" and all(.[]; type == "number" or type == "string")' >/dev/null 2>&1; then
      tjc_error "Step $INDEX depends_on must be an array."; return 1
    fi

    CONDITION=$(tjc_workflow_get_step_condition "$FILE" "$INDEX")
    case "$CONDITION" in on_success|always|on_failure|"var:"*) ;; *) tjc_error "Step $INDEX has unsupported condition '$CONDITION'."; return 1;; esac

    RETRY=$(tjc_workflow_get_step_retry_attempts "$FILE" "$INDEX")
    [ "$RETRY" -le 10 ] || { tjc_error "Step $INDEX retry attempts cannot exceed 10."; return 1; }
    TIMEOUT=$(tjc_workflow_get_step_timeout "$FILE" "$INDEX")
    [ "$TIMEOUT" -le 86400 ] || { tjc_error "Step $INDEX timeout cannot exceed 86400 seconds."; return 1; }

    case "$TYPE" in
      create_session)
        SESS=$(echo "$PARAMS" | jq -r '.session_name // ""')
        [ -z "$SESS" ] || echo "$SESS" | grep -Eq '^[A-Za-z0-9_-]{1,64}$' || { tjc_error "Step $INDEX session_name is unsafe."; return 1; }
        ;;
      watch_session)
        SID=$(echo "$PARAMS" | jq -r '.session_id // ""')
        [ -z "$SID" ] || echo "$SID" | grep -Eq '^[A-Za-z0-9_.-]{1,128}$' || { tjc_error "Step $INDEX session_id is unsafe."; return 1; }
        ;;
      get_pr)
        PR=$(echo "$PARAMS" | jq -r '.pr_number // ""')
        echo "$PR" | grep -Eq '^[1-9][0-9]*$' || { tjc_error "Step $INDEX pr_number must be a positive integer."; return 1; }
        ;;
    esac
    INDEX=$((INDEX + 1))
  done

  # Validate the dependency graph against the full steps array. The previous
  # recursive expression evaluated `length` against each dependency value
  # instead of the root steps array, incorrectly rejecting valid workflows.
  if ! yq '.steps' "$FILE" | jq -e '
    . as $steps |
    def deps($i): ($steps[$i].depends_on // []) | map(if type == "number" then . else (try tonumber catch -1) end);
    def visit($i; $path):
      if ($i < 0 or $i >= ($steps | length)) then false
      elif ($path | index($i)) != null then false
      else all(deps($i)[]; visit(. ; ($path + [$i])))
      end;
    all(range(0; ($steps | length)); visit(. ; []))
  ' >/dev/null 2>&1; then
    tjc_error 'Workflow contains an invalid dependency reference or cycle.'
    return 1
  fi

  return 0
}
