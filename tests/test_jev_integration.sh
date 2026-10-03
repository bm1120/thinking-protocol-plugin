#!/usr/bin/env bash
# tests/test_jev_integration.sh — Jev skill and template integration tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# --- Test 1: jev-judgment skill exists with correct frontmatter ---
check "jev_skill_exists" '[[ -f "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md" ]]'
check "jev_skill_name" 'grep -q "name: jev-judgment" "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md"'
check "jev_skill_system" 'grep -q "system: true" "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md"'

# --- Test 2: All 3 templates exist and contain required placeholders ---
for tmpl in noul choice score; do
  check "${tmpl}_template_exists" '[[ -f "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt" ]]'
  check "${tmpl}_has_state" 'grep -q "STATE" "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt"'
  check "${tmpl}_has_question" 'grep -q "QUESTION" "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt"'
done
check "choice_has_options" 'grep -q "OPTIONS" "$PLUGIN_ROOT/lib/jev_templates/choice.txt"'

# --- Test 3: bias-check references jev-judgment ---
check "bias_check_jev" 'grep -q "jev-judgment\|Jev\|jev" "$PLUGIN_ROOT/system_files/.claude/skills/bias-check/SKILL.md"'
check "bias_check_noul" 'grep -q "noul\|Noul" "$PLUGIN_ROOT/system_files/.claude/skills/bias-check/SKILL.md"'

# --- Test 4: stage-transition-check references jev ---
check "stage_check_jev" 'grep -qi "jev" "$PLUGIN_ROOT/system_files/.claude/skills/stage-transition-check/SKILL.md"'

# --- Test 5: validator.md has parallel fan-out ---
check "validator_parallel" 'grep -q "병렬\|Parallel\|parallel\|fan-out\|Fan-Out" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'
check "validator_synthesis" 'grep -q "합성\|Synthesis\|synthesis\|통합" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'
check "validator_fallback" 'grep -qi "fallback\|순차" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'

# --- Test 6: session-start.sh has Ollaya check ---
check "hook_ollaya" 'grep -qi "ollaya\|OLLAYA\|11434" "$PLUGIN_ROOT/system_files/.claude/hooks/session-start.sh"'

# --- Test 7: router is sourceable without error ---
check "router_sourceable" 'bash -c "source $PLUGIN_ROOT/lib/local_llm_router.sh && type ollaya_available >/dev/null 2>&1"'
check "router_has_query" 'bash -c "source $PLUGIN_ROOT/lib/local_llm_router.sh && type local_llm_query >/dev/null 2>&1"'

# --- Test 8: migrate.sh has local_llm merge function ---
check "migrate_local_llm" 'grep -q "local_llm\|_logs" "$PLUGIN_ROOT/lib/migrate.sh"'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
