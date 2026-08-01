#!/bin/sh

# TJC Version Command
# Displays version information.

# Public function: tjc_version
# Usage: tjc_version <base_dir>
# Description: Reads and outputs content of the VERSION file.
# Returns: Exit code 0 on success, 1 on failure.
tjc_version() {
  BASE_DIR_PATH="${1:-}"
  if [ -z "$BASE_DIR_PATH" ]; then
    return 1
  fi

  VERSION_FILE="${BASE_DIR_PATH}/VERSION"
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
    return 0
  else
    printf 'unknown\n'
    return 1
  fi
}
