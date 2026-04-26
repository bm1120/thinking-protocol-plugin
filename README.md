# thinking-protocol-plugin

System layer plugin for the Thinking-Protocol Second Brain vault (`bm1120/thinking-protocol-vault`).

This plugin ships skills, agents, hooks, Core protocol files, and the research-feed fetch script. It is paired with the vault scaffold but distributed independently so existing vaults can receive system-layer updates via `/migrate`.

## Install

In a vault session:

```
/plugin install bm1120/thinking-protocol-plugin
/migrate
```

For new vaults: clone the scaffold (`bm1120/thinking-protocol-vault`) first, run `./setup.sh`, then install this plugin and run `/migrate`.

For existing v0.1-v0.3 vaults: this is the migration path. `/migrate` auto-detects existing vault, creates `_backup/<timestamp>/` of all system files, then overwrites with v0.4.0 versions. Forked system files (`system: false` in frontmatter) are preserved.

## Update

```
/plugin update
/migrate
```

`/migrate` is idempotent: same backup+overwrite logic. `system: false` files are skipped.

A SessionStart hook reminds you when vault VERSION ≠ plugin VERSION.

## Uninstall

```
/plugin uninstall thinking-protocol-plugin
```

This removes the plugin and Claude Code auto-cleans `${CLAUDE_PLUGIN_DATA}`. System files already deposited in your vault (`.claude/`, `Core_Thinking_Protocol.md`, etc.) remain — they are your vault's content. To remove them, delete or roll back from `_backup/<latest>/`.

<!-- TASK-11-FULL-CONTENT: full Uninstall flow elaboration replaces this section -->

## Rollback

The most recent `/migrate` invocation creates a backup at `_backup/<timestamp>/`. To rollback:

```
cp -r _backup/<latest_timestamp>/* .
./setup.sh --verify
```

After rollback, optionally `/plugin uninstall thinking-protocol-plugin`.

<!-- TASK-11-FULL-CONTENT: full Rollback flow elaboration replaces this section -->

## Versioning

Plugin VERSION = vault scaffold VERSION (synchronized SemVer).

See `CHANGELOG.md` for release history.
