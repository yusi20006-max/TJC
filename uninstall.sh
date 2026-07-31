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

rm -f "$BIN_DIR/tjc" "$BIN_DIR/jules"
rm -rf "$SHARE_DIR"

printf 'Removed %s and command links from %s\n' "$SHARE_DIR" "$BIN_DIR"
