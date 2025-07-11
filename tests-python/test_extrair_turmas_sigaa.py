import unittest
from unittest.mock import patch, MagicMock, mock_open
import sys
import os
from bs4 import BeautifulSoup

# --- Adiciona o diretório raiz ao path para que a importação funcione ---
# Isso é necessário para que o Python encontre o módulo 'coleta_dados'
# ao executar os testes a partir do diretório raiz.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
# --------------------------------------------------------------------------

# Importa as funções do script que queremos testar
from coleta_dados.scraping import extrair_turmas_sigaa as scraper

class TestHelperFunctions(unittest.TestCase):
    """Testa as funções auxiliares de limpeza de texto."""

    def test_remover_acentos(self):
        """Testa se os acentos são removidos corretamente."""
        self.assertEqual(scraper._remover_acentos("Olá, como vai você? CÉDULA"), "Ola, como vai voce? CEDULA")
        self.assertEqual(scraper._remover_acentos("Engenharia de Computação"), "Engenharia de Computacao")
        self.assertEqual(scraper._remover_acentos("Texto sem acentos"), "Texto sem acentos")
        self.assertEqual(scraper._remover_acentos(""), "")
        self.assertEqual(scraper._remover_acentos(123), 123) # Deve retornar o valor original se não for string

    def test_limpar_texto(self):
        """Testa a limpeza geral do texto (espaços, acentos)."""
        self.assertEqual(scraper.limpar_texto("  Olá,   Mundo!  \n"), "Ola, Mundo!")
        self.assertEqual(scraper.limpar_texto("Cálculo 1  "), "Calculo 1")
        self.assertEqual(scraper.limpar_texto(None), None) # Deve lidar com valores não-string


class TestDataExtraction(unittest.TestCase):
    """Testa as funções de extração de dados do HTML."""

    def test_extrair_equivalencias(self):
        """Testa a extração de equivalências de um HTML simulado."""
        html = """
        <td>
            <acronym title="FGA0001 - COMPUTAÇÃO BÁSICA">FGA0001</acronym>
            <acronym title="FGA0002 - ALGORITMOS E ESTRUTURAS DE DADOS">FGA0002</acronym>
        </td>
        """
        soup = BeautifulSoup(html, "html.parser")
        cells = soup.find_all("td")
        
        # A função espera uma lista de células [th, td]
        # O 'th' pode ser um mock simples, pois não é usado na lógica de extração.
        mock_th = BeautifulSoup("<th>Equivalências:</th>", "html.parser").th
        
        resultado = scraper.extrair_equivalencias([mock_th, cells[0]])
        self.assertEqual(resultado, "FGA0001 (COMPUTACAO BASICA), FGA0002 (ALGORITMOS E ESTRUTURAS DE DADOS)")

    def test_extrair_equivalencias_sem_equivalencias(self):
        """Testa o caso em que não há equivalências."""
        html = "<td>Nenhuma</td>"
        soup = BeautifulSoup(html, "html.parser")
        cells = soup.find_all("td")
        mock_th = BeautifulSoup("<th>Equivalências:</th>", "html.parser").th
        
        resultado = scraper.extrair_equivalencias([mock_th, cells[0]])
        self.assertEqual(resultado, "Nenhuma")

    @patch('coleta_dados.scraping.extrair_turmas_sigaa.extrair_equivalencias')
    def test_coleta_dados(self, mock_extrair_equivalencias):
        """Testa a função 'coleta_dados' simulando uma resposta POST."""
        # Configura o mock da função de equivalências
        mock_extrair_equivalencias.return_value = "FGA0001 (COMPUTACAO BASICA)"

        # HTML simulado que seria retornado pelo POST
        mock_html_details = """
        <html><body>
            <table class="visualizacao">
                <tr><th>Código:</th><td>CIC0007</td></tr>
                <tr><th>Nome:</th><td>ESTRUTURA DE DADOS</td></tr>
                <tr><th>Unidade Responsável:</th><td>FACULDADE DO GAMA - FGA</td></tr>
                <tr><th>Ementa:</th><td>Conteúdo da ementa aqui.</td></tr>
                <tr><th>Equivalências:</th><td>...</td></tr>
            </table>
        </body></html>
        """
        # Mock da sessão e da resposta
        mock_session = MagicMock()
        mock_response = MagicMock()
        mock_response.text = mock_html_details
        mock_session.post.return_value = mock_response

        # Chama a função a ser testada
        dados = scraper.coleta_dados(mock_session, '12345', 'viewstate_xyz', 'http://fake.url', {})

        # Verifica se o POST foi chamado
        mock_session.post.assert_called_once()
        
        # Verifica se o resultado está correto e sem acentos
        self.assertEqual(dados['unidade_responsavel'], "FACULDADE DO GAMA ")
        self.assertEqual(dados['ementa'], "Conteudo da ementa aqui.")
        # Verificamos se a função de equivalências foi chamada pela coleta_dados
        mock_extrair_equivalencias.assert_called_once()


