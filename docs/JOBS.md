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

## Persistence and locking

Each Job is stored as one JSON document. Updates are written to a private temporary file and then moved into place so readers do not normally observe a partially written document.

Mutating operations acquire a per-Job lock under `.locks/`. Lock acquisition uses atomic directory creation. A lock records its owning process ID; if the recorded owner is no longer alive, the lock can be recovered automatically. Active locks are never removed solely because they are old.

The lock timeout is controlled by `TJC_JOB_LOCK_TIMEOUT` and defaults to five attempts. The timeout prevents a blocked command from waiting forever on an active owner.

## Recovery guarantees

The Job layer rejects invalid Job IDs and malformed JSON records instead of treating them as valid state. Tests cover stale-lock recovery, corrupted-record rejection, and persistence after atomic updates.

Cancellation changes the persisted lifecycle state. An executor is responsible for terminating the underlying process when it observes `CANCELLED`; the persistence layer deliberately does not kill arbitrary processes by itself.

## Security

Job records never intentionally contain API keys or authentication headers. Inputs used as Job IDs are validated before they are converted into filesystem paths. Private directory/file permissions are applied where supported.

## Architecture

The Job layer is intentionally independent of the CLI. Workflow, queue, scheduler, and provider components should use Job lifecycle functions rather than implementing their own persistent status model.

## Verification

The Job foundation includes the core lifecycle tests plus recovery-focused coverage in `test/test_jobs_recovery.sh`. The recovery suite verifies stale-lock recovery, rejection of corrupted records, and readability of records after atomic updates.

## Future Extensions

TJC v2 can build on this foundation with worker queues, execution backends, richer results/artifacts, concurrency control, and provider orchestration. Those capabilities remain separate from the persistence/lifecycle layer.
