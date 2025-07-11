# GitHub Actions Workflows

Este diretório contém os workflows do GitHub Actions para automação de testes e CI/CD.

## Workflows Disponíveis

### 1. `test.yml` - Testes Gerais
- **Trigger**: Push/PR para `main` ou `develop`
- **Funcionalidades**:
  - Roda em múltiplas versões do Node.js (18.x, 20.x)
  - Verificação de tipos TypeScript
  - Linting
  - Testes unitários
  - Relatório de cobertura

### 2. `backend-tests.yml` - Testes Específicos do Backend
- **Trigger**: Push/PR que afeta arquivos em `no_fluxo_backend/**`
- **Funcionalidades**:
  - Otimizado para mudanças no backend
  - Cache de dependências npm
  - Upload de relatórios de cobertura
  - Artefatos para download

## Como Usar

### Para Desenvolvedores
1. Faça um Pull Request para `main` ou `develop`
2. Os workflows rodarão automaticamente
3. Verifique os resultados na aba "Actions" do GitHub

### Para Configurar Codecov (Opcional)
1. Acesse [codecov.io](https://codecov.io)
2. Conecte seu repositório
3. Os relatórios de cobertura serão enviados automaticamente

### Comandos Locais
```bash
# Rodar testes localmente
cd no_fluxo_backend
npm test

# Rodar com cobertura
npm run test:coverage

# Verificar tipos
npm run type-check

# Linting
npm run lint
```

## Estrutura dos Testes
- **Localização**: `no_fluxo_backend/tests-ts/`
- **Padrão**: `*.test.ts`
- **Configuração**: Jest com TypeScript

## Troubleshooting

### Se os testes falharem:
1. Verifique se todas as dependências estão instaladas
2. Execute `npm ci` para instalar dependências limpas
3. Verifique se o TypeScript está compilando corretamente
4. Execute os testes localmente primeiro

### Se o linter falhar:
1. Execute `npm run lint:fix` para corrigir automaticamente
2. Verifique as regras no `.eslintrc.js` 