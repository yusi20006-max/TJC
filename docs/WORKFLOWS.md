# TJC Workflow Engine

The TJC Workflow Engine allows you to chain multiple automation steps into a single executable definition. Workflows are defined in valid YAML or JSON files and are validated strictly before execution to prevent unsafe commands.

## Allowed Step Types

To protect the system and prevent arbitrary shell injection, only the following step types are allowed:

1. **`doctor`**: Verifies local environment and dependencies (`jq`, `yq`, `shellcheck`).
2. **`create_session`**: Creates a new session with Google Jules.
   - Parameters:
     - `session_name` (optional): Alphanumeric identifier for the session.
3. **`watch_session`**: Watches the progress of a session.
   - Parameters:
     - `session_id` (optional): Alphanumeric identifier of the session to watch. Defaults to the last created session.
4. **`list_activities`**: Lists recent Jules activity stream.
5. **`get_pr`**: Retrieves pull request information from GitHub.
   - Parameters:
     - `pr_number` (required): Positive integer.

## Workflow Schema Example

Workflows contain a `name`, optional `description`, and a list of `steps`.

### Example: `my-workflow.yml`

```yaml
name: "Daily Sync and Review"
description: "Executes a system health doctor check, creates a session, and retrieves PR info"
steps:
  - type: doctor
  - type: create_session
    session_name: "morning_sync"
  - type: watch_session
  - type: list_activities
  - type: get_pr
    pr_number: 16
```

## Running Workflows via CLI

Workflows can be managed and executed using the following commands:

### 1. Run a Workflow
Execute a workflow definition:
```sh
tjc workflow run my-workflow.yml
```

### 2. List Execution Reports
Display a summary history of all workflow executions:
```sh
tjc workflow list
```

### 3. Show Detailed Execution Report
Review step-by-step statuses, execution times, and step outputs:
```sh
tjc workflow show report_20260801_120000_12345.json
```

## States and Reporting

Workflows go through several lifecycle states:
- **`PENDING`**: Steps not yet started.
- **`RUNNING`**: Active step.
- **`COMPLETED`**: Successfully executed step or workflow.
- **`FAILED`**: Failed step or workflow.
- **`CANCELLED`**: Cancelled steps (occurs to downstream steps when an upstream step fails).

If any workflow step fails, execution halts safely, updating reports and cancelling subsequent steps immediately.
Reports are stored as structured JSON files under `~/.config/tjc/workflows/reports/`.
