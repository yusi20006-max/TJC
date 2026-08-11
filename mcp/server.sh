#!/bin/sh

# TJC local MCP server (stdio JSON-RPC transport).
# shellcheck disable=SC1091
. "${BASE_DIR}/lib/provider.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/job/jobs.sh"
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/engine.sh"

mcp_response() {
  ID="${1:-null}"; RESULT="${2:-null}"
  jq -cn --argjson id "$ID" --argjson result "$RESULT" '{jsonrpc:"2.0",id:$id,result:$result}'
}

mcp_error() {
  ID="${1:-null}"; CODE="$2"; MESSAGE="$3"
  jq -cn --argjson id "$ID" --argjson code "$CODE" --arg message "$MESSAGE" '{jsonrpc:"2.0",id:$id,error:{code:$code,message:$message}}'
}

mcp_allowed_execution() { [ "${TJC_MCP_ALLOW_EXECUTION:-false}" = true ]; }

mcp_validate_path() {
  PATH_VALUE="${1:-}"
  [ -n "$PATH_VALUE" ] || return 1
  case "$PATH_VALUE" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) return 1;; esac
  [ -f "$PATH_VALUE" ]
}

mcp_tool_list() {
  jq -cn '{tools:[
    {name:"tjc_list_sources",description:"List sources connected to the configured provider.",inputSchema:{type:"object",properties:{},additionalProperties:false}},
    {name:"tjc_create_session",description:"Create a provider session. Execution permission is required.",inputSchema:{type:"object",properties:{prompt:{type:"string"},source:{type:"string"},branch:{type:"string"},title:{type:"string"}},required:["prompt","source"],additionalProperties:false}},
    {name:"tjc_get_session",description:"Inspect a provider session.",inputSchema:{type:"object",properties:{session_id:{type:"string"}},required:["session_id"],additionalProperties:false}},
    {name:"tjc_list_activities",description:"List activities for a provider session.",inputSchema:{type:"object",properties:{session_id:{type:"string"}},required:["session_id"],additionalProperties:false}},
    {name:"tjc_create_job",description:"Create a persistent TJC Job. Execution permission is required.",inputSchema:{type:"object",properties:{id:{type:"string"},description:{type:"string"}},required:["id"],additionalProperties:false}},
    {name:"tjc_get_job",description:"Inspect a persistent TJC Job.",inputSchema:{type:"object",properties:{id:{type:"string"}},required:["id"],additionalProperties:false}},
    {name:"tjc_cancel_job",description:"Cancel a TJC Job. Execution permission is required.",inputSchema:{type:"object",properties:{id:{type:"string"}},required:["id"],additionalProperties:false}},
    {name:"tjc_validate_workflow",description:"Validate a local workflow definition.",inputSchema:{type:"object",properties:{path:{type:"string"}},required:["path"],additionalProperties:false}},
    {name:"tjc_run_workflow",description:"Run a local workflow. Execution permission is required.",inputSchema:{type:"object",properties:{path:{type:"string"}},required:["path"],additionalProperties:false}}
  ]}'
}

