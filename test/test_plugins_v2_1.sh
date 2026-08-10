#!/bin/sh
set -eu

BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
mkdir -p "$HOME"

# shellcheck disable=SC1091
. "$BASE_DIR/lib/config.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/policy/policy.sh"
# shellcheck disable=SC1091
. "$BASE_DIR/plugin/manager.sh"

assert_fail() {
  if "$@"; then
    echo "expected failure: $*" >&2
    exit 1
  fi
}

GOOD="$TMP/good"
mkdir -p "$GOOD"
cat >"$GOOD/plugin.yml" <<'YAML'
schema_version: 1
name: good_plugin
entrypoint: entrypoint.sh
capabilities:
  - plugin.execute
YAML
cat >"$GOOD/entrypoint.sh" <<'SH'
#!/bin/sh
printf 'plugin-ok:%s\n' "$1"
SH
chmod 700 "$GOOD/entrypoint.sh"

tjc_plugin_install_local "$GOOD" >/dev/null
tjc_plugin_validate_manifest good_plugin

BAD="$TMP/bad"
mkdir -p "$BAD"
cat >"$BAD/plugin.yml" <<'YAML'
schema_version: 1
name: bad_plugin
entrypoint: ../outside.sh
capabilities:
  - plugin.execute
YAML
cat >"$BAD/outside.sh" <<'SH'
#!/bin/sh
exit 0
SH
chmod 700 "$BAD/outside.sh"
assert_fail tjc_plugin_install_local "$BAD"

LINK="$TMP/link"
mkdir -p "$LINK"
cat >"$LINK/plugin.yml" <<'YAML'
schema_version: 1
name: link_plugin
entrypoint: entrypoint.sh
capabilities:
  - plugin.execute
YAML
ln -s /bin/sh "$LINK/entrypoint.sh"
assert_fail tjc_plugin_install_local "$LINK"

echo 'test_plugins_v2_1: PASS'
