#!/bin/sh

# TJC Workflow Parser
# Parses YAML/JSON workflow files using yq and jq.
# Keeps the workflow module decoupled from execution.

# Public function: tjc_workflow_get_name
# Usage: tjc_workflow_get_name <workflow_file>
# Description: Extracts the 'name' field from a workflow definition.
# Returns: String name on success, or empty on failure. Exit code 0 on success, non-zero on failure.
tjc_workflow_get_name() {
  FILE="$1"
  if [ -z "$FILE" ]; then
    return 1
  fi
  yq -r '.name // ""' "$FILE" 2>/dev/null
}

# Public function: tjc_workflow_get_description
# Usage: tjc_workflow_get_description <workflow_file>
# Description: Extracts the 'description' field from a workflow definition.
# Returns: String description on success, or empty on failure. Exit code 0 on success, non-zero on failure.
tjc_workflow_get_description() {
  FILE="$1"
  if [ -z "$FILE" ]; then
    return 1
  fi
  yq -r '.description // ""' "$FILE" 2>/dev/null
}

# Public function: tjc_workflow_get_steps_count
# Usage: tjc_workflow_get_steps_count <workflow_file>
# Description: Extracts the total number of steps from a workflow definition.
# Returns: Non-negative integer count. Exit code 0 on success, non-zero on failure.
tjc_workflow_get_steps_count() {
  FILE="$1"
  if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    printf '0\n'
    return 1
  fi
  yq '.steps | length' "$FILE" 2>/dev/null || printf '0\n'
}

# Public function: tjc_workflow_get_step_type
# Usage: tjc_workflow_get_step_type <workflow_file> <step_index>
# Description: Extracts the 'type' field from a step at the given index.
# Returns: String step type on success. Exit code 0 on success, non-zero on failure.
tjc_workflow_get_step_type() {
  FILE="$1"
  INDEX="$2"
  if [ -z "$FILE" ] || [ -z "$INDEX" ]; then
    return 1
  fi
  yq -r ".steps[$INDEX].type // \"\"" "$FILE" 2>/dev/null
}

# Public function: tjc_workflow_get_step_params
# Usage: tjc_workflow_get_step_params <workflow_file> <step_index>
# Description: Extracts the parameters of a step at the given index as a compact JSON string.
# Returns: Compact JSON string of the step parameters. Exit code 0 on success, non-zero on failure.
tjc_workflow_get_step_params() {
  FILE="$1"
  INDEX="$2"
  if [ -z "$FILE" ] || [ -z "$INDEX" ]; then
    return 1
  fi
  yq -c ".steps[$INDEX] // {}" "$FILE" 2>/dev/null
}
