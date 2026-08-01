# TJC (Termux Jules CLI)

TJC is a secure, POSIX-shell-based CLI platform for Google Jules API workflows, fully compatible with standard Linux and Android via Termux.

---

## Documentation Directory

Explore the complete TJC production manual:
- **[Installation & Prerequisites Guide](docs/INSTALLATION.md)** — Comprehensive installation and platform troubleshooting.
- **[Workflow Engine Manual](docs/WORKFLOWS.md)** — Schema declarations, parameters, and reporting details.
- **[Scheduler System Guide](docs/SCHEDULER.md)** — Running non-daemon cron tasks, schedules, and automatic triggers.
- **[Plugin & Extension System](docs/PLUGINS.md)** — Guide on writing custom workflow steps and CLI commands.
- **[Testing & Verification Guide](docs/TESTING.md)** — Custom testing framework, assertions, and linting guidelines.
- **[Development Manual](docs/DEVELOPMENT.md)** — Architectural standards, coding styles, and developer checks.

---

## Phase 4 Features

### 1. Workflow Engine
Chain multiple automation steps into modular, secure, robust execution definitions. Workflows are declared in YAML/JSON, strictly validated to prevent command injection or directory traversal, and track detailed reports.

For full schema and usage details, see [docs/WORKFLOWS.md](docs/WORKFLOWS.md).

**Example Workflow File (`sync.yml`):**
```yaml
name: "System Sync and Check"
steps:
  - type: doctor
  - type: create_session
    session_name: "auto_sync"
  - type: watch_session
  - type: list_activities
  - type: get_pr
    pr_number: 16
```

**Commands:**
- `tjc workflow run <file.yml>`: Validates and runs a workflow step-by-step.
- `tjc workflow list`: Summarizes all workflow execution histories.
- `tjc workflow show <report_file.json>`: Displays step-by-step outputs and statuses.

---

### 2. Scheduler System
Persistently configure and run TJC workflows on a schedule without memory-heavy background daemons, fully compatible with cron, Termux:Boot, and Termux:Tasker.

For full documentation and integration guides, see [docs/SCHEDULER.md](docs/SCHEDULER.md).

**Commands:**
- `tjc schedule add <id> <workflow_file.yml> [expr]`: Adds a scheduled workflow.
- `tjc schedule list`: Lists configured active schedules.
- `tjc schedule remove <id>`: Unregisters a scheduled job.
- `tjc schedule run [id]`: Manually triggers job(s) immediately.
- `tjc schedule run-pending`: Automatically triggers jobs whose interval has elapsed since the last run.
- `tjc schedule history <id>`: Displays comprehensive job execution logs.

---

## Foundation Commands
- `tjc help`: Display help information.
- `tjc version`: Display version information.

## Quick Start Scenarios

Here are two quick practical scenarios showing how to use TJC's core capabilities.

### Scenario 1: Running a One-off Dependency and PR Audit
1. Create a `dev-audit.yml` file:
   ```yaml
   name: "Developer Audit"
   steps:
     - type: doctor
     - type: get_pr
       pr_number: 16
   ```
2. Run the audit workflow via CLI:
   ```sh
   tjc workflow run dev-audit.yml
   ```
3. View the generated JSON report:
   ```sh
   tjc workflow list
   ```

### Scenario 2: Registering and Manually Triggering a Scheduled Task
1. Register a task to check dependencies hourly:
   ```sh
   tjc schedule add hourly_doctor dev-audit.yml hourly
   ```
2. Manually execute the scheduled task immediately:
   ```sh
   tjc schedule run hourly_doctor
   ```
3. Check the execution logs of the schedule:
   ```sh
   tjc schedule history hourly_doctor
   ```

## Installation & Uninstallation

For complete system setup and troubleshooting details, please refer to the **[Installation Guide](docs/INSTALLATION.md)**.

```sh
# Install TJC with default prefix ($HOME/.local)
./install.sh

# Uninstall TJC
./uninstall.sh
```
