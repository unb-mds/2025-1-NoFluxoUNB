# Start Backend
Write-Host "Starting NoFluxo Backend..." -ForegroundColor Green
Set-Location (Join-Path $PSScriptRoot "backend")
npm run dev
