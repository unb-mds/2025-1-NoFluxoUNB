# config.py (VERSÃO FINAL COM VALORES HARDCODED)
import os

# NÃO VAMOS MAIS LER DO .ENV. OS VALORES ESTÃO FIXOS AQUI.

# Chave de API mais recente que você gerou na interface
RAGFLOW_API_KEY = ""

# O endereço do seu servidor RAGFlow
RAGFLOW_BASE_URL = ""
# O ID do seu agente novo e correto
#RAGFLOW_AGENT_ID = "10b20f0248a611f089a9fa761c0fa70c"

RAGFLOW_AGENT_ID = ""

# Verificação final para garantir que não estão vazios
if not RAGFLOW_API_KEY or not RAGFLOW_BASE_URL or not RAGFLOW_AGENT_ID:
    raise ValueError(
        "Erro: Uma ou mais variáveis de configuração estão faltando no arquivo config.py"
    )
