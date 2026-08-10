# TJC v2 Architecture

## System Overview

```text
                           +------------------+
                           |    TJC CLI       |
                           +--------+---------+
                                    |
          +-------------------------+-------------------------+
          |                         |                         |
          v                         v                         v
   Workflow Engine            Job System                 Scheduler
          |                         |                         |
          +------------+------------+-------------------------+
                       |
                       v
                Queue / Workers
                       |
                       v
                 Provider Layer
                       |
                       v
                     Jules

External AI Agents
        |
        v
   MCP stdio server
        |
        +---- Policy Engine
        |
        +---- TJC internal APIs

Cross-cutting:
  Configuration / Authentication
  Logging / Audit / Correlation IDs
  Security validation
```

## Core Boundaries

### CLI

The CLI is a dispatch layer. Business logic belongs in reusable modules rather than command handlers.

### Job System

Jobs provide persistent lifecycle state for long-running operations. Job storage uses restrictive filesystem permissions, atomic writes, and per-Job locks.

### Workflow Engine

Workflows are declarative execution plans. The validator establishes the safety boundary before execution. The engine handles dependencies, conditions, retries, timeouts, reports, and resume.

### Queue

The Queue schedules workflow Jobs for bounded parallel execution. Queue claims use filesystem locks so multiple workers cannot claim the same item simultaneously.

### Provider Layer

Provider-specific HTTP and authentication are isolated behind a provider adapter. Jules is the current implementation.

### MCP

The MCP server exposes a controlled set of TJC capabilities over local stdio JSON-RPC. It never exposes arbitrary shell execution.

### Policy

The Policy Engine is the authorization boundary. Unknown operations are denied by default. MCP execution, plugin execution, and filesystem writes are intentionally restrictive by default.

### Observability

Human-readable logs and structured audit events are separate. Audit events use correlation IDs and redact sensitive field names before persistence.

## Data and State

Persistent state lives under the configured TJC directory, normally:

`~/.config/tjc/`

Major state areas:

```text
jobs/
queue/
workflows/reports/
schedules/
logs/
audit/
policy.yml
```

Sensitive files use restrictive permissions.

## Security Model

The security model is defense in depth:

1. CLI input validation.
2. Workflow schema validation.
3. Provider isolation.
4. Policy authorization.
5. Job/queue locking.
6. Restricted state permissions.
7. Secret redaction.
8. No arbitrary shell execution in workflows or MCP.

## Compatibility

TJC remains POSIX-shell based and targets:

- Android Termux
- standard Linux

No root privileges or permanent daemon are required for the core automation architecture.

## Extension Strategy

Future v2 work should extend interfaces rather than bypass them:

- new providers implement the Provider boundary
- new execution modes use Jobs
- parallel execution uses Queue/Workers
- external agents use MCP
- authorization uses Policy
- diagnostics use Observability

This prevents provider-specific or transport-specific code from spreading through the core domain.
