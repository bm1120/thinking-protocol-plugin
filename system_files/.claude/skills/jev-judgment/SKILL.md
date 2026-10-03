---
name: jev-judgment
description: Wrapper skill for all Jev/Kev local decision model calls. Other skills call this instead of Ollaya directly. Returns typed judgment (Choice/Score/Noul) with confidence. Graceful degrade when Ollaya unavailable.
system: true
---

# jev-judgment

**Invoked by:** Any skill needing a local LLM judgment (bias-check, stage-transition-check, premortem-analysis, etc.)
**Stage:** Any (wrapper, not stage-specific).

## When to invoke

Call this skill whenever you need a **structured local judgment** to supplement Claude's analysis:
- **Noul** (yes/no): "Is sunk cost bias active?", "Does this meet JTBD format?"
- **Choice** (classify): "ADVANCE / ROLLBACK / FAILURE_HANDLING", "SMALL / NON_TRIVIAL"
- **Score** (1-5): novelty, plausibility, urgency

## Procedure

1. **Check Ollaya availability** by running:
   ```bash
   source lib/local_llm_router.sh && ollaya_available && echo "UP" || echo "DOWN"
   ```

2. **If DOWN:** Skip Jev judgment entirely. Output:
   ```
   Jev: (Ollaya 미실행 — Claude 단독 판정)
   ```
   Continue with Claude-only analysis. This is not an error.

3. **If UP:** Execute the query:
   ```bash
   source lib/local_llm_router.sh
   result=$(local_llm_query "<type>" "<state>" "<question>")
   echo "$result"
   ```

4. **Interpret result:**
   - `confidence: "high"` (probability ≥ 0.8) → 신뢰 가능
   - `confidence: "medium"` (0.6-0.8) → 참고용
   - `confidence: "low"` (< 0.6) → 낮은 신뢰도 플래그 표시

5. **Compare with Claude analysis:**
   - 일치 → "✅ Claude + Jev 일치" 표시
   - 불일치 → "⚠️ 판정 불일치" + 양쪽 근거 병기, 사용자 판단 위임

## Output format

```
### Jev 보조 판정
- 타입: <noul|choice|score>
- 모델: <kev-0.8b|kev-4b|kev-9b|openjev-27b-q4>
- 판정: <answer>
- 확률: <probability>
- 신뢰도: <confidence>
- Claude 비교: <✅ 일치 | ⚠️ 불일치>
```

## Logging

Every call is automatically logged to `_logs/jev_judgments.jsonl` by `lib/local_llm_router.sh`. No additional logging needed in this skill.

## Anti-patterns

- Calling Ollaya directly without going through `lib/local_llm_router.sh`. → Always source the router.
- Treating Jev as the final authority. → Jev is second opinion only.
- Blocking on Ollaya timeout. → Router has 30s max-time; if it returns empty, proceed without Jev.
- Running Jev in Diverge for evaluation purposes. → Score(novelty) is permitted only for post-Diverge compression, not during idea generation.
