---
name: decision-retrospective
description: Run a structured retrospective on a past decision. Measures premortem recall rate, surprise count, and updates cumulative quality metrics. Triggered by session-start hook when a decision's retrospective due date has passed.
system: true
---

# decision-retrospective

**Invoked by:** User via `/retrospective <decision_id>`, or prompted by session-start hook.
**Stage:** Post-Decide (feedback loop).

## When to invoke

- session-start hook detects a decision with `retrospective.status == "pending"` and `due_date <= today`
- User explicitly asks to review a past decision

## Procedure

1. **Load decision log:** Read `_decision_log/{decision_id}.jsonl`.
2. **Ask user for outcome:** Use AskUserQuestion:
   "결정 후 어떤 결과가 있었나요? 예상치 못한 문제가 있었으면 알려주세요. 없으면 엔터."
3. **Premortem recall check:** For each premortem prediction in the log:
   - Use `jev-judgment` Noul: "Did this predicted failure actually occur?"
   - Mark as `hit` or `miss`
4. **Compute metrics:**
   - Premortem Recall Rate = hits / total predictions
   - Surprise Count = actual problems not in premortem list
   - Decision Drift = already recorded at Decide time (read from log)
5. **Update decision log:**
   ```json
   {
     "retrospective": {
       "status": "completed",
       "completed_at": "<ISO date>",
       "recall_rate": 0.75,
       "surprises": ["unexpected issue 1", "unexpected issue 2"],
       "user_input": "<what user said>"
     }
   }
   ```
6. **Update cumulative summary:** Read/create `_decision_log/_summary.json`:
   ```json
   {
     "total_decisions": 12,
     "completed_retrospectives": 8,
     "avg_premortem_recall": 0.68,
     "avg_decision_drift": 2.9,
     "process_adherence": {"FULL": 9, "PARTIAL": 2, "SKIPPED": 1},
     "trend": "recall_rate improving (+0.12 over last 5)"
   }
   ```
7. **Display summary** to user in Korean.

## Output format

```
## 회고 완료: [결정 제목]

- Premortem 적중률: N/M (XX%)
- 예상 외 문제: N개
- Decision Drift: X.X/5 (결정 시 기록)
- 누적 평균 적중률: XX% (↑/↓ 변화)

[적중 항목 / 미적중 항목 / 예상 외 문제 상세]
```

## Anti-patterns

- 결과가 좋았다 = 좋은 결정이었다로 판단. → 프로세스 품질만 측정. 운을 걸러낸다.
- 회고를 건너뛰기. → session-start hook이 지속적으로 리마인드.
- Jev 판정만으로 적중 여부 확정. → 사용자 입력이 최종 판단.

Output to user in Korean.
