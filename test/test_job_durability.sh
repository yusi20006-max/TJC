#!/bin/sh
set -eu

BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TJC_CONFIG_DIR=$(mktemp -d)
export TJC_CONFIG_DIR
trap 'rm -rf "$TJC_CONFIG_DIR"' EXIT HUP INT TERM

# shellcheck disable=SC1091
. "$BASE_DIR/lib/config.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/job/jobs.sh"

# Normal lifecycle still works.
tjc_job_create durable_test 'durability test'
tjc_job_set_status durable_test QUEUED
tjc_job_set_status durable_test RUNNING
tjc_job_set_status durable_test COMPLETED
[ "$(tjc_job_status durable_test)" = COMPLETED ]

# Simulate a stale lock owned by a non-existent PID. A new lock acquisition
# must recover it instead of waiting for the timeout.
mkdir -p "$(tjc_job_dir)/.locks/stale_test.lock"
printf '%s\n' '999999999' > "$(tjc_job_dir)/.locks/stale_test.lock/pid"
LOCK=$(tjc_job_lock stale_test)
[ -d "$LOCK" ]
tjc_job_unlock "$LOCK"
[ ! -e "$(tjc_job_dir)/.locks/stale_test.lock" ]

echo 'Job durability tests passed.'
