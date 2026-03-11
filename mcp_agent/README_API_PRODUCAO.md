# 🚀 Darcy AI - API de Produção

API FastAPI standalone para recomendação de disciplinas da UnB usando IA.

## 📋 Arquitetura

```
Frontend (Svelte) → Backend (Node.js/TypeScript) → FastAPI (Python) → Gemini + Maritaca AI + Supabase
```

### Componentes

1. **api_producao.py**: Servidor FastAPI com endpoint `/recomendar`
2. **Gemini Embeddings**: Converte termos em vetores (256D)
3. **Maritaca AI (Sabiá-4)**: Análise e ranking de disciplinas
4. **Supabase**: Busca vetorial com pgvector

## 🔧 Instalação

### 1. Dependências Python

```bash
cd mcp_agent
pip install fastapi uvicorn google-generativeai openai supabase python-dotenv
```

### 2. Variáveis de Ambiente

Crie/edite o arquivo `.env` na pasta `mcp_agent`:

```env
# Maritaca AI (Sabiá)
MARITACA_API_KEY=sua_chave_maritaca

# Google Gemini (Embeddings)
GOOGLE_API_KEY=sua_chave_google

# Supabase (Busca Vetorial)
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
```

### 3. Backend Node.js

Adicione ao `.env` do backend (`no_fluxo_backend/.env`):

```env
# URL da API FastAPI (desenvolvimento)
SABIA_API_URL=http://localhost:8000

# Mesmas chaves acima para validação
MARITACA_API_KEY=sua_chave_maritaca
GOOGLE_API_KEY=sua_chave_google
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
```

## 🚀 Como Usar

### Desenvolvimento (3 terminais)

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

### Teste Direto da API

```bash
# Via curl
curl -X POST http://localhost:8000/recomendar \
  -H "Content-Type: application/json" \
  -d '{"interesse": "inteligência artificial"}'

# Via Python
python -c "import requests; print(requests.post('http://localhost:8000/recomendar', json={'interesse': 'machine learning'}).json())"
```

## 📊 Endpoint da API

### POST /recomendar

**Request:**
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
      "nota": 10,
      "justificativa": "Foco central em algoritmos de IA"
    }
  ],
  "resposta_completa": "**CIC0087 - APRENDIZADO DE MÁQUINA | Nota: 10/10 | Motivo:** ..."
}
```

## 🔍 Como Funciona

1. **Usuário pergunta**: "quero aprender sobre IA"

2. **Backend Node.js** → POST para FastAPI `/recomendar`

3. **FastAPI recebe** e chama Maritaca Sabiázinho-4:
   - IA expande: `["inteligência artificial", "machine learning", "redes neurais", "dados"]`

4. **Gemini gera embeddings** (256D) para os 4 termos em **1 única chamada**

5. **Busca vetorial** no Supabase:
   - Threshold: 0.55
   - Top 10 por termo
   - Remove duplicatas

6. **Maritaca Sabiá-4** ranqueia e formata:
   - Notas 1-10 por relevância
   - Justificativas concisas
   - Formato estruturado

7. **Retorna JSON** ao backend → frontend

## 🆚 Diferenças vs Versão Anterior (MCP)

| Característica | MCP (Antigo) | FastAPI (Novo) |
|---|---|---|
| **Embeddings** | Modelo local 420MB | Gemini API (online) |
| **Inicialização** | ~30s (1ª vez) | ~2s |
| **Comunicação** | subprocess stdin/stdout | HTTP REST |
| **Escalabilidade** | 1 processo por request | Assíncrono, múltiplos |
| **Deploy** | Complexo (Python + Node) | Separado (containerizar) |
| **Manutenção** | Difícil (acoplado) | Fácil (desacoplado) |

## 🐳 Deploy em Produção

### Opção 1: Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  darcy-api:
    build: ./mcp_agent
    ports:
      - "8000:8000"
    environment:
      - MARITACA_API_KEY=${MARITACA_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
  
  backend:
    build: ./no_fluxo_backend
    ports:
      - "3000:3000"
    environment:
      - SABIA_API_URL=http://darcy-api:8000
    depends_on:
      - darcy-api
```

### Opção 2: VPS Separadas

- **VPS 1** (API FastAPI): Railway, Render, Fly.io
- **VPS 2** (Backend Node): Vercel, Netlify Functions
- **Frontend**: Vercel, Netlify (estático)

### Opção 3: Serverless

- **API FastAPI**: AWS Lambda + API Gateway (com layers)
- **Backend**: Vercel Serverless Functions
- **Frontend**: Vercel Edge

## 🔒 Segurança

- ✅ **Service Role Key** no backend (nunca expor no frontend)
- ✅ **Rate limiting** no FastAPI (recomendado)
- ✅ **CORS** configurado para origens permitidas
- ✅ **Validação** de entrada com Pydantic

## 📈 Performance

- **Primeira query**: ~3-5s (Gemini + Maritaca + Supabase)
- **Queries seguintes**: ~2-3s (cache de conexões)
- **Throughput**: ~10-20 requests/s (com uvicorn workers)

## 🐛 Troubleshooting

### Erro: "Cannot connect to Sabiá API"

```bash
# Verifique se a API está rodando
curl http://localhost:8000

# Deve retornar: {"detail":"Not Found"} (404 é normal, significa que está no ar)
```

### Erro: "GOOGLE_API_KEY não encontrada"

```bash
# Verifique o .env
cd mcp_agent
cat .env | grep GOOGLE_API_KEY

# Se vazio, adicione a chave
echo "GOOGLE_API_KEY=sua_chave_aqui" >> .env
```

### API lenta na primeira query

**Normal!** Gemini e Maritaca fazem cold start. A partir da 2ª query fica rápido.

## 📚 Recursos

- [FastAPI Docs](https://fastapi.tiangolo.com/)
- [Gemini Embeddings](https://ai.google.dev/gemini-api/docs/embeddings)
- [Maritaca AI](https://plataforma.maritaca.ai/)
- [Supabase Vector](https://supabase.com/docs/guides/ai/vector-search)

---

**Versão:** 2.0 (FastAPI)  
**Embedding Model:** Gemini gemini-embedding-001 (256D)  
**LLM:** Sabiá-4 + Sabiázinho-4 (Maritaca AI)  
**Banco:** Supabase PostgreSQL + pgvector
