#!/bin/sh
set -eu

BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BASE_DIR"

PASSED=0
FAILED=0
for TEST in test/test_jobs.sh test/test_workflows.sh test/test_scheduler.sh test/test_workflow_v2.sh test/test_queue.sh test/test_providers.sh test/test_mcp.sh test/test_audit.sh test/test_policy.sh; do
  if [ -x "$TEST" ]; then
    if "$TEST"; then PASSED=$((PASSED + 1)); else FAILED=$((FAILED + 1)); fi
  elif sh "$TEST"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

printf 'Test suites: passed=%s failed=%s\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
