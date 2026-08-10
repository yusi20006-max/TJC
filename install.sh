#!/bin/sh
set -eu

PREFIX_ARG="${PREFIX:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      [ "$#" -ge 2 ] || { echo 'Missing value for --prefix.' >&2; exit 1; }
      PREFIX_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[ -n "$PREFIX_ARG" ] || PREFIX_ARG="$HOME/.local"

BIN_DIR="$PREFIX_ARG/bin"
SHARE_DIR="$PREFIX_ARG/share/tjc"

mkdir -p "$BIN_DIR" "$SHARE_DIR"

# Copy the complete runtime tree. TJC v2 is modular and runtime modules must
# remain together with the entrypoint after installation.
cp -R commands config docs lib workflow scheduler job queue mcp policy providers VERSION README.md LICENSE CHANGELOG.md CONTRIBUTING.md .gitignore "$SHARE_DIR/"
cp jules "$SHARE_DIR/jules"
chmod +x "$SHARE_DIR/jules"

ln -sf "$SHARE_DIR/jules" "$BIN_DIR/tjc"
ln -sf "$SHARE_DIR/jules" "$BIN_DIR/jules"

printf 'Installed TJC to %s\n' "$SHARE_DIR"
printf 'Executables: %s/tjc, %s/jules\n' "$BIN_DIR" "$BIN_DIR"
