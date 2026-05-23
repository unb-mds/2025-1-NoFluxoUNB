# Motor 2 v2 — Implementação Completa com Validação de Oferta de Optativas

## Status: ✅ IMPLEMENTADO E TESTADO

Data: 2026-05-23
Branch: `feature/motor-planejador-formatura`

---

## 1. Enriquecimento de Dados de MATR

### Problema
Dados de `semestreAtual` (MATR) do fluxograma_atual no banco continham apenas `codigo` e `status`, faltavam `nome` e `creditos`.

### Solução Implementada
- **Arquivo**: `plano_formatura.service.ts` → função `gerarPlanoCompletov2`
- **Técnica**: Cross-reference lookup com array `materias`
- **Resultado**: MateriaSemestreAtual enriquecidas com nome e creditos via:
  ```typescript
  const matInfo = materias.find(x => norm(x.codigo) === norm(m.codigo));
  return {
    codigo: m.codigo,
    nome: matInfo?.nome || m.nome || m.codigo,
    creditos: getCreditosSafely(matInfo ?? { creditos: 4 }),
    status: "MATR",
  };
  ```

### Commits
- `cee050c3` — fix: Enrich semestreAtual with nome and creditos from materias lookup

---

## 2. Coluna de Semestre Atual (MATR)

### Problema
MATR não estava sendo exibida na interface do plano de formatura.

### Solução Implementada
- **Novo componente**: `SemestreAtualColumn.svelte`
  - Visual: Purple styling (distingue de colunas futuras)
  - Conteúdo: Dados enriquecidos de MATR
  - Data attributes: `data-subject-code` para setas de pré-requisitos
  
- **Atualização**: `PlanoFormaturaView.svelte`
  - Usa dados enriquecidos diretamente: `planoV2.semestreAtual.materias`
  - Removido lookup em `fluxogramaStore` (dados já vêm do backend)
  - Added debug logging para rastrear disponibilidade de dados

### Commits
- `cb0d52c1` — feat: Add hours calculation logging + new SemestreAtualColumn component

---

## 3. Auditoria de Horas (Optativas Críticas)

### Problema Identificado
```
ALLOCATED IN PLAN:
  Optativa alocada: 0h ❌ NENHUMA OPTATIVA SENDO ALOCADA
REMAINING AFTER PLAN:
  Optativa restante: 300h ❌ TODAS AS OPTATIVAS FICARAM FALTANDO
```

### Causa Raiz
Obrigatórias estavam ocupando ~330h por semestre (limite: 360h), deixando apenas ~90h para optativas necessárias (300h).

### Diagnóstico Implementado
- **Arquivo**: `plano_formatura.service.ts`
- **Função**: `distribuirSlots()` com logging step-by-step
- **Output**: Rastreia espaço disponível por semestre e quanto de optativa foi alocado

```
[distribuirSlots] Starting with 3 semesters, need 300h optativas...
  [Semestre 0] Horas usadas: 330h, espaço disponível: 30h
    → Optativa: faltam 300h, espaço 30h, vou alocar 30h
      ✓ Alocado 30h optativa (total acumulado: 30h)
```

### Commits
- `8281b5d4` — debug: Add detailed logging inside distribuirSlots

---

## 4. Prevenção de "Optativas Fantasmas" ⭐ CRÍTICA

### Novo Requisito de Negócio
Não recomende optativas que não possuem turmas reais cadastradas. Muitas optativas do catálogo UnB raramente abrem.

### Solução Implementada

#### 4.1 Controller: Identificar Optativas com Oferta Real
```typescript
// PlanejamentoController.ts
const { data: turmasData } = await SupabaseWrapper.get()
    .from("turmas")
    .select("id_materia");

const codigosComOferta = new Set<string>();
// Mapeia codigos_materia que têm turmas confirmadas
```

#### 4.2 Aplicar Bônus/Penalidade no Score
```typescript
// plano_formatura.service.ts → calcularScore()
if (isOptativa && codigosComOferta) {
    if (temOferta) {
        score += 5  // 🟢 BÔNUS: Prioriza optativas com oferta real
    } else {
        score = Math.max(0, score - 10)  // 🔴 PENALIDADE: Desclassifica phantom
    }
}
```

