---
name: motor2-e2e-test
description: End-to-end test for Motor 2 (Task 13). Full user flow: auth → upload → navigate → generate → interact.
---

# Motor 2 E2E Test Skill

**Purpose:** Validate complete user journey through Motor 2.

**Scope:** Authentication → transcript upload → `/plano-formatura` navigation → plan generation → UI interaction.

**Model:** Sonnet 4.6 (complex multi-step validation)

## Prerequisites

- [ ] Both servers running: `pnpm run dev` (frontend 5173) + `pnpm run dev:backend` (backend 3325)
- [ ] Test user account ready (email + password)
- [ ] Test transcript file (CSV with ≥5 completed courses)

## Test Sequence

**Step 1: Login**
- [ ] Navigate to http://localhost:5173
- [ ] Log in with test credentials
- [ ] Verify: redirected to `/fluxograma` (dashboard)

**Step 2: Upload Transcript**
- [ ] Click "Carregar Histórico" (or equivalent button)
- [ ] Select test CSV file
- [ ] Verify: "Histórico carregado" confirmation
- [ ] Verify: course list populates with ≥5 courses marked "Aprovado"

**Step 3: Navigate to Plano**
- [ ] Click navbar/sidebar link "Plano de Formatura"
- [ ] Verify: URL is `/plano-formatura`
- [ ] Verify: page title shows "Plano de Formatura"

**Step 4: Onboarding Modal**
- [ ] Verify: modal appears with 3 questions
- [ ] Question 1: "Você trabalha ou estagia?" — select "Não"
- [ ] Question 2: "Quantos créditos?" — select "Até 24"
- [ ] Question 3: "Qual é seu objetivo?" — select "Equilíbrio"
- [ ] Click "Gerar meu plano"
- [ ] Verify: modal closes, loading spinner shows briefly

**Step 5: Plan Display**
- [ ] Verify: semester cards appear in horizontal scroll
- [ ] Verify: first card labeled "Próximo semestre" (blue background)
- [ ] Verify: subsequent cards labeled with dates (e.g., "2026.2")
- [ ] Verify: summary shows "Formatura estimada: YYYY.S"
- [ ] Verify: "Semestres restantes: N" displays

**Step 6: Color Coding**
- [ ] Identify critical courses (orange border/badge)
- [ ] Identify recommended courses (blue border)
- [ ] Verify: at least 1 course is marked "Crítica"

**Step 7: Credit Limit Toggle**
- [ ] Current limit button is highlighted (blue)
- [ ] Click different limit (e.g., 16 or 32)
- [ ] Verify: plan recalculates in <1s
- [ ] Verify: semester cards refresh
- [ ] Verify: credit counts change

**Step 8: Adjust Preferences**
- [ ] Click "Ajustar preferências" button
- [ ] Verify: onboarding modal reopens with previous answers selected
- [ ] Change one answer (e.g., "Você trabalha?" → "Sim")
- [ ] Click "Gerar meu plano"
- [ ] Verify: plan recalculates, modal closes

**Step 9: Optional Credits Notice**
- [ ] Scroll down below semester cards
- [ ] If "Créditos livres" section appears:
  - [ ] Verify: shows "Optativas: N créditos" and "Complementares: M créditos"
  - [ ] Verify: message suggests using flowchart or AI assistant

**Step 10: Refresh Persistence**
- [ ] Reload page (F5)
- [ ] Verify: plan persists (no re-onboarding)
- [ ] Verify: preference choices are remembered

## Pass/Fail Criteria

- ✅ All 10 steps complete without errors
- ❌ Any step fails → report step + error

**Gate:** Must pass before Motor 2 release.
