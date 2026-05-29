---
tags:
  - core
  - transitions
  - six_stage
date: 2026-04-24
system: true
managed_by: thinking-protocol-plugin
---

# Stage Transition Rules

Defines the gating criteria for moving between the 6 stages of the Core Thinking Protocol. Read alongside `Core_Thinking_Protocol.md` — this file is the procedural companion.

The `stage-transition-check` skill uses this file to answer "can we move to the next stage, stay, or step back?". Subagents invoke that skill before yielding control.

## How to use

1. Name the current stage.
2. Look up the forward transition from current → next.
3. Run the Pre-check list. All items must be true.
4. If all pass, produce the Hand-off artifact and pass control to the next stage's subagent.
5. If any Pre-check fails, consult the "Common rollback triggers" section; revert one stage and re-run from there.
6. If the situation matches §Failure handling, follow that procedure instead of normal transition.

## Self-deception scan

Before EVERY forward transition, the agent scans its OWN reasoning (not the candidate — that is `bias-check`, Converge-only) for process rationalizations:

| Red-flag feeling | Rationalization | Reality / required check |
|---|---|---|
| "Grasped it well enough" | "Clear from context" | Felt-clear has been wrong. Verify against the source. |
| "Start now, ask mid-way" | "Begin, clarify later" | Wrong-direction work → full rework. Frame first. |
| "Did something like this before" | "Prior ≈ current" | Prior ≠ current; the same words differ by context. Re-read the actual prior. |
| "While I'm at it, add this" | "It's related" | Scope creep. Related ≠ requested. Stay in Frame's scope. |
| "Looks right, so it'll work" | "Plausible = correct" | Plausible ≠ verified. Run it / check it. |
| "I'm confident" | confidence | Confidence ≠ evidence. Produce the evidence. |

Right-size-governed: skip for `small` decisions (`Core_Thinking_Protocol.md` §Right-size). Run at every gate for non-trivial decisions.

## Forward transitions

### 1 → 2: Frame → Diverge

#### Pre-check

- JTBD problem statement drafted.
- Scope in/out bullets ≥ 3 each.
- Success criteria ≥ 2.
- ≥ 1 reframing considered.
- Constraints classified hard vs soft.
- Right-size verdict recorded (small | non-trivial, with one-line justification).

#### Hand-off artifact

- Problem statement (JTBD format).
- Success criteria list.
- Reframing option(s).

#### Common rollback triggers

- User pushes back on the framing ("that's not what I meant").
- Scope oscillates between turns — ambiguity not resolved.
- "Not sure which reframing" left unresolved.

### 2 → 3: Diverge → Incubate

#### Pre-check

- ≥ 15 ideas captured.
- No evaluation language present (scan each bullet for "realistic", "feasible", "actually" etc.).
- ≥ 1 Remote-Association idea included.
- ≥ 3 Worst-Possible candidates included.
- List dated and stored in `00_Idea_Inbox/`.
- If idea count ≥ 15, a `diverge-compression` artifact (5–10 clusters with original idea numbers preserved) exists alongside the full list. (Generation: main orchestration agent invokes `diverge-compression` skill before this transition. If count < 15, no artifact required — full list alone is sufficient. Below 15, Diverge stage is incomplete; route back to ideator.)

#### Hand-off artifact

- The dated idea list with capture timestamp.
- Reference back to the Frame problem statement.
- If idea count ≥ 15: the `diverge-compression` artifact (5–10 clusters with original idea numbers preserved). If count < 15: no compression artifact — full list alone is the handoff. (Below 15: Diverge incomplete, route back to ideator.)

#### Common rollback triggers

- Fewer than 15 ideas AND no novel angle observed — ideation loop prematurely converged.
- Evaluation language slipped in — rewind and re-run Diverge without looking at the Converge stage.

### 3 → 4: Incubate → Illuminate

#### Pre-check

- Incubation log entry exists with an explicit revisit trigger.
- The revisit trigger has fired (clock time passed, next session began, external event occurred).
- User/agent has NOT evaluated the idea set during the delay.
- Agent reads the log fresh (cold-start) before synthesis begins — the remembered gist is not a substitute for re-reading the original.

#### Hand-off artifact

- The dated incubation log reference.
- A re-read Frame problem statement (confirm scope still valid).

#### Common rollback triggers

- Revisit happened too early (clock check failed) — extend the delay and re-queue.
- Evaluation occurred during delay — void the incubation, restart Diverge with a new delay.

### 4 → 5: Illuminate → Converge

#### Pre-check

- Shortlist of 3–7 candidates from the Diverge set (no new ideas introduced).
- One synthesis sentence per shortlisted item.
- Original Frame problem statement re-verified (did scope change during incubation?).
- If scope changed materially, a scope-delta note attached to the handoff.