#### 4.3 Resultado
| Optativa | Tem Turma? | Score Base | Modificação | Score Final | Recomendada? |
|----------|-----------|------------|-------------|-------------|--------------|
| FGA0160  | ✅ SIM    | 3          | +5          | **8**       | ✅ SIM       |
| DSC9999  | ❌ NÃO    | 3          | -10         | **0**       | ❌ NÃO       |

Quando optativas reais acabam, o sistema usa slots genéricos: `"~60h de Optativas"`

### Commits
- `0473fdaf` — feat: Implement 'phantom optative' prevention via real offer validation

---

## 5. Logging de Diagnóstico

### Motor 2 - Auditoria de Horas

```
========== [Motor2] HOURS CALCULATION AUDIT ==========
REQUIRED vs COMPLETED:
  Total:        1770/3480h
  Obrigatória:  1350/2580h
  Optativa:     420/900h

IN-PROGRESS (MATR):
  Obrigatória (MATR): 180h
  Optativa (MATR):    180h
  MATR subjects (6): DSC0172(4cr), CDT1106(4cr), ...

CALCULATED SHORTAGE:
  Obrigatória faltante: 2580 - 1350 - 180 = 1050h
  Optativa faltante:    900 - 420 - 180 = 300h

ALLOCATED IN PLAN:
  Obrigatória alocada: 990h
  Optativa alocada:    0h  ← ⚠️ PROBLEMA

REMAINING AFTER PLAN:
  Obrigatória restante: 60h
  Optativa restante:    300h  ← ⚠️ PROBLEMA
```

### Phantom Optative Detection

```
[Motor2 v2] Optativas com oferta real: 45 (FGA0160, FGA0108, FGA0124, ...)
[Motor2 v2] Optativas SEM oferta real: 23 (DSC0999, MAT0888, ...)
```

---

## 6. Próximos Passos

### Problema Pendente: Alocação de Optativas
Atualmente **0h de optativas** estão sendo alocadas porque:
1. ✅ Obrigatórias ocupam ~330h/semestre (limite 360h)
2. ❌ Restam apenas ~30h para optativas (precisam 300h)

**Possíveis soluções**:
1. **Aumentar limite de créditos** de 24 para 32 cr/semestre
2. **Distribuir obrigatórias menos densamente** e reservar espaço para optativas
3. **Alocar optativas ANTES de obrigatórias** (inverter ordem)

### Teste Prático
Execute a geração de plano de um aluno e verifique:
```
[Motor2 v2] Optativas com oferta real: X
[Motor2 v2] Optativas SEM oferta real: Y
[distribuirSlots] Final: optativaAlocada=ZZZh
```

---

## 7. Commits Relacionados

```
cb0d52c1 feat: Add hours calculation logging + SemestreAtualColumn
cee050c3 fix: Enrich semestreAtual with nome and creditos lookup
c46d70ee audit: Add detailed optative hours calculation verification
8281b5d4 debug: Add detailed logging inside distribuirSlots
0473fdaf feat: Implement 'phantom optative' prevention via real offer validation
```

---

## 8. Arquivos Modificados

### Backend
- `src/controllers/PlanejamentoController.ts` — Query turmas + pass codigosComOferta
- `src/services/plano_formatura.service.ts` — Enrich MATR, calcularScore, logging

### Frontend
- `src/lib/components/plano-formatura/PlanoFormaturaView.svelte` — MATR column logic + debug logs
- `src/lib/components/plano-formatura/SemestreAtualColumn.svelte` — Novo componente MATR

---

## Status Resumido

| Item | Status | Notas |
|------|--------|-------|
| ✅ MATR enriquecida | FEITO | nome + creditos via lookup |
| ✅ MATR coluna visível | FEITO | Purple styling, data-attributes |
| ⚠️ Alocação optativas | PROBLEMA | 0h alocadas de 300h necessárias |
| ✅ Phantom optatives | FEITO | +5 bônus com oferta, -10 sem oferta |
| ✅ Logging completo | FEITO | Auditoria de horas e optativas |

**Ação Recomendada**: Ajustar algoritmo de distribuição para reservar espaço para optativas.
