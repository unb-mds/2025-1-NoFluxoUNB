---
name: motor2-frontend-check
description: Type-check and build frontend for Motor 2 (Tasks 5-12). Validates types, component syntax, and production build.
---

# Motor 2 Frontend Check Skill

**Purpose:** Validate frontend code quality and buildability for Motor 2.

**Scope:** Tasks 5–12 (types, service, store, 4 components, route, nav).

**Model:** Haiku 4.5 (linting + type checking, low cost)

## Execution Checklist

- [ ] Navigate to `no_fluxo_frontend_svelte/`
- [ ] Run Svelte type check: `npm run check 2>&1 | head -50`
  - **Expected:** No errors
  - **If fail:** Report first error (file:line)
- [ ] Run ESLint: `npm run lint -- --max-warnings=0 2>&1 | head -50`
  - **Expected:** No warnings
  - **If fail:** Report first 3 violations
- [ ] Run full build: `npm run build 2>&1 | tail -20`
  - **Expected:** Build succeeds (exit 0)
  - **If fail:** Report last error from stderr
- [ ] Verify routes registered:
  ```bash
  grep -r "PLANO_FORMATURA" src/lib/config/routes.ts src/lib/components/layout/{Navbar,Sidebar}.svelte
  ```
  - **Expected:** 3+ matches (routes.ts, Navbar, Sidebar)
  - **If fail:** List missing references

## Output Format

Report as:
1. Svelte check: ✅ / ❌ (error details)
2. ESLint: ✅ / ❌ (violations list)
3. Build: ✅ / ❌ (error details)
4. Routes: ✅ / ❌ (missing in: file list)

**Gate:** All 4 MUST be ✅ before Task 13 (E2E).
