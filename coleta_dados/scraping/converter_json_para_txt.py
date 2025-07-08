import json
import os
import sys

'''
Este arquivo visa converter o .json obtido do arquivo '01_extrair_turmas_sigaa.py', para .txt
'''


# Caminho onde estão seus arquivos .json
#entrada = "dados_finais"
#saida = "chunks_finais2"
if len(sys.argv) < 3:
    print("Erro: Forneça os nomes das pastas de entrada e saída como argumentos.")
    print("Uso: python script_json_para_txt.py <pasta_de_entrada> <pasta_de_saida>")
    sys.exit(1)
entrada = sys.argv[1]
saida = sys.argv[2]

os.makedirs(saida, exist_ok=True)

# Campos que você quer extrair (edite conforme necessário)
campos = [
    "disciplina",
    "codigo",
    "unidade_responsavel",
    "ementa"

]

def formatar_turma(turma):
    linhas = []
    for campo in campos:
        valor = turma.get(campo, "").strip()
        if valor:
            linhas.append(f"{campo.replace('_', ' ').capitalize()}: {valor}")
    return "\n".join(linhas)

def main():
    # Para cada arquivo .json na pasta
    for nome_arquivo in os.listdir(entrada):
        if nome_arquivo.endswith(".json"):
            with open(os.path.join(entrada, nome_arquivo), "r", encoding="utf-8") as f:
                dados = json.load(f)
            
            chunks = []
            for turma in dados:
                # Gera o texto da turma formatado
                turma_formatada = formatar_turma(turma)
                chunks.append(turma_formatada)

            # Salva um .txt com os chunks separados por 2 quebras de linha
            nome_txt = nome_arquivo.replace(".json", ".txt")
            with open(os.path.join(saida, nome_txt), "w", encoding="utf-8") as out:
                out.write("\n\n\n".join(chunks))


if __name__ == "__main__":
    main()
