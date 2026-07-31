#!/bin/sh

tjc_info() {
  printf '%s%s%s\n' "$TJC_COLOR_BLUE" "$*" "$TJC_COLOR_RESET"
}

tjc_success() {
  printf '%s%s%s\n' "$TJC_COLOR_GREEN" "$*" "$TJC_COLOR_RESET"
}

tjc_warn() {
  printf '%s%s%s\n' "$TJC_COLOR_YELLOW" "$*" "$TJC_COLOR_RESET" >&2
}

tjc_error() {
  printf '%sError: %s%s\n' "$TJC_COLOR_RED" "$*" "$TJC_COLOR_RESET" >&2
}
