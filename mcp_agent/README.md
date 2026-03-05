# 🤖 MCP Agent - Sabiá AI Assistant

Agente inteligente para recomendação de disciplinas da UnB usando busca semântica vetorial e integração com Maritaca AI (Sabiá-4).

## 📋 Visão Geral

Esta pasta contém o sistema de IA do NoFluxoUNB, composto por:
- **Servidor MCP** (Model Context Protocol) para integração com LLMs
- **Agente Sabiá** para interação via terminal ou chamado pelo backend
- **Modelo de embedding** local para busca semântica
- **Integração com Supabase** para consulta de disciplinas

## 🏗️ Arquitetura

```
mcp_agent/
├── servidor_mcp_sabia.py    # Servidor MCP com busca vetorial
├── agente_sabia.py           # Agente (modo interativo + modo API via stdin)
├── baixar_modelo.py          # Script para baixar o modelo local
├── databaseScript.py         # Script para popular embeddings no Supabase
├── modelo_local_v2/          # Modelo SentenceTransformer local (~420MB)
├── .env                      # Credenciais (Supabase + Maritaca)
└── requirements-mcp.txt      # Dependências mínimas do MCP Agent
```

## 🔧 Componentes Principais

### 1. **servidor_mcp_sabia.py**
Servidor MCP que expõe a ferramenta `buscar_materias_unb`:
- Carrega modelo de embedding na inicialização
- Gera embeddings de 384 dimensões
- Consulta função RPC `match_materias` no Supabase
- Retorna disciplinas ordenadas por similaridade semântica
- Threshold de similaridade: 0.3 · Top 10 resultados

### 2. **agente_sabia.py**
Opera em dois modos:
- **Modo interativo:** conversa contínua via terminal
- **Modo API (stdin):** recebe JSON pelo stdin, retorna JSON pelo stdout — usado pelo backend Node.js

```bash
python agente_sabia.py                            # Modo interativo
echo '{"interesse": "IA"}' | python agente_sabia.py  # Modo API
```

### 3. **modelo_local_v2/**
Modelo **paraphrase-multilingual-MiniLM-L12-v2** (384D, multilíngue, ~420MB).

---

## 🚀 Como Subir o MCP Agent

### Pré-requisitos

> **Windows:** Python 3.11 ou 3.12 é recomendado. O Python 3.14 ainda não tem wheels pré-compilados para `pyiceberg`/`pyroaring` (dependências indiretas do `supabase`), causando erro de compilação. Alternativa: instalar [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/).

### Passo 1 – Ambiente virtual

**Opção A: venv dentro do `no_fluxo_backend` (recomendado para dev)**

```powershell
cd no_fluxo_backend
python -m venv venv
.\venv\Scripts\Activate.ps1
```

**Opção B: venv na raiz do projeto**

```powershell
cd 2025-1-NoFluxoUNB
python -m venv venv
.\venv\Scripts\Activate.ps1
```

### Passo 2 – Instalar dependências Python

```powershell
# PyTorch CPU (deve ser instalado antes para evitar download da versão CUDA)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Dependências do projeto
pip install -r requirements.txt
```

> O `pnpm dev` dentro de `no_fluxo_backend` faz isso automaticamente via `postinstall`.

### Passo 3 – Baixar o modelo de embeddings

```powershell
cd mcp_agent
python baixar_modelo.py
```

O modelo será salvo em `mcp_agent/modelo_local_v2/`. Tamanho: ~420MB.

### Passo 4 – Configurar variáveis de ambiente

Crie/edite `mcp_agent/.env`:

```env
SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
SUPABASE_KEY=sua_anon_key
MARITACA_API_KEY=sua_chave_maritaca
```

> As mesmas variáveis devem estar em `no_fluxo_backend/.env` para o backend chamar o agente.

### Passo 5 – Testar o agente interativo

```powershell
cd mcp_agent
python agente_sabia.py
```

```
Conectando ao Servidor MCP...
✅ Agente Sabiá-4 Pronto!

Você: machine learning
```

### Passo 6 – Testar o modo API (como o backend chama)

```powershell
echo '{"interesse": "inteligencia artificial"}' | python agente_sabia.py
```

Retorno esperado:
```json
{
  "success": true,
  "disciplinas": [
    {"codigo": "CIC0087", "nome": "APRENDIZADO DE MÁQUINA", "nota": 10, "justificativa": "..."}
  ],
  "resposta_completa": "..."
}
```

---

## 🌐 Subir o Backend com o MCP integrado

