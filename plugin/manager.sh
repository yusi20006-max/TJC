#!/bin/sh
# TJC v2.1 Plugin Manager
# Plugins are opt-in, manifest-driven, and policy-gated.
# This schema constant is part of the sourced module's public API.
# shellcheck disable=SC2034

TJC_PLUGIN_SCHEMA_VERSION=1

tjc_plugin_dir() {
  printf '%s/plugins\n' "$(tjc_config_dir)"
}

tjc_plugin_valid_name() {
  case "${1:-}" in
    ''|*[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

tjc_plugin_manifest() {
  NAME="${1:-}"
  tjc_plugin_valid_name "$NAME" || return 1
  printf '%s/%s/plugin.yml\n' "$(tjc_plugin_dir)" "$NAME"
}

tjc_plugin_init_dir() {
  DIR=$(tjc_plugin_dir)
  mkdir -p "$DIR"
  chmod 700 "$DIR"
}

tjc_plugin_validate_manifest() {
  NAME="${1:-}"
  tjc_plugin_valid_name "$NAME" || return 1
  FILE=$(tjc_plugin_manifest "$NAME")
  [ -f "$FILE" ] || return 1
  yq . "$FILE" >/dev/null 2>&1 || return 1
  SCHEMA=$(yq -r '.schema_version // 0' "$FILE" 2>/dev/null)
  [ "$SCHEMA" = 1 ] || return 1
  MANIFEST_NAME=$(yq -r '.name // ""' "$FILE" 2>/dev/null)
  [ "$MANIFEST_NAME" = "$NAME" ] || return 1
  ENTRY=$(yq -r '.entrypoint // ""' "$FILE" 2>/dev/null)
  case "$ENTRY" in
    ''|/*|*..*|*'/'*) return 1 ;;
  esac
  PLUGIN_ROOT="$(tjc_plugin_dir)/$NAME"
  ENTRY_FILE="$PLUGIN_ROOT/$ENTRY"
  [ -f "$ENTRY_FILE" ] || return 1
  [ -x "$ENTRY_FILE" ] || return 1
  find "$PLUGIN_ROOT" -type l -print -quit | grep . >/dev/null 2>&1 && return 1
  CAPS=$(yq -r '.capabilities // [] | .[]' "$FILE" 2>/dev/null) || return 1
  for CAP in $CAPS; do
    case "$CAP" in
      plugin.execute|filesystem.read|filesystem.write|network.read|provider.read|provider.execute) : ;;
      *) return 1 ;;
    esac
  done
}

tjc_plugin_require_capabilities() {
  FILE="${1:-}"
  [ -f "$FILE" ] || return 1
  CAPS=$(yq -r '.capabilities // [] | .[]' "$FILE" 2>/dev/null) || return 1
  for CAP in $CAPS; do
    tjc_policy_require "$CAP" || return 1
  done
}

tjc_plugin_list() {
  DIR=$(tjc_plugin_dir)
  [ -d "$DIR" ] || return 0
  for P in "$DIR"/*; do
    [ -d "$P" ] || continue
    NAME=$(basename "$P")
    FILE="$P/plugin.yml"
    if [ -f "$FILE" ]; then
      STATUS=invalid
      tjc_plugin_validate_manifest "$NAME" >/dev/null 2>&1 && STATUS=valid
      printf '%s\t%s\n' "$NAME" "$STATUS"
    fi
  done
}

tjc_plugin_show() {
  NAME="${1:-}"
  tjc_plugin_validate_manifest "$NAME" || return 1
  cat "$(tjc_plugin_manifest "$NAME")"
}

tjc_plugin_run() {
  NAME="${1:-}"
  shift || true
  [ -n "$NAME" ] || return 1
  tjc_plugin_validate_manifest "$NAME" || { tjc_error "Invalid plugin: $NAME"; return 1; }
  FILE=$(tjc_plugin_manifest "$NAME")
  tjc_policy_require plugin.execute || return 1
  tjc_plugin_require_capabilities "$FILE" || return 1
  ROOT=$(dirname "$FILE")
  ENTRY=$(yq -r '.entrypoint' "$FILE")
  TJC_PLUGIN_NAME="$NAME" TJC_PLUGIN_ROOT="$ROOT" "$ROOT/$ENTRY" "$@"
}

tjc_plugin_install_local() {
  SRC="${1:-}"
  [ -d "$SRC" ] || { tjc_error 'Plugin directory not found'; return 1; }
  [ -f "$SRC/plugin.yml" ] || { tjc_error 'plugin.yml is required'; return 1; }
  find "$SRC" -type l -print -quit | grep . >/dev/null 2>&1 && { tjc_error 'Plugin symlinks are not allowed'; return 1; }
  NAME=$(yq -r '.name // ""' "$SRC/plugin.yml" 2>/dev/null)
  tjc_plugin_valid_name "$NAME" || { tjc_error 'Invalid plugin name'; return 1; }
  tjc_plugin_init_dir || return 1
  DEST="$(tjc_plugin_dir)/$NAME"
  [ ! -e "$DEST" ] || { tjc_error "Plugin already installed: $NAME"; return 1; }
  mkdir -p "$DEST"
  cp -R "$SRC"/. "$DEST"/
  chmod 700 "$DEST"
  find "$DEST" -type f -name '*.sh' -exec chmod 700 {} \;
  tjc_plugin_validate_manifest "$NAME" || { rm -rf "$DEST"; tjc_error 'Plugin manifest validation failed'; return 1; }
  tjc_success "Installed plugin: $NAME"
}
