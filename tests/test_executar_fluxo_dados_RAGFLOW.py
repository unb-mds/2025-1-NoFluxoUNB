import unittest
import os
import sys
import subprocess
import datetime
from unittest.mock import patch, MagicMock

# Importar as funções do script principal
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))
from executar_fluxo_dados_RAGFLOW import gerar_nomes_pastas, executar_script

class TestExecutarFluxoDadosRAGFLOW(unittest.TestCase):

    @patch("datetime.date")
    def test_gerar_nomes_pastas_primeiro_semestre(self, mock_date):
        mock_date.today.return_value = MagicMock(month=3, year=2025, day=15) # Março, primeiro semestre
        nomes_pastas = gerar_nomes_pastas()
        self.assertEqual(nomes_pastas["dados_finais"], "coleta_dados/dados/dados_finais_2025_1")
        self.assertEqual(nomes_pastas["chunks"], "coleta_dados/dados/chunks_finais_2025_1")
        self.assertEqual(nomes_pastas["formatados"], "coleta_dados/dados/chunks_finais_formatados_2025_1")

    @patch("datetime.date")
    def test_gerar_nomes_pastas_segundo_semestre(self, mock_date):
        mock_date.today.return_value = MagicMock(month=9, year=2025, day=20) # Setembro, segundo semestre
        nomes_pastas = gerar_nomes_pastas()
        self.assertEqual(nomes_pastas["dados_finais"], "coleta_dados/dados/dados_finais_2025_2")
        self.assertEqual(nomes_pastas["chunks"], "coleta_dados/dados/chunks_finais_2025_2")
        self.assertEqual(nomes_pastas["formatados"], "coleta_dados/dados/chunks_finais_formatados_2025_2")

    @patch("subprocess.run")
    def test_executar_script_sucesso(self, mock_subprocess_run):
        mock_subprocess_run.return_value = MagicMock(stdout="Saída de teste", stderr="")
        argumentos = ["python", "dummy_script.py", "arg1", "arg2"]
        resultado = executar_script(argumentos)
        self.assertTrue(resultado)
        mock_subprocess_run.assert_called_once_with(
            argumentos, check=True, capture_output=True, text=True, encoding="utf-8", env=unittest.mock.ANY
        )

    @patch("subprocess.run", side_effect=FileNotFoundError)
    def test_executar_script_file_not_found(self, mock_subprocess_run):
        argumentos = ["python", "non_existent_script.py"]
        resultado = executar_script(argumentos)
        self.assertFalse(resultado)

    @patch("subprocess.run", side_effect=subprocess.CalledProcessError(returncode=1, cmd="test", stderr="Erro de processo"))
    def test_executar_script_called_process_error(self, mock_subprocess_run):
        argumentos = ["python", "error_script.py"]
        resultado = executar_script(argumentos)
        self.assertFalse(resultado)

    @patch("subprocess.run", side_effect=Exception("Erro genérico"))
    def test_executar_script_generic_exception(self, mock_subprocess_run):
        argumentos = ["python", "generic_error_script.py"]
        resultado = executar_script(argumentos)
        self.assertFalse(resultado)

if __name__ == "__main__":
    unittest.main()

