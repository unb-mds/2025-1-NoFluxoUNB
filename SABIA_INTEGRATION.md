# Integração do Agente Sabiá AI - v2.0 (FastAPI)

Este documento explica como o agente Sabiá v2.0 (FastAPI) foi integrado ao sistema NoFluxo UNB.

## 📋 Arquitetura

```
Frontend (Svelte)
    ↓ HTTP
Backend (TypeScript/Node.js)
    ↓ HTTP POST /recomendar
API FastAPI (Python) - api_producao.py
    ↓
Gemini Embeddings (256D) + Maritaca AI + Supabase pgvector
```

### Mudanças vs v1.0 (MCP)

| Componente | v1.0 (MCP) | v2.0 (FastAPI) |
|---|---|---|
| Comunicação | subprocess stdin/stdout | HTTP REST |
| Embeddings | Modelo local 420MB | Gemini API |
| Inicialização | ~30s primeira vez | ~2s |
| Escalabilidade | 1 processo/request | Assíncrono |
| Deploy | Complexo (acoplado) | Simples (desacoplado) |

## 🔧 Configuração

### 1. Variáveis de Ambiente

**Backend** (`no_fluxo_backend/.env`):
```env
# URL da API FastAPI
SABIA_API_URL=http://localhost:8000

# Maritaca AI (Sabiá)
MARITACA_API_KEY=sua_chave_maritaca_aqui

# Google Gemini (Embeddings)
GOOGLE_API_KEY=sua_chave_google_aqui

# Supabase
SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
```

**API FastAPI** (`mcp_agent/.env`):
```env
# Maritaca AI (Sabiá)
MARITACA_API_KEY=sua_chave_maritaca_aqui

# Google Gemini (Embeddings)
GOOGLE_API_KEY=sua_chave_google_aqui

# Supabase
SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
```

### 2. Dependências Python

```bash
cd mcp_agent
pip install -r requirements.txt
```

Dependências principais:
- `fastapi` - Framework web assíncrono
- `uvicorn` - Servidor ASGI
- `google-generativeai` - Gemini embeddings
- `openai` - Maritaca AI (compatível com OpenAI SDK)
- `supabase-py` - Cliente Supabase

## 🚀 Como Usar

### Desenvolvimento (3 Terminais)

**Terminal 1 - API FastAPI:**
```bash
cd mcp_agent
start_api.bat  # Windows
# ou
./start_api.sh  # Linux/Mac
```

**Terminal 2 - Backend Node.js:**
```bash
cd no_fluxo_backend
npm run dev
```

**Terminal 3 - Frontend Svelte:**
```bash
cd no_fluxo_frontend_svelte
npm run dev
```

### Endpoint da API

**POST** `http://localhost:8000/recomendar`

**Request Body:**
```json
{
  "interesse": "inteligência artificial"
}
```

**Response:**
```json
{
  "success": true,
  "disciplinas": [
    {
      "codigo": "CIC0087",
      "nome": "APRENDIZADO DE MÁQUINA",
      "nota": 9,
      "justificativa": "Foco direto em algoritmos de IA e ML"
    }
  ],
  "resposta_completa": "**CIC0087 - APRENDIZADO DE MÁQUINA | Nota: 9/10 | Motivo:** ..."
}
```

### Frontend (Svelte)

```typescript
import { assistenteService } from '$lib/services/assistente.service';

// Usar Sabiá (padrão)
const resposta = await assistenteService.sendMessage('machine learning', 'sabia');

// Ou usar método específico para obter dados estruturados
const resultado = await assistenteService.sendMessageToSabia('inteligência artificial');
console.log(resultado.disciplinas); // Array de disciplinas com notas e justificativas
```

### Escolher o Agente

O frontend agora suporta dois agentes:

- **`'sabia'`**: Agente Sabiá com Maritaca AI (padrão)
- **`'ragflow'`**: Agente RAGFlow original

```typescript
// Usar Sabiá
await assistenteService.sendMessage('IA', 'sabia');

// Usar RAGFlow
await assistenteService.sendMessage('IA', 'ragflow');
```

## 📁 Arquivos Criados/Modificados

### Novos Arquivos

