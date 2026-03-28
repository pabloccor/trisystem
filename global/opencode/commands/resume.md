---
description: Resume a parked session
subtask: false
---

You are resuming a previously parked work session.

## Steps

1. Call `plans_list` to retrieve all available plans.

2. **If `$ARGUMENTS` is non-empty:**
   - Treat it as a plan name and call `plans_load` with that name directly.
   - If the load fails (plan not found), show the full list and ask the user to pick one.

3. **If `$ARGUMENTS` is empty:**
   - Display the list returned by `plans_list` in a clean, readable format.
   - Ask the user which plan they want to resume.
   - Once they choose, call `plans_load` with that name.

4. After loading the plan, summarize it back to the user:
   - What this plan is about (one sentence)
   - Where work was left off (current status)
   - The immediate next step

5. Ask the user whether they want to proceed with the identified next step or adjust direction first.

Keep your summary concise. The goal is a fast, clear handoff back into the work.
