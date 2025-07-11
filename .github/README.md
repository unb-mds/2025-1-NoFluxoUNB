# GitHub Actions - Testes Automatizados

Este diretório contém os workflows do GitHub Actions para automatizar os testes do projeto No Fluxo.

## Workflows Disponíveis

### 1. `all-tests.yml`
Workflow principal que executa todos os testes (TypeScript e Python) em paralelo.

**Triggers:**
- Push para branches `main` e `develop`
- Pull requests para branches `main` e `develop`

**Jobs:**
- `typescript-tests`: Executa testes TypeScript, ESLint e type checking
- `python-tests`: Executa testes Python com pytest
- `test-results`: Gera resumo dos resultados

### 2. `typescript-tests.yml`
Workflow específico para testes TypeScript.

**Triggers:**
- Push/PR que afetam arquivos em `no_fluxo_backend/` ou `tests-ts/`

**Funcionalidades:**
- Type checking
- ESLint
- Jest tests
- Coverage reports
- Suporte a múltiplas versões do Node.js (18.x, 20.x)

### 3. `python-tests.yml`
Workflow específico para testes Python.

**Triggers:**
- Push/PR que afetam arquivos em `tests-python/`, `coleta_dados/` ou `ai_agent/`

**Funcionalidades:**
- Instalação de dependências do sistema (tesseract, poppler)
- Testes com pytest
- Coverage reports
- Suporte a múltiplas versões do Python (3.9, 3.10, 3.11)

## Como Usar

### Execução Local
Para executar todos os testes localmente:

```bash
./run_all_tests.sh
```

### Execução Manual no GitHub
1. Vá para a aba "Actions" no repositório
2. Selecione o workflow desejado
3. Clique em "Run workflow"
4. Escolha a branch e clique em "Run workflow"

### Configuração de Secrets
Para que os workflows funcionem corretamente, configure os seguintes secrets no repositório:

- `CODECOV_TOKEN`: Token do Codecov para upload de coverage (opcional)

## Estrutura dos Testes

### TypeScript Tests
- **Localização**: `no_fluxo_backend/tests-ts/`
- **Framework**: Jest
- **Configuração**: `no_fluxo_backend/package.json`
- **Comandos**:
  - `npm test`: Executa testes
  - `npm run test:coverage`: Executa testes com coverage
  - `npm run lint`: Executa ESLint
  - `npm run type-check`: Executa type checking

### Python Tests
- **Localização**: `tests-python/`
- **Framework**: pytest
- **Configuração**: `tests-python/pytest.ini`
- **Comandos**:
  - `pytest`: Executa testes
  - `pytest --cov=.`: Executa testes com coverage

## Coverage Reports

Os workflows geram relatórios de coverage que são enviados para o Codecov:

- **TypeScript**: Coverage dos controllers e utilitários
- **Python**: Coverage dos módulos de scraping e processamento

## Troubleshooting

### Problemas Comuns

1. **Testes falhando no CI mas passando localmente**
   - Verifique se todas as dependências estão instaladas
   - Confirme se as variáveis de ambiente estão configuradas

2. **Erros de ESLint**
   - Execute `npm run lint:fix` localmente para corrigir automaticamente
   - Verifique a configuração em `.eslintrc.js`

3. **Erros de TypeScript**
   - Execute `npm run type-check` localmente
   - Verifique se todos os tipos estão corretos

4. **Erros de Python**
   - Verifique se todas as dependências estão em `requirements.txt`
   - Confirme se o pytest está instalado

### Logs e Debugging

- Os logs completos estão disponíveis na aba "Actions" do GitHub
- Cada job tem logs detalhados que podem ser expandidos
- Use `set -x` nos scripts para debug detalhado

## Contribuindo

Para adicionar novos testes:

1. **TypeScript**: Adicione arquivos `.test.ts` em `no_fluxo_backend/tests-ts/`
2. **Python**: Adicione arquivos `test_*.py` em `tests-python/`
3. **Atualize os workflows** se necessário
4. **Teste localmente** antes de fazer push

## Configuração Avançada

### Cache
Os workflows usam cache para acelerar a execução:
- **Node.js**: Cache do npm baseado no `package-lock.json`
- **Python**: Cache do pip baseado no `requirements.txt`

### Matrix Testing
- **TypeScript**: Testado em Node.js 18.x e 20.x
- **Python**: Testado em Python 3.9, 3.10 e 3.11

### Coverage Thresholds
- **TypeScript**: Configurado no Jest
- **Python**: Configurado no pytest.ini (70% mínimo) 