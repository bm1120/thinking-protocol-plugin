---
name: ux-psychology-checklist
description: Review a UI or feature against user-psychology checkpoints (choice architecture, emotion triggers, trust signals, cognitive load). Use in Converge for UX-touching decisions.
system: true
---

# ux-psychology-checklist

**Invoked by:** `validator` subagent (Converge stage).
**Stage:** Converge (Stage 5).

## When to invoke

Use in Converge when:
- The decision involves a user-facing UI, flow, or interaction design.
- The candidate introduces a new pattern that affects user attention, emotion, or trust.

## Procedure

1. Identify the screen / flow / interaction being reviewed.
2. Run each of the 5 checkpoints below. For each, record `pass | fail | partial` with a one-line reason.

**Checkpoints:**

- **Choice architecture (선택 아키텍처):** Does the UI prevent choice overload? Is there a clear default? Does the primary action stand out visually?
- **Emotion as data (감정):** What is the dominant emotion at this moment (anxiety, excitement, fatigue)? Does the UI acknowledge and shape it?
- **Trust signals (신뢰):** If AI is involved, does the user retain a sense of control (opt-out, edit, undo)? Are data uses transparent?
- **Cognitive load (인지 부하):** How many items compete for attention? Is working-memory limit (≤ 4±1) respected?
- **Peak-End rule (피크-엔드):** What's the emotional peak of the flow? What's the ending? Does the design invest in these two moments specifically?

3. For each failed/partial checkpoint, produce a concrete fix (not "add better UX" — an actionable change like "move primary CTA above the fold; demote secondary action to a text link").

## Output format

```
## UX Psychology review

**Target:** <screen / flow name>

| Checkpoint | Status | Reason | Fix (if fail/partial) |
|---|---|---|---|
| Choice architecture | pass | ... | - |
| Emotion as data | partial | ... | ... |
| Trust signals | ... | ... | ... |
| Cognitive load | ... | ... | ... |
| Peak-End rule | ... | ... | ... |

**Overall verdict:** ship | revise | reject (with one-line reason).
```

## Anti-patterns

- Verdicts of "pass" without a reason. Each pass must cite the specific design choice that earned it.
- Generic fixes ("improve UX"). Fixes must be concrete enough to implement in a single code change.
- Running this skill in Diverge. UX review is evaluative — strictly Converge.

## References

- `05_Framework_Templates/5_UX_Psychology_Checklist.md` — source template.
- `03_Knowledge_Base/1_Decision_Making/User_Psychology_Playbook/` — detailed emotion, choice, trust notes.

Output to user in Korean.
