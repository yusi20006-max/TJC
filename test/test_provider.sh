#!/bin/sh
set -eu

BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

export JULES_API_KEY='unit-test-key'
export JULES_BASE_URL='https://example.invalid/v1alpha'
export TJC_JULES_MAX_ATTEMPTS=3
export TJC_JULES_CONNECT_TIMEOUT=1
export TJC_JULES_MAX_TIME=2

MOCK_CURL="$TMP_DIR/curl"
cat > "$MOCK_CURL" <<'EOF'
#!/bin/sh
set -eu
OUT=''
CODE='200'
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) OUT="$2"; shift 2;;
    -w) CODE="$2"; shift 2;;
    -D) shift 2;;
    *) shift;;
  esac
done
printf '{"ok":true}\n' > "$OUT"
printf '%s' '200'
EOF
chmod +x "$MOCK_CURL"
export PATH="$TMP_DIR:$PATH"

# shellcheck disable=SC1091
. "$BASE_DIR/providers/jules.sh"

RESULT=$(tjc_provider_list_sources)
[ "$RESULT" = '{"ok":true}' ]

tjc_provider_authenticate

# Missing credentials must fail without attempting HTTP.
unset JULES_API_KEY
if tjc_provider_authenticate 2>/dev/null; then
  echo 'FAIL: missing API key was accepted' >&2
  exit 1
fi

echo 'Provider tests passed.'
