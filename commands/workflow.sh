#!/bin/sh

# TJC Workflow Command Handler
# Handles user interface for executing, listing, and showing reports of workflows.

# shellcheck disable=SC1091 # Dynamic path resolution at runtime
. "${BASE_DIR}/workflow/engine.sh"

# Public function: tjc_workflow
# Usage: tjc_workflow <action> [arguments]
# Description: Dispatches workflow CLI commands: run, list, show.
# Returns: Exit code 0 on success, non-zero on failure.
tjc_workflow() {
  ACTION="${1:-}"

  case "$ACTION" in
    run)
      FILE="${2:-}"
      if [ -z "$FILE" ]; then
        tjc_error "Usage: tjc workflow run <workflow_file.yml>"
        return 1
      fi

      if ! tjc_workflow_execute "$FILE"; then
        return 1
      fi
      ;;
    reports|list)
      REPORTS_DIR="$(tjc_config_dir)/workflows/reports"
      if [ ! -d "$REPORTS_DIR" ] || [ -z "$(ls -A "$REPORTS_DIR" 2>/dev/null)" ]; then
        tjc_info "No workflow execution reports found."
        return 0
      fi

      tjc_info "Workflow Execution Reports:"
      printf '%-30s %-20s %-12s %-10s\n' "WORKFLOW" "STARTED AT" "STATUS" "REPORT FILE"
      printf '%s\n' "--------------------------------------------------------------------------------"

      for REPORT in "$REPORTS_DIR"/report_*.json; do
        if [ -f "$REPORT" ]; then
          WF_NAME=$(jq -r '.workflow // "Unknown"' "$REPORT")
          STARTED=$(jq -r '.started_at // "Unknown"' "$REPORT")
          STATUS=$(jq -r '.status // "Unknown"' "$REPORT")
          FNAME=$(basename "$REPORT")

          # Add terminal colors for status
          case "$STATUS" in
            COMPLETED) STATUS_COLOR="${TJC_COLOR_GREEN}${STATUS}${TJC_COLOR_RESET}" ;;
            FAILED) STATUS_COLOR="${TJC_COLOR_RED}${STATUS}${TJC_COLOR_RESET}" ;;
            *) STATUS_COLOR="${TJC_COLOR_YELLOW}${STATUS}${TJC_COLOR_RESET}" ;;
          esac

          printf '%-30s %-20s %-12b %-10s\n' "$WF_NAME" "$STARTED" "$STATUS_COLOR" "$FNAME"
        fi
      done
      ;;
    show)
      RFILE="${2:-}"
      if [ -z "$RFILE" ]; then
        tjc_error "Usage: tjc workflow show <report_file.json>"
        return 1
      fi

      # Allow passing just filename under the reports directory or absolute path
      REPORTS_DIR="$(tjc_config_dir)/workflows/reports"
      FULL_PATH=""
      if [ -f "$RFILE" ]; then
        FULL_PATH="$RFILE"
      elif [ -f "${REPORTS_DIR}/${RFILE}" ]; then
        FULL_PATH="${REPORTS_DIR}/${RFILE}"
      fi

      if [ -z "$FULL_PATH" ]; then
        tjc_error "Report file not found: $RFILE"
        return 1
      fi

      # Read and display report nicely
      WF_NAME=$(jq -r '.workflow' "$FULL_PATH")
      FILE_PATH=$(jq -r '.file' "$FULL_PATH")
      STATUS=$(jq -r '.status' "$FULL_PATH")
      STARTED=$(jq -r '.started_at' "$FULL_PATH")
      ENDED=$(jq -r '.ended_at' "$FULL_PATH")

      case "$STATUS" in
        COMPLETED) STATUS_COLOR="${TJC_COLOR_GREEN}${STATUS}${TJC_COLOR_RESET}" ;;
        FAILED) STATUS_COLOR="${TJC_COLOR_RED}${STATUS}${TJC_COLOR_RESET}" ;;
        *) STATUS_COLOR="${TJC_COLOR_YELLOW}${STATUS}${TJC_COLOR_RESET}" ;;
      esac

      tjc_info "Workflow: $WF_NAME"
      echo "File:     $FILE_PATH"
      echo "Status:   $STATUS_COLOR"
      echo "Started:  $STARTED"
      echo "Ended:    $ENDED"
      echo ""
      tjc_info "Steps:"

      # Iterate over steps
      jq -c '.steps[]' "$FULL_PATH" 2>/dev/null | while read -r STEP_JSON; do
        IDX=$(echo "$STEP_JSON" | jq -r '.index')
        STYPE=$(echo "$STEP_JSON" | jq -r '.type')
        SSTATUS=$(echo "$STEP_JSON" | jq -r '.status')
        SSTART=$(echo "$STEP_JSON" | jq -r '.started_at // ""')
        SEND=$(echo "$STEP_JSON" | jq -r '.ended_at // ""')
        SOUT=$(echo "$STEP_JSON" | jq -r '.output // ""')

        case "$SSTATUS" in
          COMPLETED) SSTATUS_COLOR="${TJC_COLOR_GREEN}${SSTATUS}${TJC_COLOR_RESET}" ;;
          FAILED) SSTATUS_COLOR="${TJC_COLOR_RED}${SSTATUS}${TJC_COLOR_RESET}" ;;
          CANCELLED) SSTATUS_COLOR="${TJC_COLOR_YELLOW}${SSTATUS}${TJC_COLOR_RESET}" ;;
          *) SSTATUS_COLOR="${SSTATUS}" ;;
        esac

        printf '  [%s] %s (%s)\n' "$IDX" "$STYPE" "$SSTATUS_COLOR"
        if [ -n "$SSTART" ]; then
          printf '      Time: %s to %s\n' "$SSTART" "$SEND"
        fi
        if [ -n "$SOUT" ]; then
          printf '      Output:\n'
          echo "$SOUT" | sed 's/^/        /'
        fi
        echo ""
      done
      ;;
    *)
      tjc_error "Unknown workflow command: $ACTION"
      echo "Usage:"
      echo "  tjc workflow run <file.yml>   Run a workflow"
      echo "  tjc workflow list             List workflow execution reports"
      echo "  tjc workflow show <file.json> Show detailed report of a workflow execution"
      return 1
      ;;
  esac
  return 0
}
