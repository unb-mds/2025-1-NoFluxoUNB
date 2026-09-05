# Diagnóstico de dados pré-ML — NoFluxo

**Coleta:** 2026-09-04, 22:59–23:10 UTC · **Banco:** `lijmhbstgdinsukovyfl.supabase.co` (produção; não há staging)
**Método:** somente leitura, service role, via PostgREST. Scripts em `scripts/investigacao_ml/`.
**Escopo:** responder às questões 4.1–4.5 do briefing de IA/ML + perfilar o estado dos dados em cada tabela.

---

## 1. Sumário executivo

1. **O dataset para o modelo de risco existe e é utilizável**: 138.371 eventos com período válido, dos quais **4.257 reprovações** (REP/REPF) e **1.686 TRANC/CANC**. Não é grande, mas é suficiente para um primeiro modelo — e 43,1% dos alunos têm 2+ uploads, viabilizando validação temporal real.
2. **⚠ O join de matriz descrito no briefing está errado e quebra silenciosamente.** `matriz_curricular` = `"6360/1"`, `curriculo_completo` = `"6360/1 - 2017.1"`. Igualdade resolve **0 de 2.458 alunos**; com a chave certa (prefixo antes de `" - "`), resolve **100%**. Qualquer feature de matriz construída sobre o join ingênuo sai vazia sem erro.
3. **`nivel` não é confiável como campo persistido** — 0% em março/2026, ~87% desde maio. Precisa ser **derivado** via `codigo → materias → materias_por_curso` (85,0% de cobertura; os 14,8% restantes são matérias fora da matriz, não bug).
4. **⚠ O sinal principal de detecção de troca de curso proposto no briefing é inválido.** O gap entre uploads mede quando a pessoa subiu o PDF, não quando trocou de curso — e reprovava justamente os casos que o briefing lista como reais (759, 1635).
5. **A allowlist de admins resolve o problema de ruído quase sozinha**: as 2 contas de teste conhecidas (17, 318) são admins, e após filtrá-las o resíduo de "suspeita" cai para **zero**. A heurística cara da seção 4.2 não se paga.
6. **Linkar docente retroativamente: não viável.** Só 2,3% das avaliações resolvem para um docente único — e a razão dominante nem é ambiguidade, é que 89,1% se referem a semestres sem dado nenhum em `turmas`.
7. **A série temporal de vagas continuará em 2027.1, mas rala**, a menos que alguém ligue a flag manual. A densidade de 2026.2 (43 dias de coleta) foi consequência da flag ligada; 2026.1 tem literalmente **um instante** de coleta.
8. **Sem dedup, qualquer agregado infla +109,3%** — a mesma disciplina reaparece a cada novo upload do aluno.

---

## 2. Metodologia

Todo acesso passou por `@supabase/supabase-js` com a chave service role de `no_fluxo_backend/.env`. **PostgREST não aceita SQL livre** e o projeto não tem RPC de SQL dinâmico, `DATABASE_URL` ou Supabase CLI configurados — então todo agregado sobre `fluxograma_atual` (jsonb) foi calculado em JS após o fetch.

Garantias aplicadas nos scripts (verificadas, não só declaradas):
- `grep` por `insert|update|delete|upsert|rpc` nos 7 scripts: **vazio**.
- Guard `INVESTIGACAO_CONFIRM=1` — sem ele, exit 2 sem tocar o banco (testado).
- Trava de PII em runtime: `assertNoPII()` bloqueia `email`, `nome_completo`, `matricula`, `cpf`, `telefone` e `select('*')`; testada com colunas proibidas e com falsos positivos plausíveis (`nome_materia` passa, corretamente).
- Taxa de preenchimento medida com `count(head:true)` — o banco devolve só um número; nenhum valor de coluna sensível trafegou.

> **Incidente durante a coleta.** As legacy API keys do projeto foram desativadas em 2026-09-04T20:25Z, derrubando service role **e** anon key (HTTP 401 em ambas) — ou seja, backend e frontend ficaram sem acesso ao banco. Foi resolvido com a troca para uma chave nova (`sb_secret_…`) em `no_fluxo_backend/.env`. **Os demais consumidores continuam com chave legacy** (ver §9).

