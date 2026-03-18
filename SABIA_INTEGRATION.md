# Integração do Agente Sabiá AI - v2.0 (FastAPI)

Este documento explica como o agente Sabiá foi integrado ao sistema NoFluxo UNB e como subir o ambiente completo.

## 📋 Arquitetura

```
Frontend (Svelte)
    ↓  POST /assistente/analyze-sabia  { materia: "..." }
Backend (TypeScript/Node.js) — porta 3000
    ↓  SabiaService.analyzarInteresse()
    ↓  spawn python agente_sabia.py  (stdin: JSON)
Script Python (agente_sabia.py — modo API)
    ↓  StdioServerParameters → subprocess
Servidor MCP (servidor_mcp_sabia.py)
    ↓  SentenceTransformer embedding (384D)
    ↓  Supabase RPC match_materias (pgvector)
Maritaca AI API (Sabiázinho-4 + Sabiá-4)
```

---

## 🚀 Como Subir o Sistema Completo

### 1. Variáveis de Ambiente

**`no_fluxo_backend/.env`**
```env
# Supabase
SUPABASE_URL=https://.supabase.co
SUPABASE_KEY=sua_anon_key
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key

# Maritaca AI
MARITACA_API_KEY=sua_chave_maritaca

# Porta (dev local: 3000; produção/Docker: 3325)
PORT=3000
NODE_ENV=production
```

**`mcp_agent/.env`**
```env
SUPABASE_URL=https://.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
SUPABASE_KEY=sua_anon_key
MARITACA_API_KEY=sua_chave_maritaca
```

### 2. Dependências Python

O `npm run dev` dentro de `no_fluxo_backend` instala automaticamente via `postinstall`:

```powershell
# PyTorch CPU (instalar antes para evitar versão CUDA)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Demais dependências
pip install -r requirements.txt   # requirements.txt da raiz do projeto
```

> **Windows + Python 3.14:** pode falhar ao compilar `pyiceberg`/`pyroaring`. Use Python 3.11 ou 3.12, ou instale [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/).

### 3. Modelo de Embeddings

```powershell
cd mcp_agent
python baixar_modelo.py
```

Baixa `paraphrase-multilingual-MiniLM-L12-v2` (~420MB) para `mcp_agent/modelo_local_v2/`.

### 4. Subir o Backend

```powershell
cd no_fluxo_backend
npm run dev
# OU da raiz do projeto:
pnpm dev:backend
```

O `SabiaService` detecta o Python automaticamente:
1. `{raiz}/venv/Scripts/python.exe`
2. `no_fluxo_backend/venv/Scripts/python.exe`
3. `python` do sistema (PATH)

### 5. Subir o Frontend

```powershell
# Da raiz do projeto
pnpm dev:frontend
# OU
pnpm dev   # sobe só o frontend
```

O frontend usa `PUBLIC_API_URL` (`.env` do Svelte) para apontar para o backend. Padrão: `http://localhost:3000`.

---

## 🧪 Testes Manuais

### Testar o agente Python isolado

```powershell
cd mcp_agent

# Modo interativo
python agente_sabia.py

# Modo API (como o backend chama)
echo '{"interesse": "inteligencia artificial"}' | python agente_sabia.py
```

### Testar a API REST

```bash
# Health check
curl http://localhost:3000/assistente/health

# Consulta ao Sabiá
curl -X POST http://localhost:3000/assistente/analyze-sabia \
  -H "Content-Type: application/json" \
  -d '{"materia": "machine learning"}'
```

Resposta esperada:
```json
{
  "success": true,
  "disciplinas": [
    {
      "codigo": "CIC0087",
      "nome": "APRENDIZADO DE MÁQUINA",
      "nota": 10,
      "justificativa": "Fundamentos de ML e algoritmos de IA"
    }
  ],
  "resposta_completa": "**CIC0087 - APRENDIZADO DE MÁQUINA | Nota: 9/10 | Motivo:** ..."
}
```

### Usar no Frontend (TypeScript)

