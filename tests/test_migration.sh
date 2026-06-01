#!/usr/bin/env bash
# tests/test_migration.sh — /migrate (greenfield) → fork-toggle → /migrate (migration).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATE_CMD="$PLUGIN_ROOT/commands/migrate.sh"
EXPECTED_VERSION="$(cat "$PLUGIN_ROOT/VERSION")"

WORK="$(mktemp -d)"
trap "rm -rf $WORK" EXIT
cd "$WORK"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# 1. Greenfield install via /migrate (decline cron with "n")
GREENFIELD_OUT="$(echo "n" | bash "$MIGRATE_CMD")"
check "claudemem_notice" 'echo "$GREENFIELD_OUT" | grep -q "claude-mem"'
check "greenfield_version" '[[ "$(cat VERSION)" == "$EXPECTED_VERSION" ]]'
check "greenfield_agents" '[[ -d .claude/agents ]] && [[ $(ls .claude/agents | wc -l) -ge 6 ]]'
check "greenfield_skills" '[[ -d .claude/skills ]] && [[ $(ls .claude/skills | wc -l) -ge 16 ]]'
check "gitignore_backup" 'grep -qxF "_backup/" .gitignore'

# 1b. Greenfield settings.json carries claude-mem search permissions
check "claudemem_smart_search" 'grep -q "mcp__plugin_claude-mem_mcp-search__smart_search" .claude/settings.json'
check "claudemem_search"       'grep -q "mcp__plugin_claude-mem_mcp-search__search" .claude/settings.json'
check "claudemem_get_obs"      'grep -q "mcp__plugin_claude-mem_mcp-search__get_observations" .claude/settings.json'

# 2. Toggle one agent to forked (use a real plugin-shipped file)
fork_target=".claude/agents/framer.md"
if [[ -f "$fork_target" ]]; then
  sed -i.bak 's/^system: true$/system: false/' "$fork_target"
  echo "USER FORK CONTENT" >> "$fork_target"
  rm -f "$fork_target.bak"
  check "fork_toggled" 'grep -q "^system: false$" "$fork_target"'
fi

# 3. Simulate version skew: drop vault VERSION
echo "0.3.0" > VERSION

# 3b. Simulate an existing vault whose settings.json predates claude-mem perms
python3 - <<'PY'
import json
p=".claude/settings.json"
d=json.load(open(p))
allow=d["permissions"]["allow"]
d["permissions"]["allow"]=[a for a in allow if "claude-mem" not in a]
json.dump(d, open(p,"w"), indent=2, ensure_ascii=False)
PY
check "premerge_stripped" '! grep -q "claude-mem" .claude/settings.json'

# 4. Run /migrate again (vault detected → migration mode), decline cron
echo "n" | bash "$MIGRATE_CMD"

# 4b. Migration MERGE: claude-mem perms restored, no dupes, valid JSON
check "merge_smart_search" 'grep -q "mcp__plugin_claude-mem_mcp-search__smart_search" .claude/settings.json'
check "merge_search"       'grep -q "mcp__plugin_claude-mem_mcp-search__search" .claude/settings.json'
check "merge_get_obs"      'grep -q "mcp__plugin_claude-mem_mcp-search__get_observations" .claude/settings.json'
check "merge_no_dupe"      '[[ "$(grep -c "mcp__plugin_claude-mem_mcp-search__smart_search" .claude/settings.json)" == "1" ]]'
check "merge_valid_json"   'python3 -c "import json;json.load(open(\".claude/settings.json\"))"'

# 4c. Merge degrades gracefully on malformed settings.json (does not abort)
MALDIR="$(mktemp -d)"; mkdir -p "$MALDIR/.claude"
printf '{ this is not valid json ' > "$MALDIR/.claude/settings.json"
( cd "$MALDIR" && source "$PLUGIN_ROOT/lib/migrate.sh" && merge_claude_mem_permissions ) 2>/dev/null
rc=$?
check "merge_malformed_ok" '[[ '"$rc"' -eq 0 ]]'
check "merge_malformed_untouched" 'grep -q "this is not valid json" "$MALDIR/.claude/settings.json"'
rm -rf "$MALDIR"

# 5. Assertions
check "post_migration_version" '[[ "$(cat VERSION)" == "$EXPECTED_VERSION" ]]'
check "backup_created" '[[ -d _backup ]] && [[ $(ls _backup | wc -l) -ge 1 ]]'
latest_backup="$(ls -1d _backup/*/ | tail -1)"
check "manifest_present" '[[ -f "${latest_backup}_manifest.txt" ]]'
check "skipped_log_has_fork" 'grep -q "framer.md" "${latest_backup}_skipped_forks.txt"'
check "fork_preserved" 'grep -q "USER FORK CONTENT" "$fork_target"'
check "non_fork_overwritten" '! grep -q "USER FORK CONTENT" .claude/agents/researcher.md'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