---

## 3. Perfil por tabela

28 tabelas/views expostas pelo PostgREST. Contagens no momento da coleta:

| Tabela | Linhas | Observações |
|---|---:|---|
| `materias_por_curso` | 150.829 | maior tabela; grade curricular de 530 matrizes |
| `turmas_historico` | 75.227 | série temporal de vagas (ver §8) |
| `materias` | 26.531 | `dificuldade_*` preenchida em só 27,8% |
| `materias_vetorizadas` | 26.145 | embeddings pgvector (98,5% de `materias`) |
| `equivalencias` | 24.058 | |
| `pre_requisitos` | 15.507 | |
| `turmas` | 12.988 | 6.473 em 2026.1 + 6.515 em 2026.2 |
| `historicos_usuarios` | 5.130 | 2.458 alunos distintos |
| `materias_estatisticas_historico` (view) | 4.228 | acessível e correta (ver §4) |
| `users` | 3.372 | |
| `dados_users` | 2.531 | |
| `ai_usage_log` | 1.431 | |
| `avaliacoes_disciplinas` | 1.321 | |
| `matrizes` / `vw_creditos_por_matriz` | 530 | |
| `materias_estatisticas_avaliacoes` (view) | 555 | |
| `notificacoes` | 379 | pipeline de alerta de vagas ativo |
| `co_requisitos` | 216 | |
| `vaga_assinaturas` | 222 | |
| `cursos` | 157 | |
| `chat_items` / `chat_sessions` | 100 / 4 | **chat quase não é usado** (ver §10) |
| `ticket_audit_log` / `tickets` | 80 / 34 | |
| `admins` | 5 | |
| `system_settings` / `preferencias_grade` | 1 / 1 | |

**Colunas 100% nulas** (candidatas a remoção ou a bug de escrita): `admins.created_by`, `ai_pricing.updated_by`, `cursos.campus`, `tickets.assigned_to`, `tickets.admin_notes`.

**Colunas esparsas**: `materias.dificuldade_estimada`/`motivo_dificuldade`/`dificuldade_calculada_em` (27,8%), `dificuldade_fonte` (25,6%), `turmas_historico.id_turmas` (17,3% — as demais observações perderam a FK, que é `ON DELETE SET NULL`, quando `04_reconciliar_turmas.py` apagou a turma), `notificacoes.lida_em` (12,4% — a maioria não foi lida).

---

## 4. Vocabulário de status e viabilidade da view

**Os 9 status canônicos do parser conferem com os dados — nenhum status fora do conjunto.**

| Status | Total | Com período | Sem período |
|---|---:|---:|---:|
| APR | 108.699 | 108.680 | 19 |
| MATR | 20.007 | 20.007 | 0 |
| CUMP | 9.380 | 3.520 | **5.860** |
| REP | 3.709 | 3.708 | 1 |
| TRANC | 1.193 | 1.193 | 0 |
| REPF | 549 | 549 | 0 |
| CANC | 493 | 493 | 0 |
| DISP | 225 | 221 | 4 |
| REPMF | **0** | 0 | 0 |

Correções ao briefing:
- **`TRANC` e `CANC` existem** — no código (`pdfPositionExtractor.ts:172`) e nos dados (1.193 e 493).
- **`ARP` não existe** em lugar nenhum: nem código, nem dados. Erro de digitação.
- **`REPMF` existe no código mas tem zero ocorrências** — o parser aceita, a UnB não usa (ou o parser nunca acertou o caso).
- **Achado #2 do briefing confirmado com precisão:** dos 5.884 eventos sem período, **5.864 são CUMP/DISP = 99,66%**.

