#!/bin/sh
# shellcheck disable=SC1091
. "${BASE_DIR}/plugin/manager.sh"

tjc_plugin_command() {
  ACTION="${1:-list}"
  case "$ACTION" in
    list) tjc_plugin_list ;;
    show)
      NAME="${2:-}"; [ -n "$NAME" ] || { tjc_error 'Usage: tjc plugin show <name>'; return 1; }
      tjc_plugin_show "$NAME" ;;
      ;;
    install)
      SRC="${2:-}"; [ -n "$SRC" ] || { tjc_error 'Usage: tjc plugin install <directory>'; return 1; }
      tjc_plugin_install_local "$SRC" ;
      ;;
    run)
      NAME="${2:-}"; [ -n "$NAME" ] || { tjc_error 'Usage: tjc plugin run <name> [args...]'; return 1; }
      shift 2
      tjc_plugin_run "$NAME" "$@" ;
      ;;
    *)
      tjc_error 'Usage: tjc plugin [list|show <name>|install <directory>|run <name> [args...]]'
      return 1
      ;;
  esac
}
