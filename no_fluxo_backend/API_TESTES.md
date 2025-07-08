# API de Testes - NoFluxo Backend

Esta documentação descreve os endpoints de teste criados para substituir os logs de debug do sistema.

## Endpoints Disponíveis

### 1. Teste de Conexão com Banco
**GET** `/testes/banco`

Testa a conexão com o banco de dados e verifica a estrutura das tabelas.

**Resposta de Sucesso:**
```json
{
  "teste": "conexao_banco",
  "status": "sucesso",
  "resultados": {
    "total_cursos": 5,
    "cursos_disponiveis": ["Engenharia de Software", "Ciência da Computação"],
    "estrutura_valida": true,
    "materias_nivel_zero": 2,
    "materias_nivel_zero_lista": [
      {
        "nome": "Matéria Optativa 1",
        "nivel": 0
      }
    ],
    "verificar_duplicatas": {
      "total_nomes": 50,
      "nomes_unicos": 48,
      "tem_duplicatas": true,
      "duplicatas_encontradas": ["Matéria Duplicada 1", "Matéria Duplicada 2"]
    }
  }
}
```

### 2. Teste de Busca de Curso
**GET** `/testes/curso?nome_curso=Engenharia de Software`

Testa a busca de um curso específico e analisa suas matérias.

**Parâmetros:**
- `nome_curso` (query): Nome do curso a ser testado

**Resposta de Sucesso:**
```json
{
  "teste": "busca_curso",
  "status": "sucesso",
  "curso_encontrado": "Engenharia de Software",
  "resultados": {
    "total_materias": 45,
    "materias_obrigatorias": 40,
    "materias_optativas": 5,
    "verificar_duplicatas": {
      "total_nomes": 45,
      "nomes_unicos": 45,
      "tem_duplicatas": false,
      "duplicatas_encontradas": []
    },
    "niveis_encontrados": [0, 1, 2, 3, 4, 5, 6, 7, 8],
    "primeiras_5_materias": [
      {
        "nome": "Cálculo I",
        "codigo": "MAT001",
        "nivel": 1
      }
    ]
  }
}
```

### 3. Teste de Casamento de Disciplinas
**POST** `/testes/casamento`

Testa o processo de casamento entre disciplinas extraídas do PDF e as matérias do banco.

**Body:**
```json
{
  "nome_curso": "Engenharia de Software",
  "dados_extraidos": {
    "extracted_data": [
      {
        "tipo_dado": "Disciplina Regular",
        "nome": "Cálculo I",
        "codigo": "MAT001",
        "status": "APR",
        "carga_horaria": 60
      }
    ]
  }
}
```

**Resposta de Sucesso:**
```json
{
  "teste": "casamento_disciplinas",
  "status": "sucesso",
  "curso": "Engenharia de Software",
  "resultados": {
    "dados_validacao": {
      "ira": 8.5,
      "horas_integralizadas": 180,
      "pendencias": []
    },
    "estatisticas": {
      "total_disciplinas_extraidas": 15,
      "total_disciplinas_casadas": 12,
      "disciplinas_encontradas_no_banco": 12,
      "disciplinas_nao_encontradas": 3,
      "materias_concluidas": 10,
      "materias_pendentes": 2,
      "materias_optativas_concluidas": 3,
      "materias_optativas_pendentes": 1
    },
    "breakdown": {
      "materias_obrigatorias_banco": 40,
      "materias_optativas_banco": 5,
      "disciplinas_casadas": 12,
      "materias_concluidas": 10,
      "materias_pendentes": 2,
      "materias_optativas_concluidas": 3,
      "materias_optativas_pendentes": 1,
      "soma_obrigatorias": 12,
      "total_optativas": 4
    }
  }
}
```

### 4. Teste Completo
**POST** `/testes/completo`

Executa todos os testes em sequência para um curso e dados específicos.

**Body:** Mesmo formato do teste de casamento

**Resposta de Sucesso:**
```json
{
  "teste": "teste_completo",
  "status": "concluido",
  "curso": "Engenharia de Software",
  "resultados": {
    "teste_banco": {
      "status": "sucesso",
      "total_cursos": 5
    },
    "teste_curso": {
      "status": "sucesso",
      "curso_encontrado": "Engenharia de Software",
      "total_materias": 45,
      "materias_obrigatorias": 40,
      "materias_optativas": 5
    },
    "teste_casamento": {
      "status": "sucesso",
      "total_disciplinas_extraidas": 15,
      "disciplinas_com_status": 15
    }
  },
  "resumo": {
    "testes_executados": 3,
    "testes_sucesso": 3,
    "testes_erro": 0
  }
}
```

## Como Usar

### Via cURL

```bash
# Teste de banco
curl -X GET "http://localhost:3000/testes/banco"

# Teste de curso
curl -X GET "http://localhost:3000/testes/curso?nome_curso=Engenharia%20de%20Software"

# Teste de casamento
curl -X POST "http://localhost:3000/testes/casamento" \
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
        }
      ]
    }
  }'

# Teste completo
curl -X POST "http://localhost:3000/testes/completo" \
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
        }
      ]
    }
  }'
```

### Via Postman/Insomnia

1. Configure a URL base: `http://localhost:3000`
2. Use os endpoints conforme descrito acima
3. Para POST requests, configure o header `Content-Type: application/json`
4. Use o body JSON conforme os exemplos

## Códigos de Status

- **200**: Teste executado com sucesso
- **400**: Parâmetros inválidos ou faltando
- **404**: Curso não encontrado
- **500**: Erro interno do servidor

## Benefícios

1. **Substitui logs de debug**: Em vez de verificar logs no terminal, você pode fazer requisições HTTP
2. **Testes isolados**: Cada endpoint testa uma funcionalidade específica
3. **Respostas estruturadas**: Dados organizados em JSON para fácil análise
4. **Teste completo**: Endpoint que executa todos os testes em sequência
5. **Fácil integração**: Pode ser usado em scripts de automação ou ferramentas de teste

## Exemplos de Uso

### Verificar se há duplicatas no banco:
```bash
curl -X GET "http://localhost:3000/testes/banco" | jq '.resultados.verificar_duplicatas'
```

### Verificar matérias de um curso específico:
```bash
curl -X GET "http://localhost:3000/testes/curso?nome_curso=Engenharia%20de%20Software" | jq '.resultados'
```

### Testar casamento com dados reais:
```bash
curl -X POST "http://localhost:3000/testes/casamento" \
  -H "Content-Type: application/json" \
  -d @dados_teste.json
``` 