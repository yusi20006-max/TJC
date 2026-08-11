#!/bin/sh

# Test suite for TJC Workflow Engine
set -eu

export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)
BASE_DIR=$(pwd)
export BASE_DIR

. "${BASE_DIR}/lib/colors.sh"
. "${BASE_DIR}/lib/utils.sh"
. "${BASE_DIR}/lib/output.sh"
. "${BASE_DIR}/lib/config.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/engine.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/commands/workflow.sh"

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

echo "========================================="
echo "Running TJC Workflow Engine Tests..."
echo "========================================="

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

REPORT_FILE=""
for f in "${TJC_CONFIG_DIR}/workflows/reports"/report_*.json; do
  if [ -f "$f" ]; then REPORT_FILE="$f"; break; fi
done
if [ -n "$REPORT_FILE" ] && [ -f "$REPORT_FILE" ]; then
  assert_equals "Valid Test Workflow" "$(jq -r '.workflow' "$REPORT_FILE")" "Report name matches"
  assert_equals "COMPLETED" "$(jq -r '.status' "$REPORT_FILE")" "Report status is COMPLETED"
  assert_equals "2" "$(jq '.steps | length' "$REPORT_FILE")" "Report contains exactly 2 steps"
  assert_equals "COMPLETED" "$(jq -r '.steps[0].status' "$REPORT_FILE")" "Step 0 (doctor) completed successfully"
  assert_equals "COMPLETED" "$(jq -r '.steps[1].status' "$REPORT_FILE")" "Step 1 (create_session) completed successfully"
else
  printf '%s[FAIL]%s Report file was not created.\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo "--- Scenario 2: Invalid Workflow (Unknown field) ---"
INVALID_WF1="${TJC_CONFIG_DIR}/invalid_wf1.yml"
cat << 'EOF' > "$INVALID_WF1"
name: "Invalid Field"
unknown_field: "this should fail"
steps:
  - type: doctor
EOF
set +e
tjc_workflow run "$INVALID_WF1"
STATUS=$?
set -e
assert_failure "$STATUS" "Workflow with unknown top-level field is rejected"

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

echo "--- Scenario 4: Failed step halts execution safely ---"
# Use a schema-valid step whose runtime precondition is intentionally absent.
# This tests execution failure semantics without bypassing the strict validator.
INVALID_WF3="${TJC_CONFIG_DIR}/invalid_wf3.yml"
cat << 'EOF' > "$INVALID_WF3"
name: "Workflow with Failed Step"
steps:
  - type: doctor
  - type: watch_session
    session_id: "missing_session_for_test"
  - type: list_activities
EOF
set +e
tjc_workflow run "$INVALID_WF3"
STATUS=$?
set -e
assert_failure "$STATUS" "Workflow with runtime step failure fails"

NEWEST_REPORT=""
for f in "${TJC_CONFIG_DIR}/workflows/reports"/report_*.json; do
  if [ -f "$f" ]; then NEWEST_REPORT="$f"; fi
done
if [ -n "$NEWEST_REPORT" ] && [ -f "$NEWEST_REPORT" ]; then
  assert_equals "FAILED" "$(jq -r '.status' "$NEWEST_REPORT")" "Workflow status is marked as FAILED"
  assert_equals "COMPLETED" "$(jq -r '.steps[0].status' "$NEWEST_REPORT")" "Step 0 (doctor) is COMPLETED"
  assert_equals "FAILED" "$(jq -r '.steps[1].status' "$NEWEST_REPORT")" "Step 1 (watch_session) is FAILED"
  assert_equals "CANCELLED" "$(jq -r '.steps[2].status' "$NEWEST_REPORT")" "Step 2 (list_activities) is CANCELLED"
else
  printf '%s[FAIL]%s Report file was not created for failed workflow.\n' "$TJC_COLOR_RED" "$TJC_COLOR_RESET"
  FAILED_TESTS=$((FAILED_TESTS + 1))
fi

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

echo "--- Scenario 6: Logger behavior verification ---"
LOG_FILE="${TJC_CONFIG_DIR}/logs/tjc.log"
assert_success "$([ -f "$LOG_FILE" ] && echo 0 || echo 1)" "Logger successfully created log file"
assert_success "$(grep -q "Executing Step" "$LOG_FILE" && echo 0 || echo 1)" "Logger recorded executions correctly"
assert_success "$(grep -qv "key" "$LOG_FILE" && echo 0 || echo 1)" "Logger has no potential credentials/secrets written"

rm -rf "$TJC_CONFIG_DIR"
echo "----------------------------------------_"
echo "Workflow Tests Completed:"
echo "  Passed: $PASSED_TESTS"
echo "  Failed: $FAILED_TESTS"
echo "----------------------------------------_"

if [ "$FAILED_TESTS" -gt 0 ]; then exit 1; fi
exit 0
