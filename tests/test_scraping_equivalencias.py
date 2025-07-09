import re
import unicodedata
import unittest          # <--- padrão Python vem antes
from bs4 import BeautifulSoup  # <--- depois os pacotes externos


def _remover_acentos(texto_com_acento):
    if not isinstance(texto_com_acento, str):
        return texto_com_acento
    nfkd_form = unicodedata.normalize('NFKD', texto_com_acento)
    return "".join([c for c in nfkd_form if not unicodedata.combining(c)])

def limpar_texto(texto):
    if isinstance(texto, str):
        texto = re.sub(r'\s+', ' ', texto)
        return texto.strip()
    return texto

def extrair_equivalencias(cells):
    equivalencias = []
    for ac in cells[1].find_all("acronym"):
        codigo = ac.get_text(strip=True)
        descricao = ac.get("title", "").split(" - ")[-1]
        equivalencias.append(f"{codigo} ({descricao})")
    return ", ".join(equivalencias) if equivalencias else "Nenhuma"

class TestScraperUtils(unittest.TestCase):
    def test_remover_acentos(self):
        self.assertEqual(_remover_acentos("ação"), "acao")
        self.assertEqual(_remover_acentos("café"), "cafe")
        self.assertEqual(_remover_acentos("São João"), "Sao Joao")
        self.assertEqual(_remover_acentos(None), None)
        self.assertEqual(_remover_acentos(123), 123)

    def test_limpar_texto(self):
        self.assertEqual(limpar_texto("   Olá    mundo!  "), "Olá mundo!")
        self.assertEqual(limpar_texto("\nTexto\ncom\nquebra"), "Texto com quebra")
        self.assertEqual(limpar_texto(None), None)

    def test_extrair_equivalencias(self):
        html = """
        <td></td>
        <td>
            <acronym title="MAT123 - Matemática Básica">MAT123</acronym>
            <acronym title="FIS456 - Física Geral">FIS456</acronym>
        </td>
        """
        soup = BeautifulSoup(html, "html.parser")
        cells = soup.find_all("td")
        resultado = extrair_equivalencias(cells)
        self.assertIn("MAT123 (Matemática Básica)", resultado)
        self.assertIn("FIS456 (Física Geral)", resultado)

if __name__ == '__main__':
    unittest.main()
