"""
Script para baixar e salvar o modelo SentenceTransformer localmente.
Execute uma vez: python baixar_modelo.py
"""
from sentence_transformers import SentenceTransformer
import os

# Nome do modelo que será baixado
MODELO_NAME = "paraphrase-multilingual-MiniLM-L12-v2"
PASTA_DESTINO = "./modelo_local"

print(f"Baixando modelo '{MODELO_NAME}' da Hugging Face...")
print("Isso pode demorar alguns minutos na primeira vez...")

# Baixa o modelo da internet
modelo = SentenceTransformer(MODELO_NAME)

# Salva localmente
print(f"\nSalvando modelo em: {os.path.abspath(PASTA_DESTINO)}")
modelo.save(PASTA_DESTINO)

print("\n✅ Modelo baixado e salvo com sucesso!")
print(f"Agora o servidor_mcp_sabia.py pode carregar de: {PASTA_DESTINO}")
