#!/usr/bin/env bash
# lib/provider_adapter.sh — Multi-provider detection and adapter for Tribunal mode.
# Sourced by validator agent. Never executed directly.
# managed-by: thinking-protocol-plugin

# --- Detect available external providers ---
detect_providers() {
  local providers=""
  [[ -n "${GEMINI_API_KEY:-}" ]] && providers+="gemini "
  [[ -n "${OPENAI_API_KEY:-}" ]] && providers+="openai "
  echo "$providers"
}

# --- Check if tribunal is enabled in settings ---
tribunal_enabled() {
  local vault="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local settings="$vault/.claude/settings.json"
  if [[ -f "$settings" ]]; then
    python3 -c "
import json
d=json.load(open('$settings'))
t=d.get('tribunal',{})
print('true' if t.get('enabled',True) else 'false')
" 2>/dev/null || echo "true"
  else
    echo "true"
  fi
}

# --- Format provider status for display ---
provider_status() {
  local providers
  providers=$(detect_providers)
  local status=""
  if echo "$providers" | grep -q "gemini"; then
    status+="Gemini ✅ "
  fi
  if echo "$providers" | grep -q "openai"; then
    status+="GPT ✅ "
  fi
  if [[ -z "$status" ]]; then
    status="(외부 API Key 없음)"
  fi
  echo "$status"
}
