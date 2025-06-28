#!/bin/bash

# Script de exemplo para testar a API de testes do NoFluxo Backend
# Certifique-se de que o servidor está rodando em localhost:3000

BASE_URL="http://localhost:3000/fluxograma"

echo "🧪 Iniciando testes da API NoFluxo Backend"
echo "=========================================="

# Teste 1: Conexão com banco
echo ""
echo "1️⃣ Testando conexão com banco..."
curl -s -X GET "$BASE_URL/teste_banco" | jq '.'

# Teste 2: Busca de curso
echo ""
echo "2️⃣ Testando busca de curso..."
curl -s -X GET "$BASE_URL/teste_curso?nome_curso=Engenharia%20de%20Software" | jq '.'

# Teste 3: Casamento de disciplinas
echo ""
echo "3️⃣ Testando casamento de disciplinas..."
curl -s -X POST "$BASE_URL/teste_casamento" \
  -H "Content-Type: application/json" \
  -d '{
    "nome_curso": "Engenharia de Software",
    "dados_extraidos": {
      "extracted_data": [
        {
          "tipo_dado": "Disciplina Regular",
          "nome": "Cálculo I",
          "codigo": "MAT001",
          "status": "APR",
          "carga_horaria": 60
        },
        {
          "tipo_dado": "Disciplina Regular",
          "nome": "Programação I",
          "codigo": "INF001",
          "status": "APR",
          "carga_horaria": 60
        },
        {
          "tipo_dado": "Disciplina Regular",
          "nome": "Física I",
          "codigo": "FIS001",
          "status": "REP",
          "carga_horaria": 60
        }
      ]
    }
  }' | jq '.'

# Teste 4: Teste completo
echo ""
echo "4️⃣ Executando teste completo..."
curl -s -X POST "$BASE_URL/teste_completo" \
  -H "Content-Type: application/json" \
  -d '{
    "nome_curso": "Engenharia de Software",
    "dados_extraidos": {
      "extracted_data": [
        {
          "tipo_dado": "Disciplina Regular",
          "nome": "Cálculo I",
          "codigo": "MAT001",
          "status": "APR",
          "carga_horaria": 60
        },
        {
          "tipo_dado": "Disciplina Regular",
          "nome": "Programação I",
          "codigo": "INF001",
          "status": "APR",
          "carga_horaria": 60
        }
      ]
    }
  }' | jq '.'

echo ""
echo "✅ Testes concluídos!"
echo ""
echo "💡 Dicas:"
echo "   - Use 'jq' para formatar as respostas JSON"
echo "   - Verifique se o servidor está rodando em localhost:3000"
echo "   - Consulte API_TESTES.md para mais detalhes" 