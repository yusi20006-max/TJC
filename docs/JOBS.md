# TJC Job System

The TJC Job System provides a persistent lifecycle abstraction for long-running operations.

## Storage

Jobs are stored below:

`$TJC_CONFIG_DIR/jobs/`

or, when `TJC_CONFIG_DIR` is not configured:

`$HOME/.config/tjc/jobs/`

The directory is restricted to the current user and individual Job records are written with private permissions.

## States

A Job may use these states:

- `PENDING` — created but not queued.
- `QUEUED` — ready for an executor.
- `RUNNING` — currently executing.
- `COMPLETED` — completed successfully.
- `FAILED` — execution failed.
- `CANCELLED` — execution was cancelled.
- `RETRYING` — transitioning from failure back toward execution.

Valid transitions are deliberately restricted so callers cannot silently corrupt lifecycle state.

## CLI

```text
tjc job create <id> [description]
tjc job list
tjc job show <id>
tjc job status <id>
tjc job cancel <id>
tjc job retry <id>
```

Job IDs are limited to safe ASCII letters, numbers, `_`, and `-`, beginning with an alphanumeric character.

## Security

Job records never intentionally contain API keys or authentication headers. Inputs used as Job IDs are validated before they are converted into filesystem paths. Writes use a temporary private file followed by an atomic rename to reduce the chance of partially written JSON records.

## Architecture

The Job layer is intentionally independent of the CLI. Future workflow, queue, scheduler, and provider components should use Job lifecycle functions rather than implementing their own persistent status model.

## Future Extensions

TJC v2 can build on this foundation with worker queues, execution backends, richer results/artifacts, concurrency control, and provider orchestration. Those capabilities are intentionally outside this foundation implementation.
