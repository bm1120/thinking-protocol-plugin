#!/usr/bin/env bash
# tests/test_layer_marking.sh — Verify lib/classify.sh recognizes system / user / fork / fallback.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/lib/classify.sh"

PASS=0
FAIL=0

assert_class() {
  local label="$1" path="$2" expected="$3" actual
  actual="$(classify_file "$path")"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS+1))
    echo "PASS: $label ($expected)"
  else
    FAIL=$((FAIL+1))
    echo "FAIL: $label — expected '$expected', got '$actual' for $path"
  fi
}

WORK="$(mktemp -d)"
trap "rm -rf $WORK" EXIT

# Case 1: system: true in frontmatter
mkdir -p "$WORK/.claude/skills/foo"
cat > "$WORK/.claude/skills/foo/SKILL.md" <<'INNER'
---
name: foo
system: true
---

# foo
INNER
assert_class "skill_with_system_true" "$WORK/.claude/skills/foo/SKILL.md" "system"

# Case 2: system: false (fork)
mkdir -p "$WORK/.claude/skills/bar"
cat > "$WORK/.claude/skills/bar/SKILL.md" <<'INNER'
---
name: bar
system: false
forked_from: 0.4.0
---

# bar (forked)
INNER
assert_class "skill_with_system_false" "$WORK/.claude/skills/bar/SKILL.md" "system-fork"

# Case 3: no frontmatter, system path → fallback to system
mkdir -p "$WORK/.claude/skills/baz"
echo "no frontmatter here" > "$WORK/.claude/skills/baz/SKILL.md"
assert_class "skill_no_frontmatter_path_fallback" "$WORK/.claude/skills/baz/SKILL.md" "system"

# Case 4: user content directory
mkdir -p "$WORK/00_Idea_Inbox"
echo "user note" > "$WORK/00_Idea_Inbox/note.md"
assert_class "user_content_dir" "$WORK/00_Idea_Inbox/note.md" "user"

# Case 5: hybrid append-only
echo "log" > "$WORK/CHANGELOG.md"
assert_class "changelog_hybrid" "$WORK/CHANGELOG.md" "hybrid"

# Case 6: excluded
mkdir -p "$WORK/_backup/2026-04-26-1000"
echo "old" > "$WORK/_backup/2026-04-26-1000/some.md"
assert_class "backup_excluded" "$WORK/_backup/2026-04-26-1000/some.md" "excluded"

# Case 7: settings.json — always fork-respecting
echo '{}' > "$WORK/.claude/settings.json"
assert_class "settings_always_fork" "$WORK/.claude/settings.json" "system-fork"

# Case 8: hook script with marker (path-only fallback, no frontmatter possible)
mkdir -p "$WORK/.claude/hooks"
cat > "$WORK/.claude/hooks/session-start.sh" <<'INNER'
#!/usr/bin/env bash
# managed-by: thinking-protocol-plugin
echo hi
INNER
assert_class "hook_with_marker" "$WORK/.claude/hooks/session-start.sh" "system"

# Case 9: agent with system: true
mkdir -p "$WORK/.claude/agents"
cat > "$WORK/.claude/agents/test.md" <<'INNER'
---
name: test
system: true
---

agent
INNER
assert_class "agent_with_system_true" "$WORK/.claude/agents/test.md" "system"

# Case 10: domain context (always user)
echo "domain stuff" > "$WORK/MyDomain_Context.md"
assert_class "domain_context_always_user" "$WORK/MyDomain_Context.md" "user"

# Case 11 (added per Task 3 fix-up review): trailing whitespace in system: false
mkdir -p "$WORK/.claude/agents-trailing"
cat > "$WORK/.claude/agents/forked-trailing.md" <<'INNER'
---
name: trailing-fork
system: false   
---

content
INNER
assert_class "fork_with_trailing_whitespace" "$WORK/.claude/agents/forked-trailing.md" "system-fork"

# Case 12 (added per Task 3 fix-up review): quoted system value
cat > "$WORK/.claude/agents/forked-quoted.md" <<'INNER'
---
name: quoted-fork
system: "false"
---

content
INNER
assert_class "fork_with_quoted_value" "$WORK/.claude/agents/forked-quoted.md" "system-fork"

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
