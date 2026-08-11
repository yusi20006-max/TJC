#!/bin/sh

set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export BASE_DIR
export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TJC_CONFIG_DIR"
}
trap cleanup EXIT HUP INT TERM

. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/job/jobs.sh"

PASS=0
FAIL=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

# A stale lock owned by a definitely invalid PID must be recoverable.
tjc_job_create recovery_job 'Recovery test'
LOCK_DIR="$(tjc_job_dir)/.locks/recovery_job.lock"
mkdir -p "$LOCK_DIR"
printf '%s\n' '99999999' > "$LOCK_DIR/pid"

if tjc_job_set_status recovery_job QUEUED >/dev/null 2>&1; then
  pass 'stale job lock is recovered'
else
  fail 'stale job lock is recovered'
fi

if [ ! -e "$LOCK_DIR" ]; then
  pass 'recovered lock is removed after successful operation'
else
  fail 'recovered lock is removed after successful operation'
fi

# Corrupted JSON must not be accepted as a valid Job record.
tjc_job_create corrupt_job 'Corruption test'
printf '%s\n' '{not-json' > "$(tjc_job_path corrupt_job)"

if tjc_job_exists corrupt_job >/dev/null 2>&1; then
  fail 'corrupted Job record is rejected'
else
  pass 'corrupted Job record is rejected'
fi

# Atomic writes must leave the persisted record readable after updates.
tjc_job_create atomic_job 'Atomicity test'
tjc_job_set_status atomic_job QUEUED
tjc_job_set_status atomic_job RUNNING
tjc_job_set_result atomic_job 'result-ok'

if jq -e '.status == "RUNNING" and .result == "result-ok"' "$(tjc_job_path atomic_job)" >/dev/null 2>&1; then
  pass 'atomic Job updates remain valid JSON'
else
  fail 'atomic Job updates remain valid JSON'
fi

printf '%s\n' "Passed: $PASS"
printf '%s\n' "Failed: $FAIL"

[ "$FAIL" -eq 0 ]
