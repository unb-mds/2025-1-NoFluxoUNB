import urllib.request
import urllib.parse
from html.parser import HTMLParser
import json
import time
import pandas as pd
import re

class CursoParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.current_row = []
        self.rows = []
        self.viewstate = None
        
    def handle_starttag(self, tag, attrs):
        if tag == 'table' and ('class', 'listagem') in attrs:
            self.in_table = True
        elif tag == 'tr' and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag == 'td' and self.in_row:
            self.in_cell = True
        elif tag == 'input' and ('name', 'javax.faces.ViewState') in attrs:
            for attr, value in attrs:
                if attr == 'value':
                    self.viewstate = value
    
    def handle_endtag(self, tag):
        if tag == 'table' and self.in_table:
            self.in_table = False
        elif tag == 'tr' and self.in_row:
            self.in_row = False
            if self.current_row:
                self.rows.append(self.current_row)
        elif tag == 'td' and self.in_cell:
            self.in_cell = False
    
    def handle_data(self, data):
        if self.in_cell:
            self.current_row.append(data.strip())

def scrape_cursos():
    # URL base
    base_url = "https://sigaa.unb.br/sigaa/public/curso/lista.jsf?nivel=G&aba=p-graduacao"
    
    # Carregar cursos do JSON
    with open('dados/cursos-de-graduacao.json', 'r', encoding='utf-8') as f:
        cursos = json.load(f)
    
    # Criar lista para armazenar resultados
    resultados = []
    
    # Headers para simular um navegador
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    # Fazer requisição inicial para obter cookies e viewstate
    req = urllib.request.Request(base_url, headers=headers)
    response = urllib.request.urlopen(req)
    html = response.read().decode('utf-8')
    
    # Parsear HTML inicial
    parser = CursoParser()
    parser.feed(html)
    viewstate = parser.viewstate
    
    # Para cada curso
    for curso in cursos:
        nome_curso = curso['nome']
        print(f"Processando curso: {nome_curso}")
        
        # Preparar dados do formulário
        form_data = {
            'form': 'form',
            'form:inputNome': nome_curso,
            'form:inputModalidade': '',
            'form:j_id_jsp_1370969402_11': 'Buscar',
            'javax.faces.ViewState': viewstate
        }
        
        # Codificar dados do formulário
        data = urllib.parse.urlencode(form_data).encode('utf-8')
        
        # Enviar requisição de busca
        req = urllib.request.Request(base_url, data=data, headers=headers)
        response = urllib.request.urlopen(req)
        html = response.read().decode('utf-8')
        
        # Parsear HTML da resposta
        parser = CursoParser()
        parser.feed(html)
        viewstate = parser.viewstate
        
        # Processar resultados
        for row in parser.rows:
            if len(row) >= 6 and 'ATIVA' in ' '.join(row):
                info_curso = {
                    'nome': nome_curso,
                    'grau': row[1],
                    'turno': row[2],
                    'sede': row[3],
                    'modalidade': row[4],
                    'coordenador': row[5],
                    'situacao': 'ATIVA'
                }
                resultados.append(info_curso)
        
        # Esperar um pouco para não sobrecarregar o servidor
        time.sleep(1)
    
    # Converter resultados para DataFrame
    df = pd.DataFrame(resultados)
    
    # Salvar resultados
    df.to_csv('dados/cursos_ativos.csv', index=False, encoding='utf-8-sig')
    print("Scraping concluído! Resultados salvos em 'dados/cursos_ativos.csv'")

if __name__ == "__main__":
    scrape_cursos() 