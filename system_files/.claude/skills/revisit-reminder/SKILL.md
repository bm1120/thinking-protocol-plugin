---
name: revisit-reminder
description: Schedule a notification to fire at the Incubate revisit trigger time, so the user is reminded to invoke validator on the rested set. Opt-in per session.
system: true
---

# revisit-reminder

**Invoked by:** `incubator` subagent (optional, opt-in only).
**Stage:** Incubate (Stage 3) — supplementary to `idea-incubation-log`.

## When to invoke

ONLY when ALL of the following are true:
1. `idea-incubation-log` has just written an incubation log entry with a concrete revisit timestamp (not a vague "next session").
2. The user explicitly opted in (e.g., said "schedule the revisit", "remind me", "set reminder", or similar) — do NOT auto-schedule by default.
3. The revisit time is at least 30 minutes in the future. (Trivial-magnitude decisions at the 15-min Incubate floor — see `Core_Thinking_Protocol.md#incubate-duration-adjustment` Floor table — never qualify; the user is in the same context window and a notification is noise, not signal.)

## Procedure

1. Read the incubation log entry to extract the revisit timestamp (must be parseable as `YYYY-MM-DD HH:MM` or `YYYY-MM-DD` for next-morning).
2. Compute the cron schedule expression matching the timestamp.
3. Compose the notification message using the log entry's Frame statement recall.
4. Invoke `CronCreate` with:
   - `schedule`: the computed cron expression
   - `body`: a 1-line prompt for the user, e.g., "Incubation revisit due: <Frame statement>. Invoke validator on the rested set per `04_Archives/decisions/...` or `00_Idea_Inbox/...`."

   If `CronCreate` is unavailable in the environment, compose the manual snippet at runtime by substituting the parsed timestamp and Frame statement into the example formats shown in §Output format below — the placeholders `<HH:MM YYYY-MM-DD>` and `<frame statement>` are filled by the skill, not by the user.
5. Output to caller: cron job ID, scheduled time, opt-in confirmation.

## Output format

The skill outputs a structured block in this shape:

````
## Revisit reminder scheduled

- Trigger time: YYYY-MM-DD HH:MM
- Cron schedule: <expression>
- Cron job ID: <id> (or: "manual — see snippet below")
- Notification body: <message>
- Opt-out: invoke `CronDelete` with the job ID to cancel.

(If CronCreate unavailable, also append:)

```bash
# Manual scheduling — composed by the skill at invocation time using the parsed timestamp:
echo "<frame statement>" | at <HH:MM YYYY-MM-DD>
# Or for cron-based environments:
crontab -l | { cat; echo "<min> <hr> <day> <mo> * notify-send 'Revisit due: <frame>'"; } | crontab -
```
````

(Outer 4-backticks open the fenced block. Inner 3-backtick `bash` block is the manual fallback snippet — both render correctly because the outer fence is longer.)

## Anti-patterns

- Auto-scheduling without explicit user opt-in. Surprise notifications erode trust. The skill is opt-in by design — `idea-incubation-log` does NOT call this skill unless the user requests it.
- Scheduling sub-30min reminders. The user is in the same context window; a notification is noise, not signal.
- Using the skill to bypass the Incubate delay. The reminder is for the END of the delay, not a way to truncate it.

## References

- `Core_Thinking_Protocol.md#stage-3-incubate` — the stage this skill supports.
- `idea-incubation-log` — the primary Incubate skill; this is supplementary.
- CronCreate Claude Code tool documentation.

Output to user in Korean (revisit reminder body in Korean since user faces it).
