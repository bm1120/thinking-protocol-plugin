---
name: premortem-analysis
description: Run a pre-mortem — imagine the decision has failed 12 months from now and explain why — to surface failure modes the current framing hides. Use in Converge before finalizing a non-trivial decision.
system: true
---

# premortem-analysis

**Invoked by:** `validator` subagent (Converge stage).
**Stage:** Converge (Stage 5).

## When to invoke

Mandatory on non-trivial Converge passes. Use when:
- A candidate has survived bias-check and reads as the likely winner.
- Overconfidence is suspected (team consensus formed too quickly).

The pre-mortem is the single best antidote to overconfidence. It only works when done BEFORE commitment.

## Procedure

1. Fast-forward mentally: "It is 12 months after we implemented this candidate. The decision has catastrophically failed."
2. Generate ≥ 5 plausible failure stories. Each story has:
   - **Trigger:** the specific event or condition that started the failure.
   - **Propagation:** how the failure spread.
   - **Signal missed:** what we could have seen at decision time but didn't.
3. Rank the 5 stories by plausibility (high / medium / low). Focus on the top 2.
4. For each top-2 story, propose a **leading indicator** — a metric or signal observable in the first 3 months that would flag this failure mode early.
5. If ≥ 2 stories have plausibility `high` AND no leading indicator is affordable, recommend the candidate be refined or rejected.

## Output format

```
## Pre-mortem: <candidate name>

**Frame:** 12개월 후 이 결정이 완전히 실패했다.

### Failure stories

1. **Trigger:** ... / **Propagation:** ... / **Signal missed:** ... / **Plausibility:** high | medium | low
2. ...
5. ...

### Top-2 plausible failures + leading indicators

1. <story> — **Leading indicator:** <metric + threshold + horizon>
2. <story> — **Leading indicator:** <...>

**Recommendation:** proceed | refine (per leading indicator) | reject
```

## Anti-patterns

- Failure stories that are too generic ("the market changed"). Each story must name a specific trigger.
- Leading indicators that are lagging ("revenue drops after 6 months"). The indicator must fire in the first 3 months.
- Running pre-mortem after commitment. Without the "before" timing, it becomes post-hoc rationalization.

## References

- `Core_Thinking_Protocol.md` Stage 5 (Converge) — required checklist item.
- `03_Knowledge_Base/1_Decision_Making/Cognitive_Biases.md` — overconfidence and availability.
- Gary Klein's pre-mortem technique (behavioral science canon — treat as public knowledge; cite the KB note's consolidated treatment rather than invent references).

Output to user in Korean.
