#!/usr/bin/env bash
# tests/test_migration.sh — /migrate (greenfield) → fork-toggle → /migrate (migration).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATE_CMD="$PLUGIN_ROOT/commands/migrate.sh"

WORK="$(mktemp -d)"
trap "rm -rf $WORK" EXIT
cd "$WORK"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# 1. Greenfield install via /migrate (decline cron with "n")
echo "n" | bash "$MIGRATE_CMD"
check "greenfield_version" '[[ "$(cat VERSION)" == "0.4.0" ]]'
check "greenfield_agents" '[[ -d .claude/agents ]] && [[ $(ls .claude/agents | wc -l) -ge 6 ]]'
check "greenfield_skills" '[[ -d .claude/skills ]] && [[ $(ls .claude/skills | wc -l) -ge 16 ]]'
check "gitignore_backup" 'grep -qxF "_backup/" .gitignore'

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

# 4. Run /migrate again (vault detected → migration mode), decline cron
echo "n" | bash "$MIGRATE_CMD"

# 5. Assertions
check "post_migration_version" '[[ "$(cat VERSION)" == "0.4.0" ]]'
check "backup_created" '[[ -d _backup ]] && [[ $(ls _backup | wc -l) -ge 1 ]]'
latest_backup="$(ls -1d _backup/*/ | tail -1)"
check "manifest_present" '[[ -f "${latest_backup}_manifest.txt" ]]'
check "skipped_log_has_fork" 'grep -q "framer.md" "${latest_backup}_skipped_forks.txt"'
check "fork_preserved" 'grep -q "USER FORK CONTENT" "$fork_target"'
check "non_fork_overwritten" '! grep -q "USER FORK CONTENT" .claude/agents/researcher.md'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
