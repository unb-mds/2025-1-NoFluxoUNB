# Testes Exploratórios Estruturados

Além das baterias automatizadas em Jest, Vitest e Pytest, o projeto **NoFluxoUNB** conduziu sessões formais de **Testes Exploratórios Baseados em Sessão (SBET - Session-Based Exploratory Testing)** no âmbito do Módulo 4 da disciplina FGA0314.

---

## 👥 Divisão de Responsabilidades e Escopos

Cada integrante da equipe conduziu uma sessão estruturada focada em uma funcionalidade crítica do sistema, aplicando técnicas sistemáticas de teste funcional (Particionamento de Equivalência, Análise de Valor Limite, Tabela de Decisão, Transição de Estados e Error Guessing):

| Integrante | Funcionalidade Explorada | Técnicas Chave Aplicadas | Documento de Evidência |
|---|---|---|---|
| **Vitor** | **Upload de Histórico $\rightarrow$ Geração do Fluxograma** | Transição de Estados, BVA, Error Guessing | [`docs/testes/teste-exploratorio-upload-historico.md`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/docs/testes/teste-exploratorio-upload-historico.md) |
| **Enzo** | **Assistente IA (Chatbot e Recomendações)** | Error Guessing (prompts adversariais), Tabela de Decisão | [`docs/testes/teste-exploratorio-enzo.md`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/docs/testes/teste-exploratorio-enzo.md) |
| **André** | **Busca e Filtros de Disciplinas no Fluxograma** | Análise de Valor Limite, Tabela de Decisão, Normalização | [`docs/testes/teste-exploratorio-andre.md`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/docs/testes/teste-exploratorio-andre.md) |
| **Vini** | **Autenticação, Sessão e Recuperação de Conta** | Transição de Estados, Aspectos Transversais de Segurança | [`docs/testes/teste-exploratorio-vini.md`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/docs/testes/teste-exploratorio-vini.md) |
| **Kauan** | **Engine de Extração e Parsing de PDF (Python)** | Particionamento de Formatos SIGAA, BVA (arquivos limítrofes) | [`docs/testes/teste-exploratorio-kauan.md`](file:///c:/Users/Felipe%20Pedroza/Documents/UnB/nofluxo/2025-1-NoFluxoUNB/docs/testes/teste-exploratorio-kauan.md) |

---

## 🧭 Metodologia das Sessões

Cada sessão exploratória foi executada seguindo as 5 etapas estruturais:

1. **Definição da Carta da Sessão (Charter):** Objetivo, personas envolvidas, suposições de entrada e limites de tempo (timebox de 45 a 90 minutos).
2. **Mapeamento de Caminhos de Descoberta:**
   - *Fluxos Funcionais:* Caminho feliz e caminhos alternativos de navegação.
   - *Tratamento de Falhas:* Comportamento sob dados truncados, caracteres maliciosos ou conexões lentas.
   - *Experiência de Usuário (UI/UX):* Responsividade mobile, contraste e clareza de mensagens de erro.
   - *Aspectos Transversais:* Segurança, concorrência e persistência de dados no Supabase.
3. **Aplicação Sistemática de Técnicas:** Registro dos inputs de teste formulados via BVA, tabelas-verdade ou particionamento.
4. **Coleta de Evidências:** Screenshots, logs de console, payloads HTTP interceptados e gravações de reprodução (arquivados em `docs/testes/evidencias/`).
5. **Classificação de Defeitos e Criação de Issues:** Registro de severidade (Blocker, Major, Minor, Cosmetic) com passos reprodutíveis.

---

## 🐞 Principais Defeitos Mapeados e Mitigados

As sessões exploratórias geraram testes de regressão automatizados e correções no código-fonte:

1. **Truncamento de Horários Complexos:** A extração de turmas com horários espalhados por múltiplos campi foi corrigida com testes unitários em `sigaa.test.ts`.
2. **Resolução de Caracteres Especiais na Busca:** A pesquisa por disciplinas com acentuação e cedilha gerava resultados vazios; corrigido com normalização Unicode em `text.utils` e coberto em `SubjectSearch.test.ts`.
3. **Limpeza de Grade em Telas Mobile:** O botão de redefinição da grade ficava inacessível sob a barra de navegação móvel; corrigido e coberto pelo teste E2E `repro-limpar-grade-mobile.spec.ts`.
4. **Persistência de Sessão de Chat:** Falha na recuperação de mensagens anteriores do assistente após recarregamento de página; corrigido e testado em `session-persistence.test.ts`.
