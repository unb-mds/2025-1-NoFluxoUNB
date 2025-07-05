import unittest
from unittest.mock import patch, MagicMock
import os
import datetime
import sys
from coleta_dados.scraping import executar_fluxo_dados_RAGFLOW

# Adiciona o diretório pai ao sys.path para que o módulo possa ser importado
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

import coleta_dados.scraping.executar_fluxo_dados_RAGFLOW

class TestExecutarFluxoDadosRAGFLOW(unittest.TestCase):

    @patch("executar_fluxo_dados_RAGFLOW.datetime")
    def test_gerar_nomes_pastas_primeiro_semestre(self, mock_datetime):
        mock_datetime.date.today.return_value = datetime.date(2025, 3, 15) # Março, primeiro semestre

        nomes_pastas = executar_fluxo_dados_RAGFLOW.gerar_nomes_pastas()
        self.assertEqual(nomes_pastas["dados_finais"], "dados/dados_finais_2025_1")
        self.assertEqual(nomes_pastas["chunks"], "dados/chunks_finais_2025_1")
        self.assertEqual(nomes_pastas["formatados"], "dados/chunks_finais_formatados_2025_1")

    @patch("executar_fluxo_dados_RAGFLOW.datetime")
    def test_gerar_nomes_pastas_segundo_semestre(self, mock_datetime):
        mock_datetime.date.today.return_value = datetime.date(2025, 9, 10) # Setembro, segundo semestre

        nomes_pastas = executar_fluxo_dados_RAGFLOW.gerar_nomes_pastas()
        self.assertEqual(nomes_pastas["dados_finais"], "dados/dados_finais_2025_2")
        self.assertEqual(nomes_pastas["chunks"], "dados/chunks_finais_2025_2")
        self.assertEqual(nomes_pastas["formatados"], "dados/chunks_finais_formatados_2025_2")

    @patch("subprocess.run")
    def test_executar_script_sucesso(self, mock_subprocess_run):
        mock_subprocess_run.return_value = MagicMock(stdout="Saída de teste", stderr="", returncode=0)
        
        resultado = executar_fluxo_dados_RAGFLOW.executar_script(["python", "script_teste.py"])
        self.assertTrue(resultado)
        mock_subprocess_run.assert_called_once()

    @patch("subprocess.run")
    def test_executar_script_erro_arquivo_nao_encontrado(self, mock_subprocess_run):
        mock_subprocess_run.side_effect = FileNotFoundError
        
        resultado = executar_fluxo_dados_RAGFLOW.executar_script(["python", "script_inexistente.py"])
        self.assertFalse(resultado)
        mock_subprocess_run.assert_called_once()

    @patch("subprocess.run")
    def test_executar_script_erro_execucao(self, mock_subprocess_run):
        mock_subprocess_run.side_effect = executar_fluxo_dados_RAGFLOW.subprocess.CalledProcessError(1, "cmd", stderr="Erro de execução")
        
        resultado = executar_fluxo_dados_RAGFLOW.executar_script(["python", "script_com_erro.py"])
        self.assertFalse(resultado)
        mock_subprocess_run.assert_called_once()

    @patch("subprocess.run")
    def test_executar_script_erro_inesperado(self, mock_subprocess_run):
        mock_subprocess_run.side_effect = Exception("Erro genérico")
        
        resultado = executar_fluxo_dados_RAGFLOW.executar_script(["python", "script_generico.py"])
        self.assertFalse(resultado)
        mock_subprocess_run.assert_called_once()

if __name__ == "__main__":
    unittest.main()

