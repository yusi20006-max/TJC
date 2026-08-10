#!/bin/sh

# TJC Workflow Command Handler v2
# shellcheck disable=SC1091
. "${BASE_DIR}/workflow/engine.sh"

tjc_workflow() {
  ACTION="${1:-}"
  case "$ACTION" in
    validate)
      FILE="${2:-}"
      [ -n "$FILE" ] || { tjc_error 'Usage: tjc workflow validate <workflow_file>'; return 1; }
      tjc_workflow_validate "$FILE" && tjc_success "Workflow is valid: $FILE"
      ;;
    run)
      FILE="${2:-}"
      [ -n "$FILE" ] || { tjc_error 'Usage: tjc workflow run <workflow_file.yml>'; return 1; }
      tjc_workflow_execute "$FILE"
      ;;
    resume)
      REPORT="${2:-}"
      [ -n "$REPORT" ] || { tjc_error 'Usage: tjc workflow resume <report_file.json>'; return 1; }
      case "$REPORT" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) tjc_error 'Unsafe report path.'; return 1;; esac
      [ -f "$REPORT" ] || { tjc_error "Report not found: $REPORT"; return 1; }
      FILE=$(jq -r '.file // ""' "$REPORT")
      [ -n "$FILE" ] && [ -f "$FILE" ] || { tjc_error 'The original workflow file is unavailable.'; return 1; }
      tjc_workflow_execute "$FILE" "$REPORT"
      ;;
    reports|list)
      REPORTS_DIR="$(tjc_config_dir)/workflows/reports"
      if [ ! -d "$REPORTS_DIR" ]; then tjc_info 'No workflow execution reports found.'; return 0; fi
      printf '%-30s %-24s %-12s %s\n' 'WORKFLOW' 'STARTED AT' 'STATUS' 'REPORT'
      printf '%s\n' '--------------------------------------------------------------------------------'
      for REPORT in "$REPORTS_DIR"/report_*.json; do
        [ -f "$REPORT" ] || continue
        WF_NAME=$(jq -r '.workflow // "Unknown"' "$REPORT")
        STARTED=$(jq -r '.started_at // "Unknown"' "$REPORT")
        STATUS=$(jq -r '.status // "Unknown"' "$REPORT")
        printf '%-30s %-24s %-12s %s\n' "$WF_NAME" "$STARTED" "$STATUS" "$(basename "$REPORT")"
      done
      ;;
    show)
      RFILE="${2:-}"
      [ -n "$RFILE" ] || { tjc_error 'Usage: tjc workflow show <report_file.json>'; return 1; }
      case "$RFILE" in *..*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*) tjc_error 'Unsafe report path.'; return 1;; esac
      REPORTS_DIR="$(tjc_config_dir)/workflows/reports"
      FULL_PATH="$RFILE"
      [ -f "$FULL_PATH" ] || FULL_PATH="$REPORTS_DIR/$(basename "$RFILE")"
      [ -f "$FULL_PATH" ] || { tjc_error "Report file not found: $RFILE"; return 1; }
      jq . "$FULL_PATH"
      ;;
    *)
      tjc_error "Unknown workflow command: $ACTION"
      printf '%s\n' \
        'Usage:' \
        '  tjc workflow validate <file.yml>' \
        '  tjc workflow run <file.yml>' \
        '  tjc workflow resume <report.json>' \
        '  tjc workflow list' \
        '  tjc workflow show <report.json>'
      return 1
      ;;
  esac
}
