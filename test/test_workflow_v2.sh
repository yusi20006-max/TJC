#!/bin/sh
set -eu

export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)
BASE_DIR=$(pwd)
export BASE_DIR

. "${BASE_DIR}/lib/colors.sh"
. "${BASE_DIR}/lib/utils.sh"
. "${BASE_DIR}/lib/output.sh"
. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/lib/logger.sh"
. "${BASE_DIR}/workflow/engine.sh"

PASS=0
FAIL=0
assert_ok() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL: $2"; FAIL=$((FAIL+1)); fi; }
assert_fail() { if [ "$1" -ne 0 ]; then PASS=$((PASS+1)); else echo "FAIL: $2"; FAIL=$((FAIL+1)); fi; }

WF="$TJC_CONFIG_DIR/v2.yml"
cat >"$WF" <<'YAML'
name: "V2 Workflow"
description: "Dependency and retry policy test"
variables:
  environment: production
steps:
  - type: doctor
  - type: list_activities
    depends_on: [0]
    condition: "var:environment=production"
    retry:
      attempts: 1
    timeout:
      seconds: 20
  - type: get_pr
    pr_number: 23
    depends_on: [1]
YAML

set +e
tjc_workflow_validate "$WF"
CODE=$?
set -e
assert_ok "$CODE" "v2 workflow validates"

set +e
tjc_workflow_execute "$WF"
CODE=$?
set -e
assert_ok "$CODE" "v2 workflow executes"

REPORT=$(find "$TJC_CONFIG_DIR/workflows/reports" -name 'report_*.json' -type f | head -n 1)
[ -n "$REPORT" ] && assert_ok 0 "execution report exists" || assert_fail 0 "execution report exists"

if [ -n "$REPORT" ]; then
  assert_ok "$(jq -e '.status == "COMPLETED"' "$REPORT" >/dev/null; echo $?)" "workflow completed"
  assert_ok "$(jq -e '.steps[1].attempts >= 1' "$REPORT" >/dev/null; echo $?)" "attempt count recorded"
fi

BAD="$TJC_CONFIG_DIR/cycle.yml"
cat >"$BAD" <<'YAML'
name: "Cycle"
steps:
  - type: doctor
    depends_on: [1]
  - type: doctor
    depends_on: [0]
YAML
set +e
tjc_workflow_validate "$BAD"
CODE=$?
set -e
assert_fail "$CODE" "dependency cycle rejected"

UNSAFE="$TJC_CONFIG_DIR/unsafe.yml"
cat >"$UNSAFE" <<'YAML'
name: "Unsafe"
steps:
  - type: doctor
    condition: 'shell:rm -rf /'
YAML
set +e
tjc_workflow_validate "$UNSAFE"
CODE=$?
set -e
assert_fail "$CODE" "unsafe condition rejected"

rm -rf "$TJC_CONFIG_DIR"
echo "Workflow v2 tests: passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
