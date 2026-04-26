---
tags:
  - core
  - thinking_protocol
  - six_stage
date: 2026-04-24
system: true
managed_by: thinking-protocol-plugin
---

# Core Thinking Protocol

This document specifies the 6-stage sequence that every non-trivial decision in this vault flows through: **Frame → Diverge → Incubate → Illuminate → Converge → Decide**. The sequence is designed so that creative novelty (System 1) and analytical rigor (System 2) take turns rather than interfering with each other. Each stage has explicit entry/exit criteria so a subagent can self-check progress without a human gatekeeper.

The design combines four research axes — decision-making, problem-solving, causal reasoning, and creativity — plus their neuroscience grounding (DMN/CEN switching, prefrontal executive control, dopaminergic insight, predictive coding). Knowledge-base references under each stage point to the specific notes the rule is derived from.

> **Not a waterfall.** Stages may loop back (Converge may kick to Incubator). Right-size rule in §Right-size allows small decisions to collapse to 3 stages.

## Right-size

A decision is **small** when it is reversible within a day AND affects ≤ 1 of the four research axes AND has no stakeholder beyond the user. Small decisions may collapse the protocol to **Frame → Converge → Decide**.

Otherwise the decision is **non-trivial** and runs the full six stages.

The Right-size check is owned by `framer` as part of Frame exit criteria. Do not allow a user's pressure ("빨리", "rush", "just decide") to override a non-trivial classification — it is a signal to check the classification, not a signal to skip stages. See CLAUDE.md Anti-Patterns §2.

Under collapse, Converge's Entry criteria relaxes: the candidate set is produced inline during Frame by the user or `framer` (1–5 items), and Illuminate is skipped entirely. The Converge, Decide stages otherwise run their standard checklists.

## TEST MODE

A controlled exception that bypasses **Incubate only** (Stage 3). All other stages (Frame, Diverge, Converge, Decide) still run their full checklists. TEST MODE exists to enable end-to-end protocol exercises (dogfood, training, debugging) without waiting for real-world incubation timers.

### Activation requirements (all three required)

1. **Explicit statement.** The user (or invoking subagent) writes "TEST MODE" verbatim in the prompt that initiates Frame.
2. **Filename prefix.** Any file produced during the test (incubation log, decision document, Diverge capture) is prefixed with `TEST_` — e.g. `TEST_Decision_YYYY-MM-DD-<slug>.md`.
3. **Frontmatter tag.** Every produced file includes `status: test-mode` in its YAML frontmatter.

If any one of the three is missing, the bypass is invalid and Incubate runs normally.

### Storage isolation

TEST MODE outputs are written to `00_Idea_Inbox/` only. They MUST NOT be moved to `04_Archives/decisions/` or any other archive. The vault search and downstream queries treat TEST files as illustrative, not as historical decisions.

### Promotion to a real decision

A TEST result cannot be silently promoted. To convert a TEST_Decision into a real decision:
1. The Diverge idea set may be re-used as input (it is content, not a decision).
2. Incubate must be re-run from scratch with full delay duration per the standard Incubate stage.
3. Converge and Decide must re-run; the TEST_Decision document is referenced as input but not adopted.
4. The new real decision is written to `04_Archives/decisions/` per the standard Decide checklist; the TEST file remains in `00_Idea_Inbox/` as evidence of the practice run.

### Audit

Every TEST MODE invocation SHOULD result in a `CHANGELOG.md` entry of kind `test-mode` listing the produced files and the user-stated purpose. Until automated enforcement exists (deferred to Phase 5 backlog), the reviewer MUST reject any TEST MODE work that lacks this entry. This makes pattern abuse (e.g. "everything is suddenly TEST MODE") visible in audit.

### Anti-patterns

- Marking a real decision as TEST MODE to skip Incubate. → If you would act on the result, it is not TEST MODE.
- Writing TEST output to `04_Archives/`. → Storage isolation enforced; reviewer must reject.
- Re-using TEST Converge/Decide outputs in a real decision without re-running. → Diverge content is reusable; evaluation outputs are not.

## Stage 1: Frame

### Purpose

Define the decision-to-be-made sharply enough that everything downstream has a stable target. A well-framed problem constrains divergence to the right solution space and gives later stages an unambiguous reference point for exit criteria.

### Entry criteria

A raw ask or problem from the user — unscoped, possibly ambiguous, possibly misframed.

### Exit criteria

