#!/bin/bash
# Script para iniciar a API FastAPI do Sabiá

echo "[DARCY AI] Iniciando API FastAPI..."

cd "$(dirname "$0")"

# Ativa o ambiente virtual
source ../venv/bin/activate

# Inicia o servidor FastAPI com Uvicorn
echo "[DARCY AI] Servidor iniciando em http://localhost:8000"
echo "[DARCY AI] Pressione Ctrl+C para parar"
uvicorn api_producao:app --host 0.0.0.0 --port 8000 --reload
