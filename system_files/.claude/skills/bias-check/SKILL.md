---
name: bias-check
description: Surface the active cognitive biases in a decision (sunk cost, confirmation, survivorship, p-hacking, availability, anchoring, causal illusion) and propose counter-measures. Use in Converge on every non-trivial decision.
system: true
---

# bias-check

**Invoked by:** `validator` subagent (Converge stage).
**Stage:** Converge (Stage 5).

## When to invoke

Mandatory on every non-trivial Converge pass. Use when:
- A candidate has survived Critique pass 1 and needs adversarial refinement.
- The user expresses strong conviction about a candidate (confirmation bias flag).
- The candidate's evidence base is a sample of 1 (survivorship flag).

> **Scope note:** `bias-check` examines biases in the *candidate / decision content* and runs in Converge only. For the agent's own *process* rationalizations at any stage transition (e.g. "it's clear from context", "while I'm at it"), see the **Self-deception scan** in `Stage_Transition_Rules.md` — a different, complementary check.

## Procedure

For each candidate under review, iterate through the 7 bias categories below. For each bias:
1. Ask: "Is this bias active in how the candidate is being evaluated or justified?"
2. Record `active | latent | not applicable` with one-line evidence.
3. If `active`, propose a specific counter-measure (not "be careful" — an action like "baseline comparison against random sample before accepting this number").

**Biases to check:**

1. **Sunk cost fallacy (매몰비용):** Is past investment driving continued commitment?
2. **Confirmation bias (확증 편향):** Is evidence selected to support an already-held belief?
3. **Survivorship bias (생존자 편향):** Are we reasoning from successes without the silent majority of failures?
4. **P-hacking / data dredging:** Were hypotheses formed before or after seeing the data?
5. **Availability heuristic (가용성 휴리스틱):** Is a vivid recent example dominating the estimate?
6. **Anchoring (앵커링):** Is the first number / option dragging all subsequent estimates?
7. **Causal illusion (인과 환영):** Is a co-occurrence being treated as cause? (see `Causal_Illusions_and_Biases.md`)

## Output format

```
## Bias check: <candidate name>

| Bias | Status | Evidence | Counter-measure |
|---|---|---|---|
| Sunk cost | latent | ... | - |
| Confirmation | active | ... | 반대 증거 의무 탐색 (at least 2 counter-examples before proceeding) |
| Survivorship | not applicable | ... | - |
| ...
```

If ≥ 2 biases are `active`, output a final line: `**Recommendation: route this candidate back to Diverge or Frame; the evaluation is compromised.**`

## Jev 보조 판정 (선택적)

각 bias 카테고리에 대해 Claude 분석을 완료한 뒤, `jev-judgment` 스킬을 호출하여 독립적인 Jev 보조 판정을 받는다.

**호출 방법:**

각 bias마다 Jev Noul 질문을 실행한다:
```bash
source lib/local_llm_router.sh
# 예: sunk cost
local_llm_query "noul" "<candidate description and evaluation context>" "Is sunk cost fallacy active in this evaluation?"
```

**결과 처리:**
- Ollaya 미실행 → 이 섹션 전체 스킵 (Claude 분석만 사용)
- Ollaya 가용 → 7개 bias 각각에 대해 Jev Noul 판정 실행
- Claude와 Jev 불일치 시 → 테이블에 `⚠️` 열 추가:

```
| Bias | Claude | Jev | 일치 | Evidence | Counter-measure |
|---|---|---|---|---|---|
| Sunk cost | active | active(0.89) | ✅ | ... | ... |
| Confirmation | active | not active(0.62) | ⚠️ | ... | ... |
```

**Jev confidence < 0.7인 판정은 "(low confidence)" 표시하고 Claude 판정을 우선한다.**

## Anti-patterns

- Marking all biases "not applicable" without evidence. Default to `latent` if uncertain.
- Counter-measures that are reminders rather than actions. "Be more objective" is not a counter-measure.
- Running this skill in Diverge. Bias check is evaluative — strictly Converge.

## References

- `03_Knowledge_Base/1_Decision_Making/Cognitive_Biases.md` — primary source.
- `03_Knowledge_Base/3_Causal_Reasoning/Causal_Illusions_and_Biases.md` — causal-specific biases.
- `03_Knowledge_Base/1_Decision_Making/System_1_and_System_2.md` — why biases dominate when tired.

Output to user in Korean.
