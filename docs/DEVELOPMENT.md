# TJC Development Manual

This document details the architectural standards, development guidelines, file layouts, and local validation workflows for contributors and maintainers of TJC (Termux Jules CLI).

---

## Architecture Standards

TJC is a modular shell-based platform. We adhere to the following core architectural principles:

1. **POSIX Shell Compliance**: All code must run under standard POSIX `/bin/sh` or `/data/data/com.termux/files/usr/bin/sh` on Android/Termux. Do not use bashisms (such as `[[ ... ]]` or `declare`) unless strictly required and inside a Bash-specific file.
2. **Complete Module Decoupling**: The main automated subsystems—Workflow Engine, Scheduler, and Logger—must never directly invoke internal private helper functions of each other. Instead, they interact via public interfaces or standard CLI hooks.
3. **Robust Input Validation**:
   - Every user input (IDs, file paths, parameters) must be strictly validated.
   - Reject paths containing shell expansion or command injection metacharacters: `;`, `&`, `|`, `` ` ``, `$`.
   - Rejects directory traversals: `..`.
   - Ensure scheduled job IDs allow only alphanumeric characters, dashes, and underscores (`^[a-zA-Z0-9_-]+$`).
4. **Zero Key/Credential Logging**: Under no circumstances should secrets, API keys, tokens, or personal identifiers be printed to logs. The logger must strictly log operation summaries, step statuses, and general timestamps.
5. **Meaningful Exit Statuses**: Every public shell function must return explicit exit codes: `0` for success and non-zero (e.g., `1`) for failures, allowing parent scripts to react correctly.

---

## File Layout and Directory Structure

The project directory is structured as follows:

```
├── jules                # Core entrypoint script
├── install.sh           # Installation installer script
├── uninstall.sh         # Uninstallation cleanup script
├── commands/            # User-facing command routing files
│   ├── help.sh
│   ├── schedule.sh
│   ├── version.sh
│   └── workflow.sh
├── config/              # Default configuration templates (read-only)
│   └── default.conf
├── docs/                # Project documentation and manuals
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   ├── INSTALLATION.md
│   ├── PLUGINS.md
│   ├── SCHEDULER.md
│   ├── TESTING.md
│   └── WORKFLOWS.md
├── lib/                 # Shared system libraries
│   ├── colors.sh
│   ├── config.sh
│   ├── logger.sh
│   ├── output.sh
│   └── utils.sh
├── scheduler/           # Scheduler automation engine
│   ├── jobs.sh
│   ├── scheduler.sh
│   └── storage.sh
├── test/                # Local testing and validation suite
│   ├── test_scheduler.sh
│   └── test_workflows.sh
└── workflow/            # Automated workflow engine
    ├── engine.sh
    ├── parser.sh
    └── validator.sh
```

---

## Coding Conventions

- **Command Discovery**: Use the helper `tjc_command_exists` from `lib/utils.sh` to determine if system dependencies (such as `curl` or `yq`) are present.
- **Color Outputs**: Use predefined variables from `lib/colors.sh` (e.g., `TJC_COLOR_GREEN`, `TJC_COLOR_RED`) for terminal messages, but ensure they degrade gracefully when stdout is not a TTY.
- **Function Prefixes**: Prefix public functions with the module namespace (e.g., `tjc_workflow_`, `tjc_scheduler_`, `tjc_log_`).

---

## Local Verification Checks

Prior to merging any code changes, verify that your branch passes all checks.

### 1. ShellCheck Verification
Every shell script must pass ShellCheck analysis. Suppressing warnings with inline directives (e.g., `# shellcheck disable=SC1091`) is only permitted for dynamic runtime sourcing and must be fully documented.

Run linting across all files:
```sh
shellcheck jules install.sh uninstall.sh lib/*.sh commands/*.sh scheduler/*.sh workflow/*.sh test/*.sh
```

### 2. Automated Test Run
Execute both testing frameworks and verify that all test cases pass:

```sh
# Run workflow engine tests
./test/test_workflows.sh

# Run scheduler engine tests
./test/test_scheduler.sh
```

---

## Termux-Specific Notes

Since Android has a distinct sandbox model, always write scripts with Termux compatibility in mind:
- **Executable Shebangs**: The entrypoint `jules` must use the Termux-compatible shebang: `#!/data/data/com.termux/files/usr/bin/sh`.
- **User Space Isolation**: Avoid writing configurations to global Linux directories (like `/etc/` or `/var/`). Always default to standard user directories such as `$HOME/.config/tjc`.
- **Dynamic Command Resolution**: Rely on `command -v` instead of assuming hardcoded binary paths like `/usr/bin/jq` or `/bin/date`.
