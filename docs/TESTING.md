# TJC Testing Guide

This document describes the testing architecture of TJC (Termux Jules CLI), how to run existing test suites, and how to write new test scenarios.

## Test Architecture

TJC uses a lightweight, custom, POSIX-compliant testing harness built in shell scripts to ensure broad compatibility across standard Linux systems and Termux on Android.

Key characteristics:
- **Zero Heavyweight Testing Dependencies**: Relies purely on POSIX shell capabilities, `jq`, `yq`, and standard shell utilities.
- **Strict Environment Isolation**: Every test scenario dynamically creates and destroys isolated workspace environments using `mktemp -d` and overrides `TJC_CONFIG_DIR` to prevent tests from altering user configurations.
- **Assertion Helpers**: Standardized success, failure, and equality validation helpers are used for consistent assertion results.

---

## Running the Test Suite

There are two primary test scripts located in the `test/` directory.

### 1. Workflow Engine Tests
Tests the validation, execution, sequence routing, error handling, cancellation, and execution logs of workflows.
```sh
./test/test_workflows.sh
```

### 2. Scheduler System Tests
Tests the schedule registration (adding, removing, listing), interval calculations, automatic execution (`run-pending`), manual triggering, history recording, and security controls of scheduled jobs.
```sh
./test/test_scheduler.sh
```

---

## Linting & ShellCheck

TJC enforces clean code practices using ShellCheck. Before submitting code changes, run ShellCheck over all repository scripts to guarantee 100% clean shell analysis:

```sh
shellcheck jules install.sh uninstall.sh lib/*.sh commands/*.sh scheduler/*.sh workflow/*.sh test/*.sh
```

---

## Writing New Tests

To add a test scenario to an existing test script:

### 1. Use the Assertion Helpers
The test files define three primary assertion functions:

- `assert_equals <expected> <actual> <description>`: Asserts that two string values are equal.
- `assert_success <exit_code> <description>`: Asserts that the prior command exited with code `0`.
- `assert_failure <exit_code> <description>`: Asserts that the prior command exited with a non-zero code.

### 2. Standard Test Template
When creating a new scenario, follow this template to ensure proper setup and isolation:

```sh
# Setup temporary work dir for isolation
export TJC_CONFIG_DIR
TJC_CONFIG_DIR=$(mktemp -d)

# Write your scenario test
echo "--- Scenario X: Testing My Custom Feature ---"

# 1. Run command
set +e
tjc_workflow run "$SOME_WF"
STATUS=$?
set -e

# 2. Make assertions
assert_success "$STATUS" "Custom feature executes successfully"

# Clean up
rm -rf "$TJC_CONFIG_DIR"
```

### 3. Error Case Assertions
Always test negative cases (e.g., passing invalid arguments, unsafe inputs, missing fields) and assert failures:

```sh
set +e
tjc_schedule add "../unsafe_id" "$WF_FILE" "hourly"
STATUS=$?
set -e
assert_failure "$STATUS" "Directory traversal or unsafe character in ID is rejected"
```
