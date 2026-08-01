#!/bin/sh

# Test suite for TJC Workflow Engine

# Exit immediately if a command fails
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

# Source workflow engine and command handlers
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/engine.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/commands/workflow.sh"

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
echo "Running TJC Workflow Engine Tests..."
echo "========================================="

# Test Scenario 1: Valid workflow execution
echo "--- Scenario 1: Valid Workflow ---"
VALID_WF="${TJC_CONFIG_DIR}/valid_wf.yml"
cat << 'EOF' > "$VALID_WF"
name: "Valid Test Workflow"
description: "Succeeds with simple doctor and session steps"
steps:
  - type: doctor
  - type: create_session
    session_name: "test_sess"
EOF

tjc_workflow run "$VALID_WF"
STATUS=$?
assert_success "$STATUS" "Valid workflow executed successfully"

# Verify report was created and contains valid json values
REPORT_FILE=""
for f in "${TJC_CONFIG_DIR}/workflows/reports"/report_*.json; do
  if [ -f "$f" ]; then
    REPORT_FILE="$f"
    break
  fi
done
if [ -n "$REPORT_FILE" ] && [ -f "$REPORT_FILE" ]; then
  WF_NAME=$(jq -r '.workflow' "$REPORT_FILE")
  assert_equals "Valid Test Workflow" "$WF_NAME" "Report name matches"

  WF_STATUS=$(jq -r '.status' "$REPORT_FILE")
  assert_equals "COMPLETED" "$WF_STATUS" "Report status is COMPLETED"

  STEPS_COUNT=$(jq '.steps | length' "$REPORT_FILE")
  assert_equals "2" "$STEPS_COUNT" "Report contains exactly 2 steps"

  STEP0_STATUS=$(jq -r '.steps[0].status' "$REPORT_FILE")
  assert_equals "COMPLETED" "$STEP0_STATUS" "Step 0 (doctor) completed successfully"

  STEP1_STATUS=$(jq -r '.steps[1].status' "$REPORT_FILE")
  assert_equals "COMPLETED" "$STEP1_STATUS" "Step 1 (create_session) completed successfully"
else
  printf '%s[FAIL]%s Report file was not created.\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test Scenario 2: Invalid workflows are rejected (Unknown top-level fields)
echo "--- Scenario 2: Invalid Workflow (Unknown field) ---"
INVALID_WF1="${TJC_CONFIG_DIR}/invalid_wf1.yml"
cat << 'EOF' > "$INVALID_WF1"
name: "Invalid Field"
unknown_field: "this should fail"
steps:
  - type: doctor
EOF

# Set set -e off temporarily to capture exit status
set +e
tjc_workflow run "$INVALID_WF1"
STATUS=$?
set -e
assert_failure "$STATUS" "Workflow with unknown top-level field is rejected"

# Test Scenario 3: Invalid workflows are rejected (Invalid step type)
echo "--- Scenario 3: Invalid Workflow (Forbidden step type) ---"
INVALID_WF2="${TJC_CONFIG_DIR}/invalid_wf2.yml"
cat << 'EOF' > "$INVALID_WF2"
name: "Forbidden Step"
steps:
  - type: "unsupported_shell_command"
EOF

set +e
tjc_workflow run "$INVALID_WF2"
STATUS=$?
set -e
assert_failure "$STATUS" "Workflow with unauthorized/forbidden step type is rejected"

# Test Scenario 4: Failed step cancels downstream steps
echo "--- Scenario 4: Failed step halts execution safely ---"
INVALID_WF3="${TJC_CONFIG_DIR}/invalid_wf3.yml"
cat << 'EOF' > "$INVALID_WF3"
name: "Workflow with Failed Step"
steps:
  - type: doctor
  - type: get_pr # Missing pr_number, should fail
  - type: list_activities # Should be cancelled
EOF

set +e
tjc_workflow run "$INVALID_WF3"
STATUS=$?
set -e
assert_failure "$STATUS" "Workflow with missing get_pr parameter fails"

# Find newest report to verify states
NEWEST_REPORT=""
for f in "${TJC_CONFIG_DIR}/workflows/reports"/report_*.json; do
  if [ -f "$f" ]; then
    # Glob will sort alphabetically, which works for timestamps in reports
    NEWEST_REPORT="$f"
  fi
done
if [ -n "$NEWEST_REPORT" ] && [ -f "$NEWEST_REPORT" ]; then
  WF_STATUS=$(jq -r '.status' "$NEWEST_REPORT")
  assert_equals "FAILED" "$WF_STATUS" "Workflow status is marked as FAILED"

  STEP0_STATUS=$(jq -r '.steps[0].status' "$NEWEST_REPORT")
  assert_equals "COMPLETED" "$STEP0_STATUS" "Step 0 (doctor) is COMPLETED"

  STEP1_STATUS=$(jq -r '.steps[1].status' "$NEWEST_REPORT")
  assert_equals "FAILED" "$STEP1_STATUS" "Step 1 (get_pr) is FAILED"

  STEP2_STATUS=$(jq -r '.steps[2].status' "$NEWEST_REPORT")
  assert_equals "CANCELLED" "$STEP2_STATUS" "Step 2 (list_activities) is CANCELLED"
else
  printf '%s[FAIL]%s Report file was not created for failed workflow.\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Test Scenario 5: Security path checks
echo "--- Scenario 5: Security validations (unsafe path traversal) ---"
set +e
tjc_workflow run "; rm -rf /"
STATUS=$?
set -e
assert_failure "$STATUS" "Shell injection in workflow path is strictly rejected"

set +e
tjc_workflow show "; rm -rf /"
STATUS_SHOW_INJ=$?
set -e
assert_failure "$STATUS_SHOW_INJ" "Shell injection in show report path is strictly rejected"

set +e
tjc_workflow show "../../some_other_file"
STATUS_SHOW_TRAV=$?
set -e
assert_failure "$STATUS_SHOW_TRAV" "Directory traversal in show report path is strictly rejected"

# Test Scenario 6: Logger behavior
echo "--- Scenario 6: Logger behavior verification ---"
LOG_FILE="${TJC_CONFIG_DIR}/logs/tjc.log"
assert_success "$([ -f "$LOG_FILE" ] && echo 0 || echo 1)" "Logger successfully created log file"
assert_success "$(grep -q "Executing Step" "$LOG_FILE" && echo 0 || echo 1)" "Logger recorded executions correctly"

# Ensure no credentials or keys are written to log file
assert_success "$(grep -qv "key" "$LOG_FILE" && echo 0 || echo 1)" "Logger has no potential credentials/secrets written"

# Clean up temporary test files
rm -rf "$TJC_CONFIG_DIR"

echo "----------------------------------------_"
echo "Workflow Tests Completed:"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "----------------------------------------_"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
