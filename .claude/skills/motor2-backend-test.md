---
name: motor2-backend-test
description: Run backend unit tests for Motor 2 (Tasks 1-4). Validates DB migration, types, algorithm, and controller.
---

# Motor 2 Backend Test Skill

**Purpose:** Execute backend test suite for Motor 2 implementation phases.

**Scope:** Tasks 1–4 (migration, types, algorithm service, controller endpoint).

**Model:** Haiku 4.5 (fast test validation, low cost)

## Execution Checklist

- [ ] Navigate to `no_fluxo_backend/`
- [ ] Run migration check: `npx supabase migration list` (verify `20260522_add_preferencias_plano` exists)
- [ ] Run types validation: `npm run type-check`
- [ ] Run algorithm tests: `npm test -- --testPathPattern="planejamento" 2>&1`
  - **Expected:** All tests pass (0 failures)
  - **If fail:** Identify first failure, report line number + assertion
- [ ] Run endpoint validation:
  ```bash
  npm run dev &
  sleep 3
  curl -X POST http://localhost:3325/planejamento/gerar-plano \
    -H "Content-Type: application/json" \
    -d '{"curriculoCompleto":"8117/-2 - 2018.2","completedCodes":["MAT0026"],"numeroPeriodo":3,"preferencias":{"limiteCreditos":24,"objetivo":"equilibrado","trabalha":false}}'
  kill %1
  ```
  - **Expected:** JSON response with `semestresRestantes` (integer) + `plano` (array)
  - **If fail:** Report HTTP status + error message

## Output Format

Report as:
1. Migration status: ✅ / ❌
2. Types status: ✅ (0 errors) / ❌ (N errors)
3. Tests status: ✅ (all pass) / ❌ (N failures, first: file:line)
4. Endpoint status: ✅ (valid JSON) / ❌ (error details)

**Gate:** All 4 MUST be ✅ before proceeding to Task 5.
