# TJC (Termux Jules CLI)

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

---

## Documentation Directory

- **[Installation Guide](docs/INSTALLATION.md)**
- **[Workflow Engine](docs/WORKFLOWS.md)**
- **[Job System](docs/JOBS.md)**
- **[Queue and Workers](docs/QUEUE.md)**
- **[Provider Architecture](docs/PROVIDERS.md)**
- **[MCP Server](docs/MCP.md)**
- **[Scheduler System](docs/SCHEDULER.md)**
- **[Plugin System](docs/PLUGINS.md)**
- **[Testing Guide](docs/TESTING.md)**
- **[Development Manual](docs/DEVELOPMENT.md)**

---

## TJC v2 Architecture

```text
CLI
 |
 +-- Configuration / Authentication
 |
 +-- Job System
 |     |
 |     +-- Workflow Engine
 |     +-- Scheduler
 |     +-- Queue / Workers
 |
 +-- Provider Layer
 |     |
 |     +-- Jules
 |     +-- Future Providers
 |
 +-- MCP Transport
 |     |
 |     +-- Tool Boundary
 |     +-- Security Boundary
 |
 +-- Future Policy / Observability layers
```

TJC v2 uses the Job System for persistent long-running state, the Workflow Engine for safe orchestration, the Queue for bounded parallel execution, the Provider Layer for external API isolation, and MCP as a controlled external-agent interface.

## Workflow Engine v2

Workflows are declarative YAML/JSON definitions validated before execution. They support dependencies, conditions, bounded retries/timeouts, variables, structured reports, resume, and Job integration.

```sh
tjc workflow validate workflow.yml
tjc workflow run workflow.yml
tjc workflow list
tjc workflow show report.json
tjc workflow resume report.json
```

See [docs/WORKFLOWS.md](docs/WORKFLOWS.md).

## Job System

```sh
tjc job create <id> [description]
tjc job list
tjc job show <id>
tjc job status <id>
tjc job cancel <id>
tjc job retry <id>
```

See [docs/JOBS.md](docs/JOBS.md).

## Queue and Workers

```sh
tjc queue add workflow.yml 100
tjc queue list
tjc queue remove <id>
tjc queue run 2
```

The worker pool is bounded to 16 and defaults to 2. See [docs/QUEUE.md](docs/QUEUE.md).

## Provider Layer

Jules is the default provider. Provider-specific authentication and HTTP operations are isolated from the Job and Workflow domains.

```sh
export TJC_PROVIDER=jules
export JULES_API_KEY='...'
```

See [docs/PROVIDERS.md](docs/PROVIDERS.md).

## MCP Server

Run the local stdio MCP server with:

```sh
tjc mcp serve
```

Mutation/execution tools are disabled by default. An explicitly trusted local integration can enable them with:

```sh
export TJC_MCP_ALLOW_EXECUTION=true
```

There is no generic shell/exec MCP tool. See [docs/MCP.md](docs/MCP.md).

## Scheduler System

```sh
tjc schedule add <id> <workflow_file.yml> [expr]
tjc schedule list
tjc schedule remove <id>
tjc schedule run [id]
tjc schedule run-pending
tjc schedule history <id>
```

See [docs/SCHEDULER.md](docs/SCHEDULER.md).

## Foundation Commands

```sh
tjc help
tjc version
```

## Installation

```sh
./install.sh
./uninstall.sh
```

For platform setup and troubleshooting see [docs/INSTALLATION.md](docs/INSTALLATION.md).
