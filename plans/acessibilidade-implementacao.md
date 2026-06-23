# Plano de Implementação — Acessibilidade NoFluxoUNB

**Branch**: `feat/testes-acessibilidade`
**Autor**: Vitor Trancoso (PTOSS-2)
**Data**: junho/2026
**Documentos de referência**: `docs/testes/seminario-acessibilidade.pdf`, `docs/testes/relatorio-acessibilidade.pdf`

## 1. Objetivo

Aplicar no projeto NoFluxoUNB as recomendações do relatório de acessibilidade WCAG 2.2 + a pesquisa de referência (ISO/IEC 25010, axe-core, *accessibility by design*), em três frentes:

1. **Correções de código** prioritárias (skip link, gerência de foco SPA, ARIA em formulários, status com ícone+texto, contraste).
2. **Modo de acessibilidade** configurável pelo usuário em `/configuracoes` (alto contraste, redução de movimento, fonte ampliada, fonte para dislexia).
3. **Pipeline de testes a11y** (Vitest + `@axe-core/svelte` + Playwright + `@axe-core/playwright` + *gate* em CI).

## 2. Particionamento (sem conflitos de arquivo)

| Agente | Escopo | Arquivos exclusivos |
|---|---|---|
| **A — Layout e foco SPA** | Skip link, `<main id="main-content" tabindex="-1">`, gerência de foco com `afterNavigate`, store `a11y` global, aplicação de classes no `<html>` | `src/routes/+layout.svelte`, `src/lib/stores/a11y.ts` (novo), `src/lib/actions/skipLink.ts` (novo) |
| **B — Navbar e link de configurações** | `aria-current="page"` nos links ativos, item de menu para `/configuracoes` | `src/lib/components/layout/Navbar.svelte` |
| **C — Formulários ARIA** | `aria-invalid`, `aria-describedby`, `aria-live` em `TextInput`; remover `tabindex=-1` do toggle de senha; `autocomplete` correto | `src/lib/components/forms/TextInput.svelte`, `src/lib/components/auth/LoginForm.svelte` |
| **D — Página `/configuracoes`** | Nova rota com toggles: alto contraste, reduzir movimento, fonte ampliada, dislexia, mostrar foco reforçado; persistência em localStorage; integra com store `a11y` | `src/routes/configuracoes/+page.svelte` (novo), `src/routes/configuracoes/+page.ts` (novo) |
| **E — CSS de acessibilidade** | `.sr-only`, `.sr-only-focusable`, regras para `prefers-reduced-motion`, classes `.a11y-high-contrast`, `.a11y-large-text`, `.a11y-dyslexic`, `.a11y-focus-bold` | `src/app.css` |
| **F — Status visual redundante** | Acrescentar ícone + label textual ao status da disciplina (concluída, em curso, disponível, bloqueada, reprovada) | `src/lib/components/fluxograma/SubjectCard.svelte` |
| **G — Testes axe + CI** | `@axe-core/svelte` em Vitest (button, input, modal), `@axe-core/playwright` para `/`, `/login`, `/configuracoes`; workflow GitHub Actions | `package.json` (deps + scripts), `tests/a11y/*.test.ts` (novos), `tests/e2e/a11y.spec.ts` (novo), `.github/workflows/a11y.yml` (novo) |

## 3. Critérios de Aceitação WCAG 2.2

- **2.4.1** Skip link presente e operável por teclado.
- **2.4.3 / 2.4.7** Foco visível em todos os controles; foco restaurado em navegação SPA para `<main>`.
- **1.3.1 / 3.3.1** Erros de formulário com `aria-invalid` + `aria-describedby` + `aria-live="polite"`.
- **1.4.1** Status NUNCA depende somente de cor — sempre cor + ícone + texto.
- **1.4.3** Contraste mínimo 4.5:1; modo alto contraste eleva a 7:1.
- **1.4.12** Modo *large text* aumenta corpo base em ≥150%.
- **2.5.8** Alvos de toque ≥ 24×24 px (modo alto contraste: ≥ 44×44 px).
- **2.3.3 / prefers-reduced-motion** Animações desativadas quando o usuário pedir.
- **4.1.2** Estados anunciados a leitor de tela via `aria-live`.

## 4. Fluxo de Execução

```
1. Plano aprovado → este documento
2. Dev server inicia (pnpm dev na 5173)
3. Chrome MCP captura ANTES: / /login /signup /configuracoes(404 ainda)
4. Workflow paralelo: 7 agentes implementadores em arquivos disjuntos
5. Workflow paralelo de REVISORES adversariais (1 por agente) validam vs evidência de código
6. Chrome MCP captura DEPOIS: mesmas rotas + /configuracoes funcional + toggles ON
7. Relatório markdown com diff de screenshots e checklist WCAG
```

## 5. Modo de Acessibilidade — Especificação Funcional

Página `/configuracoes` com seção "Acessibilidade", controlada por store `$lib/stores/a11y.ts` (persistida em `localStorage` como `nofluxo_a11y`):

| Toggle | Classe aplicada em `<html>` | Efeito visual |
|---|---|---|
| Alto contraste | `a11y-high-contrast` | Fundos pretos puros, texto branco puro, bordas brancas, foco amarelo 3px |
| Reduzir movimento | `a11y-reduced-motion` | `transition: none !important`, `animation: none !important` |
| Texto ampliado | `a11y-large-text` | `font-size: 112.5%` no root, line-height 1.65 |
| Fonte para dislexia | `a11y-dyslexic` | `font-family: 'OpenDyslexic', 'Atkinson Hyperlegible', sans-serif` (fallback nativo, sem download) |
| Foco reforçado | `a11y-focus-bold` | `:focus-visible { outline: 3px solid #FFD600 !important; outline-offset: 3px; }` |

A store também respeita `window.matchMedia('(prefers-reduced-motion: reduce)')` na inicialização. A página oferece botão **"Restaurar padrões"** e link "Saiba mais sobre acessibilidade" para `https://www.w3.org/WAI/standards-guidelines/wcag/`.

## 6. Política de Revisão Adversarial

Cada revisor recebe a saída do implementador correspondente e tem instrução explícita: *"sua tarefa é refutar. Default refuted=true em caso de dúvida. Verifique cada mudança contra arquivo:linha e contra critério WCAG citado."* Achados confirmados são listados; achados refutados são removidos sem alarde.

## 7. Não-Escopo (fora desta entrega)

- Migração para `bits-ui` `Dialog` com focus-trap nativo em TODOS os modais customizados (faremos só na config).
- Reescrita do SVG do fluxograma como `role="img"` com `<title>/<desc>` exaustivo (mantido como item de roadmap; aplicaremos `aria-label` na raiz).
- Testes com usuários reais com deficiência (roadmap institucional).
- Tradução para inglês.

## 8. Roadmap pós-entrega

1. Modo *list/table* alternativo ao grafo SVG.
2. Captação de feedback via UnB Acessibilidade.
3. `ACCESSIBILITY.md` documentando políticas.
4. Auditoria com leitor de tela real (NVDA + VoiceOver) gravada em vídeo.