All of the following artifacts must exist before handoff:
(a) JTBD-formatted problem statement ("When [situation], I want to [motivation], so I can [outcome]"),
(b) scope in/out bullets,
(c) 2–4 success criteria,
(d) hard vs soft constraints,
(e) ≥1 reframing option considered (even if rejected),
(f) "ready-to-hand-off" verdict: yes/no with one-line justification,
(g) right-size classification (small | non-trivial) with a one-line justification tying it to the Right-size definition (reversibility window, number of affected axes, stakeholders).

### Checklist

- Problem statement written in JTBD form.
- Scope: explicit in-bullets and out-bullets.
- Success criteria: 2–4 measurable outcomes.
- Constraints: separated into hard (inviolable) and soft (preferences).
- Reframing: at least one alternative framing generated and evaluated.

### Antipatterns

- Jumping to solutions before the problem is defined.
- Accepting the user's framing without considering at least one alternative.

### Responsible subagent

`framer`.

### Neuroscience evidence

Problem formulation is dominated by the prefrontal cortex: the dorsolateral PFC (dlPFC) maintains abstract goal representations in working memory, holding the target state available for comparison against candidate solutions. The anterior cingulate cortex (ACC) monitors conflict and prediction error, flagging when the current framing is internally inconsistent or when the user's stated goal mismatches their revealed constraints. Together these regions make Frame a high-executive-load stage — which is why it must run before fatigue-sensitive generative work. See `[[Problem_Space_and_Search]]` and `[[Prefrontal_Problem_Solving]]` (both created in Phase 2 Task 10).

## Stage 2: Diverge

### Purpose

Produce volume and variety of candidate solutions without evaluation. The goal is to widen the search so later stages have a rich pool to incubate and refine — not to pick a winner.

### Entry criteria

A handed-off Frame output with "ready-to-hand-off: yes".

### Exit criteria

A list of ≥ 15 candidate ideas, no ranking, no categorization, logged in `00_Idea_Inbox/` as a dated capture file.

### Checklist

- Run the mandatory ideation chain in full: `scamper-ideation` (all 7 substeps) → `remote-association-matrix` (≥ 5 pairings) → `worst-possible-idea` (≥ 3 inversions).
- Total ≥ 15 ideas across the chain, presented in 3 sections grouped by source skill.
- User-specified N is treated as a floor (not ceiling); chain runs in full.
- Explicitly state "no evaluation performed" at the end of the list.

### Antipatterns

