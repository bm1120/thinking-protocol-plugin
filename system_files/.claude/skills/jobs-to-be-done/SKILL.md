---
name: jobs-to-be-done
description: Extract the underlying job a user is "hiring" a product or decision to do, using JTBD phrasing. Use in Frame (problem definition) or Converge (testing whether a solution actually serves the real job).
system: true
---

# jobs-to-be-done

**Invoked by:** `framer` (Frame stage) or `validator` (Converge stage).
**Stage:** Frame or Converge.

## When to invoke

Use in Frame when:
- The user describes a feature request or solution (not a problem). JTBD reverse-engineers the underlying need.
- The problem is customer-facing and the surface description is a feature list rather than an outcome.

Use in Converge when:
- Testing whether a proposed solution actually serves the real job (stress test).

## Procedure

1. Identify the target user / customer segment (one sentence).
2. Write the JTBD statement in this exact form: `"When <situation>, I want <motivation>, so I can <outcome>."`
3. Decompose the statement into three components:
   - **Situation (상황):** trigger context — when does this need arise?
   - **Motivation (동기):** functional and emotional drivers — why this over alternatives?
   - **Outcome (성과):** desired progress — what state change is the user buying?
4. Identify at least 2 **competing alternatives** the user could "hire" instead (not just competitors — include "do nothing", "use a spreadsheet", "ask a friend" etc.).
5. Surface the **functional + emotional + social** dimensions of the job (Christensen's categories).

## Output format

```
## Jobs-to-be-Done

**Target user:** <one sentence>

**JTBD statement:**
"When <situation>, I want <motivation>, so I can <outcome>."

**Decomposition:**
- Situation: ...
- Motivation: ...
- Outcome: ...

**Competing alternatives:**
1. ...
2. ...

**Job dimensions:**
- Functional: ...
- Emotional: ...
- Social: ...
```

When used in Converge, add a final section **Does the solution serve this job?** with a Yes / Partial / No verdict + one-sentence reason.

## Anti-patterns

- Writing the JTBD in feature language ("I want to click a button to..."). Features are the solution, not the job.
- Skipping the "so I can" outcome clause. Without an outcome, you're describing activity, not progress.
- Competing alternatives that are all the same category of product. Include non-product alternatives.

## References

- `05_Framework_Templates/2_Jobs_to_be_Done.md` — source template.
- `03_Knowledge_Base/1_Decision_Making/User_Psychology_Playbook/` — emotion and choice architecture context.

Output to user in Korean.
