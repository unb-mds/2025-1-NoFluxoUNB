---
name: motor2-integration-test
description: Integration test for Motor 2 backend endpoint (Task 4). Validates end-to-end API.
---

# Motor 2 Integration Test Skill

**Purpose:** Test `POST /planejamento/gerar-plano` endpoint with realistic data.

**Scope:** Backend integration after Task 4 (controller wiring).

**Model:** Sonnet 4.6 (validate complex API responses)

## Setup

- [ ] Backend running: `npm run dev` (port 3325)
- [ ] Database online (Supabase)
- [ ] At least one test curriculum exists in DB: `SELECT curriculo_completo FROM matrizes LIMIT 1`

## Test Cases

**Test 1: Minimal Valid Request**
```bash
curl -X POST http://localhost:3325/planejamento/gerar-plano \
  -H "Content-Type: application/json" \
  -d '{
    "curriculoCompleto": "8117/-2 - 2018.2",
    "completedCodes": ["MAT0026", "FIS0041"],
    "numeroPeriodo": 2,
    "preferencias": {"limiteCreditos": 24, "objetivo": "equilibrado", "trabalha": false}
  }'
```
- **Expected:** 200 OK, `{ semestresRestantes: N, plano: [...], creditosOptativasFaltam: M, ... }`

**Test 2: Missing Required Field**
```bash
curl -X POST http://localhost:3325/planejamento/gerar-plano \
  -H "Content-Type: application/json" \
  -d '{ "curriculoCompleto": "8117/-2 - 2018.2" }'
```
- **Expected:** 400 Bad Request, error message

**Test 3: Invalid Curriculum**
```bash
curl -X POST http://localhost:3325/planejamento/gerar-plano \
  -H "Content-Type: application/json" \
  -d '{
    "curriculoCompleto": "INVALID",
    "completedCodes": [],
    "numeroPeriodo": 1,
    "preferencias": {"limiteCreditos": 24, "objetivo": "equilibrado", "trabalha": false}
  }'
```
- **Expected:** 500 error, "Matriz não encontrada"

**Test 4: High Credit Limit with Equilibrado**
```bash
curl -X POST http://localhost:3325/planejamento/gerar-plano \
  -H "Content-Type: application/json" \
  -d '{
    "curriculoCompleto": "8117/-2 - 2018.2",
    "completedCodes": ["MAT0026"],
    "numeroPeriodo": 1,
    "preferencias": {"limiteCreditos": 32, "objetivo": "equilibrado", "trabalha": false}
  }'
```
- **Expected:** 200 OK, first semester creditos ≤ 24 (capped for equilibrado)

## Validation

For each test: ✅ Pass (response matches expected) / ❌ Fail (actual vs. expected)

**Gate:** All 4 MUST pass before Task 5.
