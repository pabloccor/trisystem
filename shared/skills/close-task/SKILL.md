---
name: close-task
description: Standard for closing or rejecting a task after QA.
user-invocable: false
allowed-tools: Read, Write
---

Before marking a task as done:

1. Confirm the task pack acceptance is covered.
2. Confirm review exists.
3. Confirm test evidence exists or is explicitly waived with a reason.
4. Confirm a handoff file exists.
5. Confirm risks are documented.

If any condition is missing, fail the QA gate.
