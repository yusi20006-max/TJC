# TJC (Termux Jules CLI) v2.0.0

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

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
 +-- MCP Transport / Tool Boundary
 +-- Policy Engine
 +-- Observability / Audit
```

TJC v2 separates persistent execution state, orchestration, bounded parallelism, external API access, external-agent transport, authorization, and observability.

See [docs/ARCHITECTURE_V2.md](docs/ARCHITECTURE_V2.md).

## Documentation

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

## Core Commands

```sh
tjc workflow validate workflow.yml
tjc workflow run workflow.yml
tjc workflow resume report.json

tjc job list
tjc job show <id>

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

MCP mutation/execution remains policy-controlled and is denied by default unless the policy explicitly permits `mcp.execute`.

## Jules Provider

```sh
export TJC_PROVIDER=jules
export JULES_API_KEY='...'
```

Provider-specific HTTP behavior is isolated behind the Provider Layer. Never commit API keys.

## Installation

```sh
./install.sh
./uninstall.sh
```

The installer packages the complete v2 runtime tree, including workflow, Job, Queue, MCP, Policy, Provider, Scheduler, command, and shared-library modules.

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for platform setup.

## Release

Current version: **2.0.0**

See [CHANGELOG.md](CHANGELOG.md) and [AUDIT_REPORT.md](AUDIT_REPORT.md).
