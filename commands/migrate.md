---
name: migrate
description: Bootstrap or migrate this vault's system layer (skills/agents/hooks/Core protocol). Greenfield install OR existing-vault migration with auto-backup. Idempotent.
---

# /migrate

Run from a vault directory. The command:

1. Detects whether this is a fresh vault (no system files) or existing v0.x vault.
2. **Greenfield:** copies plugin system_files/* into vault paths. Initializes VERSION, .gitignore.
3. **Migration:** creates `_backup/<timestamp>/` snapshot of all current system files, then overwrites with plugin versions. Forked files (`system: false` frontmatter) are preserved + listed in `_skipped_forks.txt`.
4. After migration, prompts to schedule the research feed fetch via crontab (idempotent).

Backup location: `_backup/<YYYY-MM-DD-HHMMSS>/`.
Rollback: `cp -r _backup/<latest>/* .` then `./setup.sh --verify`.
