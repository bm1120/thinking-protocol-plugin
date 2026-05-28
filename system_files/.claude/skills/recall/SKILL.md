---
name: recall
description: Retrieve relevant past work from this vault before starting new work or a decision. Runs a structure-aware search that prioritizes by document purpose (insights/decisions/KB/analyses/inbox) and degrades gracefully on vaults missing optional layers. Proposes pointers only — never writes memos.
system: true
---

# recall

Use when starting an analysis or non-trivial decision and you want to know what prior work in this vault relates ("have we done/decided/known this before?").

## Procedure

1. Run the engine from the vault root:
   ```
   python3 .claude/skills/recall/recall.py "<the user's question>"
   ```
   (Plugin install path: `${CLAUDE_PLUGIN_ROOT}/system_files/.claude/skills/recall/recall.py`.)
2. Read the ranked pointers it returns. Each line: `[layer] path — why — confidence`.
3. Open the top 1-3 hits with the Read tool to confirm relevance before citing them.
4. Report the relevant connections to the user as pointers. If output says "Low connection density," tell the user this may be genuinely new — do not invent links.

## Rules
- **Pointers only.** This skill surfaces past work; it never writes or edits memos. The human authors.
- **Confirm before citing.** A filename match is not proof; Read the file.
- **Honest empty result.** If nothing relevant, say so — do not pad.

## Anti-patterns
- ❌ Treating a weak keyword hit as an established connection.
- ❌ Writing the linking prose for the user.
- ❌ Failing on a vault without `insights/` — the engine skips absent layers by design.