**A view `materias_estatisticas_historico` é confiável e pode ser citada como fonte.** Acessível via service role, e a paridade contra o parsing manual bateu exatamente nos 5 códigos de maior volume (DSC0172: 1.234 tentativas / 29 reprovações em ambos). Ressalva: o `taxa_reprovacao` dela conta **apenas APR/REP/REPF** como tentativa — ignora TRANC/CANC/MATR/CUMP/DISP. Para o modelo de risco, isso subestima o abandono.

---

## 5. Seção 4.1 — Densidade e qualidade de `historicos_usuarios`

**Volume:** 144.255 eventos em 5.130 uploads de 2.458 alunos (2,09 uploads/aluno). 105 uploads não têm fluxograma parseável. **1.059 alunos (43,1%) têm 2+ uploads** — confirma o achado #3 do briefing e viabiliza validação temporal.

### ⚠ O join de matriz do briefing está errado

O briefing afirma que `matriz_curricular` bate direto com `matrizes.curriculo_completo`, "join direto, sem ambiguidade". Na prática:

```
historicos_usuarios.matriz_curricular  = "6360/1"
matrizes.curriculo_completo            = "6360/1 - 2017.1"
```

Join por igualdade resolve **0 de 2.458 alunos**. Normalizando os dois lados pelo prefixo antes de `" - "` (parte dos históricos guarda a string completa, parte só o prefixo):

| Situação | Alunos |
|---|---:|
| matriz resolvida sem ambiguidade | 2.391 |
| chave ambígua (mesmo código/versão, `ano_vigor` distinto) | 67 |
| sem correspondência | 0 |

14 das 516 chaves são ambíguas. **Risco prático:** o join ingênuo não dá erro — só devolve vazio. Uma feature de matriz construída assim treina com dado ausente silenciosamente.

### `nivel` precisa ser derivado, não lido

O campo **não é persistido de forma estável**. Presença por mês de upload:

| Mês | Eventos | Com `nivel` |
|---|---:|---:|
| 2026-03 | 10.455 | **0,0%** |
| 2026-04 | 21.471 | 43,4% |
| 2026-05 | 13.456 | 85,9% |
| 2026-06 | 8.396 | 88,3% |
| 2026-07 | 40.454 | 87,5% |
| 2026-08 | 43.330 | 87,1% |
| 2026-09 | 6.693 | 84,4% |

Foi introduzido em ~abril/2026 e estabilizou em ~87%. Derivando via `codigo → materias → materias_por_curso`:

- **85,0% deriváveis** (58.567 eventos)
- 14,8% são matérias fora da matriz do aluno (optativas/extras) — **estrutural, não bug**
- 0,3% (182) têm código inexistente no catálogo `materias`

Os ~13% que faltam no campo persistido são exatamente as matérias fora da matriz: o teto de ~87% é o comportamento correto, não uma falha de preenchimento.

### Dedup: dois problemas distintos, tamanhos opostos

| | Ocorrências |
|---|---:|
| Grupos (aluno, código) com 2+ eventos no upload mais recente | 396 |
| → re-matrícula legítima (períodos distintos) | **392** |
| → duplicata literal (mesmo período+status+menção) = bug | **4** |

Duplicata literal é desprezível (4 eventos, em `ICB0329` e `DEG0233`). **Mas a inflação entre uploads é grande:** somar todos os uploads dá 144.255 eventos contra 68.928 usando só o mais recente por aluno — **+109,3%**. Agregado sem dedup dobra as contagens.

---

## 6. Seção 4.2 — Heurística de troca de curso

**74 alunos** têm 2+ cursos em `curso_extraido`.

### ⚠ O Sinal 1 proposto no briefing é inválido

O briefing propunha o gap temporal entre uploads como sinal de maior peso (0.5), assumindo que troca real leva tempo. Rodando contra os dados, ele **reprovou os casos que o próprio briefing lista como reais**:

- **id_user 759** subiu os históricos de Eng. Aeroespacial e Eng. de Software **no mesmo dia** — cada um internamente coerente (55,56% e 47,5%, períodos 2023.x–2026.1, com equivalências).
- **id_user 1635** alterna Geologia e Eng. Ambiental, e **ambos progridem no tempo** (GEO 12,8%→20,5%→25,6%; AMB 11,8%→13,7%).

