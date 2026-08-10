#!/bin/sh
# TJC Job System Foundation
# Persistent, POSIX-shell-compatible lifecycle management for long-running operations.
# These status constants are part of the sourced module's public API.
# shellcheck disable=SC2034

TJC_JOB_PENDING="PENDING"
TJC_JOB_QUEUED="QUEUED"
TJC_JOB_RUNNING="RUNNING"
TJC_JOB_COMPLETED="COMPLETED"
TJC_JOB_FAILED="FAILED"
TJC_JOB_CANCELLED="CANCELLED"
TJC_JOB_RETRYING="RETRYING"

TJC_JOB_LOCK_TIMEOUT="${TJC_JOB_LOCK_TIMEOUT:-5}"

tjc_job_dir() {
  if command -v tjc_config_dir >/dev/null 2>&1; then
    printf '%s/jobs\n' "$(tjc_config_dir)"
  else
    printf '%s/.config/tjc/jobs\n' "${HOME}"
  fi
}

tjc_job_ensure_dir() {
  DIR=$(tjc_job_dir)
  if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR" || return 1
  fi
  chmod 700 "$DIR" 2>/dev/null || true
  if [ ! -d "$DIR/.locks" ]; then
    mkdir -p "$DIR/.locks" || return 1
    chmod 700 "$DIR/.locks" 2>/dev/null || true
  fi
}

tjc_job_valid_id() {
  printf '%s\n' "${1:-}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'
}

tjc_job_path() {
  tjc_job_valid_id "$1" || return 1
  printf '%s/%s.json\n' "$(tjc_job_dir)" "$1"
}

tjc_job_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

tjc_job_lock() {
  ID="$1"
  tjc_job_ensure_dir || return 1
  LOCK="$(tjc_job_dir)/.locks/$ID.lock"
  ATTEMPT=0

  while ! mkdir "$LOCK" 2>/dev/null; do
    # Recover a lock left by a process that is no longer alive. The lock
    # directory is never removed merely because it is old: ownership is
    # checked through the recorded PID first.
    if [ -f "$LOCK/pid" ]; then
      OWNER_PID=$(cat "$LOCK/pid" 2>/dev/null || true)
      case "$OWNER_PID" in
        ''|*[!0-9]*) ;;
        *)
          if ! kill -0 "$OWNER_PID" 2>/dev/null; then
            rm -f "$LOCK/pid"
            rmdir "$LOCK" 2>/dev/null || true
            continue
          fi
          ;;
      esac
    fi

    ATTEMPT=$((ATTEMPT + 1))
    if [ "$ATTEMPT" -ge "$TJC_JOB_LOCK_TIMEOUT" ]; then
      echo "Timed out waiting for Job lock '$ID'." >&2
      return 1
    fi
    sleep 1
  done

  # mkdir is atomic on the local filesystem; write ownership metadata only
  # after the lock directory has been acquired.
  printf '%s\n' "$$" > "$LOCK/pid" || {
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
    return 1
  }
  printf '%s\n' "$LOCK"
}

tjc_job_unlock() {
  LOCK="$1"
  OWNER_PID=$(cat "$LOCK/pid" 2>/dev/null || true)
  if [ -z "$OWNER_PID" ] || [ "$OWNER_PID" = "$$" ]; then
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || true
  fi
}

tjc_job_write_atomic() {
  TARGET="$1"
  CONTENT="$2"
  DIR=$(dirname "$TARGET")
  TMP="$DIR/.job.$$.tmp"
  (umask 077 && printf '%s\n' "$CONTENT" > "$TMP") || return 1
  chmod 600 "$TMP" 2>/dev/null || true
  mv -f "$TMP" "$TARGET"
}

tjc_job_create() {
  ID="${1:-}"
  DESCRIPTION="${2:-}"
  if ! tjc_job_valid_id "$ID"; then
    echo "Invalid Job ID." >&2
    return 1
  fi
  tjc_job_ensure_dir || return 1
  PATHNAME=$(tjc_job_path "$ID") || return 1
  LOCK=$(tjc_job_lock "$ID") || return 1
  if [ -e "$PATHNAME" ]; then
    tjc_job_unlock "$LOCK"
    echo "Job '$ID' already exists." >&2
    return 1
  fi
  NOW=$(tjc_job_now)
  JSON=$(jq -n \
    --arg id "$ID" \
    --arg description "$DESCRIPTION" \
    --arg created "$NOW" \
    '{id:$id,description:$description,status:"PENDING",created_at:$created,updated_at:$created,started_at:null,completed_at:null,attempts:0,result:null,error:null}') || {
      tjc_job_unlock "$LOCK"
      return 1
    }
  RET=0
  tjc_job_write_atomic "$PATHNAME" "$JSON" || RET=1
  tjc_job_unlock "$LOCK"
  return "$RET"
}

tjc_job_exists() {
  PATHNAME=$(tjc_job_path "$1") 2>/dev/null || return 1
  [ -f "$PATHNAME" ] && jq -e 'type == "object" and (.id|type == "string") and (.status|type == "string")' "$PATHNAME" >/dev/null 2>&1
}

tjc_job_get() {
  PATHNAME=$(tjc_job_path "$1") || return 1
  [ -f "$PATHNAME" ] || return 1
  jq -e . "$PATHNAME"
}

