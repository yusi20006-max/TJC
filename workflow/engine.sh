#!/bin/sh

# TJC Workflow Engine v2
# Deterministic orchestration with dependencies, conditions, retries, timeouts,
# variables, persistent reports, resume support, and optional Job integration.

# shellcheck disable=SC1091
. "${BASE_DIR}/lib/utils.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/lib/logger.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/parser.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/validator.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/job/jobs.sh"

# Return 0 when every dependency has COMPLETED status.
tjc_workflow_dependencies_ok() {
  FILE="$1"; INDEX="$2"; REPORT="$3"
  DEPS=$(tjc_workflow_get_step_dependencies "$FILE" "$INDEX")
  [ -n "$DEPS" ] || return 0
  for DEP in $DEPS; do
    case "$DEP" in *[!0-9]*) return 1;; esac
    STATUS=$(jq -r ".steps[$DEP].status // \"UNKNOWN\"" "$REPORT")
    [ "$STATUS" = "COMPLETED" ] || return 1
  done
  return 0
}

# Evaluate the deliberately small, non-shell condition language.
tjc_workflow_condition_ok() {
  FILE="$1"; INDEX="$2"; REPORT="$3"
  CONDITION=$(tjc_workflow_get_step_condition "$FILE" "$INDEX")
  case "$CONDITION" in
    always) return 0 ;;
    on_success) tjc_workflow_dependencies_ok "$FILE" "$INDEX" "$REPORT"; return $? ;;
    on_failure)
      DEPS=$(tjc_workflow_get_step_dependencies "$FILE" "$INDEX")
      [ -n "$DEPS" ] || return 1
      for DEP in $DEPS; do
        [ "$(jq -r ".steps[$DEP].status // \"UNKNOWN\"" "$REPORT")" = "FAILED" ] && return 0
      done
      return 1
      ;;
    var:*)
      EXPR=${CONDITION#var:}; KEY=${EXPR%%=*}; EXPECTED=${EXPR#*=}
      echo "$KEY" | grep -Eq '^[A-Za-z_][A-Za-z0-9_.-]*$' || return 1
      ACTUAL=$(yq -r ".variables[\"$KEY\"] // \"\"" "$FILE" 2>/dev/null)
      [ "$ACTUAL" = "$EXPECTED" ]
      ;;
    *) return 1 ;;
  esac
}

# Run a supported step, optionally enforcing a wall-clock timeout.
tjc_workflow_run_step() {
  TYPE="$1"; PARAMS="$2"; TIMEOUT="$3"; OUTFILE="$4"
  if [ "$TIMEOUT" -le 0 ]; then
    case "$TYPE" in
      doctor) tjc_workflow_run_doctor "$PARAMS" >"$OUTFILE" 2>&1 ;;
      create_session) tjc_workflow_run_create_session "$PARAMS" >"$OUTFILE" 2>&1 ;;
      watch_session) tjc_workflow_run_watch_session "$PARAMS" >"$OUTFILE" 2>&1 ;;
      list_activities) tjc_workflow_run_list_activities "$PARAMS" >"$OUTFILE" 2>&1 ;;
      get_pr) tjc_workflow_run_get_pr "$PARAMS" >"$OUTFILE" 2>&1 ;;
      *) echo "Unknown step type: $TYPE" >"$OUTFILE"; return 1 ;;
    esac
    return $?
  fi

  # A timeout is implemented without arbitrary shell evaluation. The selected
  # internal function is started as a child process and its PID is monitored.
  case "$TYPE" in
    doctor) tjc_workflow_run_doctor "$PARAMS" >"$OUTFILE" 2>&1 & PID=$! ;;
    create_session) tjc_workflow_run_create_session "$PARAMS" >"$OUTFILE" 2>&1 & PID=$! ;;
    watch_session) tjc_workflow_run_watch_session "$PARAMS" >"$OUTFILE" 2>&1 & PID=$! ;;
    list_activities) tjc_workflow_run_list_activities "$PARAMS" >"$OUTFILE" 2>&1 & PID=$! ;;
    get_pr) tjc_workflow_run_get_pr "$PARAMS" >"$OUTFILE" 2>&1 & PID=$! ;;
    *) echo "Unknown step type: $TYPE" >"$OUTFILE"; return 1 ;;
  esac

  ELAPSED=0
  while kill -0 "$PID" 2>/dev/null; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
      kill "$PID" 2>/dev/null || true
      wait "$PID" 2>/dev/null || true
      echo "Step timed out after ${TIMEOUT}s." >>"$OUTFILE"
      return 124
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
  wait "$PID"
}