`created_at` mede quando a pessoa subiu o PDF, não quando trocou de curso. Aluno real sobe os dois PDFs na mesma sessão. Com os pesos do briefing, 759 e 1635 pontuavam 0,15 — "suspeita".

### Sinais redesenhados

| Sinal | Peso | Racional |
|---|---:|---|
| S1 — nº de cursos distintos | 0,35 | 2 = troca/dupla matrícula; 4+ = PDFs de terceiros |
| S2 — monotonia **por curso** | 0,35 | cada curso deve progredir, não oscilar |
| S3 — coerência do início acadêmico | 0,30 | a mesma pessoa começa na mesma época |

S3 usa o menor `ano_periodo` entre disciplinas regulares, excluindo equivalência/CUMP/DISP (que carregam o período do curso anterior).

**Resultado:** 64 plausível · 8 média · 2 suspeita. Contra o ground truth: **4 de 5 corretos** — 318 ✓, 759 ✓, 1635 ✓, 245 ✓; **17 ficou em "média" (0,55)** em vez de "suspeita".

> **Não continuei ajustando os pesos.** Com 5 casos rotulados, seguir mexendo até o 17 virar é overfit, não validação. E o 17 é admin — a allowlist já o pega.

### Limitação de design, registrada

S1+S2 somam 0,70 sozinhos, então qualquer aluno com 2 cursos e progressão monotônica classifica como "plausível" **mesmo com 10 anos entre os inícios** (id_user 1399). Isso não foi "corrigido" de propósito: spread grande também é o perfil de aluno que volta à universidade anos depois, que o achado #4 do briefing diz ser dado real. **O dado não distingue troca antiga de histórico de terceiro** — por isso esses casos saem numa lista de revisão humana (13 alunos), não numa classe automática.

---

## 7. Seção 4.3 — Contas de teste

Cruzando `admins.auth_id × users.auth_id`: **5 admins, todos com `id_user` correspondente** — 312, 8, 17, 318, 20 (todos `superadmin`).

**As duas contas de teste conhecidas do briefing (17 e 318) são admins — cobertura 2/2.** E o resíduo depois de filtrar admins:

| | |
|---|---:|
| suspeitas totais | 2 |
| que são admin | 2 |
| **resíduo não-admin** | **0** |

**Conclusão:** a hipótese do briefing na seção 4.3 está certa e é mais forte do que ele supunha — o cruzamento barato com `admins` captura todo o ruído detectável. A heurística da 4.2 não encontrou um único caso de ruído fora da allowlist.

**Ressalva:** `admins.created_by` é **100% nulo**, então a allowlist não tem rastro de quem marcou cada admin. Se ela virar tabela, esse campo precisa ser preenchido de fato.

---

## 8. Seção 4.4 — Linkar docente em `avaliacoes_disciplinas`: **não viável**

| Candidatos a docente | Avaliações | % |
|---|---:|---:|
| 0 (sem turma correspondente) | 1.177 | **89,1%** |
| 1 (resolvido) | 30 | **2,3%** |
| 2 | 37 | 2,8% |
| 3+ | 77 | 5,8% |

O obstáculo dominante não é a ambiguidade de professor — é **cobertura temporal**. `turmas` e `turmas_historico` só têm dados de **2026.1 e 2026.2**, enquanto as avaliações se concentram em semestres anteriores:

| Semestre da avaliação | Avaliações | Há turma? |
|---|---:|---|
| 2025.1 | 377 | não |
| 2025.2 | 374 | não |
| 2024.2 | 225 | não |
| 2026.1 | 164 | sim |
| 2024.1 | 63 | não |
| (vazio) | 56 | não |
| 2023.x / 2022.x | 55 | não |
| 2026.2 | 6 | sim |
| **2034.2** | 1 | não — **data impossível, erro de digitação** |