1. **`mcp_agent/agente_sabia_api.py`**
   - Script wrapper que recebe JSON via stdin
   - Processa consulta com Sabiá
   - Retorna resultado estruturado via stdout

2. **`no_fluxo_backend/src/services/sabia.service.ts`**
   - Serviço TypeScript que gerencia chamadas ao Python
   - Usa `child_process.spawn` para executar o script
   - Formata resposta como Markdown

### Arquivos Modificados

3. **`no_fluxo_backend/src/controllers/assistente_controller.ts`**
   - Adicionado endpoint `/assistente/analyze-sabia`
   - Integrado com `SabiaService`
   - Health check atualizado

4. **`no_fluxo_backend/.env`**
   - Adicionadas variáveis `MARITACA_API_KEY` e `SUPABASE_KEY`

5. **`no_fluxo_frontend_svelte/src/lib/services/assistente.service.ts`**
   - Suporte para múltiplos agentes
   - Novo método `sendMessageToSabia()`
   - Tipos TypeScript atualizados

## 🔍 Como Funciona

1. **Usuário envia pergunta** no frontend (ex: "quero aprender sobre IA")

2. **Frontend chama** `/assistente/analyze-sabia` com a pergunta

3. **Backend (TypeScript)** chama `SabiaService.analyzarInteresse()`

4. **SabiaService** executa o script Python via `spawn`:
   ```
   python mcp_agent/agente_sabia_api.py < input.json > output.json
   ```

5. **Script Python**:
   - Recebe interesse via stdin
   - Chama Maritaca AI (Sabiá-4) para expandir termos
   - Usa MCP para buscar no Supabase via embeddings
   - Ranqueia resultados com Sabiá
   - Retorna JSON estruturado via stdout

6. **Backend** parseia resposta e retorna ao frontend

## 🧪 Teste Manual

### 1. Teste do Script Python

```bash
cd mcp_agent
echo '{"interesse": "inteligencia artificial"}' | python agente_sabia_api.py
```

### 2. Teste da API

```bash
curl -X POST http://localhost:3000/assistente/analyze-sabia \
  -H "Content-Type: application/json" \
  -d '{"materia": "machine learning"}'
```

### 3. Health Check

```bash
curl http://localhost:3000/assistente/health
```

Resposta esperada:
```json
{
  "status": "healthy",
  "service": "AI Assistant",
  "ragflowConfigured": false,
  "sabiaConfigured": true,
  "timestamp": "2026-03-03T..."
}
```

## ⚠️ Troubleshooting

### Erro: "MARITACA_API_KEY não configurada"

- Verifique se a variável está no `.env` do backend
- Reinicie o servidor backend após adicionar

### Erro: "Python script failed with code 1"

- Verifique se as dependências Python estão instaladas
- Teste o script manualmente (comando acima)
- Verifique os logs do stderr no console do backend

### Erro: "Cannot find module 'modelo_local'"

- Baixe o modelo Sentence Transformers
- Coloque na pasta `mcp_agent/modelo_local`

### Timeout na requisição

- Aumente o timeout no `sabia.service.ts` se necessário
- Verifique conexão com Maritaca AI e Supabase

## 📊 Comparação: Sabiá vs RAGFlow

| Característica | Sabiá | RAGFlow |
|---|---|---|
| Modelo de IA | Maritaca (Sabiá-4) | RAGFlow Agent |
| Busca | Embeddings + Supabase | RAGFlow KB |
| Latência | ~5-10s | ~3-5s |
| Configuração | Maritaca API Key | RAGFlow completo |
| Offline | Embeddings locais | Não |
| Ranking | IA Brasileira | IA genérica |

## 🎯 Próximos Passos

- [ ] Adicionar seletor de agente no frontend (UI)
- [ ] Cache de resultados frequentes
- [ ] Métricas de uso (qual agente mais usado)
- [ ] Fallback automático se um agente falhar
- [ ] Streaming de respostas (SSE)

## 📝 Observações

- O agente Sabiá é o **padrão** nas chamadas do frontend
- RAGFlow ainda está disponível se necessário
- Ambos podem coexistir e serem usados conforme necessidade
- A integração mantém compatibilidade com o código existente
