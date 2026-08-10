#!/bin/sh
# TJC consolidated regression test runner.
# Keep this runner POSIX-compatible so it works on Termux and Linux.

set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BASE_DIR"

PASSED=0
FAILED=0

run_test() {
  test_file=$1
  printf '\n=== Running %s ===\n' "$test_file"
  if [ ! -f "$test_file" ]; then
    printf '%s\n' "ERROR: required test file is missing: $test_file" >&2
    FAILED=$((FAILED + 1))
    return
  fi

  if sh "$test_file"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
}

run_test test/test_workflows.sh
run_test test/test_scheduler.sh

printf '\n=========================================\n'
printf 'TJC Test Runner Summary\n'
printf '  Suites passed: %s\n' "$PASSED"
printf '  Suites failed: %s\n' "$FAILED"
printf '=========================================\n'

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
exit 0
