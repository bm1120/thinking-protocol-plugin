# thinking-protocol-plugin

> Personal project, WIP. Shared as a thinking artifact, not a supported product.

A Claude Code system layer that makes an AI assistant run a **six-stage decision protocol** instead of jumping straight to an answer:

**Frame → Diverge → Incubate → Illuminate → Converge → Decide**

It ships the skills, subagents, hooks, and Core protocol files that turn a plain vault into a decision-discipline environment — plus a `/migrate` command to install and update them.

## Why

Most "second brain" tooling optimizes for *capture*. This optimizes for *how a decision is reached*.

The bet behind it: as AI automates the mechanics of analysis, the durable skill is no longer producing an answer fast — it's **framing the right question, resisting premature convergence, and separating correlation from cause**. So the protocol deliberately slows the model down at the points where human judgment usually collapses:

- It **separates divergent and convergent thinking** — never evaluating ideas while generating them.
- It **refuses to skip incubation** on non-trivial decisions, even under "just decide now" pressure.
- It applies **causal scrutiny** before any "X improves Y" claim — surfacing confounders and counterfactuals.
- It **abstains** rather than asserting psychology/neuroscience claims it can't trace to a source.

These aren't arbitrary rules. The protocol is grounded in cognitive psychology and neuroscience — e.g. incubation is modeled on hippocampal-cortical replay during rest, not treated as mysticism (see `system_files/Core_Thinking_Protocol.md`). That grounding is the point of difference from generic note/agent setups.

## What's different

| Typical second-brain / agent setup | This plugin |
|---|---|
| Captures notes; you decide how to think | Encodes *how to think* as an enforced protocol |
| Single "do the task" pass | Six stages with explicit mode separation |
| Asserts confidently | Cites or says "근거 없음" (no basis) |
| Generic prompts | Skills grounded in decision science (bias-check, premortem, causal-reasoning-check, JTBD, …) |

## vault and plugin are separate — on purpose

- **`thinking-protocol-vault`** (private) — *my* thinking. Personal notes, decisions, domain context.
- **`thinking-protocol-plugin`** (this repo, public) — the reusable *system layer* only: protocol, skills, agents, hooks.

The split is the privacy model: **thinking stays private, the method is shared.** This repo contains no personal notes — only the machinery.

## Install

This repo is its own plugin marketplace. Two steps:

```
/plugin marketplace add bm1120/thinking-protocol-plugin
/plugin install thinking-protocol-plugin@thinking-protocol
```

Then, from a vault directory:

```
/migrate
```

- **New vault**: clone the scaffold (`bm1120/thinking-protocol-vault`), run `./setup.sh`, then the steps above.
- **Existing v0.1–v0.3 vault**: `/migrate` is the upgrade path. It auto-detects the vault, snapshots all system files to `_backup/<timestamp>/`, then overwrites with the current versions. Forked files (`system: false` in frontmatter) are preserved and listed in `_skipped_forks.txt`.

A SessionStart hook reminds you when vault VERSION ≠ plugin VERSION.

### Requirements

- Claude Code with plugin support
- `bash`, `python3` (research-feed fetch)
- `jq` optional — hooks degrade gracefully without it

## Update

```
/plugin update
/migrate
```

`/migrate` is idempotent: same backup-then-overwrite logic, `system: false` files skipped.

## Uninstall

```
/plugin uninstall thinking-protocol-plugin
```

Claude Code auto-cleans `${CLAUDE_PLUGIN_DATA}`. System files already deposited in your vault (`.claude/`, `Core_Thinking_Protocol.md`, …) remain — they're your vault's content now. To remove them, roll back from `_backup/<latest>/`.

## Rollback

The most recent `/migrate` creates `_backup/<timestamp>/`:

```bash
# From vault root
ls _backup/                       # find latest timestamp
cp -rp _backup/<timestamp>/. .    # restore (note trailing /. for dotfiles)
./setup.sh --verify               # confirm 8/8 PASS
```

Backups accumulate; prune manually with `rm -rf _backup/2026-*` if needed.

## Versioning

Plugin VERSION = vault scaffold VERSION (synchronized SemVer). See `CHANGELOG.md` for release history.

## License

MIT — see `LICENSE`.