class TestMainProcess(unittest.TestCase):
    """
    Testa as funções principais do processo de scraping,
    simulando chamadas de rede e I/O de arquivos.
    """

    def setUp(self):
        """Configura mocks que serão usados em vários testes."""
        # HTML simulado da página de busca inicial
        self.mock_html_initial = """
        <html><body>
            <form id="formTurma">
                <input name="javax.faces.ViewState" value="initial_viewstate" />
                <input type="submit" value="Buscar" id="formTurma:buscar" />
            </form>
        </body></html>
        """
        # HTML simulado da página de resultados da busca
        self.mock_html_results = """
        <html><body>
            <input name="javax.faces.ViewState" value="results_viewstate" />
            <table class="listagem">
                <tr class="agrupador">
                    <td>
                        <a onclick="jsf.util.chain(this,event,{'id':'12345'},'rich-jsf-function');">
                            <span class="tituloDisciplina">CIC0007 - ESTRUTURA DE DADOS</span>
                        </a>
                    </td>
                </tr>
                <tr>
                    <td></td><td>CIC0007 - ESTRUTURA DE DADOS</td><td>T01</td>
                    <td>24T34</td><td>SALA A1</td><td>PROFESSOR X</td>
                </tr>
            </table>
        </body></html>
        """

    @patch('requests.Session')
    @patch('coleta_dados.scraping.extrair_turmas_sigaa.coleta_dados')
    def test_processar_departamento_com_sucesso(self, mock_coleta_dados, mock_Session):
        """Testa o processamento de um departamento que retorna turmas."""
        # Configura o retorno da função 'coleta_dados'
        mock_coleta_dados.return_value = {
            "unidade_responsavel": "FACULDADE DO GAMA ",
            "ementa": "Ementa da disciplina."
        }
        
        # Configura o mock da sessão e suas respostas
        mock_session_instance = MagicMock()
        mock_get_response = MagicMock(status_code=200, text=self.mock_html_initial)
        mock_post_response = MagicMock(status_code=200, text=self.mock_html_results)
        
        # A primeira chamada (GET) retorna a página inicial, as seguintes (POST) retornam os resultados
        mock_session_instance.get.return_value = mock_get_response
        mock_session_instance.post.return_value = mock_post_response
        mock_Session.return_value = mock_session_instance

        # Chama a função
        resultado = scraper.processar_departamento(id_atual=650)

        # Verifica os resultados
        self.assertEqual(resultado['departamento_id'], 650)
        self.assertEqual(len(resultado['turmas']), 1)
        turma = resultado['turmas'][0]
        self.assertEqual(turma['disciplina'], " ESTRUTURA DE DADOS")
        self.assertEqual(turma['codigo'], "CIC0007 ")
        self.assertEqual(turma['ementa'], "Ementa da disciplina.")

        # Verifica se 'coleta_dados' foi chamada com os parâmetros corretos
        mock_coleta_dados.assert_called_once_with(
            mock_session_instance, '12345', 'results_viewstate', 
            "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf", 
            {'id': '12345'}
        )

    @patch("builtins.open", new_callable=mock_open, read_data="id\n650\n651")
    def test_carregar_ids_departamentos(self, mock_file):
        """Testa o carregamento de IDs de um arquivo CSV simulado."""
        ids = scraper.carregar_ids_departamentos()
        mock_file.assert_called_with('dados/departamentos_ID_unb.csv', 'r', encoding='utf-8')
        self.assertEqual(ids, [650, 651])

    @patch("builtins.open")
    @patch("json.dump")
    @patch("os.path.join")
    @patch("pathlib.Path.mkdir")
    def test_salvar_por_departamento(self, mock_mkdir, mock_join, mock_json_dump, mock_open_file):
        """Testa se a função de salvar por departamento funciona como esperado."""
        resultados = [
            {"departamento_id": 650, "turmas": [{"codigo": "CIC0001"}]},
            {"departamento_id": 651, "turmas": []} # Departamento sem turmas não deve ser salvo
        ]
        
        # Configura o mock_join para retornar um caminho de arquivo falso
        mock_join.return_value = "fake_dir/turmas_depto_650.json"
        
        scraper.OUTPUT_DIR = "fake_dir"
        scraper.salvar_por_departamento(resultados)

        # Verifica se a criação de diretório foi chamada
        mock_mkdir.assert_called_once()
        
        # Verifica se 'open' e 'json.dump' foram chamados apenas uma vez (para o depto com turmas)
        mock_open_file.assert_called_once_with("fake_dir/turmas_depto_650.json", 'w', encoding='utf-8')
        mock_json_dump.assert_called_once()
        # Verifica se o conteúdo correto foi passado para o json.dump
        self.assertEqual(mock_json_dump.call_args[0][0], [{"codigo": "CIC0001"}])


if __name__ == '__main__':
    # Adicionamos um argumento fake ao sys.argv, pois o script original espera
    # um nome de pasta como argumento de linha de comando.
    sys.argv.append('output_test_folder')
    unittest.main(argv=['first-arg-is-ignored'], exit=False)