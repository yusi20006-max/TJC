# TJC (Termux Jules CLI)

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, compatible with standard Linux and Android via Termux.

---

## Documentation Directory

- **[Installation Guide](docs/INSTALLATION.md)**
- **[Workflow Engine](docs/WORKFLOWS.md)**
- **[Job System](docs/JOBS.md)**
- **[Scheduler System](docs/SCHEDULER.md)**
- **[Plugin System](docs/PLUGINS.md)**
- **[Testing Guide](docs/TESTING.md)**
- **[Development Manual](docs/DEVELOPMENT.md)**

---

## TJC v2 Architecture

TJC v2 introduces a unified execution model:

```text
CLI
 |
 +-- Configuration / Authentication
 |
 +-- Job System
 |     |
 |     +-- Workflow Engine
 |     +-- Scheduler
 |     +-- Future Queue / Workers
 |
 +-- Provider Layer
 |     |
 |     +-- Jules
 |     +-- Future Providers
 |
 +-- Future MCP / Policy / Observability layers
```

The Job System provides persistent lifecycle tracking for long-running operations. The Workflow Engine uses it as the execution abstraction while retaining the safe v1 step boundary.

## Workflow Engine v2

Workflows are declarative YAML/JSON definitions. They are validated before execution and never expose a generic shell execution primitive.

Supported v2 capabilities include:

- dependency-aware steps
- conditional execution
- bounded retries
- bounded timeouts
- workflow variables
- structured execution reports
- resume from a previous report
- Job System integration

Example:

```yaml
name: "Production Review"
variables:
  environment: production
steps:
  - type: doctor
  - type: list_activities
    depends_on: [0]
    condition: "var:environment=production"
    retry:
      attempts: 2
    timeout:
      seconds: 30
  - type: get_pr
    pr_number: 23
    depends_on: [1]
```

Commands:

```sh
tjc workflow validate workflow.yml
tjc workflow run workflow.yml
tjc workflow list
tjc workflow show report.json
tjc workflow resume report.json
```

See [docs/WORKFLOWS.md](docs/WORKFLOWS.md) for the complete schema and security model.

## Job System

The Job System provides persistent state for long-running operations.

Supported states:

`PENDING` → `QUEUED` → `RUNNING` → `COMPLETED`

with failure, cancellation, and retry paths.

Commands include:

```sh
tjc job create <id> [description]
tjc job list
tjc job show <id>
tjc job status <id>
tjc job cancel <id>
tjc job retry <id>
```

See [docs/JOBS.md](docs/JOBS.md).

## Scheduler System

Persistently configure and run TJC workflows on schedules without requiring a memory-heavy permanent daemon.

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
