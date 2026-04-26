---
name: diverge-compression
description: Pre-categorize a Diverge output of ≥ 15 ideas into 5–10 groups before Converge dispatch, to keep validator's working memory tractable. Preserves original idea numbers.
system: true
---

# diverge-compression

**Invoked by:** main orchestration agent (between Diverge and Incubate, or before validator if Small).
**Stage:** between Stage 2 (Diverge) and Stage 3 (Incubate).

## When to invoke

ALL must be true:
1. Diverge output is complete (≥ 15 ideas, "no evaluation performed" trailer present).
2. Idea count ≥ 15.
3. Caller is the main orchestration agent, NOT the ideator (ideator's job is generation, not categorization — invoking this from inside Diverge would violate mode separation).

If idea count < 15, do NOT invoke. Below 15 the Diverge stage is incomplete; route back to ideator.

## Procedure

1. Read the full Diverge idea list (numbered 1..N).
2. Group ideas into 5–10 thematic clusters using ONLY the idea text — do not introduce new ideas, do not rank groups.
3. For each cluster:
   - State the cluster theme in ≤ 10 words.
   - List the original idea numbers belonging to this cluster.
   - Note 1–2 representative ideas verbatim (the most prototypical of the cluster).
4. List any ideas that don't fit any cluster as `Singletons`.
5. Output the compressed view, preserving the link back to the full list.

This is **not** Converge. No idea is dropped. No idea is ranked. Categorization is structural, not evaluative — clusters reflect *similarity*, not *quality*.

## Output format

The skill outputs a structured block in this shape:

````
## Diverge Compression — N ideas → K clusters

**Source:** <reference to original Diverge log entry — file path or in-conversation block>

### Cluster 1: <theme, ≤ 10 words>
- Idea #s: 3, 7, 12, 18, 22, 31
- Representative: "<idea #7 verbatim>"

### Cluster 2: <theme>
- Idea #s: 1, 4, 9, 16
- Representative: "<idea #4 verbatim>", "<idea #16 verbatim>"

... (5–10 clusters total)

### Singletons (ideas not fitting any cluster)
- Idea #s: 25, 33

## Hand-off
Categorization is structural, not evaluative. Validator should critique each cluster's representative first, then drill into specific ideas in surviving clusters. Original idea numbers are preserved for traceability.
````

(Outer 4-backticks open the fenced block. Inner 3-backtick block is the example of compressed output the skill produces. Plain markdown inside the inner block — no nested fences.)

## Anti-patterns

- Dropping ideas during compression. → Every original idea must appear in either a cluster or the Singletons list.
- Ranking clusters by quality. → That's Converge. The compression is structural sorting only.
- Generating new ideas while compressing. → Route those back to Diverge in a follow-up session; do not slip them into clusters.
- Invoking when count < 15. → Below 15 the Diverge stage is incomplete; the chain is broken, not the threshold.

## References

- `Core_Thinking_Protocol.md#stage-2-diverge` — the upstream stage.
- `Stage_Transition_Rules.md#2--3-diverge--incubate` — the transition this fits inside (compression happens between exit of stage 2 and entry of stage 3).
- Phase 4 dogfood "망가진 것" #5 — the originating problem.
- Phase 7-1 dogfood — chain enforcement and threshold lowering.

Output to user in Korean (categorization themes in Korean for vault consistency).
