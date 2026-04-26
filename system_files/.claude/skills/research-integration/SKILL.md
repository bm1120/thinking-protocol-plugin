---
name: research-integration
description: Execute the 6-step Research Integration Protocol on a single research item (feed entry, paper, blog post). Turn it into exactly one of Merge / Defer / Reject — never "read and forget".
system: true
---

# research-integration

**Invoked by:** `researcher` subagent; also directly by the user when they hand-pick a research item.
**Stage:** meta (not a decision stage; runs in parallel to the main 6-stage flow).

## When to invoke

Use this skill when:
- A new item appears in `00_Idea_Inbox/Automated_Research_Feed.md` and the user asks to "process it".
- The user pastes a paper / blog post / talk note asking "should we integrate this?".
- A `researcher` subagent decides to absorb a finding surfaced mid-flow.

Do NOT use this skill for general Q&A about a paper — that's a different, lightweight action.

## Procedure

1. **Capture** — record source (URL, DOI if available, author, year). Produce field `Source: <link/DOI>`.
2. **Extract Claim** — compress the finding to one actionable sentence of the form `"<observation> ⇒ <implied rule>"`. If you can't, archive to `04_Archives/research_rejected/<date>-<slug>.md` with reason `"not actionable"`. Produce field `Claim: <one sentence>`.
3. **Map to Stage** — which Core artifact does this claim change? Pick one of: (a) a specific Stage in `Core_Thinking_Protocol.md`, (b) a transition in `Stage_Transition_Rules.md`, (c) a note in `03_Knowledge_Base/<axis>/`, (d) a subagent or skill prompt, (e) none. If (e), archive with reason `"no stage target"`. Produce field `Target: <file + section>`.
4. **Draft Rule Change** — write a concrete before/after diff. Do not apply it yet. Produce field `Diff: <before/after>`.
5. **Shadow Test** — pick 1–2 recent entries from `04_Archives/decisions/` and apply the drafted rule retroactively. Would the outcome have been different / clearer / faster? Write 1–2 sentences per shadow case. If no decisions exist, construct a synthetic Frame-stage case. Produce field `Shadow Test: <id(s) + outcome>`.
6. **Merge or Reject or Defer**:
   - **Merge:** apply the diff; add a CHANGELOG entry in canonical schema (Kind: `research` or `rule`); commit.
   - **Reject:** archive the full draft to `04_Archives/research_rejected/<date>-<slug>.md`; add a brief CHANGELOG entry of kind `research` with rejection reason; commit.
   - **Defer:** record a concrete condition ("after 5 more decisions of type X") and re-queue to `00_Idea_Inbox/` with the condition annotated.

## Output format

A markdown block containing the 5 fields (Source / Claim / Target / Diff / Shadow Test) plus a final line: `Outcome: Merge | Reject | Defer`. If Merge or Reject, include the committed CHANGELOG entry verbatim.

## Anti-patterns

- Force-fitting a finding to a stage it doesn't address. If Map to Stage returns "none", archive.
- Skipping Shadow Test because "it's obviously right". Shadow Test is the falsification gate.
- Over-claiming citation strength. Use "suggests" / "is consistent with" rather than "proves".

## References

- `Research_Integration_Protocol.md` — authoritative 6-step pipeline.
- `CHANGELOG.md` — canonical entry schema.
- `04_Archives/decisions/`, `04_Archives/research_rejected/` — archive destinations.

Output to user in Korean when invoked during a Korean conversation; keep fields in English for CHANGELOG parsing consistency.
