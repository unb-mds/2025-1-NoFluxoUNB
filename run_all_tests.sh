#!/bin/bash

# Script para executar todos os testes do projeto
# TypeScript e Python

set -e

echo "🚀 Iniciando execução de todos os testes..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir com cores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Verificar se estamos no diretório raiz do projeto
if [ ! -f "no_fluxo_backend/package.json" ]; then
    print_error "Este script deve ser executado no diretório raiz do projeto"
    exit 1
fi

# Testes TypeScript
print_status "Executando testes TypeScript..."

cd no_fluxo_backend

# Verificar se node_modules existe
if [ ! -d "node_modules" ]; then
    print_warning "Instalando dependências TypeScript..."
    npm install
fi

# Type check
print_status "Executando type check..."
npm run type-check

# ESLint
print_status "Executando ESLint..."
npm run lint

# Testes
print_status "Executando testes Jest..."
npm test

# Testes com coverage
print_status "Executando testes com coverage..."
npm run test:coverage

print_success "✅ Testes TypeScript Backend concluídos com sucesso!"

cd ..

# Testes Frontend SvelteKit (Vitest)
print_status "Executando testes Frontend SvelteKit (Vitest)..."

cd no_fluxo_frontend_svelte

if [ ! -d "node_modules" ]; then
    print_warning "Instalando dependências do Frontend..."
    npm install
fi

print_status "Executando Vitest..."
npm run test:unit

print_success "✅ Testes Frontend concluídos com sucesso!"

cd ..

# Testes Python
print_status "Executando testes Python..."

cd tests-python

# Verificar se virtualenv existe
if [ ! -d "venv" ]; then
    print_warning "Criando virtualenv..."
    python3 -m venv venv
fi

# Ativar virtualenv
source venv/bin/activate

# Instalar dependências
print_status "Instalando dependências Python..."
pip install -r requirements.txt
pip install pytest pytest-cov pytest-mock

# Executar testes
print_status "Executando testes pytest..."
python -m pytest -v --cov=. --cov-report=html --cov-report=term-missing

print_success "✅ Testes Python concluídos com sucesso!"

# Desativar virtualenv
deactivate

cd ..

print_success "🎉 Todos os testes foram executados com sucesso!"
print_status "Relatórios de coverage disponíveis em:"
print_status "- Backend TypeScript: no_fluxo_backend/coverage/"
print_status "- Frontend SvelteKit: no_fluxo_frontend_svelte/coverage/"
print_status "- Python: tests-python/htmlcov/" 