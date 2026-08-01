#!/bin/sh

# TJC Configuration Management Helpers

# Public function: tjc_config_dir
# Usage: tjc_config_dir
# Description: Returns the directory path where TJC configuration and state are stored.
# Returns: String directory path. Exit code 0.
tjc_config_dir() {
  if [ -n "${TJC_CONFIG_DIR:-}" ]; then
    printf '%s\n' "$TJC_CONFIG_DIR"
  else
    printf '%s\n' "${HOME}/.config/tjc"
  fi
  return 0
}

# Public function: tjc_ensure_config_dir
# Usage: tjc_ensure_config_dir
# Description: Ensures that the standard config directory exists with secure permissions (chmod 700).
# Returns: Exit code 0.
tjc_ensure_config_dir() {
  # shellcheck disable=SC3043 # local is supported by all target POSIX shells in Termux and standard Linux
  local DIR
  DIR=$(tjc_config_dir)
  if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
  fi
  chmod 700 "$DIR"
  return 0
}

# Public function: tjc_default_config_template
# Usage: tjc_default_config_template <base_dir>
# Description: Returns the file path to the default configuration template.
# Returns: String file path. Exit code 0 on success, 1 on failure.
tjc_default_config_template() {
  BASE_DIR_PATH="${1:-}"
  if [ -z "$BASE_DIR_PATH" ]; then
    return 1
  fi
  printf '%s/config/default.conf\n' "$BASE_DIR_PATH"
  return 0
}
