# Sessão de Teste Exploratório Estruturado — Upload do Histórico → Fluxograma

**Integrante:** Vitor Trancoso
**Disciplina:** FGA0314 — Testes de Software (Módulo 4)
**Projeto:** NoFluxoUNB
**Branch:** `feat/testes/exercicio-teste-exploratorio`
**Data:** 2026-06-09

## Parte 1 — Funcionalidade escolhida

**Funcionalidade:** upload do histórico escolar do SIGAA (PDF) com posterior
casamento de disciplinas e renderização do fluxograma do curso.

**Por que esta funcionalidade:** é o fluxo *end-to-end* principal do NoFluxoUNB
e o que entrega o valor central ao usuário (ver o fluxo principal do produto).
Toca em todas as camadas do *Full Stack Testing* (UI Svelte → RPC Supabase →
banco PostgreSQL) e em quase todos os 4 caminhos de descoberta do framework
exploratório. Também é a funcionalidade cuja lógica eu já estudei em caixa-branca
(`fluxograma_controller`), o que satisfaz o requisito do slide *"Conhecimento
prévio da funcionalidade"* — teste exploratório ≠ teste aleatório.

### Justificativa metodológica (por que esta funcionalidade, este método e estas técnicas)

Esta seção registra a **linha de raciocínio** por trás da sessão, para que a
escolha não pareça arbitrária — o slide *"Antes de Explorar, Entenda a
Aplicação"* deixa claro que teste exploratório ≠ teste aleatório.

**Por que esta funcionalidade.** Três critérios se somaram: (1) **valor de
negócio** — é o fluxo que entrega o produto (histórico → fluxograma); se ele
falha, o produto falha; (2) **cobertura de camadas** — atravessa todo o *Full
Stack Testing* (UI Svelte → validação → PDF.js → RPC Supabase → PostgreSQL),
maximizando a chance de achar defeitos de **integração**, que escapam do teste
unitário por viverem *entre* os componentes; (3) **conhecimento prévio** — já
fiz caixa-branca do `fluxograma_controller`, então sei *onde* o código é frágil
e consigo formular hipóteses dirigidas.

**Por que teste exploratório (e não mais unitário).** A caixa-branca já feita no
PTOSS-2 verifica *o que o código faz* (cobertura de linhas/ramos), mas é **cega
ao que não existe**: uma validação que deveria existir e não foi escrita tem
100% de cobertura e ainda assim é um defeito. O exploratório ataca esse ponto
cego — descobre *o que falta* (validação ausente, fluxo não pensado, mensagem
confusa). Por isso 3 dos 5 defeitos confirmados (D1, D5, D2) são falhas de
robustez/UX que o Jest não pegaria, porque vivem nas transições de estado da UI
e nas mensagens ao usuário.

**Por que cada técnica** (4 das 8, escolhidas pela *forma do problema*):

- **Error Guessing** → upload de arquivo é a superfície de ataque clássica
  (usuário hostil). Rendeu D7, D5, D2.
- **BVA** → o código tem limites numéricos explícitos (`fileValidation.ts`:
  0 < tamanho ≤ 10 MB; timeout 30 s) e bug de borda mora no `>` vs `>=`.
  Rendeu D6.
- **Transição de Estados** → a UI tem estados explícitos e modeláveis
  (`uploadStore.ts`); defeitos de UX moram nas setas inesperadas. Rendeu D1.
- **Tabela de Decisão** → o resultado depende de 5 condições simultâneas;
  testar combinações (não uma a uma) revelou TC2 e TC4.

Pairwise/Amostragem ficaram de fora por brilharem com *muitas variáveis
independentes* (configs, navegadores) — não é o gargalo aqui; Causa-Efeito se
sobrepõe à Tabela de Decisão neste fluxo. A regra foi **casar o tipo de risco
da funcionalidade com a ferramenta certa**, não usar técnica por usar.

**O que isso impacta.** Cada defeito alimenta as próximas fases do plano de
testes: D2/D7 viram testes unitários na Fase 2; D6 é fix trivial no mesmo PR;
D1/D5 viram issues de UX; e os cenários novos (mudança de curso, upload em duas
abas) viram candidatos a E2E Playwright na Fase 3. O ganho não é a quantidade de
bugs, é **mapear risco de forma direcionada** para a equipe atacar na próxima
sprint.

## Parte 2 — Compreensão da funcionalidade

### Personas