tjc_job_status() {
  PATHNAME=$(tjc_job_path "$1") || return 1
  [ -f "$PATHNAME" ] || return 1
  jq -er '.status' "$PATHNAME"
}

tjc_job_set_status() {
  ID="${1:-}"
  NEW_STATUS="${2:-}"
  ERROR_MSG="${3:-}"
  case "$NEW_STATUS" in
    PENDING|QUEUED|RUNNING|COMPLETED|FAILED|CANCELLED|RETRYING) ;;
    *) echo "Invalid Job status." >&2; return 1 ;;
  esac
  PATHNAME=$(tjc_job_path "$ID") || return 1
  LOCK=$(tjc_job_lock "$ID") || return 1
  if ! tjc_job_exists "$ID"; then
    tjc_job_unlock "$LOCK"
    echo "Job '$ID' not found or is corrupt." >&2
    return 1
  fi
  CURRENT=$(jq -r '.status' "$PATHNAME") || {
    tjc_job_unlock "$LOCK"
    return 1
  }
  case "$CURRENT:$NEW_STATUS" in
    PENDING:QUEUED|PENDING:CANCELLED|QUEUED:RUNNING|QUEUED:CANCELLED|RUNNING:COMPLETED|RUNNING:FAILED|RUNNING:CANCELLED|FAILED:RETRYING|RETRYING:QUEUED|RETRYING:RUNNING) ;;
    "$NEW_STATUS:$NEW_STATUS") tjc_job_unlock "$LOCK"; return 0 ;;
    *)
      tjc_job_unlock "$LOCK"
      echo "Invalid state transition: $CURRENT -> $NEW_STATUS" >&2
      return 1
      ;;
  esac
  NOW=$(tjc_job_now)
  if [ "$NEW_STATUS" = "RUNNING" ]; then
    JSON=$(jq --arg status "$NEW_STATUS" --arg now "$NOW" '.status=$status | .updated_at=$now | .started_at=$now | .completed_at=null | .attempts=(.attempts+1)' "$PATHNAME")
  elif [ "$NEW_STATUS" = "COMPLETED" ] || [ "$NEW_STATUS" = "CANCELLED" ]; then
    JSON=$(jq --arg status "$NEW_STATUS" --arg now "$NOW" --arg err "$ERROR_MSG" '.status=$status | .updated_at=$now | .completed_at=$now | .error=(if $err == "" then .error else $err end)' "$PATHNAME")
  elif [ "$NEW_STATUS" = "FAILED" ]; then
    JSON=$(jq --arg status "$NEW_STATUS" --arg now "$NOW" --arg err "$ERROR_MSG" '.status=$status | .updated_at=$now | .completed_at=$now | .error=$err' "$PATHNAME")
  else
    JSON=$(jq --arg status "$NEW_STATUS" --arg now "$NOW" --arg err "$ERROR_MSG" '.status=$status | .updated_at=$now | .error=(if $err == "" then .error else $err end)' "$PATHNAME")
  fi
  RET=$?
  if [ "$RET" -eq 0 ]; then
    tjc_job_write_atomic "$PATHNAME" "$JSON"
    RET=$?
  fi
  tjc_job_unlock "$LOCK"
  return "$RET"
}

tjc_job_set_result() {
  ID="${1:-}"
  RESULT="${2:-}"
  PATHNAME=$(tjc_job_path "$ID") || return 1
  LOCK=$(tjc_job_lock "$ID") || return 1
  if ! tjc_job_exists "$ID"; then
    tjc_job_unlock "$LOCK"
    return 1
  fi
  NOW=$(tjc_job_now)
  JSON=$(jq --arg result "$RESULT" --arg now "$NOW" '.result=$result | .updated_at=$now' "$PATHNAME") || {
    tjc_job_unlock "$LOCK"
    return 1
  }
  tjc_job_write_atomic "$PATHNAME" "$JSON"
  RET=$?
  tjc_job_unlock "$LOCK"
  return "$RET"
}

tjc_job_cancel() {
  ID="${1:-}"
  STATUS=$(tjc_job_status "$ID") || return 1
  case "$STATUS" in
    PENDING|QUEUED|RUNNING|RETRYING) tjc_job_set_status "$ID" CANCELLED "Cancelled by user" ;;
    COMPLETED|FAILED|CANCELLED) echo "Job '$ID' is already terminal ($STATUS)." >&2; return 1 ;;
    *) return 1 ;;
  esac
}

tjc_job_retry() {
  ID="${1:-}"
  STATUS=$(tjc_job_status "$ID") || return 1
  if [ "$STATUS" != "FAILED" ]; then
    echo "Only FAILED jobs can be retried." >&2
    return 1
  fi
  tjc_job_set_status "$ID" RETRYING && tjc_job_set_status "$ID" QUEUED
}

tjc_job_list() {
  DIR=$(tjc_job_dir)
  [ -d "$DIR" ] || return 0
  for FILE in "$DIR"/*.json; do
    [ -f "$FILE" ] || continue
    jq -r '[.id,.status,.attempts,.created_at,.updated_at] | @tsv' "$FILE" 2>/dev/null || true
  done
}
