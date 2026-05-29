---
name: stage-transition-check
description: Judge whether the current stage's Exit criteria are met and the next stage's Entry criteria are satisfied. Invoke whenever a subagent is about to hand off, or the user asks "can we move on?".
system: true
---

# stage-transition-check

**Invoked by:** any subagent (framer, ideator, incubator, validator, presenter, researcher) before yielding control.
**Stage:** meta (not a specific stage; called between stages).

## When to invoke

Use this skill at exactly one moment: before a subagent hands off control to the next stage's subagent. Also use it when the user asks any of: "can we move to X?", "are we done with Y?", "should we step back?".

## Procedure

1. Identify the current stage (one of Frame / Diverge / Incubate / Illuminate / Converge / Decide).
2. Open `Stage_Transition_Rules.md` and locate the `N → M` block matching the current stage.
3. Run every Pre-check item in that block. For each, record `pass | fail` with a one-line reason. Do NOT guess — if you can't verify a check, mark it `fail` and return the missing artifact.
4. Run the **Self-deception scan** (`Stage_Transition_Rules.md`): for non-trivial decisions, scan your own reasoning against the rationalization table and name any fired red-flag plus its required check. Skip for `small` decisions (per §Right-size).
5. If all Pre-checks pass AND the scan is clear (or fired flags are addressed): produce the Hand-off artifact (described in the same block) and output `ADVANCE: next stage is <M>`.
6. If any Pre-check fails: compare against the `Common rollback triggers` in the same block; if a match, output `ROLLBACK: go back to <previous stage>` with the trigger name.
7. If the situation matches a scenario in §Failure handling of `Stage_Transition_Rules.md`: output `FAILURE-HANDLING: <scenario>` and follow that procedure instead.

## Output format

One of exactly three outputs:

- `ADVANCE: <current> → <next>` + Hand-off artifact content.
- `ROLLBACK: <current> → <previous>` + trigger name + one-line reason.
- `FAILURE-HANDLING: <scenario name>` + the procedure step from §Failure handling.

Always include a bullet list of the Pre-check results (pass/fail + reason) so the caller can audit the decision.

## Anti-patterns

- Guessing a Pre-check result when you can't verify it. The whole point of this skill is to catch missing artifacts.
- Advancing a stage when a Pre-check is ambiguous. Default is ROLLBACK or FAILURE-HANDLING.

## References

- `Stage_Transition_Rules.md` — the authoritative source; this skill only wraps it.
- `Core_Thinking_Protocol.md` for Entry/Exit criteria per stage.

Output to user in Korean when invoked during a Korean conversation; internal reasoning can stay English.
