#!/bin/sh
set -eu

BASE_DIR=$(pwd)
export BASE_DIR
. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/lib/provider.sh"

PASS=0
FAIL=0
ok() { if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); else echo "FAIL: $2"; FAIL=$((FAIL+1)); fi; }

unset JULES_API_KEY
set +e
tjc_provider_init >/tmp/tjc-provider-test.out 2>&1
CODE=$?
set -e
ok "$( [ "$CODE" -ne 0 ]; echo $? )" "missing key rejected"
ok "$( grep -q 'Invalid Jules API key' /tmp/tjc-provider-test.out; echo $? )" "safe authentication error"

export JULES_API_KEY='test-secret-value'
export TJC_PROVIDER=jules
set +e
tjc_provider_load >/dev/null 2>&1
CODE=$?
set -e
ok "$CODE" "Jules provider loads"

set +e
tjc_provider_authenticate >/tmp/tjc-provider-test.out 2>&1
CODE=$?
set -e
ok "$CODE" "authentication detects configured key"
ok "$( grep -q 'test-secret-value' /tmp/tjc-provider-test.out; echo $? )" "provider does not echo API key"

rm -f /tmp/tjc-provider-test.out
echo "Provider tests: passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