```typescript
import { assistenteService } from '$lib/services/assistente.service';

// Sabiá (padrão)
const resposta = await assistenteService.sendMessage('machine learning', 'sabia');

// Dados estruturados
const resultado = await assistenteService.sendMessageToSabia('inteligência artificial');
console.log(resultado.disciplinas);
```

---

## 📁 Arquivos Relevantes

| Arquivo | Descrição |
|---|---|
| `mcp_agent/agente_sabia.py` | Agente principal (modo interativo + API stdin) |
| `mcp_agent/servidor_mcp_sabia.py` | Servidor MCP com busca vetorial |
| `mcp_agent/baixar_modelo.py` | Download do modelo de embeddings |
| `no_fluxo_backend/src/services/sabia.service.ts` | Serviço TS que chama o Python via spawn |
| `no_fluxo_backend/src/controllers/assistente_controller.ts` | Controller com endpoint `/assistente/analyze-sabia` |
| `no_fluxo_frontend_svelte/src/lib/services/assistente.service.ts` | Service do frontend |
| `requirements.txt` | Dependências Python do projeto todo |

---

## 🔍 Como o Backend Chama o Python

O `SabiaService` usa `child_process.spawn` para executar `agente_sabia.py`:

```
Backend → spawn(python, [agente_sabia.py])
           stdin: '{"interesse": "machine learning"}'
           stdout: '{"success": true, "disciplinas": [...], "resposta_completa": "..."}'
```

O script detecta que está em modo API via `sys.stdin.isatty()` e retorna JSON pelo stdout sem precisar de argumentos CLI.

---

## ⚠️ Troubleshooting

### `spawn ... ENOENT` no log do backend

```
[SabiaService] Failed to start Python process: spawn .../venv/Scripts/python.exe ENOENT
```

**Causa:** O `SabiaService` não encontrou o executável Python.  
**Solução:** Verifique se o venv existe em `no_fluxo_backend/venv/` (criado com `python -m venv venv` dentro de `no_fluxo_backend`).

### `[WinError 2]` no JSON de retorno do Python

```json
{"success": false, "error": "[WinError 2] O sistema não pode encontrar o arquivo especificado"}
```

**Causa:** O `agente_sabia.py` tentou iniciar o servidor MCP com um Python que não existe.  
**Solução:** O `agente_sabia.py` agora usa `sys.executable` automaticamente. Se o erro persistir, confirme que está rodando com o venv ativado.

### `Microsoft Visual C++ 14.0 or greater is required`

**Causa:** Pacotes `pyiceberg`/`pyroaring` precisam compilar extensões C no Windows com Python 3.14.  
**Solução:** Use `supabase>=2.24.0,<2.25.0` (sem `pyiceberg`) no `requirements.txt`, ou use Python 3.11/3.12.

### Conflito httpx: `gotrue`, `postgrest` incompatíveis

**Causa:** `supabase 1.x` exige `httpx < 0.24`; `mcp` instala `httpx 0.28+`.  
**Solução:** Atualizar para `supabase >= 2.24.0` no `requirements.txt`.

### CORS bloqueado no frontend

**Causa:** Backend rodando em porta diferente da esperada pelo frontend (`PUBLIC_API_URL`).  
**Solução:** Ajuste `PORT` no `.env` do backend para `3000` (dev), ou configure `PUBLIC_API_URL` no `.env` do frontend:

```env
# no_fluxo_frontend_svelte/.env
PUBLIC_API_URL=http://localhost:3000
```

---

## 📊 Comparação: Sabiá vs RAGFlow

| Característica | Sabiá | RAGFlow |
|---|---|---|
| Modelo de IA | Maritaca (Sabiá-4) | RAGFlow Agent |
| Busca | Embeddings locais + Supabase pgvector | RAGFlow KB |
| Latência | ~5–10s | ~3–5s |
| Configuração | Maritaca API Key | RAGFlow completo |
| Offline | Embeddings locais | Não |
| Ranking | IA Brasileira | IA genérica |

O agente **Sabiá é o padrão** nas chamadas do frontend. RAGFlow permanece disponível como alternativa.