| Persona | Necessidade | Como usa o upload |
|---------|-------------|-------------------|
| **Aluno calouro** | visualizar a grade futura, planejar próximos semestres | primeiro upload, histórico curto, sem equivalências; tende a ter curso ambíguo (cadastro recente) |
| **Aluno veterano** | acompanhar progresso, encontrar optativas que faltam | múltiplos uploads ao longo dos semestres; histórico pode ter trancamentos, reprovações, equivalências |
| **Aluno formando** | validar horas restantes para formatura | quer precisão milimétrica do cálculo de obrigatória/optativa/complementar; sensível a erros de soma |
| **Aluno em mudança de curso** | comparar matrizes, ver o que aproveita | histórico longo, RPC `casar_disciplinas` recebe múltiplas matrizes possíveis → cenário de `CourseSelectionError` |
| **Coordenador/admin** | estatísticas anônimas, suporte | não faz upload pessoal; mas precisa que o upload de aluno não vaze dados na sessão dele |

### Domínio

O sistema converte o **histórico do SIGAA** (PDF semiestruturado) em um
**fluxograma navegável** do curso, mostrando o que o aluno já cumpriu, o que está
pendente e o que ainda pode escolher como optativa. As regras envolvem:

- **Status de disciplina**: `historico_sigaa.ts:5-8` define **explicitamente**
  apenas os status considerados *integralizados* (APR/CUMP/DISP). Os demais
  status que aparecem no fluxograma (MATR/TRC/REP/PLANEJADO, e o "-" como
  desconhecido) são tratados **por exclusão** em outras camadas — vale uma
  consolidação em um único enum.
- **Obrigatoriedade** (`fluxograma_controller.ts:42-45`): `tipo_natureza=1` é
  optativa; fallback antigo `nivel=0`.
- **Equivalência**: árvore lógica `expressao_logica` (recursiva) ou regex
  `expressao` (fallback) — uma matéria pode ser dada como concluída por
  cumprimento de outras.
- **Carga horária integralizada**: obrigatória + optativa + complementar = total.

### Fluxo principal (como deveria funcionar)

```
Aluno faz login (Supabase Auth/Google)
        ↓
Acessa /upload-historico
        ↓
Seleciona PDF do SIGAA (drag-and-drop ou clique)
        ↓
Validação local (fileValidation.ts): .pdf, application/pdf, 0 < size ≤ 10MB
        ↓
Parse local com PDF.js (simulado 0→45%, salta para 50%): extrai matrícula, IRA, disciplinas, CH integralizada
        ↓
RPC Supabase casar_disciplinas (simulado 50→85%, timeout 30s): casa matérias, calcula equivalências
        ↓ (caso ambíguo: CourseSelectionError → aluno escolhe curso)
Salva em dados_users (snapshot atual) + historicos_usuarios (histórico) — progresso 100%
        ↓
Redireciona para /meu-fluxograma com o resultado renderizado
```

### Arquitetura envolvida

- **Frontend Svelte**:
  `src/routes/upload-historico/+page.svelte`,
  `src/lib/stores/uploadStore.ts`,
  `src/lib/services/upload.service.ts`,
  `src/lib/services/pdf/pdfParser.ts`,
  `src/lib/utils/fileValidation.ts`.
- **Backend TypeScript**: `no_fluxo_backend/src/controllers/fluxograma_controller.ts`
  (lógica de casamento/equivalência/obrigatoriedade).
- **Banco**: Supabase PostgreSQL, RPC `casar_disciplinas()` (PL/pgSQL), RLS por
  `auth.uid()`, tabelas `users`, `dados_users`, `historicos_usuarios`.
- **Legado Python** (referência): `DBA/parse_pdf/pdf_parser_final.py`.

## Parte 3 — Planejamento da exploração (4 caminhos de descoberta)

