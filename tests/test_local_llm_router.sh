#!/usr/bin/env bash
# tests/test_local_llm_router.sh — local_llm_router unit tests with mock Ollaya
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/lib/local_llm_router.sh"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# --- Test 1: ollaya_available returns 1 when no server ---
OLLAYA_ENDPOINT="http://localhost:59999"
check "ollaya_unavailable" '! ollaya_available'

# --- Test 2: detect_hw_tier returns valid tier ---
tier=$(detect_hw_tier)
check "tier_is_number" '[[ "$tier" =~ ^[1-4]$ ]]'

# --- Test 3: model_for_tier returns correct model ---
check "tier1_model" '[[ "$(model_for_tier 1)" == "kev-0.8b" ]]'
check "tier2_model" '[[ "$(model_for_tier 2)" == "kev-4b" ]]'
check "tier3_model" '[[ "$(model_for_tier 3)" == "kev-9b" ]]'
check "tier4_model" '[[ "$(model_for_tier 4)" == "openjev-27b-q4" ]]'

# --- Test 4: build_request outputs valid JSON ---
req=$(build_request "noul" "test state" "is this true?")
check "request_valid_json" 'echo "$req" | python3 -c "import sys,json;json.load(sys.stdin)"'
check "request_has_type" 'echo "$req" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"type\"]==\"noul\""'

# --- Test 5: parse_response handles Jev output ---
MOCK_RESPONSE='{"answer":true,"probability":0.91,"confidence":"high"}'
parsed=$(parse_response "$MOCK_RESPONSE" "noul")
check "parsed_answer" 'echo "$parsed" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"answer\"]==True"'
check "parsed_confidence" 'echo "$parsed" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"confidence\"]==\"high\""'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
