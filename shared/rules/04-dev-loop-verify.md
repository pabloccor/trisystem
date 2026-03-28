# Dev loop and verification rule

- Dev servers (back + front) must be running before any implementation work begins.
- Every checklist item in Phase 2+ must include a verification step that can be checked in localhost.
- After completing the backend and frontend parts of a slice, run `/dev-verify` to check status.
- Never mark a slice as complete without telling the user exactly what to see/do in their browser.
- If dev servers are down, restart them before continuing work.
- The TECHNICAL_GUIDE is the single source of truth for server commands, ports, and health checks.
- If a slice cannot be verified in localhost, split it into smaller verifiable pieces.
