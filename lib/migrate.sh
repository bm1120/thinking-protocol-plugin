#!/usr/bin/env bash
# lib/migrate.sh — shared migration logic. Sourced by commands/migrate.sh.
# Exports: detect_vault, do_backup, do_overwrite, write_gitignore_entries,
# register_cron_if_consented, merge_claude_mem_permissions.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/lib/classify.sh"

# Returns 0 if cwd looks like a thinking-protocol vault (has system files), 1 otherwise.
detect_vault() {
  [[ -d ".claude" || -f "Core_Thinking_Protocol.md" ]]
}

# Args: $1 = backup_dir
do_backup() {
  local backup_dir="$1"
  mkdir -p "$backup_dir"
  local manifest="$backup_dir/_manifest.txt"
  : > "$manifest"

  while IFS= read -r src; do
    local rel="${src#$PLUGIN_ROOT/system_files/}"
    case "$rel" in *.tmpl|setup.sh) continue ;; esac
    if [[ -f "$rel" ]]; then
      local class="$(classify_file "$rel")"
      if [[ "$class" == "system" ]]; then
        mkdir -p "$backup_dir/$(dirname "$rel")"
        cp -p "$rel" "$backup_dir/$rel"
        echo "$rel" >> "$manifest"
      fi
    fi
  done < <(find "$PLUGIN_ROOT/system_files" -type f)
}

# Args: $1 = backup_dir (for skipped log)
do_overwrite() {
  local backup_dir="$1"
  local skipped_log="$backup_dir/_skipped_forks.txt"
  : > "$skipped_log"
  local migrated=0 skipped=0

  while IFS= read -r src; do
    local rel="${src#$PLUGIN_ROOT/system_files/}"
    case "$rel" in *.tmpl|setup.sh) continue ;; esac
    local class="system"
    if [[ -f "$rel" ]]; then
      class="$(classify_file "$rel")"
    fi
    case "$class" in
      system)
        mkdir -p "$(dirname "$rel")"
        cp -p "$src" "$rel"
        migrated=$((migrated+1))
        ;;
      system-fork)
        echo "$rel" >> "$skipped_log"
        skipped=$((skipped+1))
        ;;
    esac
  done < <(find "$PLUGIN_ROOT/system_files" -type f)

  if [[ -d ".claude/hooks" ]]; then
    chmod +x .claude/hooks/*.sh 2>/dev/null || true
  fi

  echo "migrated: $migrated"
  echo "skipped (forked): $skipped"
}

write_gitignore_entries() {
  for entry in "_backup/" "_logs/"; do
    if [[ -f .gitignore ]]; then
      grep -qxF "$entry" .gitignore || echo "$entry" >> .gitignore
    else
      echo "$entry" > .gitignore
    fi
  done
}

# Idempotently merge claude-mem search permissions into the existing vault's
# .claude/settings.json. Operates on the cwd (vault root). .tmpl files are only
# rendered in the greenfield path, so existing vaults need this injection.
# No-op if settings.json is absent (greenfield handles new vaults).
merge_claude_mem_permissions() {
  local settings=".claude/settings.json"
  [[ -f "$settings" ]] || return 0
  python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        d = json.load(f)
    allow = d.setdefault("permissions", {}).setdefault("allow", [])
    wanted = [
        "mcp__plugin_claude-mem_mcp-search__smart_search",
        "mcp__plugin_claude-mem_mcp-search__search",
        "mcp__plugin_claude-mem_mcp-search__get_observations",
    ]
    missing = [w for w in wanted if w not in allow]
    if missing:
        # insert before the first WebFetch/WebSearch entry to mirror template ordering
        idx = next((i for i, a in enumerate(allow) if a in ("WebFetch", "WebSearch")), len(allow))
        allow[idx:idx] = missing
        with open(p, "w") as f:
            json.dump(d, f, indent=2, ensure_ascii=False)
            f.write("\n")
except Exception as e:
    sys.stderr.write("WARN: could not merge claude-mem permissions into %s (%s); left unchanged.\n" % (p, e))
    sys.exit(0)
PY
}

# Idempotent: returns 0 if entry added or already present, 1 if user declined.
register_cron_if_consented() {
  local pwd_q
  printf -v pwd_q '%q' "$(pwd)"
  local cmd="cd $pwd_q && python3 scripts/fetch_research.py >> _logs/research-fetch.log 2>&1"
  local marker="thinking-protocol-plugin"

  if crontab -l 2>/dev/null | grep -qF "$marker"; then
    echo "Cron entry already present (research-feed-fetch). Skipping."
    return 0
  fi

  echo ""
  echo "Schedule daily research feed fetch at 09:00 (your local timezone)?"
  echo "Adds to user crontab: 0 9 * * * $cmd  # $marker"
  echo "Confirm [y/N]:"
  read -r ans || ans=""
  if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    (crontab -l 2>/dev/null; echo "0 9 * * * $cmd  # $marker") | crontab -
    echo "Cron entry added. Verify: crontab -l | grep $marker"
    return 0
  else
    echo "Cron skipped. Run python3 scripts/fetch_research.py manually."
    return 1
  fi
}
