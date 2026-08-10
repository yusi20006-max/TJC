# Changelog

## 2.0.0

TJC v2 introduces the production architecture for persistent automation and external-agent integration.

### Execution Architecture

- Persistent Job System with lifecycle states, locking, retries, cancellation, results, and history.
- Advanced Workflow Engine with dependency validation, conditions, bounded retries/timeouts, variables, structured reports, and resume.
- Persistent priority Queue with bounded worker execution and atomic claims.
- Scheduler remains compatible with the daemonless Termux/Linux execution model.

### Provider Architecture

- Provider-neutral abstraction layer.
- Jules provider adapter with `X-Goog-Api-Key` authentication and bounded HTTP retry behavior.
- Provider-specific HTTP details isolated from workflow/job domains.

### MCP

- Local stdio JSON-RPC MCP server.
- Tool discovery, provider/session access, Job operations, and Workflow operations.
- Explicit execution boundary with no generic shell/exec tool.

### Security and Policy

- Central human-readable Policy Engine.
- Unknown operations denied by default.
- MCP execution, plugin execution, and filesystem writes are restrictive by default.
- Workflow, Queue, and Job command boundaries enforce policy decisions.
- Structured audit events redact sensitive field names before persistence.

### Observability

- Correlation IDs.
- JSONL audit stream.
- `tjc audit` and `tjc logs` inspection commands.
- Restrictive audit storage permissions.

### Documentation and Testing

- Added architecture documentation for Jobs, Queue, Providers, MCP, Observability, and Policies.
- Added dedicated tests for v2 workflow, Job, Queue, MCP, Provider, Audit, and Policy components.

## 1.0.0

- Production Readiness Audit completed, ensuring 100% production-readiness.
- High-performance, daemonless design with non-daemon Scheduler System running via a 'run-pending' pull model.
- Decoupled Workflow Engine supporting YAML/JSON execution plans, sequential steps, and detailed report tracking.
- Secure design with API secret masking, strict validation of alphanumeric and file path patterns to prevent command injection, and secure folder permissions (700 and 600).
- Standardized Shell/POSIX shared libraries (`lib/`) for config, logging, terminal colors, and checks.
- Comprehensive POSIX testing harness with automated suites (`test_workflows.sh` and `test_scheduler.sh`) running in isolated environments.
- 100% ShellCheck compliance across all project scripts.
- Exhaustive documentation updates including new manuals for installation, testing, development, workflows, scheduler, and plugins.

## 0.1.0-dev

- Initial bootstrap structure
- CLI entrypoint and basic commands
- Install and uninstall scripts
- Base documentation and CI shellcheck workflow
