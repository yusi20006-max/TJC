#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck source=/dev/null
. "$ROOT/providers/jules.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$1"; }

JULES_API_KEY='test-key'
TJC_JULES_MAX_ATTEMPTS=3
TJC_JULES_CONNECT_TIMEOUT=1
TJC_JULES_MAX_TIME=2
TJC_JULES_BACKOFF_CAP=2

if tjc_jules_valid_number 3 && ! tjc_jules_valid_number 0 && ! tjc_jules_valid_number abc; then
  pass 'numeric configuration validation'
else
  fail 'numeric configuration validation'
fi

JULES_BASE_URL='http://insecure.example'
if ! tjc_jules_validate_config >/dev/null 2>&1; then
  pass 'HTTPS-only provider URL'
else
  fail 'HTTPS-only provider URL'
fi

JULES_BASE_URL='https://jules.googleapis.com/v1alpha'
if tjc_jules_method_allowed GET && tjc_jules_method_allowed POST && ! tjc_jules_method_allowed TRACE; then
  pass 'HTTP method allowlist'
else
  fail 'HTTP method allowlist'
fi

if ! tjc_jules_request GET '/bad path' >/dev/null 2>&1; then
  pass 'endpoint character validation'
else
  fail 'endpoint character validation'
fi

unset JULES_API_KEY
if ! tjc_jules_require_key >/dev/null 2>&1; then
  pass 'missing credential rejection'
else
  fail 'missing credential rejection'
fi

printf 'Provider hardening tests passed.\n'
