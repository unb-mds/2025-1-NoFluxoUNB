#!/bin/bash

echo "🚀 Iniciando servidor de testes do NoFluxo..."
echo

# Verificar se o Node.js está instalado
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não encontrado. Por favor, instale o Node.js primeiro."
    exit 1
fi

# Verificar se as dependências estão instaladas
if [ ! -d "node_modules" ]; then
    echo "📦 Instalando dependências..."
    npm install
    if [ $? -ne 0 ]; then
        echo "❌ Erro ao instalar dependências."
        exit 1
    fi
fi

# Iniciar o servidor
echo "🎯 Iniciando servidor na porta 3002..."
echo
echo "💡 Certifique-se de que o backend principal está rodando na porta 3000"
echo
npm run dev 