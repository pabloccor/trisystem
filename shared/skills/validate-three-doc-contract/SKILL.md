---
name: validate-three-doc-contract
description: Validate the three required markdown files and refresh generated artifacts if needed.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
---

Validate the current repository against the three-doc contract.

Canonical location: `docs/source-of-truth/`.

Run the bootstrap validation (e.g. `python3 .claude/bin/bootstrap_three_docs.py --validate-only`) if the script exists.

If valid, summarize: documents found, whether canonical or legacy discovery was used, prefix consistency, number of phases, number of generated tasks if artifacts already exist.

If invalid, summarize: blocking errors, warnings, exact files that caused ambiguity.
