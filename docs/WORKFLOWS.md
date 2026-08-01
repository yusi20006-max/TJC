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

## Real-world Automation Scenarios

Here are some complete, practical examples of how to combine step types for common developer workflows.

### Scenario A: Continuous Review of Incoming PRs

In this scenario, we perform a doctor check to verify local CLI tools, initiate a secure Jules session, and fetch details for a specific Pull Request. This is typical for pre-flight or CI-based automated reviews.

Create a file named `pr-review-workflow.yml`:

```yaml
name: "CI Pull Request Pre-flight Review"
description: "Checks dependencies, logs a new Jules session, and retrieves GitHub PR #17"
steps:
  - type: doctor
  - type: create_session
    session_name: "pr_17_check"
  - type: watch_session
  - type: list_activities
  - type: get_pr
    pr_number: 17
```

**To execute:**
```sh
tjc workflow run pr-review-workflow.yml
```

### Scenario B: Scheduled Daily System Verification

In this scenario, we run a system health check and list recent Google Jules activity streams to monitor automated background tasks.

Create a file named `daily-check.json`:

```json
{
  "name": "Daily System Verification",
  "description": "Verifies tools and audits the Google Jules activity log",
  "steps": [
    {
      "type": "doctor"
    },
    {
      "type": "list_activities"
    }
  ]
}
```

**To execute:**
```sh
tjc workflow run daily-check.json
```
