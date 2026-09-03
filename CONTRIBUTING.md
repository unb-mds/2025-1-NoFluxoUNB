# Guia de Contribuição e Configuração do Ambiente

Obrigado pelo seu interesse em contribuir para o **NoFluxoUnB**! Este guia detalha a arquitetura atual do projeto e como configurar e executar cada um dos serviços em sua máquina local sem conflitos de dependências.

---

## 🏛️ Estrutura do Projeto

O NoFluxoUnB é composto pelos seguintes módulos:

| Módulo | Tecnologia | Diretório | Descrição |
|---|---|---|---|
| **Frontend** | SvelteKit v2, Svelte 5, Tailwind 4, TS | `no_fluxo_frontend_svelte/` | Aplicação web interativa |
| **Backend** | Express.js, TypeScript, Node.js | `no_fluxo_backend/` | API REST principal (porta 3325) |
| **Agente IA** | FastAPI, Python, OpenAI, Gemini | `mcp_agent/` | Serviço de IA e recomendações |
| **DBA & Scripts** | Python, Supabase, BeautifulSoup | `DBA/database/`, `DBA/scraping/` | Ingestão, scraping e migrações |
| **Parse PDF** | Python, PyMuPDF, Flask | `no_fluxo_backend/parse-pdf/` | Extração de dados de históricos em PDF |

---

## 📋 Pré-requisitos

- **Git**: [Download Git](https://git-scm.com/downloads)
- **Node.js**: Versão 20 LTS ou superior. [Download Node.js](https://nodejs.org/)
- **pnpm**: Recomendado para o monorepo (`npm install -g pnpm`) ou `npm`
- **Python**: Versão 3.10 até 3.12 (ou 3.14 com wheels compatíveis). [Download Python](https://www.python.org/)

---

## ⚡ 1. Início Rápido (Setup Automatizado)

Criamos um script que configura automaticamente o ambiente virtual Python e instala as dependências dos projetos:

```bash
# Clone o repositório
git clone https://github.com/unb-mds/2025-1-NoFluxoUNB.git
cd 2025-1-NoFluxoUNB

# Executa a configuração completa (Python venv + dependências Node)
python scripts/setup_env.py --node
```

Após a execução, ative o ambiente virtual conforme seu sistema operacional (instruções abaixo).

---

## 🐍 2. Configuração do Ambiente Python (DBA, MCP Agent e Scripts)

Para evitar erros como `ModuleNotFoundError` decorrentes de diferentes versões do Python no sistema, **sempre utilize o ambiente virtual (`venv`)** e o prefixo `python -m pip`.

### 2.1. Criar e Ativar o Ambiente Virtual

Na raiz do repositório:

```bash
# Criar o ambiente virtual (se ainda não existir)
python -m venv venv

# Ativação no Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# Ativação no Windows (CMD):
.\venv\Scripts\activate.bat

# Ativação no Linux/macOS:
source venv/bin/activate
```

> **Dica Windows:** Se encontrar erro de permissão no PowerShell (`ExecutionPolicy`), execute:  
> `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

### 2.2. Instalação das Dependências Python

Com o `venv` ativado:

```bash
# Opção A: Instalar todos os pacotes consolidados do projeto
python -m pip install -r requirements.txt

# Opção B: Instalar apenas para um módulo específico
# Para scripts de banco de dados (DBA/database):
python -m pip install -r DBA/database/requirements.txt

# Para o agente de inteligência artificial (mcp_agent):
python -m pip install -r mcp_agent/requirements.txt

# Para scraping do SIGAA (DBA/scraping):
python -m pip install -r DBA/scraping/requirements.txt


---

## 🚀 3. Configuração do Backend (Node.js / Express)

### 3.1. Instalar Dependências

```bash
cd no_fluxo_backend
npm install
```

### 3.2. Variáveis de Ambiente (`.env`)

Crie um arquivo `.env` dentro de `no_fluxo_backend/` com as chaves do Supabase:

```ini
PORT=3325
SUPABASE_URL=https://sua-url-supabase.supabase.co
SUPABASE_KEY=sua-chave-anon-ou-service-role
```

### 3.3. Iniciar o Backend em Modo Desenvolvimento

```bash
npm run dev
```

O servidor iniciará em `http://localhost:3325`.

---

## 🎨 4. Configuração do Frontend (SvelteKit)

### 4.1. Instalar Dependências

```bash
cd no_fluxo_frontend_svelte
pnpm install   # ou npm install
```

### 4.2. Variáveis de Ambiente (`.env`)

Crie o arquivo `.env` em `no_fluxo_frontend_svelte/`:

```ini
PUBLIC_SUPABASE_URL=https://sua-url-supabase.supabase.co
PUBLIC_SUPABASE_ANON_KEY=sua-chave-anonima
PUBLIC_BACKEND_URL=http://localhost:3325
```

### 4.3. Iniciar o Frontend em Modo Desenvolvimento

```bash
pnpm dev       # ou npm run dev
```

Acesse a aplicação em `http://localhost:5173`.

---

## 🤖 5. Configuração do MCP Agent (IA)

O agente fornece suporte inteligente e recomendações personalizadas de matérias.

```bash
cd mcp_agent

# Certifique-se de estar com o venv ativado
python -m pip install -r requirements.txt

# Iniciar a API FastAPI
python api_producao.py
```

---

## 🔧 6. Solução de Problemas Comuns (Troubleshooting)

### `ModuleNotFoundError: No module named 'supabase'` (ou outro pacote)
- **Causa:** O pacote foi instalado globalmente ou em outro Python diferente daquele em execução no terminal.
- **Solução:**
  1. Verifique qual python está ativo: `where python` (Windows) ou `which python` (Linux).
  2. Garanta que o venv está ativado (o terminal exibirá `(venv)` no início da linha).
  3. Instale com o interpretador ativo: `python -m pip install -r requirements.txt`.

### Erro de permissão ao rodar scripts no PowerShell
Execute no terminal antes de ativar o venv:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Problemas com build de pacotes no Python 3.14 no Windows
Alguns pacotes podem não ter rodas pré-compiladas para versões experimentais do Python. Recomendamos o uso de Python 3.11 ou 3.12.

---

## 🌿 7. Fluxo de Trabalho e Git

1. Crie uma branch para a sua tarefa:
   ```bash
   git checkout -b feature/minha-melhoria
   ```
2. Siga as diretrizes em `COMMIT_GUIDELINES.md`.
3. Rode os testes e linter antes de abrir PR:
   ```bash
   pnpm test
   pnpm lint
   ```
4. Abra um Pull Request detalhando as alterações e testes realizados.
