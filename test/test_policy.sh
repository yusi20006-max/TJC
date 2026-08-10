#!/bin/sh
set -eu

BASE_DIR=$(pwd)
export BASE_DIR
export TJC_CONFIG_DIR=$(mktemp -d)
. "${BASE_DIR}/lib/config.sh"
. "${BASE_DIR}/policy/policy.sh"

# Missing policy uses restrictive defaults for external/high-risk operations.
tjc_policy_allow mcp.read
if tjc_policy_allow mcp.execute; then exit 1; fi
if tjc_policy_allow plugin.execute; then exit 1; fi

POLICY="$TJC_CONFIG_DIR/custom-policy.yml"
cat >"$POLICY" <<'YAML'
version: 1
defaults:
  default: deny
operations:
  workflow.run: allow
  mcp.execute: deny
YAML
export TJC_POLICY_FILE="$POLICY"
tjc_policy_allow workflow.run
if tjc_policy_allow mcp.execute; then exit 1; fi
if tjc_policy_allow unknown.operation; then exit 1; fi

printf '%s\n' 'Policy tests: passed'
rm -rf "$TJC_CONFIG_DIR"
