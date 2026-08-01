#!/bin/sh

# TJC Terminal Output Helpers

# Public function: tjc_info
# Usage: tjc_info <message...>
# Description: Outputs an informative message in blue to standard output.
# Returns: Exit code 0.
tjc_info() {
  printf '%s%s%s\n' "$TJC_COLOR_BLUE" "$*" "$TJC_COLOR_RESET"
  return 0
}

# Public function: tjc_success
# Usage: tjc_success <message...>
# Description: Outputs a success message in green to standard output.
# Returns: Exit code 0.
tjc_success() {
  printf '%s%s%s\n' "$TJC_COLOR_GREEN" "$*" "$TJC_COLOR_RESET"
  return 0
}

# Public function: tjc_warn
# Usage: tjc_warn <message...>
# Description: Outputs a warning message in yellow to standard error.
# Returns: Exit code 0.
tjc_warn() {
  printf '%s%s%s\n' "$TJC_COLOR_YELLOW" "$*" "$TJC_COLOR_RESET" >&2
  return 0
}

# Public function: tjc_error
# Usage: tjc_error <message...>
# Description: Outputs an error message in red to standard error.
# Returns: Exit code 0.
tjc_error() {
  printf '%sError: %s%s\n' "$TJC_COLOR_RED" "$*" "$TJC_COLOR_RESET" >&2
  return 0
}
