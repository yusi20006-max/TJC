# TJC (Termux Jules CLI)

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

---

## Documentation Directory

- **[Installation Guide](docs/INSTALLATION.md)**
- **[Workflow Engine](docs/WORKFLOWS.md)**
- **[Job System](docs/JOBS.md)**
- **[Queue and Workers](docs/QUEUE.md)**
- **[Provider Architecture](docs/PROVIDERS.md)**
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
 +-- Future MCP / Policy / Observability layers
```

The Job System provides persistent lifecycle tracking for long-running operations. The Workflow Engine uses it as the execution abstraction. The Queue provides bounded parallel workers for independent workflow Jobs. Provider-specific HTTP behavior is isolated behind the Provider Layer.

## Workflow Engine v2

Workflows are declarative YAML/JSON definitions. They are validated before execution and never expose a generic shell execution primitive.

Supported capabilities include dependency-aware steps, conditions, bounded retries, bounded timeouts, variables, structured reports, resume, and Job integration.

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

Queue a validated workflow with an optional priority:

```sh
tjc queue add workflow.yml 100
```

Inspect or remove queued work:

```sh
tjc queue list
tjc queue remove <id>
```

Run a bounded worker pool:

```sh
tjc queue run 2
```

The worker limit is conservative by default and cannot exceed 16.

See [docs/QUEUE.md](docs/QUEUE.md).

## Provider Layer

Jules is the default provider. Provider-specific authentication and HTTP operations are isolated from the Job and Workflow domains.

```sh
export TJC_PROVIDER=jules
export JULES_API_KEY='...'
```

See [docs/PROVIDERS.md](docs/PROVIDERS.md).

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
