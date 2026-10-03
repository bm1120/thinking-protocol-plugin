#!/usr/bin/env bash
# lib/local_llm_router.sh — Single entry point for all local LLM (Jev/Kev) calls.
# Sourced by skills/hooks. Never executed directly.
# managed-by: thinking-protocol-plugin

# --- Config ---
OLLAYA_ENDPOINT="${OLLAYA_ENDPOINT:-http://localhost:11434}"
TIER_CACHE="${HOME}/.cache/thinking-protocol/hw_tier.json"
TIER_CACHE_TTL=86400  # 24 hours

# --- Ollaya health check ---
ollaya_available() {
  curl -sf --max-time 2 "${OLLAYA_ENDPOINT}/health" >/dev/null 2>&1
}

# --- Hardware tier detection ---
detect_hw_tier() {
  # Check cache first
  if [[ -f "$TIER_CACHE" ]]; then
    local cached_at
    cached_at=$(python3 -c "import json;print(json.load(open('$TIER_CACHE'))['cached_at'])" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    if (( now - cached_at < TIER_CACHE_TTL )); then
      python3 -c "import json;print(json.load(open('$TIER_CACHE'))['tier'])" 2>/dev/null
      return
    fi
  fi

  local total_mb=0

  # macOS
  if [[ "$(uname)" == "Darwin" ]]; then
    local bytes
    bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    total_mb=$(( bytes / 1024 / 1024 ))
  else
    # Linux
    total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  fi

  local tier=1
  if (( total_mb >= 49152 )); then
    tier=4
  elif (( total_mb >= 32768 )); then
    tier=3
  elif (( total_mb >= 16384 )); then
    tier=2
  else
    tier=1
  fi

  # Cache result
  mkdir -p "$(dirname "$TIER_CACHE")"
  python3 -c "
import json
with open('$TIER_CACHE','w') as f:
    json.dump({'tier':$tier,'total_mb':$total_mb,'cached_at':$(date +%s)},f)
" 2>/dev/null || true

  echo "$tier"
}

# --- Tier → model mapping ---
model_for_tier() {
  local tier="${1:-1}"
  case "$tier" in
    1) echo "kev-0.8b" ;;
    2) echo "kev-4b" ;;
    3) echo "kev-9b" ;;
    4) echo "openjev-27b-q4" ;;
    *) echo "kev-0.8b" ;;
  esac
}

# --- Build request JSON ---
build_request() {
  local type="$1" state="$2" question="$3"
  python3 -c "
import json,sys
print(json.dumps({
    'type': '$type',
    'state': $(python3 -c "import json;print(json.dumps('$state'))"),
    'question': $(python3 -c "import json;print(json.dumps('$question'))")
},ensure_ascii=False))
"
}

# --- Parse Jev response ---
parse_response() {
  local response="$1" type="$2"
  # Normalize and add metadata
  python3 -c "
import json,sys
raw = json.loads('''$response''')
result = {
    'answer': raw.get('answer'),
    'probability': raw.get('probability', 0.0),
    'confidence': raw.get('confidence', 'unknown'),
    'type': '$type'
}
print(json.dumps(result))
"
}

# --- Main query function (called by skills) ---
# Usage: local_llm_query <type> <state> <question>
# Returns: JSON with answer/probability/confidence or empty string if unavailable
local_llm_query() {
  local type="$1" state="$2" question="$3"

  if ! ollaya_available; then
    echo ""
    return 0
  fi

  # Read settings override
  local vault="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local model_override=""
  local tier_override=""
  if [[ -f "$vault/.claude/settings.json" ]]; then
    model_override=$(python3 -c "import json;d=json.load(open('$vault/.claude/settings.json'));print(d.get('local_llm',{}).get('model_override',''))" 2>/dev/null || echo "")
    tier_override=$(python3 -c "import json;d=json.load(open('$vault/.claude/settings.json'));print(d.get('local_llm',{}).get('tier_override',''))" 2>/dev/null || echo "")
  fi

  local model=""
  if [[ -n "$model_override" ]]; then
    model="$model_override"
  elif [[ -n "$tier_override" ]]; then
    model=$(model_for_tier "$tier_override")
  else
    model=$(model_for_tier "$(detect_hw_tier)")
  fi

  local request_body
  request_body=$(build_request "$type" "$state" "$question")

  local response
  response=$(curl -sf --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "${OLLAYA_ENDPOINT}/v1/decisions" 2>/dev/null) || {
    echo ""
    return 0
  }

  local parsed
  parsed=$(parse_response "$response" "$type")

  # Log to _logs/jev_judgments.jsonl
  local log_dir="$vault/_logs"
  if [[ -d "$log_dir" ]] || mkdir -p "$log_dir" 2>/dev/null; then
    python3 -c "
import json, datetime
entry = {
    'timestamp': datetime.datetime.now().isoformat(),
    'type': '$type',
    'model': '$model',
    'result': json.loads('''$parsed''')
}
with open('$log_dir/jev_judgments.jsonl','a') as f:
    f.write(json.dumps(entry,ensure_ascii=False)+'\n')
" 2>/dev/null || true
  fi

  echo "$parsed"
}
