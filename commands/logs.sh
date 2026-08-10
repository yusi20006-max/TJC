#!/bin/sh
# shellcheck disable=SC1091
. "${BASE_DIR}/lib/logger.sh"

tjc_logs_command() {
  LIMIT="${2:-50}"
  echo "$LIMIT" | grep -Eq '^[1-9][0-9]*$' || { tjc_error 'Usage: tjc logs [tail] [count]'; return 1; }
  LOG_FILE="$(tjc_config_dir)/logs/tjc.log"
  [ -f "$LOG_FILE" ] || { tjc_info 'No log file found.'; return 0; }
  tail -n "$LIMIT" "$LOG_FILE"
}
