# Motor 2 — Cadeia de formatura personalizada

## O que faz
Dado o estado atual do aluno, gera uma sequência de semestres futuros com as matérias recomendadas para ele se formar no menor tempo possível.

O plano é estimativa — recalcula toda vez que o aluno sobe novo histórico. Não é fixo.

## Entradas
- Matérias concluídas (de `historicos_usuarios.fluxograma_atual`)
- Matérias faltantes (degree audit contra `materias_por_curso` + `matrizes`)
- Grafo de pré-requisitos (`pre_requisitos.expressao_logica` — suporta AND/OR em jsonb)
- Co-requisitos (`co_requisitos`)
- `nivel` de cada matéria em `materias_por_curso` — semestre esperado no fluxo padrão
- Limite de créditos por semestre (onboarding do aluno)

## Saída
```json
{
  "semestres_restantes": 5,
  "formatura_estimada": "2027.1",
  "plano": [
    {
      "semestre": "2025.2",
      "tipo": "recomendado",
      "creditos": 24,
      "materias": [
        {
          "codigo": "CIC0110",
          "nome": "Compiladores",
          "creditos": 4,
          "critica": true,
          "desbloqueia_direto": 3,
          "desbloqueia_indireto": 5,
          "motivo": "desbloqueia 3 matérias e está atrasada"
        }
      ]
    },
    {
      "semestre": "2026.1",
      "tipo": "estimado",
      "creditos": 24,
      "materias": []
    }
  ]
}
```

## Algoritmo

### Passo 1 — Degree audit
Calcular o que falta:
- Obrigatórias não concluídas (tipo_natureza obrigatória em materias_por_curso)
- Créditos optativos restantes (ch_optativa_exigida - integralizado)
- Créditos complementares restantes

### Passo 2 — Grafo de dependências
Montar grafo direcionado das matérias faltantes com base em `pre_requisitos`.
`expressao_logica` é jsonb — avaliar AND/OR para determinar se pré-requisitos estão satisfeitos.
Uma matéria só entra num semestre se todos seus pré-requisitos foram concluídos em semestres anteriores.

### Passo 3 — Score de prioridade
Para cada matéria faltante:
```
score =
  + 3 se obrigatória
  + 2 × qtd matérias que desbloqueia diretamente
  + 1 × qtd matérias que desbloqueia indiretamente (cadeia completa)
  + 2 se nivel < semestre_atual do aluno (está atrasada)
```

### Passo 4 — Distribuição gulosa por semestres
```
semestre_atual = []
para cada iteração até zerar matérias faltantes:
  candidatas = matérias com pré-requisitos satisfeitos
  ordenar candidatas por score desc
  preencher semestre até limite de créditos do aluno
  marcar matérias escolhidas como "cursadas"
  avançar para próximo semestre
```

Co-requisitos devem entrar no mesmo semestre.

### Passo 5 — Marcar críticas
Matéria é crítica quando:
- Score >= threshold (definir empiricamente, sugestão: top 30% do score)
- OU está atrasada (nivel < semestre_atual)

Matérias críticas nunca são removidas mesmo com carga reduzida.

## Onboarding (3 perguntas — só na primeira vez)
1. Trabalha ou estagia? → ajusta limite de créditos
2. Quantos créditos por semestre? (16 / 24 / 32)
3. Objetivo: velocidade máxima ou equilíbrio?

Salvar em `dados_users` ou tabela nova `perfil_planejamento_user`.

## Regras importantes
- Próximo semestre: recomendação firme baseada no estado atual
- Semestres seguintes: estimativa, marcar `tipo: "estimado"` no output
- Recalcula sempre que aluno sobe novo histórico
- Não depende de dados de dificuldade ou taxa de reprovação
- Não prevê turmas/horários futuros (isso é o Motor 1 — próxima etapa)
- Impacto de reduzir carga deve ser calculado e exibido: "+1 semestre", "+2 semestres"

## Localização no projeto
- Controller: `no_fluxo_backend/src/controllers/PlanejamentoController.ts`
- Rota sugerida: `GET /planejamento/:id_user`
- Registrar em `src/index.ts`

## Frontend
- Tela: colunas verticais por semestre, scroll horizontal
- Próximo semestre destacado com tag "Recomendado"
- Semestres seguintes com tag "Estimado"
- Cards coloridos: crítico (laranja #993C1D), recomendado (azul #185FA5), estimado (cinza)
- Pill "crítico" em matérias com score alto
- Mostrar "desbloqueia X matérias" em cada card crítico
- Stats no topo: semestres restantes, matérias faltando, formatura estimada
- Botão "Ajustar carga" → slider de créditos → recalcula impacto em tempo real
- Botão "Montar grade" → chama Motor 1 (próxima etapa)