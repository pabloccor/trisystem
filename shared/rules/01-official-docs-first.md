# Official docs first

- Before planning or implementation, verify relevant APIs, commands, libraries, platforms, and AI assistant behavior against official documentation.
- Prefer first-party documentation and version-specific pages when the version is known.
- If official docs and internal docs disagree:
  1. stop coding,
  2. write the discrepancy to `.claude/memory/official-doc-notes/`,
  3. reconcile the three source documents,
  4. continue only after the conflict is explicit.
- Use the `official-docs-researcher` agent proactively.
