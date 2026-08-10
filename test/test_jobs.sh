#!/bin/sh

set -eu

export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)
BASE_DIR=$(pwd)
export BASE_DIR

. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/lib/output.sh"
. "${BASE_DIR}/job/jobs.sh"

PASSED_TESTS=0
FAILED_TESTS=0

assert_equals() {
  EXPECTED="$1"
  ACTUAL="$2"
  DESC="$3"
  if [ "$EXPECTED" = "$ACTUAL" ]; then
    printf '[PASS] %s\n' "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '[FAIL] %s (expected=%s actual=%s)\n' "$DESC" "$EXPECTED" "$ACTUAL"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_success() {
  CODE="$1"
  DESC="$2"
  if [ "$CODE" -eq 0 ]; then
    printf '[PASS] %s\n' "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '[FAIL] %s (exit=%s)\n' "$DESC" "$CODE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_failure() {
  CODE="$1"
  DESC="$2"
  if [ "$CODE" -ne 0 ]; then
    printf '[PASS] %s\n' "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '[FAIL] %s (unexpected success)\n' "$DESC"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

printf '%s\n' '========================================='
printf '%s\n' 'Running TJC Job System Tests'
printf '%s\n' '========================================='

tjc_job_create job_alpha 'Test Job'
assert_equals PENDING "$(tjc_job_status job_alpha)" 'Job starts in PENDING state'
assert_success "$([ -f "$TJC_CONFIG_DIR/jobs/job_alpha.json" ] && echo 0 || echo 1)" 'Persistent Job record created'
assert_equals job_alpha "$(jq -r '.id' "$TJC_CONFIG_DIR/jobs/job_alpha.json")" 'Job ID persisted'
assert_equals 'Test Job' "$(jq -r '.description' "$TJC_CONFIG_DIR/jobs/job_alpha.json")" 'Description persisted'

set +e
tjc_job_create '../unsafe' 'invalid' >/dev/null 2>&1
S1=$?
tjc_job_create 'bad/id' 'invalid' >/dev/null 2>&1
S2=$?
tjc_job_set_status job_alpha COMPLETED >/dev/null 2>&1
S3=$?
set -e
assert_failure "$S1" 'Directory traversal Job ID rejected'
assert_failure "$S2" 'Path separator Job ID rejected'
assert_failure "$S3" 'Invalid lifecycle transition rejected'

tjc_job_set_status job_alpha QUEUED
assert_equals QUEUED "$(tjc_job_status job_alpha)" 'PENDING -> QUEUED transition works'
tjc_job_set_status job_alpha RUNNING
assert_equals RUNNING "$(tjc_job_status job_alpha)" 'QUEUED -> RUNNING transition works'
assert_equals 1 "$(jq -r '.attempts' "$TJC_CONFIG_DIR/jobs/job_alpha.json")" 'Running Job increments attempts'
tjc_job_set_status job_alpha COMPLETED
assert_equals COMPLETED "$(tjc_job_status job_alpha)" 'RUNNING -> COMPLETED transition works'

set +e
tjc_job_cancel job_alpha >/dev/null 2>&1
S4=$?
set -e
assert_failure "$S4" 'Terminal Job cannot be cancelled'

tjc_job_create job_beta 'Retry Job'
tjc_job_set_status job_beta QUEUED
tjc_job_set_status job_beta RUNNING
set +e
tjc_job_set_status job_beta FAILED 'simulated failure' >/dev/null 2>&1
S5=$?
set -e
assert_success "$S5" 'RUNNING -> FAILED transition works'
assert_equals 'simulated failure' "$(jq -r '.error' "$TJC_CONFIG_DIR/jobs/job_beta.json")" 'Failure reason persisted'
tjc_job_retry job_beta
assert_equals QUEUED "$(tjc_job_status job_beta)" 'FAILED Job can be retried and re-queued'

tjc_job_create job_gamma 'Cancel Job'
tjc_job_cancel job_gamma
assert_equals CANCELLED "$(tjc_job_status job_gamma)" 'PENDING Job can be cancelled'

printf '%s\n' '-----------------------------------------'
printf 'Passed: %s\n' "$PASSED_TESTS"
printf 'Failed: %s\n' "$FAILED_TESTS"
printf '%s\n' '-----------------------------------------'

rm -rf "$TJC_CONFIG_DIR"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