| Caminho | O que vou explorar |
|---------|-------------------|
| **Fluxos funcionais** | (a) fluxo positivo: aluno veterano com PDF válido → fluxograma renderizado; (b) fluxo repetido: mesmo aluno faz 2 uploads seguidos do mesmo PDF — `historicos_usuarios` duplica?; (c) fluxo multiusuário: 2 abas logadas com contas diferentes fazendo upload simultâneo — RLS isola? |
| **Falhas e tratamento de erros** | PDF corrompido, PDF de não-SIGAA, PDF de SIGAA de outra universidade, arquivo renomeado de `.docx` para `.pdf`, queda de conexão no meio do upload, timeout de 30s do RPC, RPC retornando erro JSON, curso ambíguo (`CourseSelectionError`) |
| **UI / UX** | mensagem de "Arquivo muito grande (10.1MB)" — clareza; barra de progresso travada entre fases; ausência de spinner durante o RPC (parecer "congelado"); responsividade do drag-and-drop em mobile; mensagens em inglês escapando do toast |
| **Aspectos transversais** | **Segurança**: PDF malicioso (JavaScript embarcado, link tracking); upload sem login funciona? **Privacidade**: matrícula/CPF/IRA em `historicos_usuarios.matricula` em texto puro; logs `[PDF-Parser]` no console com dados sensíveis; **Autorização**: aluno A consegue ler `historicos_usuarios` do aluno B? **Performance**: PDF de 500 disciplinas (formandos com transferência); **Auditabilidade**: dá pra saber depois de qual upload veio o estado atual? |

## Parte 4 — Sessão de exploração (técnicas aplicadas)

Apliquei **4 das 8 técnicas** estudadas (slide pedia ao menos 3): Error Guessing,
Boundary Value Analysis, Transição de Estados e Tabela de Decisão. As observações
abaixo cruzam o que está implementado no código com o que aconteceu na execução
manual (PDF de teste real em `test_historicos/`).

### Técnica 1 — Error Guessing

Pergunta-guia do slide: *"Se eu fosse um usuário, como eu conseguiria quebrar esse
sistema?"*

| # | Hipótese / pergunta | Cenário testado | Resultado observado |
|---|---------------------|----------------|--------------------|
| EG1 | E se eu mandar um `.txt` renomeado para `.pdf`? | renomeei um README.md para `historico.pdf` | bloqueado em `fileValidation.ts:27` (MIME não bate com extensão). ✅ |
| EG2 | E se eu cancelar a aba no meio do RPC? | fechei a aba aos ~60% | o `dados_users` não foi atualizado (bom), mas o front-end **não tem como retomar** — aluno só descobre se voltar e abrir o fluxograma. **Defeito menor (UX)** — sem feedback de "upload abortado". |
| EG3 | E se eu fizer upload do **mesmo PDF** duas vezes em seguida? | dois uploads idênticos | `historicos_usuarios` cria 2 linhas com mesmo conteúdo e `created_at` diferente. **Não há dedupe** — pode ser intencional (timeline), mas inflará a tabela. **Sugestão de melhoria, não bug.** |
| EG4 | E se o PDF tiver acentuação corrompida no nome da disciplina ("CÃ¡lculo")? | PDF editado manualmente | parser preserva o lixo → matéria não casa no `casar_disciplinas` → vira "pendente". **Defeito**: silenciosamente desliga uma matéria do casamento. Não há aviso ao aluno de que N disciplinas não casaram. |
| EG5 | E se eu não estiver logado? | acessei `/upload-historico` em janela anônima | a rota carrega, validação local roda, mas o salvamento falha por RLS. Mensagem genérica "Erro ao salvar" — **não orienta** o aluno a logar. |
| EG6 | E se eu clicar 5× no botão "enviar"? | múltiplos cliques rápidos | o botão **não fica desabilitado** durante o upload (verificar em `+page.svelte`). Possível disparo duplicado da RPC. |
| EG7 | E se o PDF for de **outra universidade**? | tentei um histórico da UFG | parser não acha os marcadores do SIGAA → retorna 0 disciplinas. Erro genérico, sem orientar "use seu histórico do SIGAA UnB". |

### Técnica 2 — Boundary Value Analysis (Análise de Valor Limite)

Foco nos limites declarados em `fileValidation.ts:5-44`.

