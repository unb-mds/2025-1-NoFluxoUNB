import json
import os
import sys

'''
Este arquivo visa converter o .json obtido do arquivo '01_extrair_turmas_sigaa.py', para .txt
'''

<<<<<<< HEAD
<<<<<<< HEAD
=======
>>>>>>> e230dc46013b11b69eea88dddfc80240c5a9aa54

# Caminho onde estão seus arquivos .json
#entrada = "dados_finais"
#saida = "chunks_finais2"

# Só executa se for chamado diretamente
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Erro: Forneça os nomes das pastas de entrada e saída como argumentos.")
        print("Uso: python script_json_para_txt.py <pasta_de_entrada> <pasta_de_saida>")
        sys.exit(1)
    entrada = sys.argv[1]
    saida = sys.argv[2]
else:
    # Valores padrão para quando importado
    entrada = "dados_finais"
    saida = "chunks_finais2"

os.makedirs(saida, exist_ok=True)

# Campos que você quer extrair (edite conforme necessário)
<<<<<<< HEAD
=======
# Campos que você quer extrair (podem ser importados por outros módulos)
>>>>>>> origin/dev
=======
>>>>>>> e230dc46013b11b69eea88dddfc80240c5a9aa54
campos = [
    "disciplina",
    "codigo",
    "unidade_responsavel",
    "ementa"
]

def formatar_turma(turma):
    """Formata os dados de uma única turma em uma string."""
    linhas = []
    for campo in campos:
        valor = turma.get(campo, "").strip()
        if valor:
            linhas.append(f"{campo.replace('_', ' ').capitalize()}: {valor}")
    return "\n".join(linhas)

def converter_json_para_txt(pasta_entrada, pasta_saida):
    """
    Lê arquivos .json de uma pasta de entrada, formata o conteúdo
    e salva como arquivos .txt em uma pasta de saída.
    """
    os.makedirs(pasta_saida, exist_ok=True)

    # Para cada arquivo .json na pasta
    for nome_arquivo in os.listdir(pasta_entrada):
        if nome_arquivo.endswith(".json"):
            caminho_arquivo_entrada = os.path.join(pasta_entrada, nome_arquivo)
            with open(caminho_arquivo_entrada, "r", encoding="utf-8") as f:
                dados = json.load(f)
            
            chunks = []
            for turma in dados:
                # Gera o texto da turma formatado
                turma_formatada = formatar_turma(turma)
                chunks.append(turma_formatada)

            # Salva um .txt com os chunks separados por 2 quebras de linha
            nome_txt = nome_arquivo.replace(".json", ".txt")
            caminho_arquivo_saida = os.path.join(pasta_saida, nome_txt)
            with open(caminho_arquivo_saida, "w", encoding="utf-8") as out:
                out.write("\n\n\n".join(chunks))

# --- Bloco de Execução Principal ---
# O código abaixo só será executado quando você rodar:
# python seu_script.py pasta_entrada pasta_saida
if __name__ == "__main__":
    # 1. Verificação dos argumentos
    if len(sys.argv) < 3:
        print("Erro: Forneça os nomes das pastas de entrada e saída como argumentos.")
        print("Uso: python script_json_para_txt.py <pasta_de_entrada> <pasta_de_saida>")
        sys.exit(1)
        
    # 2. Pega os argumentos
    entrada = sys.argv[1]
    saida = sys.argv[2]

    # 3. Chama a função principal do script
    converter_json_para_txt(entrada, saida)
    print(f"Conversão concluída! Arquivos salvos em '{saida}'.")