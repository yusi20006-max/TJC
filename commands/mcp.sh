#!/bin/sh
# shellcheck disable=SC1091
. "${BASE_DIR}/policy/policy.sh"

tjc_mcp_command() {
  ACTION="${1:-serve}"
  case "$ACTION" in
    serve)
      # Policy is authoritative for MCP execution. The server's legacy env flag
      # remains a compatibility detail but cannot override a policy denial.
      if tjc_policy_allow mcp.execute; then export TJC_MCP_ALLOW_EXECUTION=true; else export TJC_MCP_ALLOW_EXECUTION=false; fi
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
