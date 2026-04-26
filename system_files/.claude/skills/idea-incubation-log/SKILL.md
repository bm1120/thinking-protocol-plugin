---
name: idea-incubation-log
description: Record an idea set with a revisit-date schedule, so the Incubate stage is not bypassed. Use immediately after Diverge.
system: true
---

# idea-incubation-log

**Invoked by:** `incubator` subagent (Incubate stage).
**Stage:** Incubate (Stage 3).

## When to invoke

Use immediately after Diverge produces ≥ 15 ideas. Every non-trivial decision must pass through this skill before Converge.

## Procedure

1. Read the Diverge output (the idea list with its capture timestamp).
2. Classify the decision magnitude (default duration band):
   - **Trivial:** 30–60 min pause (shower, walk).
   - **Medium:** overnight sleep cycle.
   - **Large:** 2–3 days with ≥ 1 full sleep between.
3. Apply duration adjustment per `Core_Thinking_Protocol.md#incubate-duration-adjustment`:
   - Walk through the 6 variables. For each, mark Shorten / Neutral / Extend based on the table cells.
   - Check SHORTEN rule: is `External deadline = hard < 24h`? If YES, count the OTHER 5 Shorten ticks. If ≥ 2 of those 5 ticked, fire SHORTEN → set duration to floor.
   - Check EXTEND rule: of the 3 deep-process triggers ONLY (Sleep cycle dependence = insight-required, Input blockability = inputs continue, Stakeholder coordination = multi-party), how many ticked? If ≥ 2, fire EXTEND → set duration to ceiling. (Other Extend ticks are informational and support but do not trigger the rule.)
   - If neither fires, use default.
   - Record in the **Justification** field: rule fired (SHORTEN/EXTEND/none), counted triggers, informational supporting triggers, final duration.
4. Compute the revisit trigger from the final duration:
   - Sub-overnight: "HH:MM + Nh" or "next task context switch".
   - Overnight: "tomorrow morning first block".
   - Multi-day: "YYYY-MM-DD at HH:MM" (explicit calendar entry).
5. Append a dated entry to `05_Framework_Templates/7_Idea_Incubation_Log.md` with: idea list reference, decision magnitude, default duration, adjustment direction (shortened/default/extended), justification (one line), final duration, revisit trigger, brief Frame statement recall.
6. Output to the caller: captured (N ideas), log path, magnitude, default vs adjusted duration, justification, revisit trigger, hand-off instruction: "Do not proceed to Converge until the revisit trigger has fired."
7. **Optional opt-in revisit reminder.** If the user explicitly requested a reminder (e.g., "schedule the revisit", "remind me at trigger time"), invoke `revisit-reminder` skill with the revisit timestamp from step 4. If no opt-in, skip — the trigger is declarative only, and the user is responsible for re-engaging at the trigger time.

## Output format

```
## Incubation captured

- Idea set size: <N>
- Log entry: `05_Framework_Templates/7_Idea_Incubation_Log.md` (appended)
- Magnitude: Trivial | Medium | Large
- Default duration: <band default>
- Adjustment: shortened | default | extended
- Justification: <one line — which triggers fired, which direction>
- Final duration: <floor | default | ceiling — concrete value>
- Revisit trigger: <timestamp or condition>

**Do not proceed to Converge until the revisit trigger has fired.**
```

## Anti-patterns

- Collapsing delay to zero because the user says it's urgent. Urgency is a right-size check, not a skip license.
- Evaluating ideas while logging them. This skill captures; it does not judge.
- Vague revisit triggers ("later", "when I'm ready"). The trigger must be testable by the clock or by an external event.

## References

- `05_Framework_Templates/7_Idea_Incubation_Log.md` — the log file this skill writes to.
- `03_Knowledge_Base/4_Creativity/Incubation_Neuroscience.md` — why delay works.
- `03_Knowledge_Base/4_Creativity/Wallas_4_Stages.md` — historical framing.

Output to user in Korean.
