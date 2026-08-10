#!/bin/sh
set -eu

BASE_DIR=$(pwd)
export BASE_DIR
export TJC_CONFIG_DIR=$(mktemp -d)

INPUT=$(cat <<'EOF'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"ping","params":{}}
EOF
)

OUTPUT=$(printf '%s\n' "$INPUT" | sh "$BASE_DIR/mcp/server.sh")

printf '%s\n' "$OUTPUT" | sed -n '1p' | jq -e '.result.serverInfo.name == "tjc-mcp"' >/dev/null
printf '%s\n' "$OUTPUT" | sed -n '2p' | jq -e '.result.tools | length >= 9' >/dev/null
printf '%s\n' "$OUTPUT" | sed -n '3p' | jq -e '.result == {}' >/dev/null

# Execution must be denied unless explicitly enabled.
REQ='{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"tjc_create_job","arguments":{"id":"mcp_test"}}}'
set +e
DENIED=$(printf '%s\n' "$REQ" | sh "$BASE_DIR/mcp/server.sh")
CODE=$?
set -e
[ "$CODE" -eq 0 ]
printf '%s\n' "$DENIED" | jq -e '.error.code == -32003' >/dev/null

rm -rf "$TJC_CONFIG_DIR"
echo 'MCP tests: passed'
