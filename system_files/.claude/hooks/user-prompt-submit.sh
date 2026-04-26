#!/usr/bin/env bash
# UserPromptSubmit hook: detect stage-skip keywords and inject a caution note.
# The caution is advisory — it does NOT block the prompt; Claude sees the extra context and decides.
set -euo pipefail

# Read the user prompt from stdin (Claude Code v2 protocol).
PROMPT_JSON="$(cat)"

# Extract the text safely. If jq unavailable, fall through silently.
if ! command -v jq >/dev/null 2>&1; then
  printf '{}'
  exit 0
fi

PROMPT_TEXT="$(printf '%s' "$PROMPT_JSON" | jq -r '.prompt // ""')"

# Korean tokens — substring match (distinctive, no word-boundary issue in Korean).
KEYWORDS_KO=(
  "빨리" "지금 당장" "바로 결정" "시간 없어" "급해" "빠르게 답"
)

# English tokens — word-boundary match via regex. Must not fire on substrings
# of benign words (e.g., "rush" inside "brush", "crush", "rushed").
KEYWORDS_EN=(
  "rush" "skip the" "just tell me" "don't overthink"
)

HIT=""
LOWERED="$(printf '%s' "$PROMPT_TEXT" | tr '[:upper:]' '[:lower:]')"

# Korean: substring
for kw in "${KEYWORDS_KO[@]}"; do
  if [[ "$LOWERED" == *"$kw"* ]]; then
    HIT="$kw"
    break
  fi
done

# English: word boundary (only if no Korean hit yet).
# Uses a captured regex variable to avoid shell-escaping fragility.
if [[ -z "$HIT" ]]; then
  for kw in "${KEYWORDS_EN[@]}"; do
    RE="(^|[^a-z0-9])${kw}([^a-z0-9]|$)"
    if [[ "$LOWERED" =~ $RE ]]; then
      HIT="$kw"
      break
    fi
  done
fi

if [[ -z "$HIT" ]]; then
  printf '{}'
  exit 0
fi

jq -n --arg hit "$HIT" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": ("⚠️ Stage-skip signal detected (keyword: \"" + $hit + "\"). Before answering, apply the Right-size rule from CLAUDE.md §2 and the Anti-Patterns section. If the decision is non-trivial, do NOT skip Frame/Incubate. Surface the check to the user.")
  }
}'
