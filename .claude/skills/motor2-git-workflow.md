---
name: motor2-git-workflow
description: Git workflow for Motor 2 (commit, push, PR). Handles staging, commit messages, remote sync.
---

# Motor 2 Git Workflow Skill

**Purpose:** Manage git operations (add, commit, push, PR creation) for Motor 2 tasks.

**Scope:** All 12 implementation tasks + optional PR creation.

**Model:** Haiku 4.5 (straightforward git ops)

## Pre-Commit Checklist

- [ ] Verify branch: `git branch --show-current` (expect: `feature/motor-planejador-formatura`)
- [ ] Check status: `git status --short` (no untracked files except docs/)
- [ ] Run relevant tests:
  - Backend tasks: `cd no_fluxo_backend && npm test -- --testPathPattern="planejamento"`
  - Frontend tasks: `cd no_fluxo_frontend_svelte && npm run check`

## Commit per Task

Each task commits separately with message format:
```
feat: [Task N] [component] — brief description

- Detailed change 1
- Detailed change 2
```

Example:
```bash
git add no_fluxo_backend/src/services/plano_formatura.service.ts no_fluxo_backend/tests-ts/planejamento.test.ts
git commit -m "feat: Task 3 — Motor 2 algorithm service with full unit tests"
```

## Push Protocol

After each task (or batch of 3):
```bash
git push origin feature/motor-planejador-formatura
```

**If rejected:** Run `git pull --rebase origin main` then retry.

## PR Creation (End of Implementation)

After all 12 tasks:
```bash
gh pr create \
  --title "feat: Motor 2 — Cadeia de Formatura Personalizada" \
  --body "Implements personalized graduation planning: backend algorithm + frontend UI." \
  --base main
```

**Expected:** PR opens on GitHub with auto-linked commits.
