# TJC Workflow Engine v2

TJC workflows are declarative YAML/JSON execution plans. The engine validates the definition before execution, runs only approved built-in step types, persists structured reports, supports dependency-aware execution, conditions, retries, timeouts, variables, and resume, and can associate an execution with the TJC Job System.

## Safety Model

Workflow definitions never execute arbitrary shell commands. Step types and their parameters are allow-listed by `workflow/validator.sh`. Workflow paths, identifiers, dependency references, retry counts, and timeout values are validated before execution.

Secrets must not be placed in workflow variables, step output, or descriptions.

## Allowed Step Types

- `doctor` — verifies required local tools.
- `create_session` — creates the current local session record.
- `watch_session` — watches the selected session record.
- `list_activities` — retrieves the supported activity representation.
- `get_pr` — retrieves a GitHub issue/PR record using a positive PR number.

## Basic Schema

```yaml
name: "Daily Review"
description: "Run a health check and inspect a PR"
variables:
  environment: production
steps:
  - type: doctor
  - type: get_pr
    pr_number: 23
```

`variables` is optional and is a mapping of simple values. It is intended for declarative conditions, not arbitrary code execution.

## Dependencies

A step may declare `depends_on` using zero-based step indexes:

```yaml
steps:
  - type: doctor
  - type: get_pr
    pr_number: 23
    depends_on: [0]
  - type: list_activities
    depends_on: [1]
```

Dependencies must refer to existing steps. Cycles are rejected during validation. A normal `on_success` step runs only after all dependencies complete successfully.

## Conditions

The condition language is deliberately small and does not evaluate shell expressions.

Supported values:

- `on_success` — default; requires dependencies to complete.
- `always` — run regardless of dependency status.
- `on_failure` — run when at least one dependency failed.
- `var:<key>=<value>` — run when a workflow variable exactly matches the requested value.

Example:

```yaml
variables:
  environment: production
steps:
  - type: doctor
  - type: list_activities
    depends_on: [0]
    condition: "var:environment=production"
```

## Retry Policy

Steps can request a bounded retry count:

```yaml
steps:
  - type: get_pr
    pr_number: 23
    retry:
      attempts: 3
```

The value means additional attempts after the first attempt. Validation limits this to 10 retries.

## Timeout Policy

A step may specify a wall-clock timeout:

```yaml
steps:
  - type: get_pr
    pr_number: 23
    timeout:
      seconds: 30
```

Timeouts are bounded to 86400 seconds. The engine terminates the child process when the limit is reached and records the timeout as a failed attempt.

## Resume

Every execution produces a JSON report under:

`~/.config/tjc/workflows/reports/`

A failed execution can be resumed from its report:

```sh
tjc workflow resume report_20260810T100000Z_1234.json
```

The original workflow path must still exist and match the report. Completed steps are preserved and execution continues from the first unfinished step.

## CLI

Validate without executing:

```sh
tjc workflow validate my-workflow.yml
```

Run:

```sh
tjc workflow run my-workflow.yml
```

List reports:

```sh
tjc workflow list
```

Inspect a report:

```sh
tjc workflow show report_20260810T100000Z_1234.json
```

Resume:

```sh
tjc workflow resume report_20260810T100000Z_1234.json
```

## Reporting

Reports contain:

- workflow identity
- source file
- overall status
- start/end timestamps
- resume source
- every step's type
- step status
- attempt count
- start/end timestamps
- output
- error information

Workflow executions may also create a Job record. Job records are the long-running operation abstraction used by later TJC v2 components.

## Compatibility

The v2 engine remains POSIX-shell based and is intended for Termux and standard Linux. It does not require a permanent daemon or root privileges.

## Development Rules

When adding a new step type:

1. Add the implementation to the controlled step dispatcher.
2. Add its exact parameter allow-list to the validator.
3. Add parser coverage if required.
4. Add success/failure/security tests.
5. Update this document.
6. Run the complete test suite and ShellCheck.

Never add a generic `shell`, `exec`, `eval`, or user-controlled command step to bypass the safety boundary.
