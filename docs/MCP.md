# TJC MCP Server

TJC v2 includes a local Model Context Protocol server using stdio JSON-RPC transport.

## Architecture

```text
MCP Client
   |
   | JSON-RPC / stdio
   v
TJC MCP Server
   |
   +-- Provider Layer
   +-- Job System
   +-- Workflow Engine
   +-- Configuration
```

The MCP layer is a transport and tool adapter. It does not reimplement Job, Workflow, or Provider business logic.

## Start

Run:

```sh
tjc mcp serve
```

The server reads one JSON-RPC request per input line and writes JSON-RPC responses to stdout.

## Security Default

Mutation/execution tools are disabled by default.

For an explicitly trusted local integration, enable them with:

```sh
export TJC_MCP_ALLOW_EXECUTION=true
```

This setting is intentionally explicit and is not enabled automatically.

The server never returns `JULES_API_KEY` or private configuration data as tool output.

## Tools

The initial tool set includes:

- `tjc_list_sources`
- `tjc_create_session`
- `tjc_get_session`
- `tjc_list_activities`
- `tjc_create_job`
- `tjc_get_job`
- `tjc_cancel_job`
- `tjc_validate_workflow`
- `tjc_run_workflow`

Read-only tools can be used without execution permission. Mutating or execution tools require the explicit local execution flag.

## Protocol

Supported methods include:

- `initialize`
- `notifications/initialized`
- `tools/list`
- `tools/call`
- `ping`

Invalid methods and tool names return JSON-RPC errors instead of executing arbitrary commands.

## Input Boundaries

- Job IDs are strictly validated.
- Session IDs are strictly validated.
- Jules source identifiers must use the expected `sources/github/...` form.
- Workflow paths reject traversal and shell metacharacters.
- Only declared tool arguments are accepted by the tool schemas.
- There is no generic shell/exec MCP tool.

## Termux/Linux

The implementation uses POSIX shell, `jq`, and standard process/stdio facilities. It does not require root privileges, a network-facing daemon, or a separate MCP runtime.

## Testing

Run the MCP protocol tests with:

```sh
sh test/test_mcp.sh
```

The tests cover initialization, tool discovery, ping, and default mutation denial.