Somam-se as três limitações estruturais já previstas: múltiplas turmas por (matéria, período) sem `id_turmas` na avaliação; `turmas.docente` é texto livre sem FK (mesma pessoa com grafias diferentes infla a contagem); e **`turmas` não tem coluna `campus`** (só `local`, texto livre), então o `campus` da avaliação não desambigua.

**Recomendação retroativa:** não usar. O dado não existe e não é recuperável.

### ⚠ Correção: para o futuro, não é preciso mudar o formulário

O histórico do SIGAA **traz a turma de cada disciplina**, e o parser já a extrai
(`pdfPositionExtractor.ts:260-263,535`). O frontend também já sabe persisti-la
(`uploadStore.ts:51` lê `disc.turma`; `factories/index.ts:95` grava). Quem descartava era a
RPC `casar_disciplinas`: a temp table `_casadas` não tinha a coluna, os dois
`INSERT ... VALUES` posicionais não a passavam e o `jsonb_build_object` final não a emitia.

A prova está na diferença entre os dois caminhos de escrita:

| Campo | `historicos_usuarios` (passa pela RPC) | `dados_users` (caminho que não passa) |
|---|---:|---|
| `turma` | **0 de 144.338** | 1,7% — valores reais (`"01"`, `"06"`, `"AA"`) |
| `frequencia` | **0 de 144.338** | 1,6% — `"100,0"`, `"93,0"`, `"86,0"` |
| `professor` | 82,1% | 81,7% |

Corrigido em `supabase/migrations/20260904230000_casar_disciplinas_persistir_turma.sql`
(4 pontos dentro da função; alinhamento posicional conferido: 21 colunas, 21 valores em
ambos os INSERTs). **Não faz backfill** — o PDF de origem não é guardado, então os 144k
eventos já persistidos continuam sem turma.

Com turma no histórico, o docente de uma avaliação pode ser **derivado do histórico de quem
avalia** (turma + matéria + período → `turmas.docente`), sem perguntar nada a mais no
formulário e sem guardar quem respondeu. Vale só para avaliações feitas depois que os alunos
subirem histórico novo.

Corrigir também o `semestre` de texto livre (o `2034.2` e os 56 vazios) com um `CHECK` ou
select fechado.

> `historicos_usuarios.fluxograma_atual` carrega `professor` em **82,1%** dos eventos. Não
> resolve a 4.4 sozinho (a avaliação é anônima; é o professor *daquele aluno*), mas é uma
> fonte rica e inexplorada para outras análises — ex.: taxa de reprovação por professor.

---

## 9. Seção 4.5 — Cobertura de `turmas_historico`

| Período | Observações | Matérias | Primeira | Última | Obs/matéria |
|---|---:|---:|---|---|---:|
| 2026.1 | 6.473 | 3.434 | 2026-04-12T23:07 | 2026-04-12T23:07 | 1,9 |
| 2026.2 | 68.754 | 3.516 | 2026-07-16T22:27 | 2026-09-01T02:58 | **19,6** |

**Confirmado exatamente o que o briefing suspeitava:** 2026.1 tem *um único instante* de coleta (primeira = última) — é snapshot, não série temporal. 2026.2 tem 43 dias distintos de coleta.

Os três sinais são coerentes entre si:
- **A (cadência real):** `turmas.last_updated_at` tem só 2 instantes distintos — 2026-04-12 (linhas de 2026.1, congeladas desde o fim do período) e 2026-09-01 (2026.2). Última execução há ~89h.
- **B (trigger):** grava normalmente, e rotulou `2026.2` sozinho — **o pipeline é period-aware, sem hardcode**. Vai funcionar em 2027.1 sem alteração de código.
- **C (flag):** `scraping_turmas_rapido = {"enabled": false}`, desligada em 2026-08-31 — data que coincide com o fim da coleta densa.

**Conclusão:** a coleta continua em 2027.1 automaticamente, mas **a densidade depende de alguém ligar a flag manualmente durante o período de matrícula**. Sem isso, 2027.1 vai parecer 2026.1: um snapshot inútil para modelagem. O modelo de previsão de lotação tem hoje **um único período** com série temporal real — não dá para validar generalização entre períodos até que 2027.1 seja coletado com a flag ligada.

