import subprocess
import sys
import os
import datetime

'''
Este arquivo, junta os demas arquivos com iniciais '01', '02' e '03' , para serem executados em 1 arquivo só (o  arquivo atual)
Os resultados extraidos desse arquivo visam estruturar esses dados obtidos para alimentar a base de conhecimento do RagFlow.

'''


def gerar_nomes_pastas():
    """
    Gera nomes de pasta dinâmicos com base no ano e semestre atuais.
    Exemplo: para junho de 2025, o sufixo será '2025_1'.
    """
    hoje = datetime.date.today()
    ano = hoje.year
    # Define o semestre: 1 para meses de 1 a 6, 2 para meses de 7 a 12
    semestre = 1 if hoje.month <= 6 else 2
    
    sufixo_semestre = f"{ano}_{semestre}"
    diretorio_base = "coleta_dados/dados"
    
    nomes = {
        "dados_finais": os.path.join(diretorio_base, f"dados_finais_{sufixo_semestre}"),
        "chunks": os.path.join(diretorio_base, f"chunks_finais_{sufixo_semestre}"),
        "formatados": os.path.join(diretorio_base, f"chunks_finais_formatados_{sufixo_semestre}")
    }
    print(f"Pastas a serem utilizadas neste semestre ({sufixo_semestre}):")
    print(f" - Dados brutos: {nomes['dados_finais']}")
    print(f" - Chunks TXT: {nomes['chunks']}")
    print(f" - Formatados RAG: {nomes['formatados']}")
    return nomes

def executar_script(argumentos_comando):
    """
    Executa um script Python com uma lista de argumentos e verifica erros.
    """
    nome_do_script = argumentos_comando[1] # O segundo item é o nome do script
    print("-" * 60)
    print(f"▶️  Iniciando a execução de: {nome_do_script}")
    print("-" * 60)
    
    try:
        env_utf8 = os.environ.copy()
        env_utf8["PYTHONIOENCODING"] = "utf-8"

        processo = subprocess.run(
            argumentos_comando, 
            check=True, 
            capture_output=True, 
            text=True, 
            encoding='utf-8',
            env=env_utf8
        )
        
        print("--- Saída do Script ---")
        print(processo.stdout)
        print("-----------------------")
        print(f"✅  '{nome_do_script}' concluído com sucesso!")
        return True

    except FileNotFoundError:
        print(f"❌  ERRO: O arquivo '{nome_do_script}' não foi encontrado.")
        return False
    except subprocess.CalledProcessError as e:
        print(f"❌  ERRO: O script '{nome_do_script}' encontrou um erro e foi interrompido.")
        print("\n--- Erro Detalhado ---\n" + e.stderr + "\n----------------------")
        return False
    except Exception as e:
        print(f"❌  Ocorreu um erro inesperado ao executar '{nome_do_script}': {e}")
        return False

def main():
    """
    Função principal que executa todos os scripts em sequência com nomes de pastas dinâmicos.
    """
    print("=" * 60)
    print("🚀 INICIANDO FLUXO DE PROCESSAMENTO DE DADOS COM NOMES DINÂMICOS")
    print("=" * 60)

    pastas = gerar_nomes_pastas()

    pasta_scripts = "coleta_dados/scraping"

    # Define a lista de comandos a serem executados
    comandos = [
        [sys.executable, os.path.join(pasta_scripts, "extrair_turmas_sigaa.py"), pastas["dados_finais"]],
        [sys.executable, os.path.join(pasta_scripts, "converter_json_para_txt.py"), pastas["dados_finais"], pastas["chunks"]],
        [sys.executable, os.path.join(pasta_scripts, "formatar_para_ragflow.py"), pastas["chunks"], pastas["formatados"]]
    ]

    for cmd in comandos:
        sucesso = executar_script(cmd)
        if not sucesso:
            print("\n🛑 O fluxo foi interrompido devido a um erro no script acima.")
            break
    
    print("\n" + "="*60)
    print("🏁 FLUXO DE PROCESSAMENTO FINALIZADO.")
    print("="*60)

if __name__ == "__main__":
    main()