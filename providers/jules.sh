#!/bin/sh

# TJC Jules provider adapter.
# The provider boundary owns HTTP transport and Jules-specific authentication.
# Higher-level Jobs, Workflows, and policy decisions stay outside this file.

JULES_BASE_URL="${JULES_BASE_URL:-https://jules.googleapis.com/v1alpha}"
TJC_JULES_MAX_ATTEMPTS="${TJC_JULES_MAX_ATTEMPTS:-3}"
TJC_JULES_CONNECT_TIMEOUT="${TJC_JULES_CONNECT_TIMEOUT:-10}"
TJC_JULES_MAX_TIME="${TJC_JULES_MAX_TIME:-30}"
TJC_JULES_BACKOFF_CAP="${TJC_JULES_BACKOFF_CAP:-8}"

# Keep provider configuration bounded so a malformed environment cannot create
# an unbounded retry loop or an effectively infinite curl invocation.
tjc_jules_valid_number() {
  case "${1:-}" in
    ''|*[!0-9]*) return 1 ;;
    *) [ "$1" -gt 0 ] 2>/dev/null ;;
  esac
}

tjc_jules_validate_config() {
  tjc_jules_valid_number "$TJC_JULES_MAX_ATTEMPTS" || tjc_jules_error 'Error: TJC_JULES_MAX_ATTEMPTS must be a positive integer.' || return 1
  tjc_jules_valid_number "$TJC_JULES_CONNECT_TIMEOUT" || tjc_jules_error 'Error: TJC_JULES_CONNECT_TIMEOUT must be a positive integer.' || return 1
  tjc_jules_valid_number "$TJC_JULES_MAX_TIME" || tjc_jules_error 'Error: TJC_JULES_MAX_TIME must be a positive integer.' || return 1
  tjc_jules_valid_number "$TJC_JULES_BACKOFF_CAP" || tjc_jules_error 'Error: TJC_JULES_BACKOFF_CAP must be a positive integer.' || return 1
  case "$JULES_BASE_URL" in
    https://*) return 0 ;;
    *) tjc_jules_error 'Error: Jules base URL must use HTTPS.'; return 1 ;;
  esac
}

# Return a stable local error without echoing response bodies or credentials.
tjc_jules_error() {
  printf '%s\n' "$1" >&2
  return 1
}

tjc_jules_require_key() {
  [ -n "${JULES_API_KEY:-}" ] || tjc_jules_error 'Error: Jules API key is not configured.'
}

tjc_jules_method_allowed() {
  case "${1:-}" in
    GET|POST|PUT|PATCH|DELETE) return 0 ;;
    *) return 1 ;;
  esac
}

tjc_jules_request() {
  METHOD="${1:-GET}"
  ENDPOINT="${2:-}"
  BODY="${3:-}"
  ATTEMPT=1

  tjc_jules_require_key || return 1
  tjc_jules_validate_config || return 1
  tjc_jules_method_allowed "$METHOD" || tjc_jules_error 'Error: Unsupported Jules HTTP method.' || return 1
  [ -n "$ENDPOINT" ] || tjc_jules_error 'Error: Jules API endpoint is empty.' || return 1
  case "$ENDPOINT" in
    *[!a-zA-Z0-9_./:-]*) tjc_jules_error 'Error: Jules API endpoint contains unsupported characters.'; return 1 ;;
  esac

  case "$ENDPOINT" in
    /*) URL="$JULES_BASE_URL$ENDPOINT" ;;
    *) URL="$JULES_BASE_URL/$ENDPOINT" ;;
  esac

  while [ "$ATTEMPT" -le "$TJC_JULES_MAX_ATTEMPTS" ]; do
    TMP_BODY=$(mktemp) || tjc_jules_error 'Error: Unable to create temporary response file.' || return 1
    TMP_HEADERS=$(mktemp) || { rm -f "$TMP_BODY"; tjc_jules_error 'Error: Unable to create temporary header file.'; return 1; }

    if [ "$METHOD" = "GET" ]; then
      CODE=$(curl -sS --connect-timeout "$TJC_JULES_CONNECT_TIMEOUT" --max-time "$TJC_JULES_MAX_TIME" \
        -o "$TMP_BODY" -D "$TMP_HEADERS" -w '%{http_code}' \
        -H "x-goog-api-key: $JULES_API_KEY" -H 'Accept: application/json' "$URL" 2>/dev/null) || CODE=000
    elif [ -n "$BODY" ]; then
      CODE=$(curl -sS --connect-timeout "$TJC_JULES_CONNECT_TIMEOUT" --max-time "$TJC_JULES_MAX_TIME" \
        -o "$TMP_BODY" -D "$TMP_HEADERS" -w '%{http_code}' -X "$METHOD" \
        -H "x-goog-api-key: $JULES_API_KEY" -H 'Content-Type: application/json' \
        -H 'Accept: application/json' --data "$BODY" "$URL" 2>/dev/null) || CODE=000
    else
      CODE=$(curl -sS --connect-timeout "$TJC_JULES_CONNECT_TIMEOUT" --max-time "$TJC_JULES_MAX_TIME" \
        -o "$TMP_BODY" -D "$TMP_HEADERS" -w '%{http_code}' -X "$METHOD" \
        -H "x-goog-api-key: $JULES_API_KEY" -H 'Content-Type: application/json' \
        -H 'Accept: application/json' "$URL" 2>/dev/null) || CODE=000
    fi

    case "$CODE" in
      200|201|202|204)
        cat "$TMP_BODY"
        rm -f "$TMP_BODY" "$TMP_HEADERS"
        return 0
        ;;
      400)
        rm -f "$TMP_BODY" "$TMP_HEADERS"
        tjc_jules_error 'Error: Jules rejected the request (400).'
        return 1
        ;;
      401|403)
        rm -f "$TMP_BODY" "$TMP_HEADERS"
        tjc_jules_error 'Error: Jules authentication or authorization failed.'
        return 1
        ;;
      408|425|429|500|502|503|504|000)
        rm -f "$TMP_BODY" "$TMP_HEADERS"
        if [ "$ATTEMPT" -lt "$TJC_JULES_MAX_ATTEMPTS" ]; then
          DELAY="$ATTEMPT"
          [ "$DELAY" -le "$TJC_JULES_BACKOFF_CAP" ] || DELAY="$TJC_JULES_BACKOFF_CAP"
          sleep "$DELAY"
          ATTEMPT=$((ATTEMPT + 1))
          continue
        fi
        ;;
      *)
        rm -f "$TMP_BODY" "$TMP_HEADERS"
        tjc_jules_error "Error: Jules API request failed (HTTP $CODE)."
        return 1
        ;;
    esac
  done

  tjc_jules_error 'Error: Jules API temporarily unavailable after bounded retries.'
}

tjc_provider_authenticate() { tjc_jules_require_key && tjc_jules_validate_config; }
tjc_provider_list_sources() { tjc_jules_request GET /sources; }
tjc_provider_create_session() { tjc_jules_request POST /sessions "${1:-{}}"; }
tjc_provider_get_session() { tjc_jules_request GET "/sessions/$1"; }
tjc_provider_list_activities() { tjc_jules_request GET "/sessions/$1/activities"; }
tjc_provider_get_pull_request() { tjc_jules_request GET "/pullRequests/$1"; }
tjc_provider_cancel_operation() { tjc_jules_request POST "/sessions/$1:cancel" '{}'; }
