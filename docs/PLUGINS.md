# TJC Plugin and Extension System

This document outlines the design and implementation of the plugin and extension model for TJC (Termux Jules CLI).

## Extension Architecture

TJC is designed with strict modularity in mind. The core CLI (`jules`), the Workflow Engine (`workflow/`), and the Scheduler (`scheduler/`) are highly decoupled. Extending TJC does not require modifying core logic; instead, you can extend functionality using two primary mechanisms:

1. **Custom Workflow Steps**: Add custom automated actions to the workflow step router.
2. **Custom CLI Subcommands**: Add new custom commands directly to the `jules` entrypoint command dispatcher.

---

## 1. Custom Workflow Steps

Workflows in TJC are defined as sequential arrays of execution steps. The step router in `workflow/engine.sh` dispatches step types to dedicated helper functions.

### How to Create a Custom Workflow Step Action

To register a new step type (e.g., `git_sync`):

#### Step A: Implement the execution function
Implement the shell function in an existing or new helper file in `workflow/engine.sh` or within a plugin script sourced by `workflow/engine.sh`:

```sh
# Usage: tjc_workflow_run_git_sync <params_json>
# Description: Custom plugin step to sync a local repository with a remote.
tjc_workflow_run_git_sync() {
  PARAMS="$1"
  REPO_PATH=$(echo "$PARAMS" | jq -r '.repo_path // ""')
  BRANCH=$(echo "$PARAMS" | jq -r '.branch // "main"')

  if [ -z "$REPO_PATH" ]; then
    echo "Error: repo_path parameter is required."
    return 1
  fi

  echo "Syncing repository at $REPO_PATH on branch $BRANCH..."
  # Put custom logic here (e.g., git pull or push)
  return 0
}
```

#### Step B: Register the action in the router
In `workflow/engine.sh`, add your custom step type inside the `tjc_workflow_execute` switch case:

```sh
    case "$STEP_TYPE" in
      ...
      git_sync)
        if ! STEP_OUTPUT=$(tjc_workflow_run_git_sync "$STEP_PARAMS" 2>&1); then
          STEP_STATUS="FAILED"
        fi
        ;;
```

#### Step C: Add validation in validator.sh
To maintain strict input security, you must also allow and validate your step type and its arguments in `workflow/validator.sh`:

```sh
      git_sync)
        PARAMS=$(tjc_workflow_get_step_params "$FILE" "$INDEX")
        STEP_KEYS=$(echo "$PARAMS" | jq -r 'keys[]')
        for S_KEY in $STEP_KEYS; do
          case "$S_KEY" in
            type|repo_path|branch) ;;
            *)
              tjc_error "Workflow validation failed: Step $INDEX has unknown parameter '$S_KEY' for git_sync."
              return 1
              ;;
          esac
        done
        ;;
```

---

## 2. Custom CLI Subcommands

TJC executes user commands by routing arguments through the `jules` entrypoint script.

### Registering a New Command

To add a new subcommand (e.g., `tjc cleanup`):

1. **Create the Command File**: Create a shell file under `commands/cleanup.sh`.
2. **Implement the Entrypoint**: Declare a public function `tjc_cleanup()`. Ensure it contains descriptive usage comments and returns appropriate exit codes (0 for success, non-zero for failure).
3. **Include the Script in `jules`**: Update the case block in the `jules` root script:
   ```sh
     cleanup)
       . "$BASE_DIR/commands/cleanup.sh"
       tjc_cleanup "$@"
       ;;
   ```
4. **Update Help Output**: Add documentation for the new command inside `commands/help.sh`.

---

## Extension Best Practices

When designing and writing extensions or plugins for TJC, adhere to these strict engineering principles:

- **Pass ShellCheck**: All new shell files must be 100% compliant with `shellcheck`.
- **Zero Log Leakage**: Under no circumstances should secrets, passwords, or personal keys be written to the log or output files.
- **Robust Input Validation**: Strictly validate alphanumeric characters, prevent command injection (`;&|`$), and reject directory traversal (`..`).
- **Use Decoupled Interfaces**: Interact with other modules using their public shell functions or CLI commands rather than reaching into private helper variables.
- **Handle Exit Statuses Gracefully**: Ensure every plugin action yields meaningful exit status codes so that the workflow engine can cancel downstream operations upon failure.
