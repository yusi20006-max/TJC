# TJC (Termux Jules CLI) v2.1.2

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

## Stability Release

**Current version: 2.1.2**

TJC v2.1.2 is the corrective patch release following the verified v2.1.1 release. It preserves the v2.1 stability and production-hardening baseline while making the repository, installer, and release metadata consistent with the released version line.

## Architecture

```text
CLI
 |
 +-- Configuration / Authentication
 +-- Job System
 |     +-- Workflow Engine
 |     +-- Scheduler
 |     +-- Queue / Workers
 +-- Provider Layer
 |     +-- Jules
 |     +-- Future Providers
 +-- Plugin Runtime
 |     +-- Manifest
 |     +-- Capabilities
 |     +-- Policy
 +-- MCP Transport / Tool Boundary
 +-- Policy Engine
 +-- Observability / Audit
```

TJC separates persistent execution state, orchestration, bounded parallelism, external API access, extension capabilities, external-agent transport, authorization, and observability.

## Core Commands

```sh
tjc workflow validate workflow.yml
tjc workflow run workflow.yml
tjc workflow resume report.json

tjc job list
tjc job show <id>
tjc job status <id>

tjc queue add workflow.yml 100
tjc queue list
tjc queue run 2

tjc mcp serve
tjc policy show
tjc policy check mcp.execute

tjc audit list
tjc audit tail 50
tjc logs tail 50
```

MCP mutation/execution is policy-controlled and denied by default unless the policy explicitly permits `mcp.execute`.

## Jules Provider

```sh
export TJC_PROVIDER=jules
export JULES_API_KEY='...'
```

Provider HTTP behavior is isolated behind the Provider Layer. Credentials must never be committed or persisted in Job, Workflow, audit, or documentation data.

## Installation

```sh
./install.sh
./uninstall.sh
```

The installer packages the complete runtime tree. See [docs/INSTALLATION.md](docs/INSTALLATION.md).

## Documentation

- [Architecture](docs/ARCHITECTURE_V2.md)
- [Installation](docs/INSTALLATION.md)
- [Workflows](docs/WORKFLOWS.md)
- [Jobs](docs/JOBS.md)
- [Queue](docs/QUEUE.md)
- [Providers](docs/PROVIDERS.md)
- [MCP](docs/MCP.md)
- [Policies](docs/POLICIES.md)
- [Observability](docs/OBSERVABILITY.md)
- [Scheduler](docs/SCHEDULER.md)
- [Plugins](docs/PLUGINS.md)
- [Testing](docs/TESTING.md)
- [Development](docs/DEVELOPMENT.md)
- [v2.1 Hardening](docs/V2_1_HARDENING.md)
- [Audit Report](AUDIT_REPORT.md)

## Release

Current version: **2.1.2**

See [CHANGELOG.md](CHANGELOG.md) for the complete release history.
