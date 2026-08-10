# TJC v2.1 Execution Plan

This document consolidates the remaining hardening work into larger implementation batches.

## Batch A — Runtime and API Reliability

- Jules provider timeout and retry policy
- HTTP error classification
- session polling and cancellation
- pagination handling
- credential redaction
- integration tests

## Batch B — Durable Execution

- crash-safe Job transitions
- stale-lock recovery
- atomic state replacement
- corrupted-state handling
- idempotent retry semantics
- queue recovery after interrupted workers
- fault-injection tests

## Batch C — Extension Security

- plugin discovery and lifecycle
- explicit capability declarations
- Policy Engine integration
- plugin validation
- safe loading and failure isolation
- plugin security tests

## Batch D — Packaging and Release

- staged installer
- upgrade detection
- rollback path
- manifest verification
- preservation of user configuration
- Termux/Linux smoke tests

## Batch E — Final Release Gate

- complete test suite
- ShellCheck
- integration audit
- security review
- documentation consistency
- version/changelog verification
- release artifact verification

The batches should be executed without requiring interactive approval between them. A batch stops only for a genuine blocker that risks data loss, security, or an invalid release.