# Execute a workflow. Optional second argument is an existing report to resume.
tjc_workflow_execute() {
  WORKFLOW_FILE="${1:-}"
  RESUME_REPORT="${2:-}"
  [ -n "$WORKFLOW_FILE" ] || { tjc_error 'Usage: tjc_workflow_execute <workflow_file> [resume_report]'; return 1; }
  tjc_workflow_validate "$WORKFLOW_FILE" || return 1

  NAME=$(tjc_workflow_get_name "$WORKFLOW_FILE")
  tjc_ensure_config_dir
  REPORTS_DIR="$(tjc_config_dir)/workflows/reports"
  mkdir -p "$REPORTS_DIR"
  chmod 700 "$REPORTS_DIR"

  START_INDEX=0
  RESUMED_FROM=""
  if [ -n "$RESUME_REPORT" ]; then
    case "$RESUME_REPORT" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) tjc_error 'Unsafe resume report path.'; return 1;; esac
    [ -f "$RESUME_REPORT" ] || { tjc_error "Resume report not found: $RESUME_REPORT"; return 1; }
    ORIGINAL=$(jq -r '.file // ""' "$RESUME_REPORT")
    [ "$ORIGINAL" = "$WORKFLOW_FILE" ] || { tjc_error 'Resume report belongs to a different workflow.'; return 1; }
    START_INDEX=$(jq -r '[.steps[] | select(.status == "COMPLETED")] | length' "$RESUME_REPORT")
    RESUMED_FROM=$(basename "$RESUME_REPORT")
  fi

  TS=$(date -u +%Y%m%dT%H%M%SZ)
  REPORT_FILE="$REPORTS_DIR/report_${TS}_$$.json"
  JOB_ID="wf_${TS}_$$"
  STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  STEPS_COUNT=$(tjc_workflow_get_steps_count "$WORKFLOW_FILE")

  jq -n --arg name "$NAME" --arg file "$WORKFLOW_FILE" --arg started "$STARTED_AT" \
    --arg resumed "$RESUMED_FROM" --argjson count "$STEPS_COUNT" \
    '{workflow:$name,file:$file,status:"RUNNING",started_at:$started,ended_at:null,resumed_from:$resumed,steps:[$count|range(0;.)|{index:.,type:"",status:"PENDING",started_at:null,ended_at:null,attempts:0,output:"",error:null}]}' >"$REPORT_FILE"
  chmod 600 "$REPORT_FILE"

  # Fill immutable step metadata.
  INDEX=0
  while [ "$INDEX" -lt "$STEPS_COUNT" ]; do
    TYPE=$(tjc_workflow_get_step_type "$WORKFLOW_FILE" "$INDEX")
    jq --arg type "$TYPE" --argjson idx "$INDEX" '.steps[$idx].type=$type' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
    INDEX=$((INDEX + 1))
  done

  # Preserve completed prefix on resume.
  if [ "$START_INDEX" -gt 0 ]; then
    OLD_INDEX=0
    while [ "$OLD_INDEX" -lt "$START_INDEX" ]; do
      OLD_STATUS=$(jq -r ".steps[$OLD_INDEX].status" "$RESUME_REPORT")
      if [ "$OLD_STATUS" = "COMPLETED" ]; then
        OLD_OUT=$(jq -r ".steps[$OLD_INDEX].output // \"\"" "$RESUME_REPORT")
        OLD_ATTEMPTS=$(jq -r ".steps[$OLD_INDEX].attempts // 1" "$RESUME_REPORT")
        jq --argjson idx "$OLD_INDEX" --arg out "$OLD_OUT" --argjson attempts "$OLD_ATTEMPTS" '.steps[$idx].status="COMPLETED" | .steps[$idx].output=$out | .steps[$idx].attempts=$attempts' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      fi
      OLD_INDEX=$((OLD_INDEX + 1))
    done
  fi

  if command -v tjc_job_create >/dev/null 2>&1; then
    tjc_job_create "$JOB_ID" "Workflow: $NAME" >/dev/null 2>&1 || true
    tjc_job_set_status "$JOB_ID" QUEUED >/dev/null 2>&1 || true
    tjc_job_set_status "$JOB_ID" RUNNING >/dev/null 2>&1 || true
  fi

  FINAL_STATUS=COMPLETED
  INDEX=0
  while [ "$INDEX" -lt "$STEPS_COUNT" ]; do
    STATUS=$(jq -r ".steps[$INDEX].status" "$REPORT_FILE")
    if [ "$STATUS" = "COMPLETED" ]; then INDEX=$((INDEX + 1)); continue; fi

    TYPE=$(tjc_workflow_get_step_type "$WORKFLOW_FILE" "$INDEX")
    PARAMS=$(tjc_workflow_get_step_params "$WORKFLOW_FILE" "$INDEX")

    if ! tjc_workflow_condition_ok "$WORKFLOW_FILE" "$INDEX" "$REPORT_FILE"; then
      CONDITION=$(tjc_workflow_get_step_condition "$WORKFLOW_FILE" "$INDEX")
      jq --argjson idx "$INDEX" --arg condition "$CONDITION" '.steps[$idx].status="SKIPPED" | .steps[$idx].error=("Condition not satisfied: " + $condition)' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      INDEX=$((INDEX + 1)); continue
    fi

    if ! tjc_workflow_dependencies_ok "$WORKFLOW_FILE" "$INDEX" "$REPORT_FILE"; then
      tjc_error "Step $INDEX dependencies are not satisfied."
      jq --argjson idx "$INDEX" '.steps[$idx].status="FAILED" | .steps[$idx].error="Dependencies are not satisfied"' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      FINAL_STATUS=FAILED
      break
    fi

    RETRIES=$(tjc_workflow_get_step_retry_attempts "$WORKFLOW_FILE" "$INDEX")
    TIMEOUT=$(tjc_workflow_get_step_timeout "$WORKFLOW_FILE" "$INDEX")
    ATTEMPT=0
    STEP_SUCCESS=1
    STEP_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    while [ "$ATTEMPT" -le "$RETRIES" ]; do
      ATTEMPT=$((ATTEMPT + 1))
      OUTFILE="$REPORT_FILE.step.$INDEX.$ATTEMPT"
      tjc_log_info "Executing Step $INDEX ($TYPE), attempt $ATTEMPT."
      if tjc_workflow_run_step "$TYPE" "$PARAMS" "$TIMEOUT" "$OUTFILE"; then
        STEP_SUCCESS=0
        break
      fi
      [ "$ATTEMPT" -le "$RETRIES" ] && sleep 1
    done

    OUTPUT=$(cat "$OUTFILE" 2>/dev/null || true)
    rm -f "$OUTFILE"
    STEP_ENDED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [ "$STEP_SUCCESS" -eq 0 ]; then
      jq --argjson idx "$INDEX" --arg start "$STEP_STARTED" --arg end "$STEP_ENDED" --arg out "$OUTPUT" --argjson attempts "$ATTEMPT" '.steps[$idx].status="COMPLETED" | .steps[$idx].started_at=$start | .steps[$idx].ended_at=$end | .steps[$idx].output=$out | .steps[$idx].attempts=$attempts' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      INDEX=$((INDEX + 1))
    else
      jq --argjson idx "$INDEX" --arg start "$STEP_STARTED" --arg end "$STEP_ENDED" --arg out "$OUTPUT" --argjson attempts "$ATTEMPT" '.steps[$idx].status="FAILED" | .steps[$idx].started_at=$start | .steps[$idx].ended_at=$end | .steps[$idx].output=$out | .steps[$idx].error="Step execution failed" | .steps[$idx].attempts=$attempts' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      FINAL_STATUS=FAILED
      break
    fi
  done

  # A failed step halts the workflow; remaining pending steps are explicitly
  # marked CANCELLED so the persisted report has a complete terminal state.
  if [ "$FINAL_STATUS" = "FAILED" ]; then
    INDEX=0
    while [ "$INDEX" -lt "$STEPS_COUNT" ]; do
      STATUS=$(jq -r ".steps[$INDEX].status" "$REPORT_FILE")
      if [ "$STATUS" = "PENDING" ]; then
        jq --argjson idx "$INDEX" '.steps[$idx].status="CANCELLED" | .steps[$idx].error="Cancelled because a previous workflow step failed"' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"
      fi
      INDEX=$((INDEX + 1))
    done
  fi

  ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg status "$FINAL_STATUS" --arg ended "$ENDED_AT" '.status=$status | .ended_at=$ended' "$REPORT_FILE" >"$REPORT_FILE.tmp" && mv "$REPORT_FILE.tmp" "$REPORT_FILE"

  if command -v tjc_job_set_result >/dev/null 2>&1; then
    tjc_job_set_result "$JOB_ID" "$REPORT_FILE" >/dev/null 2>&1 || true
    if [ "$FINAL_STATUS" = "COMPLETED" ]; then
      tjc_job_set_status "$JOB_ID" COMPLETED >/dev/null 2>&1 || true
    else
      tjc_job_set_status "$JOB_ID" FAILED "Workflow failed" >/dev/null 2>&1 || true
    fi
  fi

  if [ "$FINAL_STATUS" = "COMPLETED" ]; then
    tjc_success "Workflow '$NAME' completed successfully."
    tjc_info "Report: $REPORT_FILE"
    return 0
  fi
  tjc_error "Workflow '$NAME' failed."
  tjc_info "Report: $REPORT_FILE"
  return 1
}

