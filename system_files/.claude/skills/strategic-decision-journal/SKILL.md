---
name: strategic-decision-journal
description: Record a strategic decision with rationale, assumptions, alternatives considered, retrospective trigger, and Co-Execution Scope. Use in Decide for non-trivial decisions where traceability matters.
system: true
---

# strategic-decision-journal

**Invoked by:** `presenter` subagent (Decide stage).
**Stage:** Decide (Stage 6).

## When to invoke

Use in Decide when:
- The decision has reversibility cost > 1 week.
- Multiple stakeholders are affected.
- The decision will be revisited or audited later.

For small decisions (right-size = small), a shorter one-line log suffices; this skill is overkill.

## Procedure

1. Record decision metadata:
   - Date (YYYY-MM-DD)
   - Decision maker(s)
   - Decision type (strategic / operational / reversible / irreversible)
2. State the decision in one sentence.
3. List the **explicit assumptions** behind the decision (3–7 items, each testable).
4. List the **alternatives rejected** (from Converge output) with one-line reason per rejection.
5. Write a **Pre-mortem** paragraph: "If this decision fails in 12 months, the most likely cause is..."
6. Set a **retrospective trigger** (date or condition): when do we revisit? "Review on YYYY-MM-DD" or "Review after N signals".
7. Compute the **Co-Execution Scope** for the chosen decision (per `Core_Thinking_Protocol.md` Stage 6 Checklist + presenter.md Output field 6):
   - ✅ AI 단독 가능: tasks the AI can complete without further user input.
   - 🤝 AI 보조 가능 (사용자 입력 필요): tasks the AI can drive but requires the user for a specific input.
   - ❌ 사용자 단독 (AI 부적합): tasks the user must do themselves.
   - 예상 첫 실행 단위 (AI 협업 시): the smallest 30–60 min step that would begin execution.
   - Compound learning hook: what gets learned from running the first execution unit.
8. Save to `04_Archives/decisions/YYYY-MM-DD-<slug>.md`.

## Output format

File at `04_Archives/decisions/YYYY-MM-DD-<slug>.md`:

```markdown
---
tags:
  - decision
  - <domain>
date: YYYY-MM-DD
status: active | revised | archived
---

# <Decision title>

## Decision
<one sentence>

## Metadata
- Date: YYYY-MM-DD
- Decision maker(s): ...
- Type: ...

## Assumptions (explicit)
- ...

## Alternatives rejected
| Alternative | Why rejected |
|---|---|
| ... | ... |

## Pre-mortem
If this decision fails in 12 months, the most likely cause is ...

## Retrospective trigger
Review on YYYY-MM-DD (or: Review after <condition>)

## Compound learning
Next time this decision type comes up, remember: ...

## Co-Execution Scope

- ✅ **AI 단독 가능:** ...
- 🤝 **AI 보조 가능 (사용자 입력 필요):** ...
- ❌ **사용자 단독 (AI 부적합):** ...

**예상 첫 실행 단위 (AI 협업 시):** ...

**Compound learning hook:** ...
```

## Anti-patterns

- Assumptions that aren't testable ("we believe users will like it"). Make them testable: "≥ 60% of active users will complete the onboarding flow within 2 minutes."
- Skipping the retrospective trigger. Without a revisit, the decision silently becomes permanent.
- Writing a pre-mortem that's a generic risk list. The pre-mortem must commit to a single most-likely failure cause.

## References

- `05_Framework_Templates/3_Strategic_Decision_Journal.md` — source template.
- `Core_Thinking_Protocol.md` Stage 6 (Decide) — the fields this skill produces.

Output to user in Korean; keep file frontmatter in English for parser consistency.
