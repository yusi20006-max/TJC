#!/bin/sh

# TJC Help Command
# Displays help menu and usage instructions for all standard TJC commands.

# Public function: tjc_help
# Usage: tjc_help <base_dir>
# Description: Displays commands, descriptions, and syntax guides.
tjc_help() {
  printf 'TJC (Termux Jules CLI)\n\n'
  printf 'Usage:\n'
  printf '  tjc <command> [options]\n\n'
  printf 'Core Commands:\n'
  printf '  help, -h, --help                 Display this help menu\n'
  printf '  version, -v, --version           Display version information\n\n'
  printf 'Workflow Engine Commands:\n'
  printf '  workflow run <file.yml>          Execute a workflow defined in a YAML/JSON file\n'
  printf '  workflow list                    List summary records of workflow executions\n'
  printf '  workflow show <file.json>        Display step-by-step outcomes and statuses\n\n'
  printf 'Scheduler Commands:\n'
  printf '  schedule add <id> <file> [expr]  Register a workflow schedule\n'
  printf '  schedule list                    List active scheduled jobs\n'
  printf '  schedule remove <id>             Unregister a scheduled job\n'
  printf '  schedule run [id]                Trigger scheduled job(s) immediately\n'
  printf '  schedule run-pending             Automatically execute pending due scheduled jobs\n'
  printf '  schedule history <id>            Show past execution records of a schedule\n'
  return 0
}
