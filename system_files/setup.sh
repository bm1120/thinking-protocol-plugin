#!/bin/bash
# setup.sh — placeholder substitution for Business SecondBrain template
# Usage:
#   ./setup.sh              # Substitute placeholders + delete .tmpl files
#   ./setup.sh --verify     # Check no .tmpl files remain, no orphan {{VAR}} markers
#   ./setup.sh --dry-run    # Print files that would change, no changes
#
# Required environment variables:
#   PROJECT_NAME      — snake_case or PascalCase ASCII (regex: ^[A-Za-z][A-Za-z0-9_]*$)
#   VAULT_ABS_PATH    — absolute path to the target vault (must be a directory)
#   DOMAIN_NAME       — PascalCase, single word (regex: ^[A-Z][A-Za-z]*$)
#   PRIMARY_DOMAINS   — 1-200 chars, no <>&
#   RECURRING_TASKS   — optional; empty or "(skip)" allowed
#
# Convenience: if `setup.env` exists in the same directory as this script,
# its variable assignments are auto-sourced before validation.
# See setup.env.example for the file format.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/setup.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  echo "Loaded environment from $ENV_FILE" >&2
fi

MODE="${1:-substitute}"

REQUIRED_VARS=("PROJECT_NAME" "VAULT_ABS_PATH" "DOMAIN_NAME" "PRIMARY_DOMAINS")

validate_env() {
  for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
      echo "ERROR: Missing required variable: $var" >&2
      echo "See SETUP.md §2 for required environment variables." >&2
      exit 1
    fi
  done

  if ! [[ "$PROJECT_NAME" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "ERROR: PROJECT_NAME='$PROJECT_NAME' fails regex ^[A-Za-z][A-Za-z0-9_]*$" >&2
    echo "Use snake_case or PascalCase ASCII (e.g., My_Vault, MyVault)." >&2
    exit 1
  fi

  if [ ! -d "$VAULT_ABS_PATH" ]; then
    echo "ERROR: VAULT_ABS_PATH='$VAULT_ABS_PATH' is not an existing directory" >&2
    exit 1
  fi

  if ! [[ "$DOMAIN_NAME" =~ ^[A-Z][A-Za-z]*$ ]]; then
    echo "ERROR: DOMAIN_NAME='$DOMAIN_NAME' fails regex ^[A-Z][A-Za-z]*$" >&2
    echo "Use PascalCase single word (e.g., Marketing, Engineering)." >&2
    exit 1
  fi

  local len=${#PRIMARY_DOMAINS}
  if [ "$len" -lt 1 ] || [ "$len" -gt 200 ]; then
    echo "ERROR: PRIMARY_DOMAINS length ($len) must be 1-200 chars" >&2
    exit 1
  fi
  if [[ "$PRIMARY_DOMAINS" =~ [\<\>\&] ]]; then
    echo "ERROR: PRIMARY_DOMAINS contains forbidden chars (<, >, &)" >&2
    exit 1
  fi

  RECURRING_TASKS="${RECURRING_TASKS:-}"
  if [ "$RECURRING_TASKS" = "(skip)" ]; then
    RECURRING_TASKS=""
  fi
}

find_tmpl_files() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  find "$dir" -type f -name "*.tmpl"
}

substitute_file() {
  local tmpl="$1"
  local target="${tmpl%.tmpl}"

  target="${target//<Domain>/$DOMAIN_NAME}"

  sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{VAULT_ABS_PATH}}|$VAULT_ABS_PATH|g" \
      -e "s|{{DOMAIN_NAME}}|$DOMAIN_NAME|g" \
      -e "s|{{PRIMARY_DOMAINS}}|$PRIMARY_DOMAINS|g" \
      -e "s|{{RECURRING_TASKS}}|$RECURRING_TASKS|g" \
      "$tmpl" > "$target"
  rm "$tmpl"
}

case "$MODE" in
  --verify)
    remaining_tmpl=$(find_tmpl_files | wc -l | tr -d ' ')
    if [ "$remaining_tmpl" -gt 0 ]; then
      echo "FAIL: $remaining_tmpl .tmpl files remain (setup not run or partial):" >&2
      find_tmpl_files >&2
      exit 1
    fi

    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # setup.sh, tests/, and skill/agent docs legitimately contain {{VAR}} patterns
    # (sed commands, test fixtures, documentation examples) — exclude them from the
    # orphan scan to avoid false positives. The scan still covers all template-output
    # files (CLAUDE.md, settings.json, <Domain>_Context.md, hook .sh, etc.).
    # `|| true` is required because grep exits 1 on zero matches (the normal
    # success case here); under `set -euo pipefail` that would otherwise abort
    # the script with no diagnostic.
    orphans=$( (grep -rE "\{\{[A-Z_]+\}\}" "$dir" --include="*.md" --include="*.json" --include="*.sh" --exclude="setup.sh" --exclude-dir="tests" --exclude-dir="skills" --exclude-dir="agents" 2>/dev/null || true) | wc -l | tr -d ' ')
    if [ "$orphans" -gt 0 ]; then
      echo "FAIL: $orphans orphan {{VAR}} markers found:" >&2
      grep -rEn "\{\{[A-Z_]+\}\}" "$dir" --include="*.md" --include="*.json" --include="*.sh" --exclude="setup.sh" --exclude-dir="tests" --exclude-dir="skills" --exclude-dir="agents" 2>/dev/null >&2
      exit 1
    fi

    echo "PASS: setup verified — no .tmpl files, no orphan placeholders"
    ;;

  --dry-run)
    validate_env
    echo "Dry run — files that would be substituted:"
    find_tmpl_files | while read tmpl; do
      target="${tmpl%.tmpl}"
      target="${target//<Domain>/$DOMAIN_NAME}"
      echo "  $tmpl → $target"
    done
    ;;

  substitute)
    validate_env

    tmpl_count=$(find_tmpl_files | wc -l | tr -d ' ')
    if [ "$tmpl_count" -eq 0 ]; then
      echo "Already setup — no .tmpl files to process. (Re-run is a no-op.)"
      exit 0
    fi

    dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    backup_dir="$dir/.bak"

    if [ -d "$backup_dir" ]; then
      rm -rf "$backup_dir"
    fi
    mkdir -p "$backup_dir"
    while IFS= read -r tmpl; do
      cp "$tmpl" "$backup_dir/$(basename "$tmpl")"
    done < <(find_tmpl_files)

    error=0
    while IFS= read -r tmpl; do
      if ! substitute_file "$tmpl"; then
        echo "ERROR: substitution failed on $tmpl" >&2
        error=1
        break
      fi
    done < <(find_tmpl_files)

    if [ "$error" -eq 1 ]; then
      echo "Rolling back from $backup_dir..." >&2
      cp "$backup_dir"/*.tmpl "$dir/" 2>/dev/null || true
      exit 1
    fi

    rm -rf "$backup_dir"

    bash "$0" --verify
    ;;

  *)
    echo "Unknown mode: $MODE" >&2
    echo "Usage: $0 [--verify | --dry-run | (no arg = substitute)]" >&2
    exit 2
    ;;
esac
