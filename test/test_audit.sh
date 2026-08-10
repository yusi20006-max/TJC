#!/bin/sh
set -eu

BASE_DIR=$(pwd)
export BASE_DIR
TJC_CONFIG_DIR=$(mktemp -d)
export TJC_CONFIG_DIR
. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/lib/audit.sh"

export TJC_CORRELATION_ID='corr_test_123'
tjc_audit_event job_status job_id=test_job status=RUNNING api_key='super-secret-value' authorization='Bearer secret'

FILE="$TJC_CONFIG_DIR/audit/events.jsonl"
test -f "$FILE"
jq -e '.[0:0] | true' >/dev/null 2>&1 || true
LINE=$(cat "$FILE")
printf '%s\n' "$LINE" | jq -e '.event == "job_status" and .correlation_id == "corr_test_123"' >/dev/null
if printf '%s\n' "$LINE" | grep -q 'super-secret-value'; then exit 1; fi
if printf '%s\n' "$LINE" | grep -q 'Bearer secret'; then exit 1; fi
printf '%s\n' "$LINE" | jq -e '.api_key == "api_key=[REDACTED]" and .authorization == "authorization=[REDACTED]"' >/dev/null

rm -rf "$TJC_CONFIG_DIR"
echo 'Audit tests: passed'
