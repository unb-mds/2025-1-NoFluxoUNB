# 🧪 Interface Web de Testes - NoFluxo Backend

Uma interface web moderna e intuitiva para testar a API do NoFluxo Backend.

## 🚀 Como Usar

### Pré-requisitos

1. **Backend principal rodando**: Certifique-se de que o servidor principal está rodando na porta 3000
2. **Node.js**: Versão 14 ou superior

### Início Rápido

#### Windows
```bash
cd no_fluxo_backend/testes-web
start.bat
```

#### Linux/Mac
```bash
cd no_fluxo_backend/testes-web
chmod +x start.sh
./start.sh
```

#### Manual
```bash
cd no_fluxo_backend/testes-web
npm install
npm run dev
```

### Acessando a Interface

Após iniciar o servidor, acesse:
- **Interface Web**: http://localhost:3002
- **Health Check**: http://localhost:3002/health

## 🎯 Funcionalidades

### 1. Teste de Conexão com Banco
- Verifica se o banco de dados está acessível
- Lista todos os cursos disponíveis
- Verifica estrutura das tabelas
- Detecta duplicatas nas matérias

### 2. Teste de Busca de Curso
- Busca um curso específico por nome
- Analisa as matérias do curso
- Verifica obrigatórias vs optativas
- Mostra estatísticas detalhadas

### 3. Teste de Casamento de Disciplinas
- Testa o processo de matching entre PDF e banco
- Aceita dados JSON de entrada
- Mostra estatísticas de casamento
- Calcula horas integralizadas

### 4. Teste Completo
- Executa todos os testes em sequência
- Fornece resumo geral
- Ideal para validação completa

## 🎨 Interface

### Características
- **Design moderno**: Interface limpa e responsiva
- **Resultados em tempo real**: JSON formatado e colorido
- **Botões de ação rápida**: Executar todos, limpar resultados, carregar exemplos
- **Validação de entrada**: Verifica JSON válido antes de enviar
- **Status visual**: Indicadores de sucesso, erro e carregamento

### Botões de Ação Rápida
- **🚀 Executar Todos os Testes**: Roda todos os testes em sequência
- **🗑️ Limpar Resultados**: Remove todos os resultados da tela
- **📝 Carregar Dados de Exemplo**: Preenche com dados de teste válidos

## 📊 Exemplo de Uso

### 1. Teste Básico
1. Acesse http://localhost:3002
2. Clique em "🚀 Executar Todos os Testes"
3. Veja os resultados de cada teste

### 2. Teste Personalizado
1. Preencha o nome do curso desejado
2. Cole os dados JSON extraídos do PDF
3. Clique no botão específico do teste
4. Analise o resultado detalhado

### 3. Dados de Exemplo
```json
{
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
```

## 🔧 Configuração

### Portas
- **Interface Web**: 3002
- **API Backend**: 3000

### Variáveis de Ambiente
O servidor usa as seguintes configurações padrão:
- `PORT`: 3002 (pode ser alterado no `server.ts`)

### CORS
A interface está configurada para aceitar requisições do backend na porta 3000.

## 🐛 Solução de Problemas

### Erro de Conexão
- Verifique se o backend está rodando na porta 3000
- Confirme se não há firewall bloqueando as portas

### Erro de JSON
- Use o botão "📝 Carregar Dados de Exemplo" para ver o formato correto
- Valide seu JSON em um validador online

### Erro de Dependências
- Execute `npm install` na pasta `testes-web`
- Verifique se o Node.js está atualizado

## 📁 Estrutura do Projeto

```
testes-web/
├── index.html          # Interface principal
├── server.ts           # Servidor Express
├── package.json        # Dependências
├── start.bat          # Script Windows
├── start.sh           # Script Linux/Mac
└── README.md          # Esta documentação
```

## 🎉 Benefícios

1. **Interface Visual**: Mais fácil que comandos curl
2. **Resultados Formatados**: JSON bem estruturado e legível
3. **Testes Rápidos**: Botões de ação rápida
4. **Validação**: Verifica dados antes de enviar
5. **Responsivo**: Funciona em desktop e mobile
6. **Fácil Uso**: Não precisa de conhecimento técnico avançado

## 🔗 Links Úteis

- **API de Testes**: http://localhost:3000/testes
- **Documentação da API**: ../API_TESTES.md
- **Scripts de Exemplo**: ../testes_exemplo.ps1 e ../testes_exemplo.sh 