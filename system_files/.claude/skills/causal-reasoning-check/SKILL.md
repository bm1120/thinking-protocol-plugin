---
name: causal-reasoning-check
description: Scrutinize any causal claim in a decision — separate correlation from causation, surface missing confounders, consider at least one counterfactual. Mandatory in Converge for any claim of the form "X causes Y" or "X will improve Y".
system: true
---

# causal-reasoning-check

**Invoked by:** `validator` subagent (Converge stage). Also triggered at Decide if a novel causal claim appears in Rationale or Compound learning.
**Stage:** Converge (Stage 5), with enforcement gate at Decide (Stage 6).

## When to invoke

Mandatory on any candidate whose rationale contains a causal claim. Causal claims take the forms:
- "X causes Y."
- "X will improve / increase / reduce Y."
- "If we do X, then Y follows."
- Any implicit cause-and-effect in decision rationale.

If a candidate is purely descriptive ("this is the current state"), this skill is not required.

## Procedure

1. **Extract the causal claim** — write it in the exact form `"<X> ⇒ <Y>"`.
2. **Classify the evidence class** using Pearl's ladder of causation:
   - **Level 1 (association):** correlational evidence only — a pattern has been observed.
   - **Level 2 (intervention):** experimental evidence — someone actually did X and measured Y.
   - **Level 3 (counterfactual):** can we reason "if X had not happened, Y would have been different"?
3. **Surface alternative explanations:**
   - **Confounder:** is there a Z that drives both X and Y? List ≥ 1 candidate confounder.
   - **Reverse causation:** could Y actually cause X instead?
   - **Selection bias / survivorship:** is the evidence drawn from a non-representative sample?
4. **State the counterfactual** — "If <X> had not happened, what would <Y> be?" — in one sentence. If you cannot state it, the causal claim is premature.
5. **Verdict:**
   - **Supported:** Level 2 or 3 evidence + confounders considered + counterfactual stated → claim can enter Decide.
   - **Weak:** Level 1 evidence only, or one confounder unresolved → claim can enter Decide as "correlation only, not causal" — rationale must be rewritten to avoid causal language.
   - **Rejected:** reverse causation plausible, or no counterfactual possible → claim must be dropped from rationale.

## Output format

```
## Causal reasoning check: <candidate name>

**Causal claim:** "<X> ⇒ <Y>"

**Evidence class:** Level 1 | Level 2 | Level 3

**Alternative explanations:**
- Confounder candidates: ...
- Reverse causation possible? ...
- Selection / survivorship risk? ...

**Counterfactual:** If <X> had not happened, <Y> would ...

**Verdict:** Supported | Weak (correlation only) | Rejected

**Action:**
- If Supported: proceed to Decide with causal claim intact.
- If Weak: rewrite rationale to use "is consistent with" / "suggests" / "correlates with" — NOT "causes" / "drives" / "produces".
- If Rejected: drop this claim from Decide's Rationale.
```

## Anti-patterns

- Accepting Level 1 evidence as causal because the pattern is strong. Strength of correlation is NOT evidence of causation.
- Listing zero confounders because "none come to mind". Force yourself to name at least one — if truly none, say so explicitly with evidence.
- Skipping the counterfactual step because "it's obvious". If it were obvious, there'd be no need to check.

## References

- `03_Knowledge_Base/3_Causal_Reasoning/Correlation_vs_Causation.md` — primary source.
- `03_Knowledge_Base/3_Causal_Reasoning/Counterfactuals_and_DAGs.md` — Pearl's ladder + DAG tooling.
- `03_Knowledge_Base/3_Causal_Reasoning/Causal_Illusions_and_Biases.md` — common intuition failures.
- `Core_Thinking_Protocol.md` Cross-stage invariant #2 — the binding rule this skill enforces.

Output to user in Korean.
