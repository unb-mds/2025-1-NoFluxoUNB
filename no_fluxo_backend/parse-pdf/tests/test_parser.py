import pytest
import os
from DBA.parse_pdf.pdf_parser_final import extrair_dados_academicos, limpar_nome_disciplina
import pypdf

# Obter o diretório do arquivo de teste
test_dir = os.path.dirname(os.path.abspath(__file__))

# Obter o diretório raiz do projeto (assumindo que a estrutura é '.../no_fluxo_backend/parse-pdf/tests')
project_root = os.path.abspath(os.path.join(test_dir, '..', '..', '..'))

# Caminho para o PDF de teste
pdf_path = os.path.join(project_root, 'test_historicos', 'historicos', 'historico_190012579 (5) (1).pdf')


def test_extrair_dados_academicos_com_pdf_real():
    """
    Testa a extração de dados de um PDF real.
    Verifica se a função retorna uma lista de disciplinas e o curso.
    """
    texto_total = ""
    try:
        with open(pdf_path, "rb") as pdf_file:
            leitor = pypdf.PdfReader(pdf_file)
            for pagina in leitor.pages:
                texto_total += pagina.extract_text() + "\n"
    except Exception as e:
        pytest.fail(f"Falha ao ler o PDF de teste: {e}")

    assert texto_total is not None and len(texto_total) > 0, "O texto extraído do PDF está vazio."

    curso, disciplinas = extrair_dados_academicos(texto_total)

    assert curso is not None, "O nome do curso não foi extraído."
    assert isinstance(disciplinas, list), "A função não retornou uma lista de disciplinas."
    assert len(disciplinas) > 0, "Nenhuma disciplina foi extraída do PDF."


def test_limpar_nome_disciplina():
    """
    Testa a função de limpeza de nome de disciplina.
    """
    assert limpar_nome_disciplina("2023.1 CÁLCULO 1") == "CÁLCULO 1"
    assert limpar_nome_disciplina("-- FÍSICA 2 --") == "FÍSICA 2"
    assert limpar_nome_disciplina("--- ALGORITMOS E ESTRUTURAS DE DADOS ---") == "ALGORITMOS E ESTRUTURAS DE DADOS"
    assert limpar_nome_disciplina("ENGENHARIA DE SOFTWARE") == "ENGENHARIA DE SOFTWARE"
    assert limpar_nome_disciplina("  COMPILADORES  ") == "COMPILADORES"
    assert limpar_nome_disciplina("REDES DE COMPUTADORES (PRÁTICA)") == "REDES DE COMPUTADORES (PRÁTICA)"