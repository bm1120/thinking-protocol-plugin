# CHANGELOG

This file mirrors `_template/CHANGELOG.md` from the source vault. Entries here cover only releases of this plugin; full history with Watch list lives in the source vault.

## v0.5.1 — 2026-06-01 — Migration claude-mem permission merge

- **kind: fix** — /migrate(마이그레이션 경로)가 기존 볼트의 `.claude/settings.json`에 claude-mem 검색 권한 3종을 멱등 머지하도록 추가. .tmpl은 greenfield에서만 렌더되어 기존 볼트엔 전파되지 않던 문제 수정.

## v0.5.0 — 2026-06-01 — claude-mem dual-source recall + Diverge parallelization

- **kind: skill** — recall을 이중소스로 업그레이드(볼트 파일 + claude-mem 세션 회상). claude-mem 미설치 시 볼트 파일 검색만 수행하며 graceful degrade. 출처 분리 2-섹션 출력.
- **kind: rule** — ideator(Diverge)를 3기법 블라인드 병렬 fan-out으로 전환. 병렬 불가 시 순차 폴백. 쓰기는 병합자 ideator만.
- settings 템플릿에 claude-mem 검색 권한 3종 추가. /migrate가 claude-mem 활성화 안내 출력.
- Source: docs/superpowers/specs/2026-05-31-claude-mem-memory-and-diverge-parallelization-design.md

## v0.4.1 — 2026-05-24 — Research feed pre-filter + public-release prep

Synced from source vault (Phase 7-3) and prepared for public release.

### Synced from source vault

- `system_files/scripts/fetch_research.py` — research-feed pre-filter (evidence-based filtering to cut human triage cost).

### Public-release prep

- **LICENSE**: added MIT (`plugin.json` license `UNLICENSED` → `MIT`).
- **Plugin spec compliance**: moved manifest to `.claude-plugin/plugin.json` (was at repo root — would not be recognized) and added `.claude-plugin/marketplace.json` so the repo self-hosts as its own marketplace.
- **README**: corrected the install path (two-step `marketplace add` → `install <name>@<marketplace>`; the old single-line `/plugin install owner/repo` did not work) and restructured around Why / What's different / vault–plugin separation.
- **Privacy**: removed a hardcoded personal absolute path from `system_files/.claude/hooks/session-start.sh` (`CLAUDE_PROJECT_DIR` fallback now `$(pwd)`).
- **Tests**: `test_migration.sh` version assertions now read from `VERSION` instead of a hardcoded `0.4.0` (were failing 2/11 after the version bump; now 11/11).

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
