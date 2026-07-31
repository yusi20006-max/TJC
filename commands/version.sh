#!/bin/sh

tjc_version() {
  VERSION_FILE="$1/VERSION"
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
  else
    printf 'unknown\n'
  fi
}
