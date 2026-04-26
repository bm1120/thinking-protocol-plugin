# CHANGELOG

This file mirrors `_template/CHANGELOG.md` from the source vault. Entries here cover only releases of this plugin; full history with Watch list lives in the source vault.

## v0.4.0 — 2026-04-26 — Initial plugin release

Phase 7-2 deliverable: hybrid distribution model.

### What's included

- 16 skills (port-vault excluded — source-vault-only)
- 6 subagents (framer, ideator, incubator, validator, presenter, researcher)
- 1 vault-side hook (session-start.sh — staleness reminder + dispatch hint)
- 3 protocol docs (Core_Thinking_Protocol, Stage_Transition_Rules, Research_Integration_Protocol)
- 1 fetch script (fetch_research.py — research feed Step 1)
- `/migrate` slash command (greenfield + migration with auto-backup + fork detection + cron prompt)
- Plugin SessionStart hook (`hooks/plugin-session-start.sh`) for VERSION skew reminder

### Closes

- Watch 18 (template upgrade gap)
- Watch 19 partial (Step 1 cron automation + structural researcher subagent surfacing)

### See also

Source vault `_template/CHANGELOG.md` v0.4.0 entry for full release context, including Watch list deltas (20-24 new).
