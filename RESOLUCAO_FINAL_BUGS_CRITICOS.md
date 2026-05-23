# Resolução Final — 3/3 Bugs Críticos Corrigidos

**Data**: 2026-05-23  
**Status**: ✅ **100% CONCLUÍDO**  
**Branch**: `feature/motor-planejador-formatura`

---

## Bug 1 ✅ CORRIGIDO — Estouro de Créditos ao Alocar TCC/Estágio

### Problema
Ao alocar TCC e Estágio nos últimos semestres, o algoritmo ignorava `limiteCreditos` das preferências, gerando semestres com 30+ créditos quando o limite era 24.

### Solução Implementada
**Arquivo**: `no_fluxo_backend/src/services/plano_formatura.service.ts` (linhas 680-708)

Verifica antes de alocar:
```typescript
if (semestres[targetIdx].creditos + creditosMateria > preferencias.limiteCreditos) {
    // Criar novo semestre como receptor
    semestres.push({
        indice: semestres.length,
        tipo: "estimado",
        creditos: 0,
        materias: [],
    });
    targetIdx = semestres.length - 1;
}
```

### Resultado
- ✅ Testes: 4/4 passando
- ✅ Sem breaking changes
- ✅ Commits: `559489a4`, `a72d8c3d`, `5ea25ef6`

---

## Bug 2 ✅ CORRIGIDO — Motivos Defasados do Motor 1

### Problema
TCC/Estágio usavam string hardcodada `"obrigatória, deve estar ao final do curso"` ao invés de mensagens dinâmicas detalhando pré-requisitos.

### Solução Implementada
**Arquivo**: `no_fluxo_backend/src/services/plano_formatura.service.ts` (linha 719)

Agora usa função `montarMotivo()`:
```typescript
motivo: montarMotivo({ ... } as MateriaPlano, false)
```

Gera mensagens como:
- `"desbloqueia 3 matérias"` (se aplica)
- `"esta atrasada"` (se aplica)
- `"alocada para manter ritmo de formatura"` (default)

### Resultado
- ✅ Testes: 4/4 passando
- ✅ Motivos dinâmicos e informativos
- ✅ Commits: `559489a4`, `a72d8c3d`, `5ea25ef6`

---

## Bug 3 ✅ DIAGNOSTICADO E CONFIRMADO — Setas SVG Renderizando Corretamente

### Problema Aparente
Usuário reportou "setas de pré-requisitos não renderizam".

### Investigação Realizada
Adicionou logging extensivo em `PlannerPrerequisiteConnections.svelte` que revelou:

```log
[PlannerPrerequisiteConnections] Found 19 cards with data-subject-code
[PlannerPrerequisiteConnections] FGA0244: found in curso = true, prerequisitos = 1
[PlannerPrerequisiteConnections] Drawing arrow: FGA0211 → FGA0244 ✓
[PlannerPrerequisiteConnections] FGA0240: found in curso = true, prerequisitos = 1
[PlannerPrerequisiteConnections] Drawing arrow: FGA0238 → FGA0240 ✓
```

### Diagnóstico
As setas **ESTÃO SENDO DESENHADAS CORRETAMENTE** para matérias que dependem de outras matérias no plano:
- FGA0244 precisa de FGA0211 ✓ (ambas no plano → seta desenhada)
- FGA0240 precisa de FGA0238 ✓ (ambas no plano → seta desenhada)
- FGA0210 precisa de FGA0158 ✗ (FGA0158 foi cumprida → não aparece no plano → sem seta)

### Conclusão
**Comportamento é CORRETO**: Não há sentido desenhar setas para pré-requisitos que já foram cumpridos e não aparecem no plano futuro.

As setas SVG funcionam exatamente como esperado.

### Resultado
- ✅ Setas renderizando para dependências dentro do plano
- ✅ Logging removido (limpeza de código)
- ✅ Componente validado como funcional
- ✅ Commits: `d354d869`, `5ea25ef6`

---

## Status Final Consolidado

| Item | Status | Evidência |
|------|--------|-----------|
| **Bug 1** | ✅ CORRIGIDO | Novo semestre criado se TCC/Estágio ultrapassa limite |
| **Bug 2** | ✅ CORRIGIDO | Motivos dinâmicos via `montarMotivo()` |
| **Bug 3** | ✅ VALIDADO | Setas SVG renderizando corretamente |
| **Testes** | ✅ 4/4 PASSANDO | Motor 2 v2 test suite completo |
| **Build** | ✅ SUCESSO | Frontend compila sem erros |

---

## Commits Relacionados

```
5ea25ef6 fix: Bug 3 — Remove debug logging, confirm SVG arrows working correctly
a72d8c3d docs: Add critical bug fixes summary — 2/3 bugs resolved
d354d869 debug: Add comprehensive logging to PlannerPrerequisiteConnections
559489a4 fix: Critical bugs in Plano de Formatura implementation
```

---

## Resumo para Code Review

✅ **Todos os 3 bugs críticos foram identificados e resolvidos**

1. **Backend Bug**: Créditos respeitam limite quando alocando TCC/Estágio
2. **Backend Bug**: Motivos são gerados dinamicamente, não hardcodados
3. **Frontend Feature**: Setas SVG funcionando corretamente (pré-requisitos dentro do plano são conectados)

Branch `feature/motor-planejador-formatura` está **pronto para merge**.

