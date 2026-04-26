---
name: worst-possible-idea
description: Deliberately generate the worst possible ideas for a problem, then invert each into a surprising positive. Use in Diverge when ideas feel too safe or evaluation-anxiety is blocking generation.
system: true
---

# worst-possible-idea

**Invoked by:** `ideator` subagent (Diverge stage).
**Stage:** Diverge (Stage 2).

## When to invoke

Use when:
- Ideation has stalled at "realistic" variations.
- The user hesitates to propose an idea fearing judgment.
- The obvious solutions all look similar.

The point is not to find a bad idea; the point is to disinhibit the generator by lowering the stakes, then extract signal from the inverted output.

## Procedure

1. State the problem (one sentence).
2. Generate ≥ 7 **worst-possible** ideas — ideas that would maximally fail, insult users, waste resources, or be actively harmful. Be specific ("charge users $10 to close the app") not vague ("bad UX").
3. For each worst idea, state its **inversion** — what is the opposite or a mirror version of this idea? The inversion is often a real candidate.
4. Collect the inversions (not the original worst ideas) into the Diverge idea list for the caller.

## Output format

Markdown block:

```
## Worst-possible + inversion

**Problem:** <one sentence>

| # | Worst idea | Inversion (candidate for Diverge) |
|---|---|---|
| 1 | 사용자가 앱을 닫을 때마다 $10을 과금한다 | 앱 닫기를 거부할 만큼 중요한 '나갈 이유'를 만든다 — 마지막 화면에 가치 summary 보여주기 |
| ... | ... | ... |
```

≥ 7 rows.

## Anti-patterns

- Writing inversions without worst ideas first. Without the worst-idea seed, the exercise becomes normal ideation.
- Self-censoring worst ideas for being "too mean". Meaner = more useful signal when inverted.
- Treating the inversions as final answers — they still need Converge-stage critique like any other Diverge output.

## References

- `05_Framework_Templates/4_Worst_Possible_Idea.md` — source template.
- `03_Knowledge_Base/4_Creativity/Divergent_vs_Convergent.md` — the disinhibition mechanism.

Output to user in Korean.
