#!/bin/bash

# Script para executar testes e lint do backend

echo "🚀 Executando testes e lint do backend No Fluxo"
echo "================================================"

# Função para executar lint
run_lint() {
    echo ""
    echo "🔍 Executando ESLint..."
    echo "----------------------"
    
    if npm run lint; then
        echo "✅ Lint executado com sucesso!"
        return 0
    else
        echo "❌ Falha no lint"
        return 1
    fi
}

# Função para executar type check
run_type_check() {
    echo ""
    echo "🔍 Executando Type Check..."
    echo "---------------------------"
    
    if npm run type-check; then
        echo "✅ Type Check executado com sucesso!"
        return 0
    else
        echo "❌ Falha no Type Check"
        return 1
    fi
}

# Função para executar testes
run_tests() {
    echo ""
    echo "🧪 Executando testes..."
    echo "----------------------"
    
    if npm test; then
        echo "✅ Testes executados com sucesso!"
        return 0
    else
        echo "❌ Falha nos testes"
        return 1
    fi
}

# Função para executar testes com coverage
run_tests_coverage() {
    echo ""
    echo "📊 Executando testes com coverage..."
    echo "-----------------------------------"
    
    if npm run test:coverage; then
        echo "✅ Testes com coverage executados com sucesso!"
        return 0
    else
        echo "❌ Falha nos testes com coverage"
        return 1
    fi
}

# Executar todas as verificações
main() {
    local exit_code=0
    
    # Lint
    if run_lint; then
        echo "✅ Lint passou!"
    else
        echo "❌ Lint falhou"
        exit_code=1
    fi
    
    # Type Check
    if run_type_check; then
        echo "✅ Type Check passou!"
    else
        echo "❌ Type Check falhou"
        exit_code=1
    fi
    
    # Testes
    if run_tests; then
        echo "✅ Testes passaram!"
    else
        echo "❌ Testes falharam"
        exit_code=1
    fi
    
    # Testes com coverage (opcional)
    run_tests_coverage
    
    echo ""
    echo "================================================"
    if [ $exit_code -eq 0 ]; then
        echo "🎉 Todas as verificações passaram!"
    else
        echo "⚠️  Algumas verificações falharam. Verifique os logs acima."
    fi
    
    exit $exit_code
}

# Executar o script principal
main 