#!/bin/sh

# TJC Utility Helpers

# Public function: tjc_command_exists
# Usage: tjc_command_exists <command_name>
# Description: Checks if a given command exists in the current system path.
# Returns: Exit code 0 if command exists, 1 if it does not.
tjc_command_exists() {
  CMD_NAME="${1:-}"
  if [ -z "$CMD_NAME" ]; then
    return 1
  fi

  if command -v "$CMD_NAME" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Public function: tjc_is_termux
# Usage: tjc_is_termux
# Description: Determines if the environment is a Termux terminal on Android.
# Returns: Exit code 0 if run inside Termux, 1 if not.
tjc_is_termux() {
  if [ -d "/data/data/com.termux/files/usr" ]; then
    return 0
  else
    return 1
  fi
}
