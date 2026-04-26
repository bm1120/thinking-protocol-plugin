---
name: remote-association-matrix
description: Force an intersection between the problem and a random distant concept to surface non-obvious ideas. Use in Diverge to escape local maxima.
system: true
---

# remote-association-matrix

**Invoked by:** `ideator` subagent (Diverge stage).
**Stage:** Diverge (Stage 2).

## When to invoke

Use when:
- Ideas are clustering near the problem domain (all variations are flavors of the same thing).
- The problem is in a well-explored category and needs a fresh frame.
- SCAMPER and Worst-Possible have been run and the output still feels tame.

## Procedure

1. State the problem (one sentence).
2. Pick 3 distant concepts — domains unrelated to the problem. Examples: biology, medieval economics, jazz improvisation, chemical reactions, urban planning, postal systems, bee colonies. The farther from the problem's home domain, the better.
3. For each distant concept, write 3 candidate ideas that force the structure of the distant concept onto the problem. Example: if the problem is "how to onboard new users" and the distant concept is "bee colonies", an idea might be "split onboarding into roles (scout / forager / attendant) where the user earns promotion by small actions".
4. Output ≥ 9 forced-association ideas (3 concepts × 3 ideas).

## Output format

Markdown block:

```
## Remote association output

**Problem:** <one sentence>

### Distant concept 1: <name>
1. <forced-association idea>
2. <idea>
3. <idea>

### Distant concept 2: <name>
4. ...
...

### Distant concept 3: <name>
7. ...
```

Flat numbered sequence across concepts (1–9+), with concept sub-headers for traceability.

## Anti-patterns

- Picking distant concepts that are actually near the problem domain. If the problem is "SaaS pricing" and you pick "e-commerce pricing", that's not distant.
- Ideas that only superficially borrow the concept's vocabulary. The structure should transfer, not just the word.
- Skipping to 1 distant concept because "3 is too many". The point of 3 is to guarantee at least one usable structural mapping.

## References

- `05_Framework_Templates/6_Remote_Association_Matrix.md` — source template.
- `03_Knowledge_Base/2_Problem_Solving/Analogical_Reasoning.md` — structure-mapping theory (Gentner).

Output to user in Korean.
