# TJC v2 Observability and Audit

TJC v2 exposes two complementary local observability layers:

- the existing human-oriented logger at `~/.config/tjc/logs/tjc.log`
- the structured audit stream at `~/.config/tjc/audit/events.jsonl`

## Structured Event Model

Audit events contain at minimum:

- `timestamp`
- `event`
- `correlation_id`

Callers may add non-sensitive metadata such as:

- `job_id`
- `workflow_id`
- `provider`
- `status`
- `duration`

## Correlation IDs

A process can provide `TJC_CORRELATION_ID`. When it is absent, TJC creates a process-scoped correlation identifier.

This allows related CLI/MCP activity to be grouped without storing secrets.

## Security

Audit files are created with restrictive permissions. Sensitive fields containing names such as `key`, `token`, `secret`, `password`, or `authorization` are replaced with `[REDACTED]` before persistence.

API keys and authentication headers must never be passed as ordinary audit metadata.

## CLI

Inspect structured events:

```sh
tjc audit list
```

Inspect the most recent events:

```sh
tjc audit tail 50
```

Inspect the human-oriented log:

```sh
tjc logs tail 50
```

## Storage

The implementation uses JSON Lines and ordinary filesystem operations. No database service is required.

## Development

Every new subsystem should emit meaningful lifecycle events while keeping sensitive values outside the event payload. Correlation IDs should be propagated across nested operations where possible.
