# Integração do Agente Sabiá AI

Este documento explica como o agente Sabiá foi integrado ao sistema NoFluxo UNB.

## 📋 Arquitetura

```
Frontend (Svelte)
    ↓
Backend (TypeScript/Node.js)
    ↓
Serviço Sabiá (sabia.service.ts)
    ↓
Script Python (agente_sabia_api.py)
    ↓
Servidor MCP (servidor_mcp_sabia.py)
    ↓
Maritaca AI API + Supabase
```

## 🔧 Configuração

### 1. Variáveis de Ambiente

Adicione as seguintes variáveis no `.env` do backend (`no_fluxo_backend/.env`):

```env
# Sabiá AI Agent (Maritaca AI)
MARITACA_API_KEY=sua_chave_maritaca_aqui
SUPABASE_URL=https://lijmhbstgdinsukovyfl.supabase.co
SUPABASE_KEY=sua_chave_supabase_anon_aqui
```

### 2. Dependências Python

Certifique-se de que as dependências Python estão instaladas:

```bash
cd mcp_agent
pip install -r requirements.txt
```

Dependências necessárias:
- `openai` (para API Maritaca)
- `mcp` (Model Context Protocol)
- `supabase-py` (cliente Supabase)
- `sentence-transformers` (embeddings locais)

### 3. Modelo Local de Embeddings

O agente usa um modelo local para gerar embeddings. Certifique-se de que a pasta `mcp_agent/modelo_local` contém o modelo do Sentence Transformers.

## 🚀 Como Usar

### Endpoint da API

**POST** `/assistente/analyze-sabia`

**Request Body:**
```json
{
  "materia": "inteligência artificial"
}
```

**Response:**
```json
{
  "resultado": "### 🎓 Disciplinas Recomendadas pelo Sabiá...",
  "disciplinas": [
    {
      "codigo": "CIC0087",
      "nome": "APRENDIZADO DE MÁQUINA",
      "nota": 9,
      "justificativa": "Foco direto em algoritmos de IA e ML"
    }
  ],
  "agente": "sabia"
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
