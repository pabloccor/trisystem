---
name: dev-loop
description: Start, restart, or check the dev servers (back + front). Use at the start of a session or when servers need to be restarted.
disable-model-invocation: true
allowed-tools: Read, Bash, Glob
---

Manage the development servers for the fullstack project.

## Objective

Ensure both backend and frontend dev servers are running with hot-reload.

## Steps

1. Read `docs/source-of-truth/*_TECHNICAL_GUIDE.md` to extract:
   - Backend start command and port
   - Frontend start command and port
   - Health check endpoints
2. Check if servers are already running (check ports with lsof).
3. If not running, start them in background using commands from the technical guide.
4. Wait and verify with health checks.
5. Report status to user with URLs to open.

## Notes
- Adapt commands from the TECHNICAL_GUIDE — do not hardcode.
- If ports are occupied, report the conflict.
- Always prefer the commands documented in the technical guide.
