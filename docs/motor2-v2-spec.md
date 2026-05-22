# Motor 2 v2 — Especificação Revisada

## Problema com v1
- Trata todas as matérias faltantes como iguais
- Não diferencia obrigatórias / optativas / complementares
- Não lê dados de `carga_horaria_integralizada`
- Não identifica semestre atual (MATR)
- Recomenda matérias específicas para optativas (quando existem 100+)

## Novo fluxo (v2)

### Input (novo endpoint: POST /planejamento/gerar-plano-completo)
```typescript
{
  id_user: string  // obrigatório — busca dados completos do banco
}
```

**Dados buscados automaticamente:**
- `dados_users.id_curso` → matriz
- `dados_users.semestre_atual`
- `dados_users.carga_horaria_integralizada` → { total, obrigatoria, optativa, complementar }
- `dados_users.fluxograma_atual` → string JSON com `dados_fluxograma[]`
- `matrizes` → ch_obrigatoria_exigida, ch_optativa_exigida, ch_complementar_exigida
- `materias_por_curso` → todas as matérias do currículo com tipo_natureza (0=obrigatória)

### Parse fluxograma_atual
```typescript
interface DisciplinaFluxo {
  codigo: string;
  status: "APR" | "REP" | "MATR" | null;
  ano_periodo: string;
  tipo_dado: string;
  // ...
}

// Extrair:
- MATR → semestre atual (não entram no plano futuro)
- APR → já concluída, desbloqueia pré-requisitos, CH já integralizada
- REP → ignora (conta como não concluída)
- null/sem status → ignora
```

### Cálculos de requisitos

```typescript
// CH integralizada por tipo (do banco ou computado de fluxograma_atual)
integralizada = {
  obrigatoria: 1020,
  optativa: 30,
  complementar: 0,
  total: 1050
}

// Matriz exige:
exigida = {
  obrigatoria: 1620,
  optativa: 600,
  complementar: 210,
  total: 2430
}

// Semestre atual (MATR) — creditoSemestreAtual é MATR que estão em andamento
creditoSemestreAtual = somarCreditos(subjects com status=MATR)

// Faltante (quer dizer, a ser alocado no plano futuro):
ch_obrigatoria_faltante = exigida.obrigatoria - integralizada.obrigatoria
                         // = 1620 - 1020 = 600 CH obrigatórias pendentes

ch_optativa_faltante = max(0, exigida.optativa - integralizada.optativa - creditoSemestreAtual.optativa)
                      // = max(0, 600 - 30 - <opcional em MATR>)

ch_complementar_faltante = max(0, exigida.complementar - integralizada.complementar)
```

### Algoritmo de geração

**Fase 1: Identificar obrigatórias pendentes**
1. Filtrar `materias_por_curso` onde tipo_natureza = 0 (obrigatória)
2. Remover as já em APR (completedCodes)
3. Montar grafo de pré-requisitos (igual a v1)

**Fase 2: Distribuir obrigatórias + estágio + TCC**
1. Usar greedy topológico igual a v1
2. **MAS:** estágio e TCC sempre nos últimos semestres (após 80% das obrigatórias)
3. Respeitar pré-requisitos

**Fase 3: Adicionar slots de optativas**
- Após alocar obrigatórias, há CH restante por semestre
- Preencher com "Optativa Slot": `{ tipo: "optativa_slot", ch: 60, descricao: "2 optativas livres (~60h)" }`
- Distribuir slots até atingir `ch_optativa_faltante` total

**Fase 4: Adicionar slots de complementares**
- Idem: `{ tipo: "complementar_slot", ch: 210, descricao: "Atividades complementares" }`
- Colocar nos semestres que ainda têm espaço

### Output esperado

```typescript
{
  semestreAtual: {
    tipo: "em_curso",
    materias: [
      { codigo: "ENE0066", nome: "...", creditos: 60, status: "MATR" },
      { codigo: "ENE0001", nome: "...", creditos: 60, status: "MATR" },
      { codigo: "ENE0068", nome: "...", creditos: 60, status: "MATR" }
    ]
  },
  semestresRestantes: 12,
  formaturaEstimada: "2028.1",
  plano: [
    {
      indice: 0,
      tipo: "recomendado",
      creditos: 84,
      materias: [
        {
          codigo: "ENE0200",
          nome: "Estágio Supervisionado",
          creditos: 60,
          critica: true,
          desbloqueiaDireto: 0,
          desbloqueiaIndireto: 0,
          score: 100,
          motivo: "obrigatória, deve estar ao final do curso"
        },
        {
          tipo: "optativa_slot",
          ch: 24,
          descricao: "Até 1 optativa"
        }
      ]
    },
    // ... mais semestres
  ],
  chObrigatóriaFaltante: 0,
  chOptativaFaltante: 300,
  chComplementarFaltante: 210
}
```

## Mudanças de código necessárias

### 1. Types (✓ já feito)
- Adicionar `PlanoFormaturav2`
- Adicionar `OptativaSlot`, `ComplementarSlot`
- Manter `PlanoFormatura` para compatibilidade

### 2. Service (novo)
- Nova função `gerarPlanoCompleto(idUser, id_curso, semestre_atual, carga_horaria_integralizada, exigida_matriz, fluxograma_atual, materias)` 
- Parsear fluxograma_atual (parse da string JSON)
- Calcular CH faltante por tipo
- Distribuir obrigatórias (v1 + coloca estágio/TCC ao final)
- Preencher com slots de optativa e complementar

### 3. Controller (novo endpoint)
- `POST /planejamento/gerar-plano-completo`
- Requer `id_user` (pode verificar JWT ou receber como param)
- Busca dados do banco: `dados_users`, `matrizes`, `materias_por_curso`, `pre_requisitos`, `co_requisitos`
- Chama nova function do service
- Retorna `PlanoFormaturav2`

## Próximos passos (questões para usuário)

1. **Autenticação**: Como identificar o `id_user`? 
   - JWT do frontend (requer logout/login)
   - Query param (inseguro, mas útil para testes)
   - Header Authorization

2. **Backward compatibility**: Manter endpoint antigo ou substituir?
   - Opção A: Manter ambos (`gerar-plano` e `gerar-plano-completo`)
   - Opção B: Unificar em um único endpoint com id_user opcional

3. **Estágio/TCC**: Como identificar no banco?
   - Buscar código hardcoded (ex: "ENE0200", "TCC0001")? 
   - Usar tipo_natureza especial?
   - Aceitar como parâmetro?

4. **Optativas recomendadas**: Se houver score > 0 para optativas, usar?
   - Sim → colocar nos primeiros slots
   - Não → apenas slots genéricos

5. **Complementares**: Sempre genérico ou buscar atividades específicas?
   - Genérico por enquanto?
