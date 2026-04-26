#!/usr/bin/env bash
# PostToolUse(Write|Edit) hook: after a write/edit touches a core file, remind about CHANGELOG.
# Core files = Core_*.md, Stage_Transition_Rules.md, Research_Integration_Protocol.md, 03_Knowledge_Base/**
set -euo pipefail

TOOL_JSON="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
  printf '{}'
  exit 0
fi

FILE_PATH="$(printf '%s' "$TOOL_JSON" | jq -r '.tool_input.file_path // .tool_input.path // ""')"

# Match only core files.
MATCH=""
case "$FILE_PATH" in
  */Core_*.md|*/Stage_Transition_Rules.md|*/Research_Integration_Protocol.md)
    MATCH="core protocol file"
    ;;
  */03_Knowledge_Base/*)
    MATCH="knowledge base file"
    ;;
esac

if [[ -z "$MATCH" ]]; then
  printf '{}'
  exit 0
fi

jq -n --arg match "$MATCH" --arg path "$FILE_PATH" '{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": ("📝 Modified " + $match + " (" + $path + "). Before ending this turn, verify CHANGELOG.md has an entry for this change (date, rationale, diff summary). If you did not make the CHANGELOG entry, make it now.")
  }
}'
