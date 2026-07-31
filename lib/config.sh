#!/bin/sh

tjc_config_dir() {
  if [ -n "${TJC_CONFIG_DIR:-}" ]; then
    printf '%s\n' "$TJC_CONFIG_DIR"
  else
    printf '%s\n' "${HOME}/.config/tjc"
  fi
}

tjc_default_config_template() {
  printf '%s/config/default.conf\n' "$1"
}