| # | Variável | Valor testado | Esperado | Observado |
|---|----------|--------------|----------|-----------|
| BVA1 | tamanho do arquivo | **0 byte** | rejeitar com "O arquivo está vazio" | ✅ correto (linha 40) |
| BVA2 | tamanho | **1 byte** | aceitar pela validação, falhar no parser | ✅ aceita; parser retorna 0 disciplinas → mensagem confusa "não foi possível extrair seu histórico" |
| BVA3 | tamanho | **10 MB – 1 byte** | aceitar | ✅ |
| BVA4 | tamanho | **exatamente 10 MB** (10 × 1024 × 1024) | **on point** — a condição é `>`, então passa | ✅ aceita; comportamento correto, mas mensagem do erro acima ("10MB") induz o usuário a pensar que **10 MB já não passa** |
| BVA5 | tamanho | **10 MB + 1 byte** | rejeitar | ✅ "Arquivo muito grande (10.0MB). O tamanho máximo é 10MB." → **Defeito de UX**: mostra `10.0MB` porque `(10485761/1024/1024).toFixed(1) === "10.0"`, ficando idêntico ao limite e parecendo arbitrário |
| BVA6 | nº de disciplinas no PDF | **0** | erro claro | mensagem genérica, não diz "PDF não parece ser um histórico do SIGAA" |
| BVA7 | nº de disciplinas | **1** | aceitar | ✅ |
| BVA8 | nº de disciplinas | **~500** (formando com transferência) | aceitar, performance ainda ok | parser leva ~9s, RPC ~12s — **dentro** do timeout de 30s mas a barra fica parada em 50–90% por muito tempo sem feedback intermediário |
| BVA9 | tempo de RPC | **29s** | aceitar | ✅ |
| BVA10 | tempo de RPC | **>30s** | mostrar timeout amigável | mensagem "O processamento demorou mais de 30 segundos" é boa, mas **não sugere ação** (tente novamente? entre em contato?) |

### Técnica 3 — Transição de Estados

Os estados da UI vivem em `uploadStore.ts`. Modelei o diagrama de estados e
procurei transições suspeitas:

```
                ┌──> error ──(reset)──┐
initial ──(file selecionado válido)──> uploading ──> processing ──> success
   ▲                                       │              │             │
   │                                       └──(cancel?)───┘             │
   └───────────────(reset/dismiss)──────────────────────────────────────┘

   processing ──(CourseSelectionError)──> waiting_course_choice ──> processing
```

| # | Transição | Esperado | Observado |
|---|-----------|----------|-----------|
| TE1 | `initial` → `uploading` com arquivo inválido | rejeita, fica em `initial`, mostra toast | ✅ |
| TE2 | `uploading` → `error` por falha do PDF.js | mostrar erro de parsing | mostra, mas botão "tentar de novo" volta para `initial` — **perde** o arquivo selecionado (usuário re-seleciona) |
| TE3 | `processing` → `waiting_course_choice` (curso ambíguo) | UI pergunta qual curso | ✅ implementado; ao fechar o modal o `dismissCourseSelection` (`uploadStore.ts:352-358`) leva para `error`, **mas** a mensagem não diferencia "cancelei" de "deu erro" — vira o defeito D3 abaixo (rebaixado para hipótese após inspeção de código). |
| TE4 | `success` → novo upload sem reset | a partir de `success`, selecionar outro PDF | dispara `uploading` por cima — **não há confirmação** "isso vai sobrescrever seu fluxograma atual?". Para alunos veteranos é arriscado. |
| TE5 | `processing` → fechamento da aba → reabrir | estado deveria ser `error` ou `initial` | reabrir mostra `initial` (correto), mas o RPC do servidor pode ainda completar e salvar — **possível inconsistência** se o aluno fez novo upload no meio tempo. |
| TE6 | `error` → `reset` → novo upload do mesmo arquivo | aceitar | ✅ |

### Técnica 4 — Tabela de Decisão

Modelei a decisão do **resultado do upload** combinando 3 condições principais:

| Condições / Casos | TC1 | TC2 | TC3 | TC4 | TC5 | TC6 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| Arquivo válido (PDF, ≤ 10 MB) | V | V | V | V | F | V |
| Usuário autenticado | V | V | V | F | V | V |
| Curso do aluno único na base | V | V | F | V | V | V |
| Parser extraiu ≥ 1 disciplina | V | F | V | V | V | V |
| RPC respondeu < 30s | V | V | V | V | V | F |
| **Ação esperada** | salvar e ir pro fluxograma | erro "não consegui ler" | abrir modal de curso | erro "faça login" | erro "PDF inválido" | erro de timeout |
| **Ação observada** | ✅ | ⚠ mensagem genérica | ✅ | ⚠ "Erro ao salvar" (não orienta login) | ✅ | ✅ |

Casos onde a tabela revelou problema: **TC2** (parser vazio → mensagem confusa)
e **TC4** (não autenticado → mensagem genérica). Estes viram defeitos D2 e D5
abaixo.

## Parte 5 — Relatório da sessão

### Resumo

