import unittest
from io import BytesIO
from coleta_dados.parse_pdf.pdf_parser_final import app  # Ajuste o caminho conforme seu projeto

class PdfUploadTestCase(unittest.TestCase):

    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_upload_pdf_success(self):
        # Abra o arquivo PDF para o teste (coloque seu arquivo PDF na pasta tests/)
        with open('tests/historico_corrigido.pdf', 'rb') as pdf_file:
            data = {
                'pdf': (pdf_file, 'historico_corrigido.pdf')
            }
            response = self.app.post('/upload-pdf', data=data, content_type='multipart/form-data')
            self.assertEqual(response.status_code, 200)
            json_data = response.get_json()
            print(json_data)  # só para ver o retorno, pode remover depois
            self.assertIn('extracted_data', json_data)

    def test_upload_pdf_no_file(self):
        response = self.app.post('/upload-pdf', data={})
        self.assertEqual(response.status_code, 400)
        json_data = response.get_json()
        self.assertIn('error', json_data)
        self.assertEqual(json_data['error'], 'Nenhum arquivo PDF enviado.')

if __name__ == '__main__':
    unittest.main()
