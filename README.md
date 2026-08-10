# TJC (Termux Jules CLI)

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

## TJC v2 Architecture

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
 +-- Observability / Audit
 +-- Future Policy Layer
```

TJC v2 separates persistent Jobs, safe Workflow orchestration, bounded Queue workers, external Provider APIs, MCP transport, and observability/security concerns.

## Documentation

- [Installation](docs/INSTALLATION.md)
- [Workflows](docs/WORKFLOWS.md)
- [Jobs](docs/JOBS.md)
- [Queue](docs/QUEUE.md)
- [Providers](docs/PROVIDERS.md)
- [MCP](docs/MCP.md)
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

tjc audit list
tjc audit tail 50
tjc logs tail 50
```

Mutation/execution through MCP is disabled by default and requires an explicit local configuration flag.

## Installation

```sh
./install.sh
./uninstall.sh
```

See [docs/INSTALLATION.md](docs/INSTALLATION.md) for platform setup.