- Self-censoring ideas that seem "unrealistic".
- Grouping or categorizing the list (that's convergent — belongs to Converge).

### Responsible subagent

`ideator`.

### Neuroscience evidence

Divergent generation is associated with the Default Mode Network (DMN), which supports spontaneous, remote-associative search across semantic memory. During genuine divergence the evaluative Central Executive Network (CEN) partially suppresses, permitting weakly-associated concepts to surface without premature rejection. This is why evaluation during generation is a neurological antipattern, not just a process one — the act of critiquing activates CEN and inhibits the DMN search it is supposed to follow. See `[[Divergent_vs_Convergent]]`, `[[DMN_CEN_Switching]]`.

> **Default ideation chain (Phase 7-1, 2026-04-26):** When `ideator` is invoked, it runs the mandatory 3-skill chain (`scamper-ideation` + `remote-association-matrix` + `worst-possible-idea`) producing ≥ 15 grouped ideas. Main orchestration auto-invokes `diverge-compression` once the ideator returns (threshold ≥ 15).

## Stage 3: Incubate

### Purpose

Enforce a deliberate pause to let unconscious processing combine and recombine the Diverge set, so that the Illuminate stage has consolidated material to surface from rather than a still-hot generative pile.

### Entry criteria

A Diverge output with ≥ 15 ideas logged to `00_Idea_Inbox/`.

### Exit criteria

An incubation log entry containing the idea set plus a concrete revisit timestamp; the agent is explicitly prohibited from evaluating or re-generating during this phase.

### Checklist

- Idea set logged to `05_Framework_Templates/7_Idea_Incubation_Log.md`.
- Default delay duration computed from magnitude (Trivial 30–60 min / Medium overnight / Large 2–3 days).
- Adjustment rules applied (see §Incubate duration adjustment below); if shortened or extended from default, justification recorded in the log entry.
- Revisit trigger stated (clock time, next-session marker, or external event).

### Antipatterns

- Allowing user urgency to collapse the delay to zero.
- Evaluating ideas while logging them.

### Responsible subagent

`incubator`.

### Neuroscience evidence

During rest and low-task-load periods, hippocampal-cortical replay consolidates recently-encoded material into long-term memory and integrates it with pre-existing schemas. Sleep cycles — specifically REM — are particularly effective at reorganizing remote associations, which is why overnight incubation outperforms a same-session pause for medium-sized decisions. The incubation benefit is not mystical; it is the neural substrate doing offline work that online evaluation would interfere with. See `[[Incubation_Neuroscience]]`, `[[Wallas_4_Stages]]`.

### Incubate duration adjustment

The default bands (Trivial 30–60 min / Medium overnight / Large 2–3 days) are starting points, not fixed. Adjust per the table below; record the chosen variables and final duration in the incubation log entry.

| Variable | Shorten ↓ trigger | Extend ↑ trigger |
|---|---|---|
| External deadline | Hard deadline < 24h | Open-ended, weeks of slack |
| Prior incubation | Months of background mental rumination | First time confronting the problem |
| Sleep cycle dependence | Analytical decision (linear analysis suffices) | Insight-required (analogical / creative synthesis) |
| Input blockability | User can disconnect (vacation, weekend) | Inputs continue (meetings, ongoing work) |
| Stakeholder coordination | Solo decision | Multi-party — others' incubation also matters |
| Reversibility | Partially reversible | Irreversible |

**Floor and ceiling (hard guards):**

| Magnitude | Floor (cannot go below) | Default | Ceiling (cannot exceed) |
|---|---|---|---|
| Trivial | 15 min | 30–60 min | overnight |
| Medium | 4 h | overnight | 2 days |
| Large | 1 sleep cycle | 2–3 days | 1 week |

**Adjustment rules:**

- **SHORTEN to floor** when: `External deadline = hard < 24h` (gate, required) **AND** ≥ 2 of the OTHER 5 Shorten ↓ triggers fire (Prior incubation / Sleep cycle dependence / Input blockability / Stakeholder coordination / Reversibility). Three Shorten triggers total including the deadline gate. Record all triggers in the log.
- **EXTEND to ceiling** when: ≥ 2 of the 3 "deep-process" Extend ↑ triggers fire: {Sleep cycle dependence = insight-required, Input blockability = inputs continue, Stakeholder coordination = multi-party}. Record the reason and convert the revisit trigger to an explicit calendar entry (not a vague "in a few days").
- **No adjustment** otherwise — use default.

**Why EXTEND is gated on 3 rows, not all 6:** The 3 deep-process triggers (insight-required, input-blockable, multi-stakeholder) specifically predict whether MORE time will *improve* the outcome — DMN reorganization needs time, unconscious processing needs uninterrupted inputs, multi-party coordination needs others' incubation too. The other 3 Extend cells (open-ended deadline, first-time-confronting, irreversible) are *informational* — they tell you that extending is *affordable* and the *risk justifies it*, but not that extending will *help*. They support the EXTEND decision but do not trigger it on their own.

The Floor/Ceiling guards exist because shortening below floor reduces the delay to ineffective brevity (no sleep cycle benefit), and extending past ceiling drifts into procrastination disguised as incubation. At ceiling (especially Large = 1 week), explicitly checkpoint: is this still active incubation, or has it drifted to avoidance? If avoidance, escalate via the Right-size rule rather than extending further.

Justification field in the log entry is mandatory whenever default is adjusted. The justification is one line: which triggers fired (with the ones counted vs informational distinguished), which direction, and the final duration.

## Stage 4: Illuminate

### Purpose

The Aha moment — re-entering the incubated set with a synthesis-ready mindset, letting consolidated associations surface as a shortlist of viable candidates.

### Entry criteria

The incubation revisit trigger has fired, and the agent has read the incubation log entry before doing anything else.

### Exit criteria

A shortlisted candidate set (3–7 items) with brief synthesis notes, handed off to `validator`.

### Checklist

- Re-read the Frame problem statement first (anchors the shortlist to the original target).
- Shortlist 3–7 from the Diverge set (no new ideas — that's Diverge).
- Write one synthesis sentence per shortlisted candidate explaining why it survived incubation.

### Antipatterns

- Generating new candidates (→ route back to Diverge).
- Critiquing candidates (→ Converge).

### Responsible subagent

`ideator` on re-entry (per CLAUDE.md §6 routing row "Returning from incubation, ready to synthesize insight"). Optionally `researcher` if new evidence surfaced during incubation and must be integrated before shortlisting.

### Neuroscience evidence

The Aha moment is marked by a characteristic gamma-band burst in the right anterior superior temporal gyrus (aSTG) roughly 300ms before conscious recognition, coupled with a dopaminergic reward prediction error signal that tags the insight as valuable. This is why Illuminate cannot be forced by effort — it is a release of already-consolidated material, not a fresh compute. Reading the Frame first biases the retrieval toward goal-relevant associations. See `[[Insight_AhaMoment]]`.

## Stage 5: Converge

### Purpose

Adversarially refine the shortlist; destroy weak candidates and strengthen survivors so that only robust options reach the decision stage.

### Entry criteria

A 3–7 candidate shortlist from Illuminate.

### Exit criteria

≤ 3 surviving candidates, each with its counter-proposal and a verdict (Keep / Refine / Drop) recorded.

### Checklist

- Critique pass on each candidate (≥ 3 attacks each — not 1 token attack).
- Counter-proposal pass on each survivor (the strongest version of the opposing view).
- Run `bias-check` skill.
- Run `premortem-analysis` skill.
- Causal-reasoning check (correlation vs. causation; missing confounders; at least one counterfactual).

### Antipatterns

- Leading with "this idea has merits" (merits go to Decide — Converge is where you try to break the idea).
- Agreeing with the most recent prior turn (sycophancy defeats adversarial refinement).

### Responsible subagent

`validator` (single-critic Adversarial Refinement loop; no 5-judge panel).

### Neuroscience evidence

Critical evaluation is driven by dlPFC top-down control — maintaining evaluation criteria in working memory while scanning candidates — combined with ventrolateral PFC (vlPFC) response inhibition that suppresses the impulse to endorse the first plausible option. Working-memory capacity bounds how many attack vectors can be held simultaneously, which is why the checklist caps critique at a finite list rather than "critique exhaustively". See `[[Executive_Control_and_Attention]]`, `[[Cognitive_Biases]]`.

## Stage 6: Decide

### Purpose

Produce a single actionable decision with traceable rationale plus a Compound learning note that feeds back into future decisions of the same type.

### Entry criteria

≤ 3 surviving candidates from Converge, each with critique and counter-proposal attached.

### Exit criteria

A one-page decision document at `04_Archives/decisions/YYYY-MM-DD-<slug>.md` containing 6 fields: Decision, Rationale, First action, Risks retained, Compound learning, Co-Execution Scope.

### Checklist

- One-sentence decision (not a hedge, not a menu).
- 3 rationale bullets referencing specific Converge survivors/rejects by name.
- First action with explicit owner + trigger.
- 1–3 risks retained (the ones you chose to accept, not the ones you mitigated).
- Any causal claim in Rationale or Compound learning traces to a scrutinized candidate from Converge; no novel causal claim introduced at Decide.
- One-line "Next time this decision type comes up, remember: X" for the Compound learning field.
- Co-Execution Scope produced for the chosen decision: ✅ AI-solo / 🤝 AI-assisted / ❌ user-solo task lists, plus first-execution unit (30–60 min) and Compound learning hook. Affordance is evaluated only here, never during Diverge or Converge (per CLAUDE.md Anti-Pattern #8).

### Antipatterns

- Hedging ("maybe we should", "one option is...") — commit to one decision or explicitly mark as provisional with a revisit date.
- Introducing novel content (route back to Diverge).

### Responsible subagent

`presenter`.

### Neuroscience evidence

Commitment is mediated by the ventromedial PFC (vmPFC), which integrates multi-attribute value into a single scalar signal, and the anterior insula, which encodes risk and anticipated regret. Dopaminergic signaling at the moment of commitment tags the chosen option, consolidating it into memory and making future retrieval of the rationale possible. Hedging bypasses this circuitry — without a commitment signal, there is no consolidation, and the Compound learning field cannot form. See `[[Neural_Basis_of_Choice]]`, `[[System_1_and_System_2]]`.

## Cross-stage invariants

Three rules bind every stage:

1. **Mode separation.** Diverge and Converge never execute in the same turn. Any action that would mix them (evaluating during Diverge, generating during Converge) is a violation and must kick the flow back one stage.
2. **Causal scrutiny at Converge and Decide.** Any recommendation that implies a cause-and-effect claim must name the causal model, surface confounders, and consider ≥ 1 counterfactual. See `03_Knowledge_Base/3_Causal_Reasoning/` (created in Phase 2 Task 10).
3. **Cite or abstain.** Any psychology/neuroscience claim must trace to a `03_Knowledge_Base/` source. If no source, output "근거 없음" and let the user decide whether to invoke `researcher` to resolve the gap.

## Changing this protocol

Changes to this file must go through the Research Integration Protocol (see `Research_Integration_Protocol.md`): a proposed change needs a cited source, a drafted diff, a Shadow Test against ≥ 1 recent decision from `04_Archives/decisions/`, and a `CHANGELOG.md` entry of kind `rule` or `research`. Speculative changes (not tied to a concrete failure or new research) are rejected.
