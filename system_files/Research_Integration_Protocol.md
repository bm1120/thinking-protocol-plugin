---
tags:
  - core
  - research_integration
date: 2026-04-24
system: true
managed_by: thinking-protocol-plugin
---

# Research Integration Protocol

This protocol turns each candidate research finding into one of three outcomes: a concrete system update, an archived-with-reason rejection, or a deferred-with-condition deferral. Never "read and forget".

The protocol is executed by the `researcher` subagent and wrapped by the `research-integration` skill. It exists because reading papers or blog posts without a rule-change pipeline produces drift: favorites get cited, unfavorables get forgotten, and the system's rules slowly untether from evidence.

**Input:** one research item (feed entry, paper, blog post, talk note).
**Outputs:** exactly one of — Merge (rule change applied + CHANGELOG entry), Defer (condition documented), Reject (archived with reason).

## The 6 steps

### 1. Capture

Confirm the item is in `00_Idea_Inbox/Automated_Research_Feed.md` (if feed-driven) or note the user-provided source. Record citation: URL, DOI if available, author, year. If the item lacks attributable provenance (no URL, no DOI, no named author), flag it — anonymous claims can still be captured, but the downstream steps must weigh them accordingly.

**Field produced:** `Source: <link/DOI>`.

### 2. Extract Claim

Compress the finding to a single actionable sentence of the form `"<observation> ⇒ <implied rule>"`. The left side is what the source reports; the right side is what our system would do differently as a result. If you cannot produce an actionable rule in one sentence, the item is not actionable; archive to `04_Archives/research_rejected/<date>-<slug>.md` with reason `"not actionable"`. Vague gestures toward "interesting implications" are rejections, not claims.

**Field produced:** `Claim: <one sentence>`.

### 3. Map to Stage

Decide which Core artifact this claim changes. Options: (a) a specific stage of `Core_Thinking_Protocol.md` (name the stage), (b) `Stage_Transition_Rules.md` (name the transition), (c) a `03_Knowledge_Base/<axis>/` note (new or modified), (d) a subagent or skill prompt, (e) none. If (e), archive with reason `"no stage target"`. Do not force-fit: a claim with no natural target is a rejection, not a homework assignment to find a target.

**Field produced:** `Target: <file + section>`.

### 4. Draft Rule Change

Write the exact diff: before/after for each affected line, or the full new section if it's a new note. The draft lives inline in this protocol's working memory, not yet in the target file. Keep the diff minimal — change the smallest unit that expresses the claim.

**Field produced:** `Diff: <before/after or new content>`.

### 5. Shadow Test

Pick 1–2 recent entries from `04_Archives/decisions/`. Apply the drafted rule retroactively. Would the decision have been different, clearer, or faster? Write 1–2 sentences per shadow case. If no recent decisions exist, create a synthetic one from a Frame stage and reason about it — but flag that this is synthetic, because synthetic shadow tests are weaker evidence than real-history replays.

**Field produced:** `Shadow Test: <decision id(s) + outcome>`.

### 6. Merge or Reject

- **Merge:** apply the diff to the target file, add a `CHANGELOG.md` entry in canonical schema (see below), commit. Outcome: `Merge`.
- **Reject:** archive the full draft (Claim + Target + Diff + Shadow rationale) to `04_Archives/research_rejected/<date>-<slug>.md`, add a brief `CHANGELOG.md` entry of kind `research` with a rejection-reason sentence, commit. Outcome: `Reject`.
- **Defer:** if Shadow Test is inconclusive AND a concrete condition could flip the verdict (e.g., "after 5 more decisions of this type"), record the condition and re-queue to `00_Idea_Inbox/` with the condition annotated. Outcome: `Defer`.

## Worked example

*Illustrative example — not a real citation.*

A hypothetical 2026 paper reports: "Problems requiring < 30 minutes of cognitive effort show stronger incubation benefits from a 2-hour nap than an overnight sleep cycle."

1. **Capture.** Source: fabricated example, no link.
2. **Extract Claim.** `"2-hour incubation ⇒ update Incubate delay-duration table for trivial decisions to prefer 2-hour nap over overnight."`
3. **Map to Stage.** Target: `Core_Thinking_Protocol.md` §Stage 3 Incubate → Checklist item 2 (delay duration table).
4. **Draft Rule Change.** Diff: replace "Trivial: 30–60 min (shower / walk)" with "Trivial: 30–60 min for immediate; for effortful-trivial (problem took > 15 min to frame), prefer 2-hour nap when schedule permits."
5. **Shadow Test.** Apply to 2 recent decisions from `04_Archives/decisions/`: one where the 30-min pause felt too short (would have benefited), one where overnight was used but problem was effortful-trivial (would have improved). Both suggest the rule change would have helped.
6. **Merge.** Apply diff, append CHANGELOG entry of kind `research` citing the (fabricated) source.

## Outcomes taxonomy

| Outcome | When | Archive location | CHANGELOG entry required |
|---|---|---|---|
| **Merge** | Shadow Test shows the rule improves ≥ 1 past decision | n/a (applied) | Yes, kind: `research` or `rule` |
| **Defer** | Condition stated + requeued | back to `00_Idea_Inbox/` with condition tag | Optional |
| **Reject** | Not actionable / no stage target / Shadow Test negative | `04_Archives/research_rejected/<date>-<slug>.md` | Yes, kind: `research`, one-sentence reason |

## Anti-patterns

1. **Force-fit a finding to a stage it doesn't address.** If Map to Stage returns "none", archive. Do not stretch the rule to fit a tangentially-related stage.
2. **Skip Shadow Test because "it's obviously right".** Shadow Test is the falsification gate. Skipping it means the system accretes claims with no feedback loop.
3. **Over-claim citation strength.** Use "suggests" and "is consistent with" rather than "proves" or "shows"; note sample sizes and method limits in the CHANGELOG entry.
