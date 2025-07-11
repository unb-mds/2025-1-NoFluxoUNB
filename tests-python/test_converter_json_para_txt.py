import unittest
import json
from unittest.mock import patch, mock_open

# Adiciona o diretório raiz ao path para que a importação funcione
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Importa o módulo que queremos testar
from coleta_dados.scraping import converter_json_para_txt as converter

class TestFormatadorDeTurma(unittest.TestCase):
    """
    Testes para a função 'formatar_turma', que é o coração da lógica de formatação.
    """

    def setUp(self):
        """
        Define os campos esperados antes de cada teste para garantir consistência.
        """
        converter.campos = ["disciplina", "codigo", "ementa"]

    def test_formatacao_com_dados_completos(self):
        """
        Testa a formatação com um dicionário que contém todos os campos.
        """
        turma = {
            "disciplina": "Calculo 1",
            "codigo": "MAT101",
            "ementa": "Ementa sobre limites e derivadas."
        }
        resultado_esperado = "Calculo 1 Mat101 Ementa sobre limites e derivadas."
        self.assertEqual(converter.formatar_turma(turma), resultado_esperado)

    def test_formatacao_com_dados_faltando(self):
        """
        Testa se a função lida bem com campos ausentes no dicionário.
        """
        turma = {
            "disciplina": "Fisica Basica",
            "ementa": "Mecanica classica."
            # O campo "codigo" está faltando
        }
        # Espera-se que o campo ausente seja ignorado na junção
        resultado_esperado = "Fisica basica  Mecanica classica."
        self.assertEqual(converter.formatar_turma(turma), resultado_esperado)

    def test_formatacao_com_aspas_simples(self):
        """
        Testa se a função substitui corretamente aspas simples por espaços.
        """
        turma = {
            "disciplina": "Introdução à Lógica",
            "codigo": "FIL001",
            "ementa": "O'que é lógica?" # Aspas simples para ser substituída
        }
        resultado_esperado = "Introdução à lógica Fil001 O que é lógica?"
        self.assertEqual(converter.formatar_turma(turma), resultado_esperado)
    
    def test_formatacao_com_dicionario_vazio(self):
        """
        Testa a formatação com um dicionário vazio.
        """
        turma = {}
        # Espera-se 3 espaços, um para cada campo esperado que não foi encontrado
        resultado_esperado = "  "
        self.assertEqual(converter.formatar_turma(turma), resultado_esperado)


class TestProcessoPrincipal(unittest.TestCase):
    """
    Testes para a função 'main', simulando o sistema de arquivos e argumentos.
    """

    @patch('sys.argv', ['converter_json_para_txt.py', 'pasta_entrada_fake', 'pasta_saida_fake'])
    @patch('os.makedirs')
    @patch('os.listdir')
    @patch('builtins.open', new_callable=mock_open)
    @patch('json.load')
    def test_main_executa_corretamente(self, mock_json_load, mock_file_open, mock_listdir, mock_makedirs):
        """
        Testa o fluxo completo da função main, simulando leitura e escrita de arquivos.
        """
        # --- Configuração dos Mocks ---
        
        # 1. Simula os arquivos que seriam encontrados no diretório de entrada
        mock_listdir.return_value = ['disciplinas_fga.json', 'documento.txt']

        # 2. Simula o conteúdo que será "lido" do arquivo JSON
        dados_json_fake = [
            {"disciplina": "APC", "codigo": "FGA001", "unidade responsavel": "Engenharias", "ementa": "Algoritmos."},
            {"disciplina": "DIAC", "codigo": "FGA002", "unidade responsavel": "Engenharias", "ementa": "Circuitos."}
        ]
        mock_json_load.return_value = dados_json_fake

        # --- Execução da Função ---
        converter.main()

        # --- Verificações (Asserts) ---

        # Verifica se a criação do diretório de saída foi chamada
        mock_makedirs.assert_called_once_with('pasta_saida_fake', exist_ok=True)

        # Verifica se o diretório de entrada foi listado
        mock_listdir.assert_called_once_with('pasta_entrada_fake')
        
        # Verifica se o arquivo JSON foi aberto para leitura
        # A primeira chamada a open() deve ser para ler o JSON
        call_leitura = mock_file_open.call_args_list[0]
        self.assertEqual(call_leitura.args[0], os.path.join('pasta_entrada_fake', 'disciplinas_fga.json'))
        self.assertEqual(call_leitura.kwargs['encoding'], 'utf-8')

        # Verifica se o arquivo TXT foi aberto para escrita
        # A segunda chamada a open() deve ser para escrever o TXT
        call_escrita = mock_file_open.call_args_list[1]
        self.assertEqual(call_escrita.args[0], os.path.join('pasta_saida_fake', 'disciplinas_fga.txt'))
        self.assertEqual(call_escrita.kwargs['mode'], 'w')

        # Verifica o conteúdo que foi escrito no arquivo de saída
        handle = mock_file_open()
        conteudo_esperado = (
            "Apc Fga001 Engenharias Algoritmos.\n\n"
            "Diac Fga002 Engenharias Circuitos."
        )
        handle.write.assert_called_once_with(conteudo_esperado)