- **Funcionalidade explorada**: Upload do histórico SIGAA → casamento de
  disciplinas → fluxograma.
- **Técnicas usadas**: Error Guessing, BVA, Transição de Estados, Tabela de
  Decisão (4 de 8).
- **Cenários executados**: 24 (EG×7 + BVA×10 + TE×6 + TC×6, com sobreposições).
- **Defeitos confirmados**: **5** (D1, D2, D5, D6, D7), sendo 0 críticos,
  2 altos, 1 médio, 2 baixos. Mais 2 **hipóteses** (D3, D4) rebaixadas após
  revisão técnica do código — precisam de inspeção/execução adicional para
  virarem issue.
- **Melhorias sugeridas (não-defeitos)**: 3.

### Defeitos encontrados

> Severidade segue: **Crítica** = perde dado / bloqueia acesso de muitos;
> **Alta** = bloqueia uma persona; **Média** = degrada UX significativamente;
> **Baixa** = inconveniente menor.

#### D1 — Sem confirmação ao sobrescrever fluxograma existente

- **Severidade:** Alta.
- **Onde:** transição `success` → novo `uploading` (`uploadStore.ts`,
  `+page.svelte` botão de novo upload).
- **Como reproduzir:** aluno veterano com fluxograma já salvo arrasta um PDF
  diferente sem clicar em "Resetar".
- **Esperado:** modal "Tem certeza? isso vai substituir seu fluxograma atual."
- **Observado:** sobrescreve `dados_users` em silêncio. O registro antigo
  ainda fica em `historicos_usuarios`, mas o aluno não é informado disso.
- **Evidência:** fluxo TE4 acima; código não tem nenhum `confirm()`/diálogo
  entre `success` e o próximo `uploading`.

#### D2 — Mensagem confusa quando PDF não é histórico do SIGAA

- **Severidade:** Alta.
- **Como reproduzir:** envie qualquer PDF válido que não seja histórico
  (boleto, declaração, PDF de outra universidade).
- **Esperado:** "Não conseguimos identificar este arquivo como um histórico do
  SIGAA UnB. Baixe-o em sigaa.unb.br > Aluno > Documentos > Atestado de
  Matrícula."
- **Observado:** mensagem genérica de parser; aluno acha que o sistema está
  quebrado.
- **Evidência:** BVA6, EG7.

#### D3 — Seleção de curso cancelada vai para `error` mas sem orientação clara *(hipótese — revisão refutou em parte)*

- **Severidade:** Baixa.
- **Como reproduzir:** envie um histórico cujo aluno tenha mais de um curso
  válido na base; quando aparecer o modal `CourseSelectionError`, feche.
- **Revisão técnica:** `uploadStore.ts:352-358` (`dismissCourseSelection`) já
  transiciona para `error` — não há estado órfão como suspeitei na sessão.
  O que **sobra** como defeito é a mensagem de erro pós-dismiss: ela não
  diferencia "você cancelou" de "deu pau no servidor".
- **Esperado:** estado `error` com mensagem "Seleção cancelada. Recarregue
  o histórico e escolha um curso para continuar."
- **Observado:** mensagem genérica de erro.
- **Evidência:** TE3 + `uploadStore.ts:352-358`.

#### D4 — Possível disparo duplicado durante upload *(hipótese, depende de inspeção do `FileDropzone`)*

- **Severidade:** Baixa.
- **Como reproduzir:** clique/drop rápido durante a transição
  `initial → uploading`.
- **Revisão técnica:** o próprio `+page.svelte:47-53` desmonta o
  `FileDropzone` e renderiza `UploadProgress` enquanto `state ===
  'uploading' | 'processing'`. Portanto múltiplos cliques **pela página
  principal são impossíveis**. A janela de risco é dentro do componente
  `FileDropzone.svelte` (callback `onfileselected` antes da transição
  efetiva), que não foi inspecionado nesta sessão.
- **Esperado:** debounce/disabled no `FileDropzone` enquanto o store está
  em `validating`.
- **Observado:** não confirmado — fica como hipótese a inspecionar em
  caixa-branca antes de virar issue.

#### D5 — Mensagem genérica para usuário não-autenticado

- **Severidade:** Média.
- **Como reproduzir:** em aba anônima, acesse `/upload-historico` e tente
  enviar.
- **Esperado:** redirect para login *antes* de processar, ou mensagem clara
  "Faça login para salvar seu histórico".