#### Hand-off artifact

- Ranked shortlist (3–7 items).
- Synthesis sentences.
- Optional: scope-delta note if scope shifted.

#### Common rollback triggers

- Scope changed substantially → return to Frame.
- New ideas emerged during synthesis → return to Diverge briefly to capture them.
- Shortlist is empty → return to Incubate with extended delay.

### 5 → 6: Converge → Decide

#### Pre-check

- ≤ 3 surviving candidates.
- Each survivor has ≥ 3 Critique bullets.
- Each survivor has a Counter-proposal.
- `bias-check` skill has been invoked.
- `premortem-analysis` skill has been invoked.
- Causal-reasoning check performed (correlation vs causation, confounders, counterfactual).

#### Hand-off artifact

- Ranked ≤ 3 candidates.
- Strongest counter-proposal per candidate.
- Cited biases and premortem findings per candidate.

#### Common rollback triggers

- < 1 surviving candidate after refinement → return to Diverge (new attempt) or Frame (reframe).
- Critic said "unable to attack this" on first pass without concrete evidence — likely sycophancy. Restart Converge with cold-start.

## Rollback paths

Rollback is normal, not a failure. The 3 most common backward moves:

1. **Converge → Incubate.** When Critique reveals that the framing is actually unclear (the problem was answered correctly, but it was the wrong problem). Re-run from Incubate with the shortlist as seeds, extending the delay.
2. **Illuminate → Diverge.** When incubation produced synthesis material that feels thin; new candidates are emerging. Return to Diverge briefly to capture them, then re-enter Incubate.
3. **Any stage → Frame.** When scope changes substantively during work. Stop and reframe; do not retrofit old work onto a new scope.

Rollback is recorded in the session log or decision archive with a one-line reason. Silent rollback hides systematic framing errors.

## Frame-restay (Frame → Frame)

A degenerate case where the Pre-check for 1 → 2 fails because the user's responses to framer's clarifying questions are insufficient (short, ambiguous, contradictory across turns), but the issue is not yet a true rollback target.

**Triggers (any one):**
- Two or more of Frame Exit criteria (a)–(g) cannot be filled with a one-line justification.
- Success criteria are stated as feelings ("I want it to feel right") with no observable proxy.
- Constraints contradict success criteria (e.g. hard constraint = "no new tools" + success = "automate workflow").
- The user's most recent reply is shorter than the framer's last question or repeats the question back.

**Procedure (one cycle, then escalate):**
1. Framer outputs `Frame-restay` verdict in the "Ready-to-hand-off" line, with a single sentence naming which Exit criterion is unfilled.
2. Framer poses **at most 2 focused questions** targeting that criterion only. No new exploration; no recap of prior turns.
3. If the next user turn fills the criterion, return to normal Frame Exit checklist.
4. If still unfilled after one re-stay cycle, escalate via the Right-size rule (`Core_Thinking_Protocol.md#right-size`). The escalation is a scope-ambiguity signal: require the user to either (a) defer the decision, (b) explicitly simplify the success criterion to something measurable, or (c) confirm a small classification (in which case Frame's burden drops). Do not advance to Diverge.

Frame-restay is not a rollback because no other stage has run yet. It is a hold-in-place pattern. The framer's verdict line includes the cycle counter `cycle N/1` (where N starts at 1 and may not exceed 1 — beyond that, step 4 escalation fires). This makes repeated re-stay attempts visible in audit.

## Failure handling

Four scenarios break the normal transition logic:

1. **User pressure to skip Incubate.** Re-route via the Right-size rule in `Core_Thinking_Protocol.md#right-size`. If the decision is non-trivial, do not skip. Log the pressure event in the incubation log — repeated pressures signal a scope misclassification.
2. **Research claim arrives mid-flow.** Do not integrate inline. Capture to `00_Idea_Inbox/Automated_Research_Feed.md` (or manual capture there), let `researcher` run the Research Integration Protocol asynchronously. Current flow continues with pre-arrival rules.
3. **Convergence stalls (same candidate wins > 5 rounds without a clear counter).** Treat as a framing problem. Return to Frame and challenge the scope and success criteria. Convergence is not the same as "exhausted the critique".
4. **TEST MODE invocation.** Verify all three activation requirements (explicit statement + `TEST_` filename prefix + `status: test-mode` frontmatter — canonical list in `Core_Thinking_Protocol.md#test-mode` §Activation requirements; keep this paraphrase in sync on edits). If valid, skip the 3 → 4 Pre-check that requires the revisit trigger to fire; instead, write a one-line note in the incubation log entry: "TEST MODE — Incubate bypassed per Core_Thinking_Protocol §TEST MODE." All other transitions run normally. If any activation requirement is missing, the bypass is invalid; proceed with Incubate per the standard 3 → 4 Pre-check.
