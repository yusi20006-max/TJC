#!/bin/sh
set -eu

PREFIX_ARG="${PREFIX:-}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prefix)
      PREFIX_ARG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$PREFIX_ARG" ]; then
  PREFIX_ARG="$HOME/.local"
fi

BIN_DIR="$PREFIX_ARG/bin"
SHARE_DIR="$PREFIX_ARG/share/tjc"

mkdir -p "$BIN_DIR" "$SHARE_DIR"
cp -R commands config docs lib VERSION README.md LICENSE CHANGELOG.md CONTRIBUTING.md .gitignore "$SHARE_DIR/"
cp jules "$SHARE_DIR/jules"
chmod +x "$SHARE_DIR/jules"

ln -sf "$SHARE_DIR/jules" "$BIN_DIR/tjc"
ln -sf "$SHARE_DIR/jules" "$BIN_DIR/jules"

printf 'Installed to %s\n' "$SHARE_DIR"
printf 'Executables: %s/tjc, %s/jules\n' "$BIN_DIR" "$BIN_DIR"