mcp_call_tool() {
  ID="$1"; NAME="$2"; ARGS="$3"
  case "$NAME" in
    tjc_list_sources)
      tjc_provider_load || { mcp_error "$ID" -32001 'Provider initialization failed.'; return; }
      RESULT=$(tjc_provider_list_sources 2>&1) || { mcp_error "$ID" -32002 "$RESULT"; return; }
      mcp_response "$ID" "$(jq -cn --arg text "$RESULT" '{content:[{type:"text",text:$text}]}')" ;;
    tjc_create_session)
      mcp_allowed_execution || { mcp_error "$ID" -32003 'Execution tools are disabled. Set TJC_MCP_ALLOW_EXECUTION=true for an explicitly trusted local server.'; return; }
      PROMPT=$(echo "$ARGS" | jq -r '.prompt // empty'); SOURCE=$(echo "$ARGS" | jq -r '.source // empty'); BRANCH=$(echo "$ARGS" | jq -r '.branch // "main"'); TITLE=$(echo "$ARGS" | jq -r '.title // "TJC MCP Session"')
      [ -n "$PROMPT" ] && [ -n "$SOURCE" ] || { mcp_error "$ID" -32602 'prompt and source are required.'; return; }
      case "$SOURCE" in sources/github/*) ;; *) mcp_error "$ID" -32602 'source must be a Jules source identifier.'; return;; esac
      BODY=$(jq -cn --arg prompt "$PROMPT" --arg source "$SOURCE" --arg branch "$BRANCH" --arg title "$TITLE" '{prompt:$prompt,sourceContext:{source:$source,githubRepoContext:{startingBranch:$branch}},automationMode:"AUTO_CREATE_PR",title:$title}')
      tjc_provider_load || { mcp_error "$ID" -32001 'Provider initialization failed.'; return; }
      RESULT=$(tjc_provider_create_session "$BODY" 2>&1) || { mcp_error "$ID" -32002 "$RESULT"; return; }
      mcp_response "$ID" "$(jq -cn --arg text "$RESULT" '{content:[{type:"text",text:$text}]}')" ;;
    tjc_get_session|tjc_list_activities)
      SESSION=$(echo "$ARGS" | jq -r '.session_id // empty')
      echo "$SESSION" | grep -Eq '^[A-Za-z0-9._:-]{1,200}$' || { mcp_error "$ID" -32602 'Invalid session_id.'; return; }
      tjc_provider_load || { mcp_error "$ID" -32001 'Provider initialization failed.'; return; }
      if [ "$NAME" = tjc_get_session ]; then RESULT=$(tjc_provider_get_session "$SESSION" 2>&1); else RESULT=$(tjc_provider_list_activities "$SESSION" 2>&1); fi
      CODE=$?; [ "$CODE" -eq 0 ] || { mcp_error "$ID" -32002 "$RESULT"; return; }
      mcp_response "$ID" "$(jq -cn --arg text "$RESULT" '{content:[{type:"text",text:$text}]}')" ;;
    tjc_create_job)
      mcp_allowed_execution || { mcp_error "$ID" -32003 'Execution tools are disabled.'; return; }
      JOB_ID=$(echo "$ARGS" | jq -r '.id // empty'); DESC=$(echo "$ARGS" | jq -r '.description // "MCP Job"')
      echo "$JOB_ID" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' || { mcp_error "$ID" -32602 'Invalid Job ID.'; return; }
      tjc_job_create "$JOB_ID" "$DESC" >/dev/null 2>&1 || { mcp_error "$ID" -32004 'Unable to create Job.'; return; }
      mcp_response "$ID" '{"content":[{"type":"text","text":"Job created."}]}' ;;
    tjc_get_job)
      JOB_ID=$(echo "$ARGS" | jq -r '.id // empty'); echo "$JOB_ID" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' || { mcp_error "$ID" -32602 'Invalid Job ID.'; return; }
      RESULT=$(tjc_job_get "$JOB_ID" 2>&1) || { mcp_error "$ID" -32004 'Job not found.'; return; }
      mcp_response "$ID" "$(jq -cn --arg text "$RESULT" '{content:[{type:"text",text:$text}]}')" ;;
    tjc_cancel_job)
      mcp_allowed_execution || { mcp_error "$ID" -32003 'Execution tools are disabled.'; return; }
      JOB_ID=$(echo "$ARGS" | jq -r '.id // empty'); echo "$JOB_ID" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' || { mcp_error "$ID" -32602 'Invalid Job ID.'; return; }
      tjc_job_cancel "$JOB_ID" >/dev/null 2>&1 || { mcp_error "$ID" -32004 'Unable to cancel Job.'; return; }
      mcp_response "$ID" '{"content":[{"type":"text","text":"Job cancelled."}]}' ;;
    tjc_validate_workflow)
      PATH_VALUE=$(echo "$ARGS" | jq -r '.path // empty'); mcp_validate_path "$PATH_VALUE" || { mcp_error "$ID" -32602 'Invalid or inaccessible workflow path.'; return; }
      tjc_workflow_validate "$PATH_VALUE" >/dev/null 2>&1 || { mcp_error "$ID" -32602 'Workflow validation failed.'; return; }
      mcp_response "$ID" '{"content":[{"type":"text","text":"Workflow is valid."}]}' ;;
    tjc_run_workflow)
      mcp_allowed_execution || { mcp_error "$ID" -32003 'Execution tools are disabled.'; return; }
      PATH_VALUE=$(echo "$ARGS" | jq -r '.path // empty'); mcp_validate_path "$PATH_VALUE" || { mcp_error "$ID" -32602 'Invalid or inaccessible workflow path.'; return; }
      RESULT=$(tjc_workflow_execute "$PATH_VALUE" 2>&1); CODE=$?
      [ "$CODE" -eq 0 ] || { mcp_error "$ID" -32005 "$RESULT"; return; }
      mcp_response "$ID" "$(jq -cn --arg text "$RESULT" '{content:[{type:"text",text:$text}]}')" ;;
    *) mcp_error "$ID" -32601 "Unknown tool: $NAME" ;;
  esac
}

mcp_handle() {
  REQUEST="$1"; ID=$(echo "$REQUEST" | jq -c '.id // null'); METHOD=$(echo "$REQUEST" | jq -r '.method // empty')
  case "$METHOD" in
    initialize)
      mcp_response "$ID" '{"protocolVersion":"2025-06-18","capabilities":{"tools":{}},"serverInfo":{"name":"tjc-mcp","version":"2.0.0"}}' ;;
    notifications/initialized) : ;;
    tools/list) mcp_response "$ID" "$(mcp_tool_list)" ;;
    tools/call)
      NAME=$(echo "$REQUEST" | jq -r '.params.name // empty'); ARGS=$(echo "$REQUEST" | jq -c '.params.arguments // {}')
      mcp_call_tool "$ID" "$NAME" "$ARGS" ;;
    ping) mcp_response "$ID" '{}' ;;
    *) [ "$ID" = null ] || mcp_error "$ID" -32601 "Unknown method: $METHOD" ;;
  esac
}

while IFS= read -r LINE; do
  [ -n "$LINE" ] || continue
  mcp_handle "$LINE"
done
