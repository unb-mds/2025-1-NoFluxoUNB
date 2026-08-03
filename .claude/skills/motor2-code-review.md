---
name: motor2-code-review
description: Code review for Motor 2 implementation (Tasks 3, 6, 7, 11). Validates patterns, security, TypeScript strictness.
---

# Motor 2 Code Review Skill

**Purpose:** Verify code quality, patterns, and security for core Motor 2 files.

**Scope:** Algorithm service, frontend service/store, UI components.

**Model:** Sonnet 4.6 (nuanced code review, catches subtle issues)

## Files to Review

**Backend (Task 3):**
- `no_fluxo_backend/src/services/plano_formatura.service.ts` (250+ lines)
  - [ ] All functions are pure (no side effects)
  - [ ] Error handling: throws on data gaps
  - [ ] Score formula matches spec: `(3 × isObrigatoria) + (2 × directDeps) + (1 × indirectDeps) + (2 × atrasada)`
  - [ ] Normalization: `toUpperCase().trim()` on all codes

**Frontend (Task 6):**
- `no_fluxo_frontend_svelte/src/lib/services/plano-formatura.service.ts` (50 lines)
  - [ ] API call includes all 4 required params
  - [ ] Supabase methods imported correctly
  - [ ] Error handling for fetch + Supabase

**Store (Task 7):**
- `no_fluxo_frontend_svelte/src/lib/stores/plano-formatura.store.svelte.ts` (100+ lines)
  - [ ] State is mutable (`$state`)
  - [ ] Getters use `$derived`
  - [ ] `gerar()` recalculates on limit change
  - [ ] `loadPreferencias()` called on mount

**Components (Task 11):**
- `PlanoFormaturaView.svelte`
  - [ ] OnboardingModal conditional render
  - [ ] Error state displayed
  - [ ] Loading spinner shown
  - [ ] Credit limit buttons wire to `setLimiteCreditos()`

## Checklist Output

For each file: ✅ Pass / ❌ Fail + issues

**Gate:** All files MUST pass before commit.
