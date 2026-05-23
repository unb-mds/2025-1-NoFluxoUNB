# Correções de Bugs Críticos — Plano de Formatura

**Data**: 2026-05-23  
**Branch**: `feature/motor-planejador-formatura`  
**Status**: 2/3 bugs corrigidos, 1/3 em debug

---

## Bug 1 ✅ CORRIGIDO — Estouro de Créditos ao Alocar TCC/Estágio

### Problema
Ao alocar TCC e Estágio nos últimos semestres, o algoritmo ignorava `limiteCreditos` das preferências, gerando semestres com 30+ créditos quando o limite era 24.

### Solução
**Arquivo**: `no_fluxo_backend/src/services/plano_formatura.service.ts` (linhas 680-708)

Ao alocar TCC/Estágio, verifica se a matéria ultrapassa o limite:
```typescript
if (semestres[targetIdx].creditos + creditosMateria > preferencias.limiteCreditos) {
    // Criar novo semestre e alocar lá
    const novoSemestre: SemestrePlano = {
        indice: semestres.length,
        tipo: "estimado",
        creditos: 0,
        materias: [],
    };
    semestres.push(novoSemestre);
    targetIdx = semestres.length - 1;  // Apontar para o novo semestre
}
```

### Verificação
- ✅ Testes: 4/4 passando
- ✅ Sem breaking changes
- ✅ Commit: `559489a4`

---

## Bug 2 ✅ CORRIGIDO — Motivos Defasados do Motor 1

### Problema
TCC/Estágio usavam string hardcodada `"obrigatória, deve estar ao final do curso"` ao invés de chamar `montarMotivo()` que detalha número de pré-requisitos desbloqueados.

### Solução
**Arquivo**: `no_fluxo_backend/src/services/plano_formatura.service.ts` (linha 719)

Agora usa:
```typescript
motivo: montarMotivo({ ... } as MateriaPlano, false)
```

Que gera mensagens dinâmicas como:
- `"desbloqueia 3 matérias"` (se desbloqueiaDireto > 0)
- `"esta atrasada"` (se atrasada)
- `"alocada para manter ritmo de formatura"` (default)

### Verificação
- ✅ Testes: 4/4 passando
- ✅ Sem breaking changes
- ✅ Commit: `559489a4`

---

## Bug 3 ⚠️ EM DEBUG — Setas SVG Não Renderizam

### Problema
Componente `PlannerPrerequisiteConnections.svelte` existe e está bem implementado, mas as setas SVG entre os cards do plano não aparecem ao fazer hover.

### Setup Verificado ✅
- ✅ Arquivo existe: `PlannerPrerequisiteConnections.svelte`
- ✅ Está wrappando corretamente o conteúdo em `PlanoFormaturaView.svelte`
- ✅ MateriaPlanCard tem `data-subject-code={materia.codigo}`
- ✅ SemestrePlanCard renderiza MateriaPlanCard corretamente
- ✅ SVG template está bem formado com markers e path elements

### Investigação em Andamento
**Logging adicionado** para debugar:

```typescript
// Verificar se curso data está carregado
console.log('[PlannerPrerequisiteConnections] curso loaded:', 
  { materias: curso.materias.length, preRequisitos: curso.preRequisitos?.length || 0 }
);

// Listar todos os cards encontrados
console.log(`[PlannerPrerequisiteConnections] Found ${cardEls.length} cards`);

// Para cada card, verificar se tem pré-requisitos
console.log(`[PlannerPrerequisiteConnections] ${subjectCode}: 
  found in curso = ${!!materiaInCurso}, 
  prerequisitos = ${prereqs.length}`
);

// Log de cada seta sendo desenhada
console.log(`[PlannerPrerequisiteConnections] Drawing arrow: ${sourceCode} → ${subjectCode}`);
```

### Como Debugar
1. Executar `npm run dev`
2. Abrir DevTools (F12)
3. Ir para Console
4. Navegar até Plano de Formatura
5. Verificar logs para:
   - Quantos cards foram encontrados
   - Quantos pré-requisitos cada matéria tem
   - Se há inconsistência na normalização de códigos
   - Se o SVG está sendo renderizado

### Possíveis Causas
1. **curso.preRequisitos vazio** — Dados de pré-requisitos não carregados
2. **Inconsistência de normalização** — Códigos em diferentes formatos (FGA0160 vs fga0160)
3. **getDirectPrerequisites() não encontrando matches** — Problema na lógica de lookup
4. **SVG dimensions** — viewBox ou width/height problemáticos

### Próximas Ações
- [ ] Verificar console.log ao executar dev server
- [ ] Confirmar se `curso.preRequisitos` tem dados
- [ ] Validar normalização de códigos é consistente
- [ ] Se necessário, adicionar fix para normalização em `getDirectPrerequisites()`

---

## Status Resumido

| Bug | Status | Commits | Testes |
|-----|--------|---------|--------|
| 1 - Créditos | ✅ CORRIGIDO | 559489a4 | 4/4 ✓ |
| 2 - Motivos | ✅ CORRIGIDO | 559489a4 | 4/4 ✓ |
| 3 - Setas SVG | ⚠️ DEBUGGING | d354d869 | Build ✓ |

---

## Como Prosseguir

```bash
# Rodar dev server para testar
cd no_fluxo_frontend_svelte
npm run dev

# Abrir http://localhost:5173/plano-formatura
# Abrir DevTools (F12) → Console
# Procurar por logs [PlannerPrerequisiteConnections]
# Analisar qual é o bloqueador
```

