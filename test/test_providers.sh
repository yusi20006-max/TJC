#!/bin/sh
set -eu

BASE_DIR=$(pwd)
export BASE_DIR
. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/lib/provider.sh"

TJC_CONFIG_DIR=$(mktemp -d)
export TJC_CONFIG_DIR
OUTFILE="$TJC_CONFIG_DIR/provider-test.out"
trap 'rm -rf "$TJC_CONFIG_DIR"' EXIT HUP INT TERM

PASS=0
FAIL=0
ok() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL: $2"; FAIL=$((FAIL+1)); fi; }

unset JULES_API_KEY
set +e
tjc_provider_init >"$OUTFILE" 2>&1
CODE=$?
set -e
if [ "$CODE" -ne 0 ]; then RESULT=0; else RESULT=1; fi
ok "$RESULT" "missing key rejected"
if grep -q 'Jules API key is not configured' "$OUTFILE"; then RESULT=0; else RESULT=1; fi
ok "$RESULT" "safe authentication error"

export JULES_API_KEY='test-secret-value'
export TJC_PROVIDER=jules
set +e
tjc_provider_load >/dev/null 2>&1
CODE=$?
set -e
ok "$CODE" "Jules provider loads"

set +e
tjc_provider_authenticate >"$OUTFILE" 2>&1
CODE=$?
set -e
ok "$CODE" "authentication detects configured key"
if grep -q 'test-secret-value' "$OUTFILE"; then RESULT=1; else RESULT=0; fi
ok "$RESULT" "provider does not echo API key"

echo "Provider tests: passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
