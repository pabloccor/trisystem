---
description: Create a pull request for the current branch
agent: build
---

Create a pull request targeting the `$ARGUMENTS` branch (default to `main` if not specified).

## Step 1: Pre-flight Check
```bash
TARGET=${ARGUMENTS:-main}
BRANCH=$(git branch --show-current)

if [ "$BRANCH" = "$TARGET" ]; then
  echo "Already on $TARGET — nothing to PR."
  exit 1
fi

git log $TARGET..$BRANCH --oneline
git status --short
```

If uncommitted changes exist, ask: commit first or stash?

Extract a ticket/issue ID from the branch name or commits (e.g. `PROJ-123`, `#42`, `ABC-456`):
```bash
echo "$BRANCH $(git log $TARGET..$BRANCH --format='%s')" | grep -oE '[A-Z]+-[0-9]+|#[0-9]+' | head -1
```

If not found, skip the ticket prefix — do not ask the user unless context makes it obvious.

## Step 2: Push & Gather Context
```bash
git push -u origin $BRANCH
git diff $TARGET..HEAD --stat
git log $TARGET..HEAD --format="%s%n%b"
```

## Step 3: Analyze & Create PR

Read changed files, then create the PR as a draft:
```bash
gh pr create \
  --base $TARGET \
  --draft \
  --title "[TICKET-ID] Short description of the change" \
  --body "$(cat <<'EOF'
## Summary
-

## Changes
-

## Testing
- [ ] Lint passes
- [ ] Tests pass
- [ ] No regressions

## Related
- Ticket: [TICKET-ID]
EOF
)"
```

Title format: `[TICKET-ID] Short description` — e.g. `[ABC-123] Add authentication middleware`

If no ticket was found, omit the `[TICKET-ID]` prefix from both the title and body.

## Step 4: Done
```bash
gh pr view --web
```

Output the PR URL. Suggest top 2 reviewers based on recent commit authors for the changed files:
```bash
git diff $TARGET..HEAD --name-only | xargs -I {} git log -5 --format="%an" -- {} 2>/dev/null | sort | uniq -c | sort -rn | head -3
```
Exclude `$(git config user.name)`.