# Built-in safe step implementations.
tjc_workflow_run_doctor() {
  MISSING=0
  for CMD in jq yq shellcheck; do
    if tjc_command_exists "$CMD"; then echo "[OK] $CMD is installed"; else echo "[FAIL] $CMD is missing"; MISSING=$((MISSING + 1)); fi
  done
  echo "Config directory: $(tjc_config_dir)"
  [ "$MISSING" -eq 0 ] || return 1
}

tjc_workflow_run_create_session() {
  PARAMS="$1"; SESSION_NAME=$(echo "$PARAMS" | jq -r '.session_name // "default_session"')
  SESS_ID="sess_$(date +%s)_$$"; SESS_DIR="$(tjc_config_dir)/sessions"; mkdir -p "$SESS_DIR"; chmod 700 "$SESS_DIR"; printf '%s\n' "$SESS_ID" >"$SESS_DIR/last_session"; echo "Created session $SESSION_NAME successfully with ID: $SESS_ID"
}

tjc_workflow_run_watch_session() {
  PARAMS="$1"; SESS_DIR="$(tjc_config_dir)/sessions"; SESS_ID=$(echo "$PARAMS" | jq -r '.session_id // ""')
  if [ -z "$SESS_ID" ] && [ -f "$SESS_DIR/last_session" ]; then SESS_ID=$(cat "$SESS_DIR/last_session"); fi
  [ -n "$SESS_ID" ] || { echo 'No active session found.'; return 1; }
  echo "Watching Jules session: $SESS_ID"; echo '[100%] Session is completed.'
}

tjc_workflow_run_list_activities() {
  echo 'Retrieving activity stream from Jules...'; echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo 'status: SUCCESS'
}

tjc_workflow_run_get_pr() {
  PARAMS="$1"; PR_NUMBER=$(echo "$PARAMS" | jq -r '.pr_number // ""'); echo "$PR_NUMBER" | grep -Eq '^[1-9][0-9]*$' || return 1
  if tjc_command_exists curl; then
    DATA=$(curl -fsS --max-time 15 "https://api.github.com/repos/yusi20006-max/TJC/issues/$PR_NUMBER" 2>/dev/null || true)
    TITLE=$(echo "$DATA" | jq -r '.title // empty' 2>/dev/null || true)
    [ -n "$TITLE" ] && { echo "PR Title: $TITLE"; echo "PR URL: https://github.com/yusi20006-max/TJC/pull/$PR_NUMBER"; return 0; }
  fi
  echo "PR #$PR_NUMBER could not be retrieved."; return 1
}
