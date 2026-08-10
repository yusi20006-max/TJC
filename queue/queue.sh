#!/bin/sh

# TJC v2 Queue
# Persistent, priority-aware, bounded worker queue for workflow Jobs.

TJC_QUEUE_DEFAULT_WORKERS="${TJC_MAX_WORKERS:-2}"

tjc_queue_dir() {
  if command -v tjc_config_dir >/dev/null 2>&1; then printf '%s/queue\n' "$(tjc_config_dir)"; else printf '%s/.config/tjc/queue\n' "$HOME"; fi
}

tjc_queue_init() {
  DIR=$(tjc_queue_dir)
  mkdir -p "$DIR/items" "$DIR/locks" "$DIR/workers" || return 1
  chmod 700 "$DIR" "$DIR/items" "$DIR/locks" "$DIR/workers" 2>/dev/null || true
}

tjc_queue_valid_id() { echo "${1:-}" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$'; }

tjc_queue_item() {
  tjc_queue_valid_id "$1" || return 1
  printf '%s/items/%s.json\n' "$(tjc_queue_dir)" "$1"
}

tjc_queue_add_workflow() {
  WORKFLOW="${1:-}"; PRIORITY="${2:-50}"; ID="${3:-}"
  [ -f "$WORKFLOW" ] || { echo "Workflow not found: $WORKFLOW" >&2; return 1; }
  echo "$PRIORITY" | grep -Eq '^[0-9]+$' || { echo 'Priority must be a non-negative integer.' >&2; return 1; }
  [ "$PRIORITY" -le 1000 ] || { echo 'Priority must not exceed 1000.' >&2; return 1; }
  tjc_queue_init || return 1
  if [ -z "$ID" ]; then ID="q_$(date -u +%Y%m%dT%H%M%SZ)_$$"; fi
  tjc_queue_valid_id "$ID" || { echo 'Invalid queue Job ID.' >&2; return 1; }
  ITEM=$(tjc_queue_item "$ID") || return 1
  LOCK="$(tjc_queue_dir)/locks/$ID.lock"
  mkdir "$LOCK" 2>/dev/null || { echo "Queue item '$ID' already exists." >&2; return 1; }
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  JOB_ID="queue_$ID"
  tjc_job_create "$JOB_ID" "Queued workflow: $WORKFLOW" || { rmdir "$LOCK"; return 1; }
  jq -n --arg id "$ID" --arg job "$JOB_ID" --arg workflow "$WORKFLOW" --arg created "$NOW" --argjson priority "$PRIORITY" '{id:$id,job_id:$job,kind:"workflow",workflow:$workflow,priority:$priority,status:"QUEUED",created_at:$created,started_at:null,completed_at:null}' >"$ITEM.tmp"
  chmod 600 "$ITEM.tmp"; mv "$ITEM.tmp" "$ITEM"
  rmdir "$LOCK"
  printf '%s\n' "$ID"
}

tjc_queue_list() {
  DIR="$(tjc_queue_dir)/items"; [ -d "$DIR" ] || return 0
  for ITEM in "$DIR"/*.json; do
    [ -f "$ITEM" ] || continue
    jq -r '[.id,.job_id,.status,.priority,.created_at,.workflow] | @tsv' "$ITEM" 2>/dev/null || true
  done | sort -t '	' -k3,3 -k4,4nr -k5,5
}

tjc_queue_remove() {
  ID="${1:-}"; ITEM=$(tjc_queue_item "$ID") || return 1
  [ -f "$ITEM" ] || { echo "Queue item '$ID' not found." >&2; return 1; }
  STATUS=$(jq -r '.status' "$ITEM")
  [ "$STATUS" = QUEUED ] || { echo 'Only QUEUED items can be removed.' >&2; return 1; }
  rm -f "$ITEM"
  JOB_ID=$(jq -r '.job_id' "$ITEM" 2>/dev/null || true)
  [ -n "$JOB_ID" ] && tjc_job_cancel "$JOB_ID" >/dev/null 2>&1 || true
}

tjc_queue_claim() {
  ITEM="$1"; ID=$(jq -r '.id' "$ITEM")
  LOCK="$(tjc_queue_dir)/locks/$ID.lock"
  mkdir "$LOCK" 2>/dev/null || return 1
  STATUS=$(jq -r '.status' "$ITEM")
  if [ "$STATUS" != QUEUED ]; then rmdir "$LOCK"; return 1; fi
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg now "$NOW" '.status="RUNNING" | .started_at=$now' "$ITEM" >"$ITEM.tmp" && mv "$ITEM.tmp" "$ITEM"
  printf '%s\n' "$LOCK"
}

tjc_queue_complete() {
  ITEM="$1"; STATUS="$2"; NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq --arg status "$STATUS" --arg now "$NOW" '.status=$status | .completed_at=$now' "$ITEM" >"$ITEM.tmp" && mv "$ITEM.tmp" "$ITEM"
}

tjc_queue_worker_once() {
  tjc_queue_init || return 1
  DIR="$(tjc_queue_dir)/items"
  CANDIDATE=$(for ITEM in "$DIR"/*.json; do [ -f "$ITEM" ] || continue; jq -r 'select(.status == "QUEUED") | [.priority,.created_at,.id,.workflow] | @tsv' "$ITEM" 2>/dev/null; done | sort -t '	' -k1,1nr -k2,2 | head -n 1)
  [ -n "$CANDIDATE" ] || return 2
  ID=$(printf '%s\n' "$CANDIDATE" | cut -f3); WORKFLOW=$(printf '%s\n' "$CANDIDATE" | cut -f4)
  ITEM=$(tjc_queue_item "$ID") || return 1
  LOCK=$(tjc_queue_claim "$ITEM") || return 3
  JOB_ID=$(jq -r '.job_id' "$ITEM")
  tjc_job_set_status "$JOB_ID" QUEUED >/dev/null 2>&1 || true
  tjc_job_set_status "$JOB_ID" RUNNING >/dev/null 2>&1 || true
  if tjc_workflow_execute "$WORKFLOW"; then
    tjc_queue_complete "$ITEM" COMPLETED
    tjc_job_set_status "$JOB_ID" COMPLETED >/dev/null 2>&1 || true
    rmdir "$LOCK"
    return 0
  fi
  tjc_queue_complete "$ITEM" FAILED
  tjc_job_set_status "$JOB_ID" FAILED 'Queued workflow failed' >/dev/null 2>&1 || true
  rmdir "$LOCK"
  return 1
}

tjc_queue_run() {
  MAX="${1:-$TJC_QUEUE_DEFAULT_WORKERS}"
  echo "$MAX" | grep -Eq '^[1-9][0-9]*$' || { echo 'Worker count must be a positive integer.' >&2; return 1; }
  [ "$MAX" -le 16 ] || { echo 'Worker count cannot exceed 16.' >&2; return 1; }
  PIDS=""; STARTED=0
  cleanup() { for PID in $PIDS; do kill "$PID" 2>/dev/null || true; done; }
  trap cleanup INT TERM HUP
  while [ "$STARTED" -lt "$MAX" ]; do
    tjc_queue_worker_once & PIDS="$PIDS $!"; STARTED=$((STARTED + 1))
  done
  CODE=0
  for PID in $PIDS; do wait "$PID" || CODE=1; done
  trap - INT TERM HUP
  return "$CODE"
}
