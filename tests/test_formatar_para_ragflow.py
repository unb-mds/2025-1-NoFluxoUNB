import unittest
from unittest.mock import patch, mock_open
import os
import sys

# Adiciona o diretório raiz ao path para que a importação funcione
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Importa o módulo que queremos testar
from coleta_dados.scraping import formatar_para_ragflow as script_a_testar

class TestFormatadorParaRagflow(unittest.TestCase):
    """
    Testes para a função `preprocess_disciplines_txt_from_folder`, que é
    a unidade central de lógica do script de formatação.
    """

    # Usamos @patch para substituir temporariamente as funções do `os` e `open`
    # por "Mocks" (simulacros) durante a execução do teste.
    @patch('os.path.exists')
    @patch('os.makedirs')
    @patch('os.listdir')
    @patch('builtins.open', new_callable=mock_open)
    def test_processamento_basico_com_dois_blocos(self, mock_file, mock_listdir, mock_makedirs, mock_exists):
        """
        Testa o caso de uso principal: um arquivo com múltiplos blocos de disciplina
        e verifica se o diretório de saída é criado.
        """
        # --- Configuração dos Mocks ---
        # 1. Simula que a pasta de saída não existe, para testar a criação
        mock_exists.return_value = False
        
        # 2. Simula os arquivos encontrados na pasta de entrada
        mock_listdir.return_value = ['curso_engenharia.txt', 'notas.md'] # Apenas .txt será processado

        # 3. Conteúdo de entrada que simula o arquivo .txt original
        conteudo_de_entrada = """
        Texto inicial que deve ser ignorado.

        Disciplina: Calculo 1
        Ementa: Estudo de limites.

        Disciplina: Fisica 1
        Ementa: Mecanica.
        """
        # Configura o mock_open para retornar nosso conteúdo fake quando for lido
        mock_file.return_value.read.return_value = conteudo_de_entrada

        # --- Execução da Função ---
        script_a_testar.preprocess_disciplines_txt_from_folder('pasta_entrada_fake', 'pasta_saida_fake')

        # --- Verificações (Asserts) ---
        
        # Verifica se a criação do diretório foi tentada corretamente
        mock_exists.assert_called_once_with('pasta_saida_fake')
        mock_makedirs.assert_called_once_with('pasta_saida_fake')

        # Verifica se o arquivo de entrada foi aberto para leitura
        mock_file.assert_any_call(os.path.join('pasta_entrada_fake', 'curso_engenharia.txt'), 'r', encoding='utf-8')
        
        # Verifica se o arquivo de saída foi aberto para escrita
        mock_file.assert_any_call(os.path.join('pasta_saida_fake', 'preprocessed_curso_engenharia.txt'), 'w', encoding='utf-8')

        # Verifica o conteúdo exato que foi escrito no arquivo de saída
        handle = mock_file()
        conteudo_escrito_esperado = (
            "Disciplina: Calculo 1; Ementa: Estudo de limites."
            "\n\n"  # Este é o record_delimiter padrão
            "Disciplina: Fisica 1; Ementa: Mecanica."
        )
        handle.write.assert_called_once_with(conteudo_escrito_esperado)

    @patch('os.path.exists', return_value=True) # Simula que a pasta já existe
    @patch('os.makedirs')
    @patch('os.listdir', return_value=['curso_letras.txt'])
    @patch('builtins.open', new_callable=mock_open)
    def test_delimitadores_customizados(self, mock_file, mock_listdir, mock_makedirs, mock_exists):
        """
        Testa se a função utiliza corretamente os delimitadores customizados.
        """
        conteudo_de_entrada = "Disciplina: Literatura\nEmenta: Seculo XIX."
        mock_file.return_value.read.return_value = conteudo_de_entrada

        # --- Execução com parâmetros customizados ---
        script_a_testar.preprocess_disciplines_txt_from_folder(
            'in_dir', 'out_dir',
            internal_field_separator=' | ',
            record_delimiter='\n#####\n'
        )

        # --- Verificações ---
        # Verifica se makedirs NÃO foi chamado, pois a pasta já existia
        mock_makedirs.assert_not_called()

        handle = mock_file()
        # O resultado final deve ser apenas uma linha, então o record_delimiter não é usado
        conteudo_escrito_esperado = "Disciplina: Literatura | Ementa: Seculo XIX."
        handle.write.assert_called_once_with(conteudo_escrito_esperado)

    @patch('os.path.exists', return_value=True)
    @patch('os.makedirs')
    @patch('os.listdir', return_value=['arquivo_sem_disciplina.txt'])
    @patch('builtins.open', mock_open(read_data='Apenas um texto qualquer sem o marcador.'))
    def test_arquivo_sem_disciplinas(self, mock_listdir, mock_makedirs, mock_exists):
        """
        Testa o comportamento da função quando o arquivo de entrada não contém o marcador "Disciplina:".
        """
        script_a_testar.preprocess_disciplines_txt_from_folder('in', 'out')

        # A única coisa que deve acontecer é a escrita de um arquivo de saída vazio.
        handle = mock_open()
        handle.assert_called_with(os.path.join('out', 'preprocessed_arquivo_sem_disciplina.txt'), 'w', encoding='utf-8')
        handle().write.assert_called_once_with('')