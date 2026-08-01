#!/bin/sh

# TJC Logging system
# Implements structured logging into standard TJC config directory.

# Public function: tjc_log_file
# Usage: tjc_log_file
# Description: Returns the path to the standard log file.
# Returns: String file path. Exit code 0.
tjc_log_file() {
  CONFIG_DIR=$(tjc_config_dir)
  printf '%s/logs/tjc.log\n' "$CONFIG_DIR"
}

# Public function: tjc_log_init
# Usage: tjc_log_init
# Description: Initializes log directory and file, setting secure permissions (chmod 600).
# Returns: Exit code 0 on success.
tjc_log_init() {
  # shellcheck disable=SC3043 # local is supported by all target POSIX shells in Termux and standard Linux
  local LOG_FILE LOG_DIR
  # Ensure base config dir exists with secure permissions (chmod 700)
  tjc_ensure_config_dir

  LOG_FILE=$(tjc_log_file)
  LOG_DIR=$(dirname "$LOG_FILE")
  if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
  fi
  chmod 700 "$LOG_DIR"

  if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
  fi
  chmod 600 "$LOG_FILE"
  return 0
}

# Public function: tjc_log
# Usage: tjc_log <level> <message...>
# Description: Writes timestamped log message with severity level.
# Returns: Exit code 0 on success.
tjc_log() {
  LEVEL="$1"
  shift
  MESSAGE="$*"

  # Ensure logger is initialized
  tjc_log_init

  TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
  LOG_FILE=$(tjc_log_file)

  printf '[%s] [%s] %s\n' "$TIMESTAMP" "$LEVEL" "$MESSAGE" >> "$LOG_FILE"
  return 0
}

# Public function: tjc_log_info
# Usage: tjc_log_info <message...>
# Description: Writes an INFO level log.
# Returns: Exit code 0.
tjc_log_info() {
  tjc_log "INFO" "$*"
}

# Public function: tjc_log_warn
# Usage: tjc_log_warn <message...>
# Description: Writes a WARN level log.
# Returns: Exit code 0.
tjc_log_warn() {
  tjc_log "WARN" "$*"
}

# Public function: tjc_log_error
# Usage: tjc_log_error <message...>
# Description: Writes an ERROR level log.
# Returns: Exit code 0.
tjc_log_error() {
  tjc_log "ERROR" "$*"
}

# Public function: tjc_log_debug
# Usage: tjc_log_debug <message...>
# Description: Writes a DEBUG level log if TJC_DEBUG is true.
# Returns: Exit code 0.
tjc_log_debug() {
  if [ "${TJC_DEBUG:-false}" = "true" ]; then
    tjc_log "DEBUG" "$*"
  fi
  return 0
}
