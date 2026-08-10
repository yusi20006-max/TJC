#!/bin/sh

tjc_mcp_command() {
  ACTION="${1:-serve}"
  case "$ACTION" in
    serve)
      # shellcheck disable=SC1091
      . "${BASE_DIR}/mcp/server.sh"
      ;;
    *)
      tjc_error "Unknown MCP command: $ACTION"
      printf '%s\n' 'Usage: tjc mcp serve'
      return 1
      ;;
  esac
}
