#!/bin/sh

# Test suite for TJC Scheduler System

set -eu

# Setup a clean, isolated configuration directory for testing
export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)

# Setup BASE_DIR pointing to project root
BASE_DIR=$(pwd)
export BASE_DIR

# Define helper functions for colors
. "${BASE_DIR}/lib/colors.sh"
. "${BASE_DIR}/lib/utils.sh"
. "${BASE_DIR}/lib/output.sh"
. "${BASE_DIR}/lib/config.sh"

# Source scheduler and workflow handlers
# shellcheck disable=SC1091
. "${BASE_DIR}/scheduler/scheduler.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/commands/schedule.sh"

# Global test stats
PASSED_TESTS=0
FAILED_TESTS=0

assert_equals() {
  EXPECTED="$1"
  ACTUAL="$2"
  DESC="$3"
  if [ "$EXPECTED" = "$ACTUAL" ]; then
    printf '%s[PASS]%s %s\n' "$TJC_COLOR_GREEN" "$TJC_COLOR_RESET" "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '%s[FAIL]%s %s (Expected: "%s", Got: "%s")\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET" "$DESC" "$EXPECTED" "$ACTUAL"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_success() {
  CODE="$1"
  DESC="$2"
  if [ "$CODE" -eq 0 ]; then
    printf '%s[PASS]%s %s\n' "$TJC_COLOR_GREEN" "$TJC_COLOR_RESET" "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '%s[FAIL]%s %s (Expected exit code 0, Got: %d)\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET" "$DESC" "$CODE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

assert_failure() {
  CODE="$1"
  DESC="$2"
  if [ "$CODE" -ne 0 ]; then
    printf '%s[PASS]%s %s\n' "$TJC_COLOR_GREEN" "$TJC_COLOR_RESET" "$DESC"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    printf '%s[FAIL]%s %s (Expected non-zero exit code, Got: %d)\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET" "$DESC" "$CODE"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

# --- TEST SCENARIOS ---

echo "========================================="
echo "Running TJC Scheduler Tests..."
echo "========================================="

# Setup valid workflow file to use for scheduling
VALID_WF="${TJC_CONFIG_DIR}/test_wf.yml"
cat << 'EOF' > "$VALID_WF"
name: "Scheduled Workflow"
steps:
  - type: doctor
EOF

# Test Scenario 1: Add a valid schedule
echo "--- Scenario 1: Add Schedule ---"
tjc_schedule add "job_sync" "$VALID_WF" "every_minute"
STATUS=$?
assert_success "$STATUS" "Successfully added valid schedule"

# Verify job file exists and contains correct properties
JOB_FILE="${TJC_CONFIG_DIR}/schedules/job_sync.json"
assert_success "$([ -f "$JOB_FILE" ] && echo 0 || echo 1)" "Job config file created"
assert_equals "job_sync" "$(jq -r '.id' "$JOB_FILE")" "Job ID in JSON is correct"
assert_equals "every_minute" "$(jq -r '.schedule_expression' "$JOB_FILE")" "Job expression in JSON is correct"

# Test Scenario 2: Listing schedules
echo "--- Scenario 2: List Schedules ---"
tjc_schedule list
STATUS=$?
assert_success "$STATUS" "Listed configured active schedules successfully"

# Test Scenario 3: Rejecting invalid schedules
echo "--- Scenario 3: Rejecting invalid/unsafe inputs ---"
set +e
# Unsafe ID
tjc_schedule add "../unsafe_id" "$VALID_WF" "hourly"
S1=$?
# Unsafe characters in path
tjc_schedule add "valid_id" "; rm -rf" "hourly"
S2=$?
# Invalid schedule expression
tjc_schedule add "valid_id2" "$VALID_WF" "invalid_interval"
S3=$?
set -e

assert_failure "$S1" "Directory traversal or unsafe characters in schedule ID rejected"
assert_failure "$S2" "Shell injection characters in workflow path rejected"
assert_failure "$S3" "Invalid interval schedule expression rejected"

# Test Scenario 4: Manual execution of a job
echo "--- Scenario 4: Manual job execution ---"
tjc_schedule run "job_sync"
STATUS=$?
assert_success "$STATUS" "Manually triggered job completed successfully"

# Verify last run status and history recording
assert_equals "COMPLETED" "$(jq -r '.last_status' "$JOB_FILE")" "Job last status updated to COMPLETED"

HIST_FILE="${TJC_CONFIG_DIR}/schedules/history/history_job_sync.json"
assert_success "$([ -f "$HIST_FILE" ] && echo 0 || echo 1)" "History log file created"
assert_equals "COMPLETED" "$(jq -r '.[0].status' "$HIST_FILE")" "First execution status recorded correctly"

# Test Scenario 5: Viewing history via CLI
echo "--- Scenario 5: View execution history via CLI ---"
tjc_schedule history "job_sync"
STATUS=$?
assert_success "$STATUS" "Display execution history via CLI successfully"

# Test Scenario 6: Run pending job automatically (automatic execution)
echo "--- Scenario 6: Automatic execution (run pending) ---"
# Set last run time to 10 minutes ago
PAST_TIME=$(date -d "10 minutes ago" +'%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-10M +'%Y-%m-%d %H:%M:%S' 2>/dev/null)
TEMP_FILE=$(mktemp)
jq --arg past "$PAST_TIME" '.last_run = $past' "$JOB_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$JOB_FILE"

tjc_schedule run-pending
STATUS=$?
assert_success "$STATUS" "Executed pending due jobs automatically"

# Test Scenario 7: Remove schedule
echo "--- Scenario 7: Remove Schedule ---"
tjc_schedule remove "job_sync"
STATUS=$?
assert_success "$STATUS" "Unscheduled and removed job successfully"
assert_failure "$([ -f "$JOB_FILE" ] && echo 0 || echo 1)" "Job config file removed"

# Clean up
rm -rf "$TJC_CONFIG_DIR"

echo "----------------------------------------_"
echo "Scheduler Tests Completed:"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "----------------------------------------_"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
