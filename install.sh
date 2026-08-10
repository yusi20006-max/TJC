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
PARENT_DIR="$PREFIX_ARG/share"
STAGE_DIR="$PARENT_DIR/.tjc-install-$$"
BACKUP_DIR="$PARENT_DIR/.tjc-backup-$$"

cleanup() {
  rm -rf "$STAGE_DIR"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$BIN_DIR" "$PARENT_DIR"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

# Build the complete runtime in a staging directory before changing the live
# installation. This prevents a partial copy from becoming the active tree.
cp -R commands config docs lib workflow scheduler job queue mcp policy providers plugin VERSION README.md LICENSE CHANGELOG.md CONTRIBUTING.md .gitignore "$STAGE_DIR/"
cp jules "$STAGE_DIR/jules"
chmod 700 "$STAGE_DIR/jules"

if [ -e "$SHARE_DIR" ]; then
  rm -rf "$BACKUP_DIR"
  mv "$SHARE_DIR" "$BACKUP_DIR"
fi

if mv "$STAGE_DIR" "$SHARE_DIR"; then
  rm -rf "$BACKUP_DIR"
else
  if [ -e "$BACKUP_DIR" ]; then
    mv "$BACKUP_DIR" "$SHARE_DIR"
  fi
  echo 'Installation failed; previous installation was restored.' >&2
  exit 1
fi

ln -sf "$SHARE_DIR/jules" "$BIN_DIR/tjc"
ln -sf "$SHARE_DIR/jules" "$BIN_DIR/jules"

printf 'Installed TJC to %s\n' "$SHARE_DIR"
printf 'Executables: %s/tjc, %s/jules\n' "$BIN_DIR" "$BIN_DIR"
