# TJC v2 Policy and Permission Engine

TJC v2 provides a central authorization layer for local CLI operations and external MCP access.

## Policy File

The default policy is stored at `~/.config/tjc/policy.yml`.

```sh
tjc policy init
tjc policy show
tjc policy check workflow.run
tjc policy check mcp.execute
```

## Configuration Format

```yaml
version: 1
defaults:
  default: deny
operations:
  workflow.validate: allow
  workflow.run: allow
  job.read: allow
  job.mutate: allow
  provider.read: allow
  provider.execute: allow
  queue.run: allow
  mcp.read: allow
  mcp.execute: deny
  filesystem.read: allow
  filesystem.write: deny
  plugin.execute: deny
```

Exact operation entries override the default. Unknown operations are denied.

## Security Boundary

The Policy Engine is independent from providers and transport layers. Sensitive external-agent capabilities default to deny, especially MCP execution, plugin execution, and filesystem writes.

Local CLI operations have explicit allow entries so existing TJC workflows, Jobs, and queues remain usable.

## Integration

Policy checks occur before execution. The MCP command translates the central policy decision into the MCP server execution boundary; an environment variable cannot override a policy denial.

## Rules

- Never allow a workflow or plugin to modify the policy file during its own execution.
- Never store credentials in policy files.
- Validate the policy file before use.
- Deny unknown operations by default.

## Testing

Policy tests cover restrictive defaults, explicit allow entries, explicit deny entries, and unknown operations.
