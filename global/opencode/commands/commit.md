---
description: Stage and commit changes grouped by logical intent using conventional commits
model: github-copilot/claude-haiku-4.5
subtask: true
agent: build
---

Analyze all uncommitted changes in this repository and commit them in logical groups.

## Steps

1. Run `git status` to list all modified, added, and deleted files.
2. Run `git diff HEAD` to read the full diff of every change.
3. Also run `git diff --cached` to include any already-staged changes.

## Grouping rules

Group files by **what change was made**, not by file type or name, necessarily. A config file and a script that both enable the same new feature belong in the same commit. Ask yourself: "If I reverted this commit, what capability or fix would be lost?" — each commit should have one clear answer.

Examples of good grouping:
- A new endpoint handler + its route registration + its config entry → one `feat:` commit
- A bug fix in a function + the test that reproduces it → one `fix:` commit
- Dependency version bumps across multiple files → one `chore:` commit
- Unrelated refactor of a utility + an unrelated docs update → two separate commits

## Commit message rules

Use the Conventional Commits format:

```
type(optional-scope): title

(optional-body)
```

- **type**: `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `ci`, `perf`, `style`
- **scope**: optional, use when it meaningfully narrows context (e.g., `auth`, `api`, `db`)
- **title**: imperative descriptive mood (`add`, `fix`, `update` — not `added`, `fixes`), max 50 chars, no period at the end
- **body**: find the proper balance between brevity and detail. Brief enough that it's easy to read, but detailed enough that it's easy to understand. Max 72 chars, no period at the end

## Execution

For each group, in order:

1. Stage only that group's files: `git add <file1> [file2 ...]`
2. Commit immediately: `git commit -S -m "type(scope): description"`

**CRITICAL: Never use `--no-gpg-sign`, `--no-verify`, or any flag that bypasses GPG signing. Every commit must be signed with `-S`. Never disable GPG signing.**


Do not push. After all commits are done, print a short summary listing each commit message and the files included in it.

If there are no changes to commit, say so and stop.
