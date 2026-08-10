#!/bin/sh
set -eu

BASE_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PREFIX="$TMP/prefix"

( cd "$BASE_DIR" && sh ./install.sh --prefix "$PREFIX" )

[ -x "$PREFIX/share/tjc/jules" ]
[ -d "$PREFIX/share/tjc/plugin" ]
[ -x "$PREFIX/bin/tjc" ]
[ -L "$PREFIX/bin/tjc" ]

# Reinstall exercises the staged replacement path.
( cd "$BASE_DIR" && sh ./install.sh --prefix "$PREFIX" )
[ -x "$PREFIX/share/tjc/jules" ]
[ -d "$PREFIX/share/tjc/plugin" ]

echo 'test_installer_v2_1: PASS'
