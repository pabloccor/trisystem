---
name: deploy-k8s
description: Standard deployment checklist for Kubernetes, Helm, or Rancher style rollouts.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Write, Bash, WebSearch, WebFetch
---

Use this only when deployment is explicitly in scope.

## Sequence

1. Read the active phase and deployment task.
2. Verify current vendor documentation for the exact deployment commands and flags you intend to use.
3. Prefer: render/plan, diff, dry-run, canary or staged rollout, rollback plan.
4. Record: commands, target cluster/environment, manifests/charts touched, rollback command, evidence paths.

Never deploy blindly from memory.