O backend Node.js chama o `agente_sabia.py` automaticamente via `SabiaService`. Para subir tudo junto:

```powershell
# Na pasta no_fluxo_backend
cd no_fluxo_backend
npm run dev
# OU com pnpm da raiz:
pnpm dev:backend
```

O `npm run dev` já executa os `pip install` necessários antes de iniciar o nodemon.

O `SabiaService` detecta o Python na seguinte ordem:
1. `venv/Scripts/python.exe` na raiz do projeto
2. `no_fluxo_backend/venv/Scripts/python.exe`
3. `python` do sistema (PATH)

---

## 📊 Pipeline de Busca

```
Usuário → "inteligência artificial"
    ↓
Sabiázinho-4 expande termos: ["machine learning", "redes neurais", "aprendizado profundo"]
    ↓
SentenceTransformer gera embedding (384D) para cada termo
    ↓
Supabase RPC match_materias (pgvector, similaridade cosseno, threshold ≥ 0.3)
    ↓
Top 10 disciplinas por termo → merge e deduplicação
    ↓
Sabiá-4 rankeia e justifica
    ↓
JSON estruturado retornado ao frontend
```

---

## 🔍 Funções do Banco de Dados

### `match_materias`
```sql
CREATE OR REPLACE FUNCTION match_materias(
    query_embedding vector(384),
    match_threshold float,
    match_count int
)
RETURNS TABLE (
    "Codigo" text,
    "Nome" text,
    "Departamento" text,
    "Ementa" text,
    similaridade float
)
```

---

## 📈 Performance

| Etapa | Tempo |
|---|---|
| Inicialização (modelo + Supabase) | ~2–3s |
| Primeira query (cold start) | ~20–30s |
| Queries seguintes | ~5–10s |
| Busca vetorial por termo | ~500–800ms |

---

## 🐛 Debugging

```powershell
# Ver logs detalhados (stderr)
python agente_sabia.py 2>&1 | more

# Testar servidor MCP isolado
python servidor_mcp_sabia.py
```

Prefixos de log:
- `[MCP]` — Servidor MCP
- `[SABIÁ]` — Chamadas à API Maritaca
- `[BUSCA]` — Busca vetorial no Supabase

---

## ⚠️ Solução de Problemas

### `FileNotFoundError: [WinError 2]` ao iniciar o agente

O `agente_sabia.py` não encontrou o Python para iniciar o servidor MCP. O script usa `sys.executable` (mesmo Python que está rodando) se o venv da raiz não existir. Verifique se está rodando com o venv ativado.

### `Microsoft Visual C++ 14.0 or greater is required` (pyiceberg, pyroaring)

Ocorre no Windows com Python 3.14. Soluções:

1. **Usar Python 3.11 ou 3.12** (recomendado):
   ```powershell
   py -3.12 -m venv venv312
   .\venv312\Scripts\Activate.ps1
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
   pip install -r requirements.txt
   ```

2. **Instalar Microsoft C++ Build Tools:** [https://visualstudio.microsoft.com/visual-cpp-build-tools/](https://visualstudio.microsoft.com/visual-cpp-build-tools/) → carga de trabalho "Desenvolvimento para desktop com C++"

### `spawn ... ENOENT` no backend Node.js

O `SabiaService` não encontrou o executável Python. Verifique:
- Se o venv existe em `no_fluxo_backend/venv/` ou na raiz
- Se `python` está no PATH do sistema

### Conflito de versões httpx / supabase

O `mcp` exige `httpx >= 0.26`. Versões antigas do `supabase` (`1.x`) exigem `httpx < 0.24`. Use `supabase >= 2.24, < 2.25` (sem `pyiceberg`):

```
supabase>=2.24.0,<2.25.0
```

---

## 📚 Dependências principais

| Pacote | Versão | Uso |
|---|---|---|
| `sentence-transformers` | latest | Embeddings locais |
| `supabase` | >=2.24,<2.25 | Banco vetorial |
| `python-dotenv` | latest | Variáveis de ambiente |
| `openai` | latest | API Maritaca (compatível OpenAI) |
| `mcp` | latest | Model Context Protocol |
| `torch` | CPU wheel | Backbone dos embeddings |

---

**Versão:** 2.0  
**Modelo:** paraphrase-multilingual-MiniLM-L12-v2 (384D)  
**LLM:** Sabiá-4 + Sabiázinho-4 (Maritaca AI)  
**Banco:** Supabase PostgreSQL + pgvector
