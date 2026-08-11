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
. "${BASE_DIR}/job/jobs.sh"
. "${BASE_DIR}/workflow/engine.sh"
. "${BASE_DIR}/queue/queue.sh"

PASS=0
FAIL=0
ok() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL: $2"; FAIL=$((FAIL+1)); fi; }

WF="$TJC_CONFIG_DIR/queue.yml"
cat >"$WF" <<'YAML'
name: "Queue Test"
steps:
  - type: doctor
YAML

tjc_queue_add_workflow "$WF" 100 queue_test >/dev/null
ok "$?" "workflow queued"

if test -f "$TJC_CONFIG_DIR/queue/items/queue_test.json"; then
  CODE=0
else
  CODE=1
fi
ok "$CODE" "queue item persisted"

if jq -e '.status == "QUEUED" and .priority == 100' "$TJC_CONFIG_DIR/queue/items/queue_test.json" >/dev/null; then
  CODE=0
else
  CODE=1
fi
ok "$CODE" "queue metadata valid"

set +e
tjc_queue_add_workflow "$WF" 100 queue_test >/dev/null 2>&1
CODE=$?
set -e
if [ "$CODE" -ne 0 ]; then
  RESULT=0
else
  RESULT=1
fi
ok "$RESULT" "duplicate queue item rejected"

rm -rf "$TJC_CONFIG_DIR"
echo "Queue tests: passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
