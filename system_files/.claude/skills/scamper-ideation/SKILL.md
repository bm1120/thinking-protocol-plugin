---
name: scamper-ideation
description: Apply the SCAMPER framework (Substitute / Combine / Adapt / Modify / Put to another use / Eliminate / Reverse) to systematically vary an existing concept. Use during Diverge when obvious angles are exhausted.
system: true
---

# scamper-ideation

**Invoked by:** `ideator` subagent (Diverge stage).
**Stage:** Diverge (Stage 2).

## When to invoke

Use when:
- The Diverge stage has produced ≥ 5 but < 15 ideas and novelty is slowing.
- The ideas look like variations of one prototype — need structural distance.
- The user is stuck on a single framing of an existing product/feature.

Do NOT use in Frame, Incubate, Converge, or Decide. SCAMPER is a divergent-only tool.

## Procedure

1. Restate the base concept (one sentence) — the thing being varied.
2. For each of the seven SCAMPER operators, produce ≥ 2 candidate variations:
   - **Substitute (대체):** 무엇을 다른 것으로 바꿀 수 있는가? (사용자, 소재, 프로세스, 가격 모델, 기술 등)
   - **Combine (결합):** 어떤 다른 개념·제품·기능과 결합할 수 있는가?
   - **Adapt (적용):** 다른 도메인의 성공 사례를 적용하면?
   - **Modify / Magnify (수정·확대):** 크기·빈도·강도·대상을 극단으로 바꾸면?
   - **Put to another use (다른 용도):** 같은 것을 완전히 다른 시장·사용자에게 제공하면?
   - **Eliminate (제거):** 무엇을 없애면 더 나은가? (기능, 단계, 가격 요소)
   - **Reverse / Rearrange (역전·재배열):** 순서·역할·인과를 뒤집으면?
3. Collect all variations into a flat numbered list — do NOT group by operator in the final output (grouping is convergent).
4. Target: 14+ variations (7 operators × 2 each) before handing back to Diverge's main list.

## Output format

Markdown block:

```
## SCAMPER output

**Base concept:** <one sentence>

1. <variation 1>
2. <variation 2>
...
14. <variation 14+>
```

No evaluation. No selection. Flat list only.

## Anti-patterns

- Grouping the list by operator in the final output — that sets up convergent thinking.
- Rejecting variations for being "unrealistic". That's Diverge's point.
- Running fewer than 2 per operator.

## References

- `05_Framework_Templates/1_SCAMPER_Ideation.md` — human-facing Obsidian template (source of Korean operator names and examples).
- `03_Knowledge_Base/4_Creativity/Divergent_vs_Convergent.md` — why variation count matters.

Output to user in Korean.
