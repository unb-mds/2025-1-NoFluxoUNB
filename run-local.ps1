# Script para rodar o projeto NoFluxo UNB localmente
# Este script simula o que o Docker faria

Write-Host "🚀 Iniciando NoFluxo UNB localmente..." -ForegroundColor Green

# Verificar se Flutter está instalado
Write-Host "📱 Verificando Flutter..." -ForegroundColor Yellow
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter não encontrado. Instale o Flutter primeiro." -ForegroundColor Red
    exit 1
}

# Verificar se Node.js está instalado
Write-Host "📦 Verificando Node.js..." -ForegroundColor Yellow
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Node.js não encontrado. Instale o Node.js primeiro." -ForegroundColor Red
    exit 1
}

# Verificar se Python está instalado
Write-Host "🐍 Verificando Python..." -ForegroundColor Yellow
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python não encontrado. Instale o Python primeiro." -ForegroundColor Red
    exit 1
}

# Build do Frontend Flutter
Write-Host "🔨 Fazendo build do Frontend Flutter..." -ForegroundColor Cyan
Set-Location no_fluxo_frontend
flutter config --enable-web
flutter pub get
flutter build web --web-renderer=html --release
Set-Location ..

# Setup do Backend
Write-Host "🔨 Configurando Backend..." -ForegroundColor Cyan
Set-Location no_fluxo_backend

# Instalar dependências Node.js
npm install

# Instalar dependências Python
pip install -r AI-agent/requirements.txt
pip install -r parse-pdf/requirements.txt

# Compilar TypeScript
npm run build

Write-Host "✅ Build concluído!" -ForegroundColor Green
Write-Host ""
Write-Host "Para iniciar o projeto:" -ForegroundColor Yellow
Write-Host "1. Frontend: Sirva os arquivos de no_fluxo_frontend/build/web" -ForegroundColor White
Write-Host "2. Backend: cd no_fluxo_backend && npm start" -ForegroundColor White
Write-Host ""
Write-Host "URLs:" -ForegroundColor Yellow
Write-Host "- Frontend: http://localhost (porta do seu servidor web)" -ForegroundColor White
Write-Host "- Backend: http://localhost:3000" -ForegroundColor White

Set-Location .. 