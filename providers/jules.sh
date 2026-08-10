#!/bin/sh

# TJC Jules provider adapter.
# Authentication uses X-Goog-Api-Key and never returns/logs the key.

JULES_BASE_URL="${JULES_BASE_URL:-https://jules.googleapis.com/v1alpha}"

tjc_jules_require_key() {
  [ -n "${JULES_API_KEY:-}" ] || { echo 'Error: Invalid Jules API key.' >&2; return 1; }
}

tjc_jules_request() {
  METHOD="${1:-GET}"; ENDPOINT="${2:-}"; BODY="${3:-}"
  tjc_jules_require_key || return 1
  [ -n "$ENDPOINT" ] || return 1
  case "$ENDPOINT" in
    /*) URL="$JULES_BASE_URL$ENDPOINT";;
    *) URL="$JULES_BASE_URL/$ENDPOINT";;
  esac

  ATTEMPT=1
  while [ "$ATTEMPT" -le 3 ]; do
    TMP_BODY=$(mktemp)
    TMP_HEADERS=$(mktemp)
    if [ "$METHOD" = "GET" ]; then
      CODE=$(curl -sS --connect-timeout 10 --max-time 30 -o "$TMP_BODY" -D "$TMP_HEADERS" -w '%{http_code}' -H "x-goog-api-key: $JULES_API_KEY" -H 'Accept: application/json' "$URL" 2>/dev/null) || CODE=000
    else
      CODE=$(curl -sS --connect-timeout 10 --max-time 30 -o "$TMP_BODY" -D "$TMP_HEADERS" -w '%{http_code}' -X "$METHOD" -H "x-goog-api-key: $JULES_API_KEY" -H 'Content-Type: application/json' -H 'Accept: application/json' ${BODY:+--data "$BODY"} "$URL" 2>/dev/null) || CODE=000
    fi

    case "$CODE" in
      200|201|202|204)
        cat "$TMP_BODY"; rm -f "$TMP_BODY" "$TMP_HEADERS"; return 0;;
      400) rm -f "$TMP_BODY" "$TMP_HEADERS"; echo 'Error: Invalid Jules API request.' >&2; return 1;;
      401|403) rm -f "$TMP_BODY" "$TMP_HEADERS"; echo 'Error: Invalid Jules API key.' >&2; return 1;;
      500|502|503|504|000) rm -f "$TMP_BODY" "$TMP_HEADERS"; [ "$ATTEMPT" -lt 3 ] && sleep "$ATTEMPT"; ATTEMPT=$((ATTEMPT + 1); continue;;
      *) rm -f "$TMP_BODY" "$TMP_HEADERS"; echo 'Error: Jules API request failed.' >&2; return 1;;
    esac
  done
  echo 'Error: Jules API temporarily unavailable.' >&2
  return 1
}

tjc_provider_authenticate() { tjc_jules_require_key; }
tjc_provider_list_sources() { tjc_jules_request GET /sources; }
tjc_provider_create_session() { tjc_jules_request POST /sessions "${1:-{}}"; }
tjc_provider_get_session() { tjc_jules_request GET "/sessions/$1"; }
tjc_provider_list_activities() { tjc_jules_request GET "/sessions/$1/activities"; }
tjc_provider_get_pull_request() { tjc_jules_request GET "/pullRequests/$1"; }
tjc_provider_cancel_operation() { tjc_jules_request POST "/sessions/$1:cancel" '{}'; }