---

## 10. Riscos e achados paralelos

1. **⚠ Chave de service role vazada no git.** `DBA/database/config.py` (~linha 41) tem um JWT de service role de produção **hardcoded como fallback**, commitado. Bypassa todo RLS. As legacy keys foram desativadas durante esta investigação — o que torna essa chave específica inerte —, mas **o padrão precisa sair do código** e a rotação precisa ser concluída.
2. **⚠ Migração de chaves incompleta.** Só `no_fluxo_backend/.env` recebeu a chave nova (`sb_secret_…`). Continuam com chave legacy (inerte): `SUPABASE_KEY` no mesmo arquivo, `mcp_agent/.env`, `no_fluxo_frontend_svelte/.env` (anon), os secrets do GitHub Actions e os manifests de deploy. **Enquanto isso não for feito, frontend e scrapers seguem sem acesso ao banco.**
3. **Ambiente único.** A mesma chave serve dev, CI e produção. Toda query desta investigação bateu em produção.
4. **`chat_sessions` = 4 linhas, `chat_items` = 100.** A ideia de "persistir o chat do assistente" já tem tabela — e ela está praticamente vazia. Antes de investir em análise de conversas da Darcy, vale entender se o recurso não está sendo usado ou se não está sendo gravado.

---

## 11. Impacto no roadmap de IA

| Ideia | Veredito | Bloqueio real |
|---|---|---|
| **Modelo de risco/evasão** | ✅ viável agora | Nenhum. 5.943 eventos negativos, 43% dos alunos com histórico temporal. Cuidar do dedup (+109%) e derivar `nivel`. |
| **Gargalos curriculares** | ✅ viável agora | A view já entrega taxa de reprovação por matéria; ampliar para contar TRANC/CANC. |
| **GNN sobre o grafo** | ✅ dado pronto | 150.829 vínculos matéria–matriz, 24.058 equivalências, 15.507 pré-requisitos, já estruturados. |
| **Sentimento de disciplinas** | ⚠ parcial | 1.321 avaliações é pouco, e **sem docente** — nunca por professor. |
| **Previsão de lotação de vagas** | ⛔ esperar | Um único período com série real. Depende de ligar a flag em 2027.1. |
| **Simulador de troca de curso** | ⚠ repensar | Só 74 alunos com 2+ cursos, e a maioria é dupla matrícula, não troca. Amostra pequena demais para aprender padrões. |

**Prioridade sugerida:** o que mudou em relação ao roadmap publicado é (a) previsão de lotação **cai** de prioridade — o dado não existe ainda e depende de uma ação operacional, não de modelagem; (b) o **saneamento do join de matriz** sobe para bloqueador, porque qualquer feature curricular construída sobre ele hoje sai vazia sem avisar; e (c) a **allowlist de admins** deixa de precisar de heurística — é um `INSERT` de 5 linhas, não um projeto.

---

## Apêndice — reprodução

```powershell
# carrega o .env sem expor a chave no histórico do shell
Get-Content no_fluxo_backend/.env | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim('"'))
  }
}
$env:INVESTIGACAO_CONFIRM='1'

node scripts/investigacao_ml/00_perfil_tabelas.mjs
node scripts/investigacao_ml/01_status_codes_e_view_check.mjs
node scripts/investigacao_ml/02_admins_allowlist.mjs      # antes do 04
node scripts/investigacao_ml/03_qualidade_historicos.mjs
node scripts/investigacao_ml/04_heuristica_troca_curso.mjs
node scripts/investigacao_ml/05_avaliacoes_docente_crosscheck.mjs
node scripts/investigacao_ml/06_turmas_historico_cobertura.mjs
```

JSONs brutos em `scripts/investigacao_ml/_reports/` (gitignored). Todos os scripts aceitam `--json` e `--limit N`.
