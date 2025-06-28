@echo off
echo 🚀 Iniciando servidor de testes do NoFluxo...
echo.

REM Verificar se o Node.js está instalado
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js não encontrado. Por favor, instale o Node.js primeiro.
    pause
    exit /b 1
)

REM Verificar se as dependências estão instaladas
if not exist "node_modules" (
    echo 📦 Instalando dependências...
    npm install
    if %errorlevel% neq 0 (
        echo ❌ Erro ao instalar dependências.
        pause
        exit /b 1
    )
)

REM Iniciar o servidor
echo 🎯 Iniciando servidor na porta 3002...
echo.
echo 💡 Certifique-se de que o backend principal está rodando na porta 3000
echo.
npm run dev

pause 