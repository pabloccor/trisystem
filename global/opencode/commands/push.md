---
description: Push current branch to its remote counterpart
model: github-copilot/claude-haiku-4.5
subtask: true
agent: build
---

Run the following git command and report the result:

!`git push origin $(git branch --show-current)`
