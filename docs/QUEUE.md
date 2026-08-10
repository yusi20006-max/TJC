# TJC v2 Queue and Workers

TJC v2 provides a lightweight persistent queue for workflow Jobs. It is designed for Termux/Linux and does not require a permanent daemon, root access, Redis, or another external queue service.

## Model

```text
Queue Item
   |
   v
Persistent item record
   |
   +--> priority ordering
   |
   +--> atomic claim lock
   |
   v
Worker
   |
   v
TJC Job + Workflow Engine
```

Queue items are stored below `~/.config/tjc/queue/` with restrictive permissions.

## Commands

Queue a workflow:

```sh
tjc queue add workflow.yml 100
```

Optional explicit queue ID:

```sh
tjc queue add workflow.yml 100 nightly_review
```

List queue items:

```sh
tjc queue list
```

Remove a queued item:

```sh
tjc queue remove nightly_review
```

Run workers:

```sh
tjc queue run 2
```

The default worker count is 2 and can be configured with `TJC_MAX_WORKERS`.

## Priority

Higher numeric priority runs first. Priority is bounded from 0 to 1000. Equal priorities use creation time for deterministic ordering.

## Concurrency and Locking

Workers claim an item using an atomic directory creation lock. Only the worker that successfully creates the lock can transition the queue item from `QUEUED` to `RUNNING`.

The underlying Job System also maintains its own Job-level locking and lifecycle state.

The worker limit is bounded to 16. This prevents accidental process explosions on small Termux devices.

## Graceful Shutdown

The worker coordinator installs signal handlers for `INT`, `TERM`, and `HUP`. Active worker processes are signalled before the coordinator exits.

Queue state is persistent, so unclaimed `QUEUED` work remains available for a later invocation.

## Failure Handling

A workflow failure marks the queue item and its associated Job as `FAILED`. Workflow-level retry policies remain controlled by the Workflow Engine rather than being duplicated in the Queue.

## Security

Queue records contain workflow paths and Job metadata, not credentials. Arbitrary shell commands are never accepted as queue payloads.

Workflow validation remains the final execution boundary.

## Compatibility

The queue uses POSIX shell primitives, filesystem persistence, and bounded child processes. It is intended to work on Termux and standard Linux without root privileges or a background service.
