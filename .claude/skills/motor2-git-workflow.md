---
name: motor2-git-workflow
description: Agents commit gradually. You push manually. No pushes or PRs from agents.
---

# Motor 2 Git Workflow

**Purpose:** Track agent commits + manage YOUR push/PR.

**Scope:** Monitor commits (agents), then push + PR (you).

## How Agents Work

- ✅ **Can commit** — gradually, with clear messages
- ❌ **Cannot push** — blocked in settings.json
- ❌ **Cannot create PR** — blocked, you do this

## Monitor Agent Commits

Watch progress in real-time:
```bash
git log --oneline -10
# See commits as agents work
```

See all changes vs main:
```bash
git diff origin/main..HEAD
```

## When Agents Are Done

1. **Review commits** — `git log` shows all agent work
2. **Run tests**:
   - Backend: `cd no_fluxo_backend && npm test -- --testPathPattern=planejamento`
   - Frontend: `cd no_fluxo_frontend_svelte && npm run check`
3. **Apply migration** (if any): `supabase db push`

## YOU Push Manually

When tests pass:
```bash
git push origin feature/motor-planejador-formatura
```

## YOU Create PR

After push:
```bash
gh pr create \
  --title "feat: Motor 2 — Cadeia de Formatura Personalizada" \
  --body "Implements personalized graduation planning: backend algorithm + frontend UI." \
  --base main
```

## Key Rules

- **Agents commit gradually** (you see commits in real-time)
- **Agents never push** (zero token waste on network I/O)
- **Agents never create PR** (you review commits first)
- **You control the release** (git push + gh pr create)
