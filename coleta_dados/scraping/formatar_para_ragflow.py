import re
import os
import sys

'''
Este arquivo visa converter o .txt obtido do arquivo '02_converter_json_para_txt.py', para também um arquivo .txt,
porém formatado para melhor estruturação no RagFlow

'''


def preprocess_disciplines_txt_from_folder(input_folder, output_folder, internal_field_separator="; ", record_delimiter="\n\n"):
    """
    Pré-processa arquivos .txt de disciplinas de uma pasta de entrada,
    transformando cada disciplina completa em uma única linha, separada por um delimitador forte.
    Salva os arquivos processados em uma pasta de saída.

    Args:
        input_folder (str): Caminho para a pasta que contém os arquivos .txt originais das disciplinas.
        output_folder (str): Caminho para a pasta onde os novos arquivos .txt pré-processados serão salvos.
        internal_field_separator (str): Separador usado entre os campos dentro da mesma linha de disciplina.
                                       Ex: "Disciplina: X; Nome componente: Y; Ementa: Z."
        record_delimiter (str): Delimitador forte usado para separar uma disciplina completa da próxima.
                                Ex: "\n#####\n"
    """
    # Cria a pasta de saída se ela não existir
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        print(f"Pasta de saída '{output_folder}' criada.")

    # Lista todos os arquivos na pasta de entrada
    for filename in os.listdir(input_folder):
        if filename.endswith('.txt'):
            input_filepath = os.path.join(input_folder, filename)
            output_filepath = os.path.join(output_folder, f"preprocessed_{filename}") # Adiciona prefixo para identificar

            print(f"Processando arquivo: {filename}")

            with open(input_filepath, 'r', encoding='utf-8') as infile:
                content = infile.read()

            # Divide o conteúdo em blocos de disciplinas, usando o padrão "Disciplina:" como ponto de início.
            discipline_blocks = re.split(r'(?m)^Disciplina:', content)
            
            # Se o primeiro item do split não começar com uma disciplina, descarte-o
            if discipline_blocks and not discipline_blocks[0].strip().startswith("Disciplina:"):
                discipline_blocks = discipline_blocks[1:]
            
            # Se ainda não houver blocos, pule o arquivo
            if not discipline_blocks:
                print(f"Nenhuma disciplina encontrada em {filename}. Pulando.")
                continue

            processed_records = []

            for block in discipline_blocks:
                # Adiciona de volta o "Disciplina:" que foi usado para dividir, se necessário
                if not block.strip().startswith("Disciplina:"):
                     block = "Disciplina:" + block.strip()
                
                # Divide o bloco em linhas e filtra linhas vazias que não sejam delimitadores de seção
                lines = [line.strip() for line in block.split('\n') if line.strip()]

                # Concatena as linhas da disciplina em uma única string, separando por internal_field_separator
                single_line_discipline = internal_field_separator.join(lines)
                single_line_discipline = re.sub(r'\s+', ' ', single_line_discipline).strip() # Normaliza múltiplos espaços

                # Ajustar a formatação de "Ementa: " para não ter espaços desnecessários
                single_line_discipline = single_line_discipline.replace("Ementa: ", "Ementa:").replace("Ementa:", "Ementa: ").strip()

                processed_records.append(single_line_discipline)

            # Junta todos os registros processados com o delimitador forte
            output_content = record_delimiter.join(processed_records)

            with open(output_filepath, 'w', encoding='utf-8') as outfile:
                outfile.write(output_content)

            print(f"Arquivo '{filename}' processado e salvo em: '{output_filepath}'")

    print("\nProcessamento de todos os arquivos .txt concluído!")


def main():

    # Defina o caminho para a pasta que contém seus arquivos .txt originais
    #input_folder_path = 'chunks_finais2' # <-- ALTERE AQUI!
    
    # Defina o caminho para a pasta onde os novos arquivos pré-processados serão salvos
    #output_folder_path = 'chunks_finais_formatados2' # <-- ALTERE AQUI!
    if len(sys.argv) < 3:
        print("Erro: Forneça os nomes das pastas de entrada e saída como argumentos.")
        print("Uso: python formataRagflow.py <pasta_de_entrada> <pasta_de_saida>")
        sys.exit(1)
    input_folder_path = sys.argv[1]
    output_folder_path = sys.argv[2]
    # Defina o delimitador que você usará no RAGFlow (deve ser o mesmo aqui e lá!)
    # Recomendo um delimitador que é improvável de aparecer no texto da disciplina
    custom_ragflow_delimiter = "\n\n" # Ou "\n---DISCIPLINA_FIM---\n", etc.

    # Execute a função de pré-processamento para a pasta
    preprocess_disciplines_txt_from_folder(input_folder_path, output_folder_path, record_delimiter=custom_ragflow_delimiter)

    print(f"\nAgora, no RAGFlow, ao adicionar os arquivos da pasta '{output_folder_path}':")
    print(f"- Defina 'Chunk Size' para um valor ALTO (ex: 9999).")
    print(f"- Defina 'Delimiter for text' para '{custom_ragflow_delimiter.strip()}'.")
    print(f"(Atenção ao copiar o delimitador: {custom_ragflow_delimiter.strip()} é sem as quebras de linha nas pontas para a interface do RAGFlow, mas o script as usa para formatar o arquivo.)")

# --- COMO USAR O SCRIPT ---
if __name__ == "__main__":
    main()
