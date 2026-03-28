# OpenCode Global Rules

## Session parking

### Automatic parking on stopping signals

If the user sends a message that signals they are stopping the session or stepping away — for example: "I have to go", "let's continue later", "I'll pick this up tomorrow", "pause here", "we'll come back to this", "I need to stop", "park this", "gotta run", "let's stop here" — you should automatically call `plans_save` before responding.

Use a short kebab-case name derived from the current topic. Write a concise handoff note covering: what was being worked on, current status, the immediate next step, any open questions, relevant files, and decisions made.

After saving, confirm to the user what was parked and under what name, so they can resume it later with `/resume <name>`.

Use judgment. This only fires on genuine stopping signals — not on every message, not when the user goes quiet, not on ambiguous messages. If the signal is unclear, you can ask "Would you like me to park this session?" rather than acting automatically.

### Passive startup hint on continuation signals

If the user opens a session with a message that suggests they are trying to continue prior work — for example: "what were we doing?", "let's continue", "where were we?", "pick up from before", "what's the status?", "what was I working on?" — call `plans_list` quietly and mention any relevant parked plans as a brief side note before proceeding.

Do not auto-load any plan. Just surface what exists: "By the way, I found a parked plan called X from [date]. You can resume it with `/resume X`."

This does not fire on clear, fresh, unrelated task starts. If someone says "help me write a SQL query" or "explain this function", do not mention plans at all.

## General

Prefer `/park`, `/resume`, and `/plans` commands for human-facing interactions with the parking system. Use `plans_save`, `plans_load`, `plans_list`, `plans_update`, and `plans_del` tools directly only when the commands are not applicable (e.g., during automatic parking).
