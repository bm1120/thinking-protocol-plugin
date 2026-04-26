#!/usr/bin/env bash
# commands/migrate.sh — Entry point for /migrate slash command.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/lib/migrate.sh"

PLUGIN_VERSION="$(cat "$PLUGIN_ROOT/VERSION")"

if detect_vault; then
  echo "Existing vault detected. Migration flow."
  VAULT_VERSION="$(cat VERSION 2>/dev/null || echo "0.0.0")"

  if [[ "$VAULT_VERSION" == "$PLUGIN_VERSION" ]]; then
    echo "Already up to date at $PLUGIN_VERSION."
    register_cron_if_consented || true
    exit 0
  fi

  if [[ "$(printf '%s\n%s' "$VAULT_VERSION" "$PLUGIN_VERSION" | sort -V | tail -1)" == "$VAULT_VERSION" ]] \
       && [[ "$VAULT_VERSION" != "$PLUGIN_VERSION" ]]; then
    echo "WARNING: vault VERSION ($VAULT_VERSION) > plugin VERSION ($PLUGIN_VERSION)."
    echo "Continue anyway? [y/N]"
    read -r ans || ans=""
    [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "Aborted (no confirmation)."; exit 1; }
  fi

  ts="$(date +%Y-%m-%d-%H%M%S)"
  backup_dir="_backup/$ts"
  echo "Creating backup at $backup_dir/..."
  do_backup "$backup_dir"

  echo "Overwriting system files..."
  do_overwrite "$backup_dir"

  write_gitignore_entries
  echo "$PLUGIN_VERSION" > VERSION

  echo ""
  echo "Migration complete: $VAULT_VERSION → $PLUGIN_VERSION"
  echo "Backup: $backup_dir/"
  echo "Skipped (forked) — see $backup_dir/_skipped_forks.txt"
  echo ""

  register_cron_if_consented || true

  echo ""
  echo "Run ./setup.sh --verify to confirm 8/8."
  exit 0
fi

# Greenfield mode
echo "Greenfield install — copying system files."
cp -rp "$PLUGIN_ROOT/system_files/." .
write_gitignore_entries
[[ -f VERSION ]] || echo "$PLUGIN_VERSION" > VERSION
chmod +x .claude/hooks/*.sh 2>/dev/null || true

register_cron_if_consented || true

echo "Greenfield install complete. VERSION=$PLUGIN_VERSION"
echo "Run ./setup.sh --verify (if scaffold present) to confirm 8/8."
