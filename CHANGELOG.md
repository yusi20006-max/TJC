# Changelog

## 2.1.1

TJC v2.1.1 is the verified patch release following the v2.1 stability and production-hardening work.

### Release Corrections

- Aligned repository version metadata with the published v2.1.1 release.
- Updated README release/version references to 2.1.1.
- Added `yq` to the CI test dependencies so workflow YAML validation is exercised in the same environment as the repository tests.
- Preserved the existing v2.1.1 release tag as immutable.

### Verification

- Workflow, scheduler, queue, MCP, provider, plugin, policy, audit, and installer regression coverage remains part of the release test suite.
- Shell syntax checks and ShellCheck remain release gates.
- CI now provisions the YAML query dependency required by the workflow validator.

## 2.1.0

TJC v2.1 is the stability and production-hardening release following the v2 automation architecture.

### Stability

- Hardened Jules Provider HTTP behavior with bounded timeout and retry handling.
- Added provider error classification and secret-safe diagnostics.
- Improved persistent Job durability, locking, recovery, and crash handling.
- Added secure Plugin Runtime capability boundaries and policy integration.
- Hardened installation and packaging for complete runtime deployment and safer upgrades.
- Expanded release verification across the v2 subsystem boundaries.

### Security

- Provider credentials remain outside persistent Job, Workflow, audit, and documentation data.
- Plugin capabilities require explicit authorization.
- Workflow, MCP, filesystem, and Plugin execution remain policy-controlled.
- Unknown policy operations remain denied by default.
- Runtime state uses restrictive filesystem permissions and atomic state updates where required.

### Verification

- Added and expanded tests for Provider, Job recovery, Plugin security, Installer behavior, Policy, MCP, Queue, Workflow, and Audit boundaries.
- CI/release gates cover shell syntax and ShellCheck where the CI environment provides them.
- The final audit records any runtime verification that cannot be performed in a repository-only environment rather than claiming it was executed.

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

- Production Readiness Audit completed.
- High-performance daemonless Scheduler System.
- Secure workflow validation and secret masking.
- POSIX testing harness and ShellCheck compliance.
- Comprehensive installation, testing, development, workflow, scheduler, and plugin documentation.

## 0.1.0-dev

- Initial bootstrap structure
- CLI entrypoint and basic commands
- Install and uninstall scripts
- Base documentation and CI shellcheck workflow
