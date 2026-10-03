#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# L4: Incubation
check "mutate_template" '[[ -f "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt" ]]'
check "mutate_no_eval" 'grep -q "NO ranking" "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt"'
check "mutate_placeholder" 'grep -q "IDEAS" "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt"'
check "incubator_track_b" 'grep -qi "Track B\|Machine Incubation" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_fresh_agent" 'grep -qi "Fresh Agent\|Outsider\|Inverter\|Connector" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_illuminate" 'grep -qi "Illuminate\|AskUserQuestion" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_buffer_only" 'grep -q "_incubation_buffer" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'

# L5: Metrics & Retrospective
check "retro_skill_exists" '[[ -f "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md" ]]'
check "retro_skill_name" 'grep -q "name: decision-retrospective" "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md"'
check "retro_premortem" 'grep -qi "premortem\|recall" "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md"'
check "presenter_metrics" 'grep -qi "decision_log\|Decision Metrics\|metrics" "$PLUGIN_ROOT/system_files/.claude/agents/presenter.md"'
check "hook_retro" 'grep -qi "RETRO\|retrospective\|회고" "$PLUGIN_ROOT/system_files/.claude/hooks/session-start.sh"'

# L6: Tribunal
check "provider_adapter" '[[ -f "$PLUGIN_ROOT/lib/provider_adapter.sh" ]]'
check "provider_detect" 'grep -q "detect_providers" "$PLUGIN_ROOT/lib/provider_adapter.sh"'
check "provider_sourceable" 'bash -c "source $PLUGIN_ROOT/lib/provider_adapter.sh && type detect_providers >/dev/null 2>&1"'
check "validator_tribunal" 'grep -qi "Tribunal\|tribunal" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'

# Migration
check "migrate_decision_log" 'grep -q "_decision_log\|decision_log" "$PLUGIN_ROOT/lib/migrate.sh"'
check "migrate_incubation_buffer" 'grep -q "_incubation_buffer\|incubation_buffer" "$PLUGIN_ROOT/lib/migrate.sh"'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
