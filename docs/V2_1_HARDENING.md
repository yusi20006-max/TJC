# TJC v2.1 Hardening Plan

This document defines the consolidated hardening batch for TJC v2.1.

## Objectives

TJC v2.1 focuses on production reliability rather than adding unrelated user-facing features.

### Provider reliability

- bounded connection and request timeouts
- retry classification for transient failures
- exponential backoff with a maximum delay
- explicit handling of rate limiting
- pagination and polling guards
- cancellation-safe session lifecycle
- secret-safe diagnostics

### Job durability

- atomic state replacement
- stale-lock detection and recovery
- deterministic state transitions
- idempotent retry behavior
- crash recovery
- corrupted-state handling
- bounded recovery scans

### Plugin security

- explicit plugin manifest
- capability declarations
- policy authorization before execution
- no implicit shell execution
- deterministic plugin discovery
- validation before activation
- failure isolation

### Packaging

- complete runtime manifest
- staged installation
- safe upgrade behavior
- preservation of user configuration
- rollback on failed installation
- Termux/Linux compatibility

### Verification

The release gate must cover the complete runtime surface rather than only individual modules:

1. syntax validation
2. ShellCheck
3. unit tests
4. integration tests
5. crash/recovery tests
6. installer smoke test
7. policy/security tests
8. provider mock tests
9. MCP protocol tests
10. clean-install and upgrade verification

## Batch Strategy

The hardening work is intentionally grouped into large vertical slices. Each slice must leave the repository in a coherent state and include tests/documentation for the affected subsystem.

The final integration audit must not claim runtime verification that was not actually executed.
