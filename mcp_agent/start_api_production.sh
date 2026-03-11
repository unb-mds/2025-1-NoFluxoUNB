#!/bin/bash
# Script para iniciar a API FastAPI em PRODUÇÃO (múltiplos workers)
echo "[DARCY AI - PRODUCAO] Iniciando API FastAPI com 4 workers..."

cd "$(dirname "$0")"

# Ativa o ambiente virtual
source ../venv/bin/activate

# Inicia o servidor FastAPI com Uvicorn em modo produção
echo "[DARCY AI] Servidor iniciando em http://0.0.0.0:8000"
echo "[DARCY AI] Workers: 4 (1 por núcleo de CPU)"
echo "[DARCY AI] Modo: PRODUCAO (sem reload)"
echo "[DARCY AI] Pressione Ctrl+C para parar"
uvicorn api_producao:app --host 0.0.0.0 --port 8000 --workers 4 --no-access-log
