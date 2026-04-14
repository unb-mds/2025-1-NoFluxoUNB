# Documentacao Completa do Projeto NoFluxo UNB - Foco em Testes de Software

> Documento voltado para o grupo de testes. Escrito com linguagem acessivel para membros juniores da equipe.

---

## Indice

1. [Visao Geral do Projeto](#1-visao-geral-do-projeto)
2. [Arquitetura de Software](#2-arquitetura-de-software)
3. [Arquitetura de Pastas](#3-arquitetura-de-pastas)
4. [Backend (Node.js/Express + TypeScript)](#4-backend-nodejsexpress--typescript)
5. [Frontend Svelte (Frontend Principal/Atualizado)](#5-frontend-svelte-frontend-principalatualizado)
6. [Frontend Flutter (Legado)](#6-frontend-flutter-legado)
7. [Agente de IA (MCP Agent - Python)](#7-agente-de-ia-mcp-agent---python)
8. [Testes Existentes no Projeto](#8-testes-existentes-no-projeto)
9. [Como Rodar os Testes](#9-como-rodar-os-testes)
10. [CI/CD - Integracao Continua e Testes Automatizados](#10-cicd---integracao-continua-e-testes-automatizados)
11. [Cobertura de Codigo (Code Coverage)](#11-cobertura-de-codigo-code-coverage)
12. [Mapa de O Que Precisa de Mais Testes](#12-mapa-de-o-que-precisa-de-mais-testes)
13. [Glossario para Juniors](#13-glossario-para-juniors)
14. [Referencia Rapida de Comandos](#14-referencia-rapida-de-comandos)

---

## 1. Visao Geral do Projeto

### O que e o NoFluxo?

O **NoFluxo** e uma aplicacao web para alunos da **Universidade de Brasilia (UnB)**. Ele ajuda os estudantes a:

- **Visualizar o fluxograma** do seu curso (quais materias cursar em cada semestre)
- **Importar o historico academico** (upload de PDF do SIGAA)
- **Ver pre-requisitos** de cada materia de forma visual
- **Calcular a integralizacao** (quanto falta para se formar)
- **Receber recomendacoes de optativas** via IA (assistente inteligente)
- **Planejar optativas** adicionando elas ao fluxograma

### Tecnologias Principais

| Componente | Tecnologia | Para que serve |
|---|---|---|
| **Frontend (Principal)** | SvelteKit + TypeScript + Tailwind CSS | Interface do usuario (o que o aluno ve e interage) |
| **Frontend (Legado)** | Flutter Web | Versao antiga da interface (ainda funcional, mas o Svelte e o atual) |
| **Backend** | Node.js + Express + TypeScript | API que processa dados, faz matching de disciplinas, gerencia usuarios |
| **Agente IA** | Python + FastAPI | Servico de recomendacao de optativas usando IA (Sabia/Maritaca) |
| **Banco de Dados** | Supabase (PostgreSQL) | Armazena cursos, materias, usuarios, historicos |
| **CI/CD** | GitHub Actions | Roda testes automaticamente a cada push/PR |
| **Deploy** | Docker + Kubernetes | Coloca a aplicacao no ar |

---

## 2. Arquitetura de Software

### Diagrama Simplificado

```
+------------------+       +------------------+       +------------------+
|                  |       |                  |       |                  |
|   Frontend       | ----> |   Backend        | ----> |   Supabase       |
|   (SvelteKit)    |       |   (Express.js)   |       |   (PostgreSQL)   |
|   Porta: 5173    |       |   Porta: 3325    |       |   (Cloud)        |
|                  |       |                  |       |                  |
+------------------+       +------------------+       +------------------+
        |                         |
        |                         v
        |                  +------------------+
        |                  |                  |
        +----------------> |   MCP Agent      |
           (direto via     |   (FastAPI)      |
            Supabase RLS)  |   Porta: 8000    |
                           |                  |
                           +------------------+
```

### Como os componentes se comunicam?

1. **Frontend -> Supabase (direto):** A maior parte dos dados (cursos, materias, usuarios) e buscada diretamente do Supabase usando RLS (Row Level Security). Isso significa que o frontend fala direto com o banco, sem passar pelo backend.

2. **Frontend -> Backend:** Usado apenas para funcionalidades especificas como o assistente de IA e algumas operacoes de matching de disciplinas.

3. **Backend -> Supabase:** O backend tambem acessa o Supabase para operacoes que precisam de permissoes elevadas (service role key).

4. **Backend -> MCP Agent:** O backend se comunica com o agente de IA para recomendacoes de optativas.

### Padrao de Arquitetura

O projeto segue uma arquitetura em **camadas**:

```
[Rotas/Controllers] -> [Services] -> [Banco de Dados]
       ^                    ^               ^
       |                    |               |
  Recebe as           Logica de        Onde os dados
  requisicoes         negocio           ficam salvos
  HTTP
```

- **Controllers**: Recebem as requisicoes HTTP, validam os dados de entrada e chamam os services
- **Services**: Contem a logica de negocio (ex: calcular integralizacao, chamar IA)
- **Banco de Dados**: Supabase como wrapper do PostgreSQL

---

## 3. Arquitetura de Pastas

### Visao Geral do Monorepo

O projeto e um **monorepo** (tudo num repositorio so) gerenciado com **pnpm workspaces**.

```
2025-1-NoFluxoUNB/                    # Raiz do projeto
|
|-- no_fluxo_backend/                 # Backend (Express.js + TypeScript)
|   |-- src/                          # Codigo fonte
|   |   |-- controllers/              # Endpoints da API
|   |   |-- services/                 # Logica de negocio
|   |   |-- utils/                    # Funcoes auxiliares
|   |   |-- index.ts                  # Ponto de entrada do servidor
|   |   |-- interfaces.ts             # Tipos TypeScript
|   |   |-- logger.ts                 # Sistema de logs
|   |   +-- supabase_wrapper.ts       # Conexao com banco
|   |-- tests-ts/                     # <<< TESTES DO BACKEND (Jest)
|   |-- parse-pdf/                    # Modulo de parsing de PDF
|   |-- testes-web/                   # Servidor de testes via web
|   |-- package.json                  # Dependencias do backend
|   +-- tsconfig.json                 # Configuracao TypeScript
|
|-- no_fluxo_frontend_svelte/         # Frontend Principal (SvelteKit)
|   |-- src/
|   |   |-- lib/
|   |   |   |-- components/           # Componentes visuais (botoes, modais, cards)
|   |   |   |-- services/             # Comunicacao com APIs e Supabase
|   |   |   |-- stores/               # Estado global da aplicacao
|   |   |   |-- types/                # Tipos TypeScript
|   |   |   |-- utils/                # Funcoes auxiliares
|   |   |   |-- factories/            # Conversao JSON <-> TypeScript
|   |   |   |-- guards/               # Protecao de rotas (auth)
|   |   |   +-- config/               # Configuracoes (URLs, rotas)
|   |   +-- routes/                   # Paginas (cada pasta = uma rota/URL)
|   |-- package.json
|   +-- svelte.config.js
|
|-- no_fluxo_frontend/                # Frontend Legado (Flutter)
|   |-- lib/                          # Codigo Dart
|   |   |-- screens/                  # Telas da aplicacao
|   |   |-- widgets/                  # Componentes reutilizaveis
|   |   |-- models/                   # Modelos de dados
|   |   |-- service/                  # Servicos de API
|   |   +-- routes/                   # Navegacao
|   +-- test/                         # <<< TESTES DO FLUTTER (apenas 1 teste basico)
|
|-- mcp_agent/                        # Agente de IA (Python/FastAPI)
|   |-- api_producao.py               # Servidor FastAPI principal
|   |-- embed_and_store.py            # Geracao de embeddings
|   +-- requirements.txt              # Dependencias Python
|
|-- tests-python/                     # <<< TESTES PYTHON (pytest)
|   |-- test_app.py                   # Testes do app Flask/AI Agent
|   |-- test_config.py                # Testes de configuracao
|   |-- test_upload_pdf.py            # Testes de upload de PDF
|   |-- test_scraping_equivalencias.py# Testes de scraping
|   +-- (outros arquivos de teste)
|
|-- .github/workflows/                # <<< CI/CD (GitHub Actions)
|   |-- all-tests.yml                 # Roda todos os testes
|   |-- typescript-tests.yml          # Testes TypeScript
|   |-- python-tests.yml              # Testes Python
|   |-- security-and-quality.yml      # Checagem de seguranca
|   +-- deploy.yml                    # Deploy em producao
|
|-- supabase/                         # Migracoes e funcoes do banco
|-- DBA/                              # Administracao do banco de dados
|-- coleta_dados/                     # Scripts de coleta de dados (scraping)
|-- documentacao/                     # Documentacao do projeto (MkDocs)
|-- scripts/                          # Scripts de deploy e utilidades
|
|-- jest.config.js                    # Configuracao global do Jest
|-- codecov.yml                       # Configuracao de cobertura de testes
|-- run_all_tests.sh                  # Script para rodar TODOS os testes
|-- package.json                      # Monorepo root
+-- pnpm-workspace.yaml               # Definicao dos workspaces
```

---

## 4. Backend (Node.js/Express + TypeScript)

### O que o backend faz?

O backend e uma **API REST** construida com Express.js. Ele expoe endpoints que o frontend consome.

### Endpoints Principais

| Metodo | Rota | O que faz |
|---|---|---|
| GET | `/fluxograma?nome_curso=X` | Retorna o fluxograma completo de um curso |
| POST | `/fluxograma/casar_disciplinas` | Cruza disciplinas do historico com o banco de dados |
| POST | `/fluxograma/integralizacao` | Calcula % de conclusao do curso |
| POST | `/fluxograma/upload-dados-fluxograma` | Salva dados do fluxograma do usuario |
| DELETE | `/fluxograma/delete-fluxograma` | Remove fluxograma salvo |
| GET | `/cursos/all-cursos` | Lista todos os cursos disponiveis |
| GET | `/materias/materias-name-by-code` | Busca nomes de materias por codigo |
| POST | `/users/register-user-with-google` | Registra usuario via Google |
| GET | `/users/get-user-by-email` | Busca usuario por email |
| POST | `/assistente/analyze-sabia` | Envia pergunta para IA (Sabia) |
| POST | `/assistente/analyze-sabia-stream` | Streaming de resposta da IA |
| GET | `/testes/banco` | Endpoint de teste - verifica conexao com banco |
| GET | `/testes/curso?nome_curso=X` | Endpoint de teste - busca curso especifico |
| GET | `/health` | Health check (Kubernetes) |

### Estrutura de um Controller

Cada controller segue este padrao:

```typescript
// src/controllers/users_controller.ts
export const UsersController: EndpointController = {
  name: "users",  // Nome do controller (vira a rota base: /users/...)
  routes: {
    "register-user-with-google": new Pair(
      RequestType.POST,                    // Metodo HTTP
      async (req: Request, res: Response) => {  // Handler
        const { email, nome_completo } = req.body;

        // 1. Validacao de entrada
        if (!email || !nome_completo) {
          return res.status(400).json({ error: "Email e nome completo sao obrigatorios" });
        }

        // 2. Logica de negocio
        const { data, error } = await SupabaseWrapper.get()
          .from('users')
          .select('*')
          .eq('email', email);

        // 3. Tratamento de erro
        if (error) {
          return res.status(500).json({ error: "Erro ao buscar usuario" });
        }

        // 4. Resposta
        return res.status(200).json(data);
      }
    ),
  }
};
```

### Services do Backend

| Service | Arquivo | Funcao |
|---|---|---|
| RagflowService | `services/ragflow.service.ts` | Integra com o RAGFlow para recomendacoes |
| SabiaService | `services/sabia.service.ts` | Integra com o Sabia (Maritaca IA) |
| IntegralizacaoService | `services/integralizacao.service.ts` | Calcula % de conclusao do curso |

### Utilidades Importantes

| Utilidade | Arquivo | O que faz |
|---|---|---|
| ControllerLogger | `utils/controller_logger.ts` | Logging estruturado por controller |
| Expressao Logica | `utils/expressao_logica.ts` | Avalia pre-requisitos recursivos (AND/OR) |
| Historico SIGAA | `utils/historico_sigaa.ts` | Valida status de disciplinas (APR, CUMP, DISP) |
| Text Utils | `utils/text.utils.ts` | Remove acentos, decodifica HTML |

---

## 5. Frontend Svelte (Frontend Principal/Atualizado)

> Este e o frontend ativo e mais atualizado do projeto. E o que os usuarios realmente usam.

### Tecnologias do Frontend

- **SvelteKit 5.51** - Framework web moderno e reativo
- **Svelte 5** - Biblioteca de UI (usa runes/$state)
- **TypeScript** - Tipagem estatica
- **Tailwind CSS 4** - Framework de CSS utilitario
- **Bits UI** - Biblioteca de componentes acessiveis
- **Vite 7** - Build tool ultrapido
- **Supabase SSR** - Autenticacao com PKCE
- **PDF.js** - Parsing de PDF no navegador
- **Zod** - Validacao de schemas

### Paginas e Rotas

| Rota | Pagina | Requer Login? |
|---|---|---|
| `/` ou `/home` | Pagina inicial (hero, como funciona, sobre nos) | Nao |
| `/login` | Login com email/senha ou OAuth (Google/GitHub) | Nao |
| `/signup` | Cadastro de novo usuario | Nao |
| `/login-anonimo` | Acesso como visitante | Nao |
| `/password-recovery` | Recuperacao de senha | Nao |
| `/fluxogramas` | Listagem de todos os cursos disponiveis | Nao |
| `/disciplinas` | Catalogo de disciplinas | Nao |
| `/meu-fluxograma` | Visualizacao do fluxograma do aluno | Sim |
| `/meu-fluxograma/[curso]` | Fluxograma de um curso especifico | Sim |
| `/upload-historico` | Upload do PDF do historico (SIGAA) | Sim |
| `/assistente` | Chat com IA para recomendacoes | Sim |
| `/termos` | Termos de servico | Nao |
| `/privacidade` | Politica de privacidade | Nao |

### Gerenciamento de Estado (Stores)

O frontend usa **Svelte stores** para gerenciar o estado global:

| Store | Arquivo | O que guarda |
|---|---|---|
| `authStore` | `stores/auth.ts` | Usuario logado, token, status de autenticacao |
| `fluxogramaStore` | `stores/fluxograma.store.svelte.ts` | Dados do curso, zoom, modo de conexao, optativas planejadas |
| `chatStore` | `stores/chatStore.ts` | Mensagens do chat com a IA |
| `uploadStore` | `stores/uploadStore.ts` | Estado do upload de PDF (progresso, erros, dados extraidos) |
| `modalStore` | `stores/modal.ts` | Controle de modais (abrir, fechar, confirmar) |
| `themeStore` | `stores/theme.ts` | Tema claro/escuro |
| `navigationStore` | `stores/navigation.ts` | Historico de navegacao |

### Servicos (Como o frontend se comunica)

| Servico | O que faz | Com quem fala |
|---|---|---|
| `auth.service.ts` | Login, cadastro, OAuth, logout | Supabase Auth |
| `fluxograma.service.ts` | Busca dados de cursos e fluxogramas | Supabase (direto) |
| `upload.service.ts` | Faz o parsing do PDF e matching de disciplinas | Browser (PDF.js) + Supabase RPC |
| `supabase-data.service.ts` | Queries diretas ao banco via RLS | Supabase |
| `user.service.ts` | Gerenciamento de perfil do usuario | Supabase |
| `assistente.service.ts` | Comunicacao com o agente de IA | Backend API |
| `integralizacao.service.ts` | Calculo de progresso do curso | Supabase |

### Fluxo Principal: Upload de Historico

Este e o fluxo mais complexo da aplicacao. Entender ele e essencial para testar:

```
1. Usuario arrasta o PDF do SIGAA para a area de upload
   |
2. [FASE 1 - BROWSER] PDF.js extrai o texto do PDF localmente
   |  -> Regex encontra: nome, matricula, curso, disciplinas, mencoes
   |  -> Retorna: dados_extraidos (JSON com tudo do historico)
   |
3. [FASE 2 - SUPABASE RPC] Chama a funcao casar_disciplinas()
   |  -> Cruza disciplinas extraidas com o banco de dados
   |  -> Encontra: materias aprovadas, pendentes, optativas
   |  -> Se o curso for ambiguo: abre modal de selecao
   |
4. [FASE 3 - SAVE] Salva no banco de dados
   |  -> Tabela dados_users: fluxograma atual
   |  -> Tabela historicos_usuarios: registro do envio
   |
5. Redireciona para /meu-fluxograma com tudo preenchido
```

### Componentes Importantes para Testar

| Componente | Local | O que faz |
|---|---|---|
| `FluxogramContainer` | `components/fluxograma/` | Renderiza o grid de semestres + materias |
| `CourseCard` | `components/fluxograma/` | Card individual de cada materia |
| `SubjectDetailsModal` | `components/fluxograma/` | Modal com detalhes da materia |
| `PrerequisiteChainDialog` | `components/fluxograma/` | Visualizacao da cadeia de pre-requisitos |
| `OptativasModal` | `components/fluxograma/` | Modal para adicionar optativas |
| `FileDropzone` | `components/upload/` | Area de drag-and-drop do PDF |
| `LoginForm` | `components/auth/` | Formulario de login |
| `SignupForm` | `components/auth/` | Formulario de cadastro |

### Status: Testes no Frontend Svelte

**SITUACAO ATUAL: Nenhum teste escrito.**

O frontend Svelte tem Vitest e Playwright configurados mas **sem nenhum arquivo de teste**. Isso e uma grande oportunidade para o grupo de testes.

Ferramentas ja instaladas:
- **Vitest 4.0** - Para testes unitarios de componentes e servicos
- **Playwright 1.58** - Para testes end-to-end (E2E)

---

## 6. Frontend Flutter (Legado)

> Este frontend e a versao anterior. O SvelteKit e o frontend ativo, mas o Flutter ainda esta no repositorio e funcional.

### Estrutura

- Usa **Flutter Web** com **Go Router** para navegacao
- Autenticacao via **Supabase Flutter**
- Estado gerenciado com **setState** (sem biblioteca externa)
- Pattern funcional com **dartz** (Either/Left/Right)

### Status: Testes no Flutter

Existe **apenas 1 arquivo de teste**: `test/widget_test.dart` - um teste de smoke basico (placeholder). Nao ha testes significativos.

---

## 7. Agente de IA (MCP Agent - Python)

### O que e?

E um servico Python que usa **IA (Sabia-4 da Maritaca)** para recomendar optativas aos alunos. Funciona assim:

1. Aluno digita um interesse (ex: "Quero aprender sobre dados")
2. O agente busca disciplinas semelhantes usando **embeddings** (vetores semanticos)
3. A IA ranqueia as melhores opcoes e explica por que recomenda cada uma
4. Retorna uma lista com nota de 0-10 e justificativa

### Tecnologias

- **FastAPI** + **Uvicorn** - Servidor web
- **Sentence Transformers** - Modelo de embeddings local
- **Maritaca AI (Sabia-4)** - LLM para recomendacoes
- **pgvector** - Extensao PostgreSQL para busca vetorial
- **Supabase** - Armazena os embeddings

---

## 8. Testes Existentes no Projeto

### Resumo Geral

| Componente | Framework | Qtd de Arquivos | Qtd Aprox. de Testes | Status |
|---|---|---|---|---|
| Backend (TypeScript) | Jest + ts-jest | 6 arquivos | ~30 testes | Funcionando |
| Python (AI Agent + Scripts) | pytest | 10 arquivos | ~40 testes | Funcionando |
| Frontend Svelte | Vitest + Playwright | 0 arquivos | 0 testes | Configurado mas vazio |
| Frontend Flutter | flutter_test | 1 arquivo | 1 teste (smoke) | Placeholder |

---

### 8.1 Testes do Backend (TypeScript/Jest)

**Localizacao:** `no_fluxo_backend/tests-ts/`

#### Arquivos de Teste

##### 1. `controller_logger.test.ts` (~240 linhas)

**O que testa:** O sistema de logging estruturado do backend.

**Casos de teste:**
- Criacao do logger com nome do controller
- Metodo `info()` gera log corretamente
- Metodo `error()` gera log de erro
- Metodo `warn()` gera log de aviso
- Metodo `http()` gera log HTTP
- Metodo `debug()` gera log de debug
- Formatacao com caracteres especiais
- Factory function `createControllerLogger()`
- Multiplos niveis de log em sequencia

**Importancia:** Garante que o sistema de logs funciona - essencial para debuggar problemas em producao.

---

##### 2. `users_controller.test.ts` (~198 linhas)

**O que testa:** Os 3 endpoints de gerenciamento de usuarios.

**Endpoint: `register-user-with-google`**
- Retorna 400 se email ou nome_completo estiver faltando
- Retorna 400 se o usuario ja existe
- Retorna 200 quando o usuario e criado com sucesso
- Retorna 500 quando ocorre erro no banco

**Endpoint: `get-user-by-email`**
- Retorna 400 se o email nao for fornecido
- Retorna 200 com dados do usuario quando encontrado
- Retorna 404 quando o usuario nao e encontrado

**Endpoint: `registrar-user-with-email`**
- Retorna 400 se campos obrigatorios estao faltando
- Retorna 200 quando criado com sucesso

---

##### 3. `cursos_controller.test.ts` (~110 linhas)

**O que testa:** O endpoint de listagem de cursos.

**Endpoint: `all-cursos`**
- Retorna 200 com lista de cursos quando sucesso
- Retorna 500 quando ha erro na tabela cursos
- Retorna 500 quando ha erro na tabela creditos_por_curso

---

##### 4. `materias_controller.test.ts` (~93 linhas)

**O que testa:** Os endpoints de busca de materias.

**Endpoint: `materias-name-by-code`**
- Retorna 400 se os codigos nao forem fornecidos
- Retorna 200 com nomes das materias

**Endpoint: `materias-from-codigos`**
- Retorna 400 se os codigos estao faltando
- Retorna 200 com dados completos
- Retorna 500 em caso de erro no banco

---

##### 5. `fluxograma_controller.test.ts` (~138 linhas)

**O que testa:** O endpoint principal de fluxograma.

**Endpoint: `fluxograma (GET)`**
- Retorna 400 se nome_curso nao for fornecido
- Retorna 200 com dados completos (materias, pre-requisitos, co-requisitos, equivalencias)
- Retorna 500 em caso de erro no banco

---

##### 6. `testes_controller.test.ts` (~276 linhas)

**O que testa:** Os endpoints de teste/debug do backend.

**Endpoint: `banco`**
- Testa conexao com banco de dados
- Retorna erro se banco falhar

**Endpoint: `curso`**
- Busca curso especifico
- Trata curso nao encontrado

**Endpoint: `casamento`**
- Testa matching de disciplinas
- Valida estrutura completa da resposta

---

#### Padrao de Teste Utilizado (Backend)

Todos os testes seguem o mesmo padrao. Entender isso facilita criar novos testes:

```typescript
// 1. IMPORT do controller e mock do Supabase
import { UsersController } from '../src/controllers/users_controller';
import { SupabaseWrapper } from '../src/supabase_wrapper';

// 2. MOCK do Supabase (simula o banco de dados)
jest.mock('../src/supabase_wrapper', () => {
  const mockEq = jest.fn();
  const mockSelect = jest.fn(() => ({ eq: mockEq }));
  const mockFrom = jest.fn(() => ({ select: mockSelect }));
  return {
    SupabaseWrapper: { get: jest.fn(() => ({ from: mockFrom })) }
  };
});

// 3. SETUP antes de cada teste
beforeEach(() => {
  // Cria request e response falsos
  mockRequest = { body: {}, query: {} };
  mockResponse = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn(),
  };
});

// 4. LIMPA os mocks depois de cada teste
afterEach(() => {
  jest.clearAllMocks();
});

// 5. TESTE em si
it('deve retornar 400 se email estiver faltando', async () => {
  // Arrange: Prepara os dados
  mockRequest.body = { email: 'test@example.com' }; // falta nome_completo

  // Act: Executa o handler
  const handler = UsersController.routes["register-user-with-google"].value;
  await handler(mockRequest as Request, mockResponse as Response);

  // Assert: Verifica o resultado
  expect(statusSpy).toHaveBeenCalledWith(400);
  expect(jsonSpy).toHaveBeenCalledWith({
    error: "Email e nome completo sao obrigatorios"
  });
});
```

**Conceitos-chave para juniors:**
- **Mock:** E uma "imitacao" de algo real. A gente finge que o banco de dados existe para testar so a logica do controller
- **Spy:** E quando a gente "espia" uma funcao pra ver se ela foi chamada corretamente
- **Arrange-Act-Assert:** Padrao de organizacao: Prepara -> Executa -> Verifica

---

### 8.2 Testes Python (pytest)

**Localizacao:** `tests-python/`

#### Arquivos de Teste

| Arquivo | O que testa |
|---|---|
| `test_app.py` | Endpoints do Flask app (IA agent), funcao de remover acentos |
| `test_config.py` | Configuracoes do sistema |
| `test_upload_pdf.py` | Funcionalidade de upload de PDF |
| `test_converter_json_para_txt.py` | Conversao de JSON para texto |
| `test_executar_fluxo_dados_RAGFLOW.py` | Pipeline de dados do RAGFlow |
| `test_extrair_turmas_sigaa.py` | Extracao de turmas do SIGAA |
| `test_formatar_para_ragflow.py` | Formatacao de dados para RAGFlow |
| `test_ragflow_agent_client.py` | Cliente do agente RAGFlow |
| `test_scraping_equivalencias.py` | Scraping de equivalencias |
| `test_visualizaJsonMateriasAssociadas.py` | Visualizacao de materias associadas |

#### Exemplo de Teste Python (test_app.py)

```python
# Fixture: cria o app de teste (roda antes de cada teste)
@pytest.fixture
def client(app):
    return app.test_client()

# Teste parametrizado: testa varios inputs de uma vez
@pytest.mark.parametrize("entrada, esperado", [
    ("Historia da Africa", "Historia da Africa"),
    ("educacao", "educacao"),
    ("texto sem acento", "texto sem acento"),
    ("", ""),
])
def test_remover_acentos_nativo(entrada, esperado):
    assert remover_acentos_nativo(entrada) == esperado

# Teste de endpoint com mock
def test_analisar_materia_endpoint_sucesso(client, mocker):
    # Mock das dependencias externas
    mock_ragflow = mocker.patch('...RagflowClient').return_value
    mock_ragflow.start_session.return_value = "sessao_123"
    mock_ragflow.analyze_materia.return_value = {"code": 0, "data": "dados"}

    # Executa a requisicao
    response = client.post('/assistente',
        data=json.dumps({'materia': 'Historia da Africa'}),
        content_type='application/json'
    )

    # Verifica
    assert response.status_code == 200
```

**Conceitos-chave para juniors:**
- **Fixture:** Funcao que prepara algo antes do teste (ex: criar o app)
- **Parametrize:** Roda o mesmo teste com dados diferentes automaticamente
- **Mocker:** Ferramenta para criar mocks no pytest

---

## 9. Como Rodar os Testes

### Pre-requisitos

Antes de rodar qualquer teste, voce precisa ter instalado:

- **Node.js 20+** (para testes TypeScript)
- **Python 3.9+** (para testes Python)
- **pnpm** (gerenciador de pacotes)

### Rodando TODOS os Testes de Uma Vez

```bash
# Na raiz do projeto:
chmod +x run_all_tests.sh
./run_all_tests.sh
```

Este script faz tudo:
1. Verifica se esta no diretorio certo
2. Instala dependencias se necessario
3. Roda type-check do TypeScript
4. Roda ESLint (linting)
5. Roda testes Jest com coverage
6. Cria virtualenv Python
7. Roda testes pytest com coverage

### Rodando Testes do Backend (TypeScript) Separadamente

```bash
# Entrar na pasta do backend
cd no_fluxo_backend

# Instalar dependencias (primeira vez)
npm install

# Rodar todos os testes
npm test

# Rodar testes com cobertura de codigo
npm run test:coverage

# Rodar um arquivo de teste especifico
npx jest tests-ts/users_controller.test.ts

# Rodar testes em modo watch (reroda ao salvar)
npx jest --watch

# Type-check (verificar erros de tipo)
npm run type-check

# ESLint (verificar padroes de codigo)
npm run lint
```

### Rodando Testes Python Separadamente

```bash
# Entrar na pasta de testes python
cd tests-python

# Criar virtualenv (primeira vez)
python3 -m venv venv

# Ativar virtualenv
source venv/bin/activate    # Mac/Linux
# venv\Scripts\activate     # Windows

# Instalar dependencias
pip install -r requirements.txt
pip install pytest pytest-cov pytest-mock

# Rodar todos os testes
python -m pytest -v

# Rodar com cobertura
python -m pytest -v --cov=. --cov-report=html --cov-report=term-missing

# Rodar um teste especifico
python -m pytest test_app.py -v

# Rodar um teste especifico dentro de um arquivo
python -m pytest test_app.py::test_health_check_endpoints -v

# Desativar virtualenv quando terminar
deactivate
```

### Rodando Testes do Frontend Svelte (quando existirem)

```bash
# Entrar na pasta do frontend
cd no_fluxo_frontend_svelte

# Instalar dependencias
pnpm install

# Rodar testes unitarios (Vitest)
pnpm test

# Rodar testes E2E (Playwright)
pnpm test:integration
```

---

## 10. CI/CD - Integracao Continua e Testes Automatizados

### O que e CI/CD?

**CI (Integracao Continua)** = Toda vez que alguem faz push ou abre um PR, os testes rodam automaticamente no GitHub.

**CD (Deploy Continuo)** = Quando o codigo e aprovado na main, o deploy acontece automaticamente.

### Workflows do GitHub Actions

O projeto tem **7 workflows** configurados:

#### 1. `all-tests.yml` - O Principal

**Quando roda:** Push na `main` ou `dev`, PRs para `main` ou `dev`

**O que faz:**

```
Job 1: typescript-tests
  -> Setup Node.js 20
  -> npm ci (instala deps)
  -> npm run type-check
  -> npm run lint (ESLint)
  -> npm test
  -> npm run test:coverage
  -> Upload coverage para Codecov

Job 2: python-tests
  -> Setup Python 3.11
  -> Instala tesseract-ocr e poppler-utils (dependencias de sistema)
  -> pip install dependencias
  -> pytest com coverage
  -> Upload coverage para Codecov

Job 3: test-results
  -> Gera resumo dos resultados
```

#### 2. `typescript-tests.yml` - Testes TypeScript Isolados

**Quando roda:** Push/PR que altere arquivos em `no_fluxo_backend/` ou `tests-ts/`

**Diferencial:** Roda em **matrix** com Node 18.x e 20.x (testa em 2 versoes)

#### 3. `python-tests.yml` - Testes Python Isolados

**Quando roda:** Push/PR que altere arquivos em `tests-python/`, `coleta_dados/`, ou `ai_agent/`

**Diferencial:** Roda em **matrix** com Python 3.9, 3.10, 3.11 (testa em 3 versoes)

#### 4. `security-and-quality.yml` - Seguranca e Qualidade

**Quando roda:** Push/PR + toda semana (domingo 02:00)

**O que faz:**
- `npm audit` - Verifica vulnerabilidades em pacotes npm
- `safety check` - Verifica vulnerabilidades em pacotes Python
- `bandit` - Analise estatica de seguranca em Python
- TypeScript strict mode check
- ESLint, Black, Flake8, isort, mypy
- Verifica pacotes desatualizados

#### 5. `deploy.yml` - Deploy em Producao

**Quando roda:** Push na `main` ou manual

**O que faz:**
- Builda imagens Docker (backend, frontend, mcp-agent)
- Push para registry privado
- Deploy no Kubernetes

#### 6. `actions.yml` - Scraping Automatizado

**Quando roda:** Mensalmente (dia 1) + manual

**O que faz:** Roda scripts de coleta de dados do SIGAA

#### 7. `ci.yml` - Documentacao

**Quando roda:** Push na `main`

**O que faz:** Deploya a documentacao MkDocs no GitHub Pages

### Visualizando os Resultados

Para ver se os testes passaram:

1. Va no repositorio no GitHub
2. Clique na aba **"Actions"**
3. Veja os workflows recentes
4. Clique em um workflow para ver detalhes
5. Cada "check" verde = testes passaram, vermelho = falharam

---

## 11. Cobertura de Codigo (Code Coverage)

### O que e cobertura?

**Cobertura de codigo** mede **quantas linhas do codigo fonte sao executadas pelos testes**. Se seu codigo tem 100 linhas e os testes executam 80 delas, a cobertura e de 80%.

### Configuracao Atual

O projeto usa **Codecov** para rastrear cobertura:

```yaml
# codecov.yml
coverage:
  status:
    project:
      default:
        target: 80%      # Meta: 80% de cobertura
        threshold: 5%     # Tolerancia: pode cair 5% sem falhar
    patch:
      default:
        target: 80%      # Codigo novo deve ter 80% de cobertura
        threshold: 5%
```

**O que e ignorado no calculo de cobertura:**
- Arquivos de teste (`tests-ts/**`, `*.test.ts`, `*.spec.ts`)
- Configuracoes (`jest.setup.js`, `jest.config.js`)

### Onde ver os relatorios

Apos rodar os testes com coverage:

- **TypeScript:** `no_fluxo_backend/coverage/` (HTML: abra `index.html`)
- **Python:** `tests-python/htmlcov/` (HTML: abra `index.html`)
- **Online:** Dashboard do Codecov (linkado no PR do GitHub)

### Como gerar o relatorio localmente

```bash
# Backend (TypeScript)
cd no_fluxo_backend
npm run test:coverage
# Abra coverage/lcov-report/index.html no browser

# Python
cd tests-python
python -m pytest --cov=. --cov-report=html
# Abra htmlcov/index.html no browser
```

---

## 12. Mapa de O Que Precisa de Mais Testes

### Prioridade ALTA (nenhum teste existe)

| Area | O que testar | Tipo de Teste Sugerido |
|---|---|---|
| **Frontend Svelte - Services** | `auth.service.ts`, `upload.service.ts`, `fluxograma.service.ts` | Unitario (Vitest) |
| **Frontend Svelte - Stores** | `authStore`, `uploadStore`, `fluxogramaStore` | Unitario (Vitest) |
| **Frontend Svelte - Utils** | `expressao-logica.ts`, `casar-materias.ts`, `ira.ts` | Unitario (Vitest) |
| **Frontend Svelte - Factories** | Conversao JSON <-> TypeScript | Unitario (Vitest) |
| **Frontend Svelte - Fluxos E2E** | Login, upload PDF, visualizar fluxograma | E2E (Playwright) |

### Prioridade MEDIA (existe parcialmente)

| Area | O que testar | O que falta |
|---|---|---|
| **Backend - casar_disciplinas** | O endpoint mais complexo (~940 linhas) | Testes de integracao com cenarios reais |
| **Backend - integralizacao** | Calculo de % de conclusao | Cenarios com diferentes tipos de creditos |
| **Backend - assistente_controller** | Endpoints de IA | Testes de streaming (SSE) |
| **Backend - Expressao Logica** | Parser de pre-requisitos recursivos | Expressoes complexas (AND/OR aninhados) |

### Prioridade BAIXA (legado)

| Area | O que testar | Justificativa |
|---|---|---|
| **Flutter Frontend** | Telas e widgets | E o frontend legado, priorizar Svelte |
| **Scripts de Scraping** | Coleta de dados | Roda mensalmente, menor impacto |

---

## 13. Glossario para Juniors

| Termo | O que significa |
|---|---|
| **Monorepo** | Um unico repositorio Git que contem varios projetos (backend, frontend, etc) |
| **Workspace (pnpm)** | Sistema que permite gerenciar multiplos projetos (packages) dentro de um monorepo |
| **Controller** | Parte do codigo que recebe requisicoes HTTP e retorna respostas |
| **Service** | Parte do codigo que contem a logica de negocio (regras, calculos) |
| **Store** | Local onde o frontend guarda dados compartilhados entre paginas/componentes |
| **Mock** | Objeto falso que simula algo real durante os testes (ex: banco de dados falso) |
| **Spy** | Funcao que "observa" se outra funcao foi chamada corretamente |
| **Fixture** | Configuracao que roda antes de cada teste para preparar o ambiente |
| **Coverage** | Porcentagem do codigo que e executado durante os testes |
| **CI/CD** | Automacao que roda testes e faz deploy toda vez que o codigo e atualizado |
| **Workflow** | Arquivo YAML que define o que o GitHub Actions deve fazer |
| **Matrix** | Configuracao que roda o mesmo teste em multiplas versoes (ex: Node 18 e 20) |
| **RLS** | Row Level Security - regras do Supabase que controlam quem pode acessar que dados |
| **RPC** | Remote Procedure Call - forma de chamar funcoes diretamente no banco (Supabase) |
| **SSE** | Server-Sent Events - forma de enviar dados do servidor em tempo real (streaming) |
| **PKCE** | Metodo seguro de autenticacao OAuth (usado pelo Supabase) |
| **E2E** | End-to-End - testes que simulam o usuario real interagindo com a aplicacao |
| **Unitario** | Testa uma funcao ou componente isoladamente |
| **Integracao** | Testa se varios componentes funcionam juntos |
| **Health Check** | Endpoint que retorna se o servico esta funcionando (usado pelo Kubernetes) |
| **Rune ($state)** | Nova forma do Svelte 5 de declarar estado reativo |
| **Embedding** | Representacao numerica (vetor) de um texto, usada para busca semantica |
| **Express** | Framework Node.js para criar APIs REST |
| **SvelteKit** | Framework full-stack para Svelte (similar ao Next.js para React) |
| **Vitest** | Framework de testes para projetos que usam Vite |
| **Playwright** | Ferramenta para testes E2E que controla navegadores reais |
| **Jest** | Framework de testes para JavaScript/TypeScript |
| **pytest** | Framework de testes para Python |

---

## 14. Referencia Rapida de Comandos

### Testes

```bash
# === BACKEND (TypeScript/Jest) ===
cd no_fluxo_backend
npm test                              # Roda todos os testes
npm run test:coverage                 # Testes + relatorio de cobertura
npx jest --watch                      # Modo watch (reexecuta ao salvar)
npx jest tests-ts/users_controller.test.ts  # Arquivo especifico
npx jest --verbose                    # Output detalhado

# === PYTHON (pytest) ===
cd tests-python
source venv/bin/activate              # Ativa virtualenv
python -m pytest -v                   # Todos os testes (verbose)
python -m pytest --cov=. --cov-report=html  # Com cobertura
python -m pytest test_app.py -v       # Arquivo especifico
python -m pytest -k "test_health"     # Filtra por nome do teste

# === FRONTEND SVELTE (quando tiver testes) ===
cd no_fluxo_frontend_svelte
pnpm test                             # Vitest (unitarios)
pnpm test:integration                 # Playwright (E2E)

# === TUDO DE UMA VEZ ===
./run_all_tests.sh                    # Roda backend + python
```

### Desenvolvimento

```bash
# Subir o projeto localmente
pnpm dev                  # Frontend Svelte (porta 5173)
pnpm dev:backend          # Backend (porta 3325)

# Verificar qualidade do codigo
cd no_fluxo_backend
npm run type-check        # Verifica tipos TypeScript
npm run lint              # Verifica padroes de codigo (ESLint)

cd no_fluxo_frontend_svelte
pnpm check                # Verifica tipos Svelte + TypeScript
pnpm lint                 # ESLint
pnpm format:check         # Verifica formatacao (Prettier)
```

### Git (para o fluxo de trabalho)

```bash
git status                # Ver arquivos modificados
git diff                  # Ver mudancas no codigo
git log --oneline -10     # Ver ultimos 10 commits
git checkout -b minha-branch  # Criar nova branch
git push origin minha-branch  # Enviar branch para o GitHub
```

---

## Resumo Final

| Pergunta | Resposta |
|---|---|
| **Onde ficam os testes?** | `no_fluxo_backend/tests-ts/` (TS) e `tests-python/` (Python) |
| **Como rodar?** | `npm test` (backend) ou `python -m pytest` (python) |
| **O que ja tem teste?** | 6 controllers do backend + 10 modulos Python |
| **O que NAO tem teste?** | Todo o frontend Svelte (0 testes) |
| **Qual a meta de cobertura?** | 80% (configurado no codecov.yml) |
| **CI/CD roda automaticamente?** | Sim, em todo push/PR para main ou dev |
| **Onde ver resultados?** | Aba "Actions" no GitHub + Codecov dashboard |
| **O que priorizar?** | Frontend Svelte (services, stores, utils, E2E) |

---

> Documento gerado em 09/04/2026 com base na analise completa do repositorio.
