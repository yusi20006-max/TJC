# TJC v2 Policy and Permission Engine

TJC v2 provides a central authorization layer for local CLI operations and external MCP access.

## Policy File

The default policy is stored at:

`~/.config/tjc/policy.yml`

Initialize or inspect it with:

```sh
tjc policy init
tjc policy show
```

Check an operation:

```sh
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

The Policy Engine is intentionally independent from providers and transport layers.

The most sensitive external-agent capabilities default to deny, especially:

- `mcp.execute`
- `plugin.execute`
- `filesystem.write`

Local TJC workflow/job/queue operations retain explicit allow entries so v1/v2 local behavior remains usable.

## Integration

The policy layer is enforced at command boundaries. MCP execution is additionally gated by policy before the MCP server is started.

Policy checks must occur before an operation starts, not after the operation has already acquired external resources.

## Security Rules

- Never treat an environment variable as an authorization override when policy denies an operation.
- Never allow a plugin or workflow to modify the policy file during its own execution.
- Keep provider credentials outside policy files.
- Validate the policy file before use.
- Deny unknown operations by default.

## Testing

Policy tests must cover allow, deny, malformed policy, missing policy, exact-operation precedence, and integration with workflow/queue/MCP boundaries.
