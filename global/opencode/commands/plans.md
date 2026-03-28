---
description: List all parked plans
model: github-copilot/claude-haiku-4.5
subtask: true
---

Call `plans_list` and display the results.

Format the output grouped by status (parked, in-progress, done, unknown). Within each group, show plans in chronological order.

For each plan show:
- Name (bold)
- Date (YYYY-MM-DD)
- Status
- One-line excerpt from the plan

If there are no plans, say so clearly.

Do not load, modify, or resume any plan. This command is read-only.
