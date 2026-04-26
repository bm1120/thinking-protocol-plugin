#!/usr/bin/env bash
# hooks/plugin-session-start.sh
# Plugin-side SessionStart hook: detect vault/plugin VERSION skew, output reminder.
# Output is JSON per Claude Code hook v2 schema (additionalContext).
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PLUGIN_VERSION="$(cat "$PLUGIN_ROOT/VERSION" 2>/dev/null || echo "?")"
VAULT_VERSION="$(cat VERSION 2>/dev/null || echo "")"

REMINDER=""

if [[ -z "$VAULT_VERSION" ]]; then
  # No VERSION file in cwd: either not a vault, or fresh dir before /migrate
  if [[ -d ".claude" || -f "Core_Thinking_Protocol.md" ]]; then
    REMINDER="⚠️ Vault has no VERSION file. Run /migrate to align with plugin v$PLUGIN_VERSION."
  fi
elif [[ "$VAULT_VERSION" != "$PLUGIN_VERSION" ]]; then
  REMINDER="⚠️ Vault VERSION ($VAULT_VERSION) ≠ plugin VERSION ($PLUGIN_VERSION). Run /migrate to update."
fi

if command -v jq >/dev/null 2>&1; then
  if [[ -n "$REMINDER" ]]; then
    jq -n --arg r "$REMINDER" \
      '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $r}}'
  else
    jq -n '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
  fi
else
  if [[ -n "$REMINDER" ]]; then
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' \
      "$(echo "$REMINDER" | sed 's/"/\\"/g')"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}'
  fi
fi
