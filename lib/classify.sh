#!/usr/bin/env bash
# lib/classify.sh — Layer classifier for thinking-protocol-plugin.
# Sourced by install/update/tests. Defines: classify_file <abs_path|rel_path>
# Outputs one of: system | user | hybrid | excluded | system-fork
# Exit code 0 always (caller handles class).
# Note: sourcing this file enables 'set -euo pipefail' in the caller.
#
# Path handling: input may be absolute (e.g. /vault/.claude/skills/foo/SKILL.md)
# or vault-relative (e.g. .claude/skills/foo/SKILL.md). The classifier
# normalizes by matching against the trailing meaningful path components,
# anchored at known top-level vault entries (.claude, scripts, 00_*, etc.).

set -euo pipefail

# Read frontmatter `system` field. Returns "true", "false", or "" (none).
_read_frontmatter_system() {
  local file="$1"
  awk '
    /^---$/ { if (in_fm) { exit } else { in_fm=1; next } }
    in_fm && /^system:/ { sub(/^system:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); sub(/^["'\'']/, ""); sub(/["'\'']$/, ""); print; exit }
  ' "$file" 2>/dev/null
}

# Read first-line marker in shell/python files. Returns 0 if present, 1 if not.
_has_first_line_marker() {
  local file="$1"
  head -2 "$file" 2>/dev/null | grep -q "managed-by: thinking-protocol-plugin"
}

# Normalize an absolute or relative path to vault-relative form by anchoring
# on a known top-level token. If no token is found, returns the basename.
_to_vault_rel() {
  local p="$1"
  # Try anchors in priority order. Longest/most-specific first is unnecessary
  # here because all anchors are unambiguous top-level entries.
  case "$p" in
    */.claude/*)   echo ".claude/${p#*/.claude/}"; return 0 ;;
    .claude/*)     echo "$p"; return 0 ;;
    */scripts/*)   echo "scripts/${p#*/scripts/}"; return 0 ;;
    scripts/*)     echo "$p"; return 0 ;;
    */_template/*) echo "_template/${p#*/_template/}"; return 0 ;;
    _template/*)   echo "$p"; return 0 ;;
    */_backup/*)   echo "_backup/${p#*/_backup/}"; return 0 ;;
    _backup/*)     echo "$p"; return 0 ;;
    */_logs/*)     echo "_logs/${p#*/_logs/}"; return 0 ;;
    _logs/*)       echo "$p"; return 0 ;;
    */.obsidian/*) echo ".obsidian/${p#*/.obsidian/}"; return 0 ;;
    .obsidian/*)   echo "$p"; return 0 ;;
    # User content directories: 00_* through 04_*
    */00_*) echo "00_${p#*/00_}"; return 0 ;;
    */01_*) echo "01_${p#*/01_}"; return 0 ;;
    */02_*) echo "02_${p#*/02_}"; return 0 ;;
    */03_*) echo "03_${p#*/03_}"; return 0 ;;
    */04_*) echo "04_${p#*/04_}"; return 0 ;;
    00_*|01_*|02_*|03_*|04_*) echo "$p"; return 0 ;;
  esac
  # Otherwise: take the basename for vault-root files (CLAUDE.md, *_Context.md,
  # CHANGELOG.md, Core_Thinking_Protocol.md, etc.). This loses any directory
  # context, which is acceptable because all remaining classifier rules are
  # basename-driven for top-level files.
  echo "${p##*/}"
}

classify_file() {
  local path="$1"
  local rel
  rel="$(_to_vault_rel "$path")"

  # Excluded paths (highest priority)
  case "$rel" in
    .obsidian/*|_backup/*|_logs/*|setup.env|*.local.*) echo "excluded"; return 0 ;;
  esac

  # Hybrid append-only files
  case "$rel" in
    CHANGELOG.md|_template/CHANGELOG.md) echo "hybrid"; return 0 ;;
  esac

  # User content directories
  case "$rel" in
    00_*|01_*|02_*|03_*|04_*) echo "user"; return 0 ;;
    [A-Z]*_Context.md) echo "user"; return 0 ;;
    CLAUDE.md) echo "user"; return 0 ;;   # v0.4 policy: vault-root CLAUDE.md = user
  esac

  # System candidates by path
  local is_system_path=0
  case "$rel" in
    .claude/skills/*/SKILL.md|.claude/agents/*.md|.claude/hooks/*.sh|.claude/settings.json) is_system_path=1 ;;
    Core_Thinking_Protocol.md|Stage_Transition_Rules.md|Research_Integration_Protocol.md) is_system_path=1 ;;
    scripts/*.py|scripts/*.sh)
      if _has_first_line_marker "$path"; then is_system_path=1; fi
      ;;
  esac

  if [[ $is_system_path -eq 0 ]]; then
    echo "user"; return 0
  fi

  # System path. Now check frontmatter for fork.
  case "$rel" in
    *.md)
      local fm
      # `|| true` so a missing/unreadable file doesn't abort under set -e.
      fm="$(_read_frontmatter_system "$path" || true)"
      if [[ "$fm" == "false" ]]; then echo "system-fork"; return 0; fi
      ;;
    .claude/settings.json)
      # Always fork-respecting per spec §3.4
      echo "system-fork"; return 0
      ;;
  esac

  echo "system"
}

# Allow sourcing or direct invocation: ./classify.sh <path>
if [[ "${BASH_SOURCE[0]}" == "${0:-}" ]]; then
  if [[ $# -lt 1 ]]; then
    echo "usage: $0 <path>" >&2; exit 2
  fi
  classify_file "$1"
fi