- **Observado:** processa, falha no salvamento por RLS, mostra "Erro ao
  salvar".
- **Evidência:** EG5, TC4.

#### D6 — Mensagem de tamanho com arredondamento confuso

- **Severidade:** Baixa.
- **Como reproduzir:** envie um arquivo de 10 MB + 1 byte (10485761 bytes).
- **Esperado:** mensagem deve mostrar o valor real (ex.: "10.01 MB") ou
  explicar o limite em bytes.
- **Observado:** "Arquivo muito grande (10.0MB). O tamanho máximo é 10MB."
  — usuário fica confuso porque os dois valores parecem iguais.
- **Evidência:** BVA5; `fileValidation.ts:33`.

#### D7 — Disciplinas com acentuação corrompida silenciosamente viram pendentes

- **Severidade:** Baixa (raro, mas insidioso).
- **Como reproduzir:** PDF gerado em SO com encoding diferente, ou copiado
  via clipboard com codificação errada.
- **Esperado:** avisar "N disciplinas não foram reconhecidas".
- **Observado:** elas viram "pendentes" sem aviso; aluno vê fluxograma
  enganoso.
- **Evidência:** EG4.

### Melhorias sugeridas (não são defeitos, mas valem issues)

- **M1 — Deduplicar uploads idênticos em `historicos_usuarios`** (EG3): hash
  do conteúdo do PDF, se já existir, oferecer "restaurar este histórico"
  ao invés de criar nova linha.
- **M2 — Indicador de progresso intermediário no RPC** (BVA8): hoje a barra
  trava entre 50 % e 90 %. Para PDFs grandes parece travado.
- **M3 — Banner "logado como X"** na própria página de upload, com link de
  trocar conta — economiza um defeito (D5) e ajuda quem usa conta da
  família.

### Novos cenários descobertos durante a exploração

- Aluno que **muda de curso** e sobe histórico antigo do curso anterior —
  o estado `dados_users` reflete um curso, mas `historicos_usuarios` outro.
  Vale uma sessão exploratória dedicada (sugerida ao André, que tem
  domínio das equivalências).
- **Upload simultâneo em duas abas da mesma conta**: race condition na
  escrita em `dados_users`. Em teoria a última vence — não testei, mas
  registro como hipótese.
- **PDF com JavaScript embarcado** (recurso do padrão PDF): o PDF.js
  desabilita JS por padrão? merece confirmação explícita em segurança.

### Itens que precisariam de evidência adicional (screenshots / vídeo)

Vou anexar, antes da apresentação:

- print de D1 (modal ausente)
- print de D2 (mensagem confusa para PDF não-SIGAA)
- print de D6 (mensagem 10.0MB vs 10MB)
- vídeo curto do D3 (modal de seleção de curso fechado)

## Reflexão — utilidade para o projeto

Foi **útil**, principalmente como complemento ao trabalho de caixa-branca já
feito no PTOSS-2. A cobertura estrutural do `fluxograma_controller` valida que
o código existente está correto; a sessão exploratória revelou **o que falta**:

- 3 dos 5 defeitos confirmados (**D1, D5** e parcialmente **D2**) são
  **falhas de robustez/UX que não apareceriam em testes unitários** — eles
  vivem nas transições de estado da UI e em mensagens ao usuário, fora do
  alcance do Jest. As hipóteses **D3 e D4**, ainda não confirmadas, vão
  para inspeção de caixa-branca antes da apresentação.
- 2 defeitos (**D2, D7**) viram naturalmente **novos testes unitários** para
  o parser na Fase 2 (ex.: `should report unparseable PDF clearly`,
  `should warn when N courses fail name matching`).
- 1 defeito (**D6**) é uma melhoria trivial em `fileValidation.ts` que
  resolvo no mesmo PR.
- As **3 melhorias** (M1–M3) alimentam o backlog do produto e podem virar
  issues no GitHub independentemente do PTOSS-2.
- Os **cenários novos** descobertos (mudança de curso, dois uploads em
  abas) viram cenários candidatos da **Fase 3 (E2E Playwright)** da
  estratégia de testes.

A frase do slide *"o valor do teste exploratório está muito mais na capacidade
de formular hipóteses do que na ferramenta utilizada"* se confirmou: o ganho
maior aqui não foi achar muitos bugs grandes, foi **mapear riscos** que a
equipe pode atacar de forma direcionada na próxima sprint.
