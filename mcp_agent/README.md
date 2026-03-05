# 🤖 MCP Agent - Sabiá AI Assistant

Agente inteligente para recomendação de disciplinas da UnB usando busca semântica vetorial e integração com Maritaca AI (Sabiá-4).

## 📋 Visão Geral

Esta pasta contém o sistema de IA do NoFluxoUNB, composto por:
- **Servidor MCP** (Model Context Protocol) para integração com LLMs
- **Agente Sabiá** para interação via terminal
- **Modelo de embedding** local para busca semântica
- **Integração com Supabase** para consulta de disciplinas

## 🏗️ Arquitetura

```
mcp_agent/
├── servidor_mcp_sabia.py    # Servidor MCP com busca vetorial
├── agente_sabia.py           # Interface interativa no terminal
├── modelo_local_v2/          # Modelo SentenceTransformer local
├── .env                      # Credenciais (Supabase + Maritaca)
└── requirements.txt          # Dependências Python
```

## 🔧 Componentes Principais

### 1. **servidor_mcp_sabia.py**
Servidor MCP que expõe a ferramenta `buscar_materias_unb`:
- Carrega modelo de embedding na inicialização (otimização)
- Gera embeddings de 384 dimensões
- Consulta função RPC `match_materias` no Supabase
- Retorna disciplinas ordenadas por similaridade semântica

**Características:**
- Pré-inicialização de sistemas para reduzir latência
- Logs detalhados para debugging
- Threshold de similaridade: 0.3
- Retorna top 10 resultados

### 2. **agente_sabia.py**
Interface de linha de comando para testes:
- Modo interativo: conversa contínua com o agente
- Modo API: usa MCP server via subprocess
- Expansão de termos com Sabiázinho-4 (modelo menor)
- Respostas contextualizadas com Sabiá-4 (modelo principal)

**Comandos:**
```bash
python agente_sabia.py               # Modo interativo
python agente_sabia.py --modo api    # Modo API (via MCP)
```

### 3. **modelo_local_v2/**
Modelo de embedding **paraphrase-multilingual-MiniLM-L12-v2**:
- **Dimensões:** 384
- **Multilíngue:** Suporta português
- **Tamanho:** ~420MB
- **Uso:** Busca semântica de disciplinas

## 🚀 Como Usar

### Pré-requisitos
```bash
# Ativar ambiente virtual
cd C:\Users\Gustavo\Desktop\2025-1-NoFluxoUNB
.\venv\Scripts\Activate.ps1

# Instalar dependências
pip install sentence-transformers supabase python-dotenv maritalk fastmcp

# Baixar modelo local ( a pasta criada deve estar dentro da pasta 'mcp_agent')
python baixar_modelo.py
```

### Configuração (.env)
```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_KEY=sua-chave-api
MARITACA_API_KEY=sua-chave-maritaca
```

### Executar Agente Interativo
```bash
cd mcp_agent
python agente_sabia.py
```

**Exemplo de uso:**
```
Digite sua pergunta: quero aprender inteligência artificial
🎓 10 disciplinas encontradas

[Respostas com disciplinas relevantes...]
```

### Integração com Website
O servidor MCP é usado pelo backend Node.js através de:
```typescript
// no_fluxo_backend/src/services/assistente.service.ts
const mcp = spawn('python', ['mcp_agent/servidor_mcp_sabia.py']);
```

## 📊 Pipeline de Busca

1. **Entrada do usuário:** "inteligência artificial"
2. **Expansão (Sabiázinho-4):** machine learning, redes neurais, aprendizado profundo
3. **Embedding:** Converte termos em vetor 384D
4. **Busca Vetorial:** Consulta Supabase com similaridade de cosseno
5. **Ranking:** Retorna top 10 (threshold ≥ 0.3)
6. **Resposta (Sabiá-4):** Formata resultado com contexto educacional

## 🔍 Funções do Banco de Dados

### `match_materias`
RPC function no Supabase para busca vetorial:
```sql
CREATE OR REPLACE FUNCTION match_materias(
    query_embedding vector(384),
    match_threshold float,
    match_count int
)
RETURNS TABLE (
    codigo_materia text,
    nome_materia text,
    departamento text,
    ementa text,
    similaridade float
)
```

Usa operador `<=>` (distância de cosseno) do pgvector.

## 📈 Performance

- **Inicialização:** ~2-3s (modelo + Supabase)
- **Busca:** ~500-800ms por query
- **Primeira query:** ~30s (carregamento inicial)
- **Queries seguintes:** <1s (sistemas pré-carregados)

## 🐛 Debugging

Para ver logs detalhados:
```bash
python agente_sabia.py 2>&1 | more
```

Logs incluem:
- `[MCP]` - Servidor MCP
- `[MARITACA]` - Chamadas à API Maritaca
- `[BUSCA]` - Busca vetorial
- Embeddings gerados (primeiros 5 valores)
- Scores de similaridade

## 🔒 Segurança

- **Credenciais:** Armazenadas em `.env` (não versionado)
- **API Keys:** Maritaca AI e Supabase
- **Modelo Local:** Sem vazamento de dados para APIs externas

## 🛠️ Manutenção

### Atualizar Modelo
Se precisar trocar o modelo de embedding:
1. Apagar pasta `modelo_local_v2/`
2. Editar `servidor_mcp_sabia.py` (linha 56)
3. Executar - novo modelo será baixado

### Ajustar Threshold
Para resultados mais/menos rigorosos:
```python
# servidor_mcp_sabia.py, linha 121
"match_threshold": 0.3,  # Menor = mais resultados
```

## 📚 Dependências

```
sentence-transformers>=2.2.0  # Embeddings
supabase>=1.0.0              # Banco vetorial
python-dotenv>=1.0.0         # Variáveis de ambiente
maritalk>=0.9.0              # Maritaca AI (Sabiá)
fastmcp>=0.1.0               # Protocolo MCP
```

## 🤝 Integração

O agente é usado em:
- **Website:** Rota `/assistente` (frontend Svelte)
- **Backend:** `AssistenteService` (Node.js)
- **Terminal:** Modo interativo para testes

---

**Versão:** 1.0  
**Modelo:** paraphrase-multilingual-MiniLM-L12-v2 (384D)  
**LLM:** Sabiá-4 + Sabiázinho-4 (Maritaca AI)  
**Banco:** Supabase PostgreSQL + pgvector
