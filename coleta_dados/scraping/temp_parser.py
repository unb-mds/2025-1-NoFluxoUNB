from bs4 import BeautifulSoup
import re
import json
import requests

def verificar_pagina_curriculo():
    """Verifica se conseguimos acessar a página de currículo"""
    url = "https://sigaa.unb.br/sigaa/public/curso/curriculo.jsf"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    print(f"Tentando acessar: {url}")
    try:
        response = requests.get(url, headers=headers)
        print(f"Status code: {response.status_code}")
        print(f"Tamanho da resposta: {len(response.text)} bytes")
        
        # Salva o HTML para inspeção
        with open('debug_curriculo.html', 'w', encoding='utf-8') as f:
            f.write(response.text)
        print("HTML salvo em debug_curriculo.html")
        
        # Verifica se estamos na página correta
        soup = BeautifulSoup(response.text, 'html.parser')
        titulo = soup.find('title')
        if titulo:
            print(f"Título da página: {titulo.text}")
            
        # Verifica se encontramos elementos importantes
        tabela_principal = soup.find('table', {'class': 'formulario'})
        if tabela_principal:
            print("Tabela principal encontrada")
        else:
            print("Tabela principal NÃO encontrada")
            
        return response.text
    except Exception as e:
        print(f"Erro ao acessar a página: {e}")
        return None

def extract_dados_por_nivel(relatorio_html):
    """
    Extrai os dados do relatório HTML e organiza por nível e natureza (Obrigatória/Optativa).
    """
    soup = BeautifulSoup(relatorio_html, 'html.parser')
    niveis = []
    
    # Encontrar a tabela principal com a classe 'formulario'
    tabela_principal = soup.find('table', {'class': 'formulario'})
    if not tabela_principal:
        print("Tabela principal não encontrada")
        return niveis
        
    # Extrair informações do curso
    nome_curso = tabela_principal.find('th', text='Matriz Curricular:').find_next('td').text.strip()
    codigo_curso = tabela_principal.find('th', text='Código:').find_next('td').text.strip()
    
    print(f"Processando curso: {nome_curso} ({codigo_curso})")
    
    # Encontrar todas as tabelas que podem conter componentes
    tabelas = soup.find_all('table')
    print(f"Total de tabelas encontradas: {len(tabelas)}")
    
    for tabela in tabelas:
        # Verifica se é uma tabela de componentes
        titulo = tabela.find('tr', {'class': 'tituloRelatorio'})
        if not titulo:
            continue
            
        nivel = titulo.find('td').text.strip()
        print(f"\nEncontrado nível: {nivel}")
        
        # Encontra todas as linhas de componentes
        componentes = tabela.find_all('tr', {'class': 'componentes'})
        print(f"Encontrados {len(componentes)} componentes para o nível {nivel}")
        
        materias = []
        for comp in componentes:
            # Extrai código, nome e carga horária
            texto = comp.find('td').text.strip()
            print(f"Processando componente: {texto}")
            
            # Tenta diferentes padrões de regex
            padroes = [
                r'([A-Z]{3}\d{4}) - (.*?) - (\d+)h',  # Padrão padrão
                r'([A-Z]{3}\d{4})\s*-\s*(.*?)\s*-\s*(\d+)h',  # Com espaços extras
                r'([A-Z]{3}\d{4})\s*-\s*(.*?)\s*-\s*(\d+)\s*h',  # Com h separado
                r'([A-Z]{3}\d{4})\s*-\s*(.*?)\s*-\s*(\d+)\s*horas',  # Com "horas"
                r'([A-Z]{3}\d{4})\s*-\s*(.*?)\s*-\s*(\d+)\s*horas-aula'  # Com "horas-aula"
            ]
            
            match = None
            for padrao in padroes:
                match = re.match(padrao, texto)
                if match:
                    break
                    
            if not match:
                print(f"Não foi possível extrair dados do componente: {texto}")
                continue
                
            codigo_materia, nome_materia, carga_horaria = match.groups()
            
            # Extrai natureza (obrigatória/optativa)
            natureza = comp.find('i').text.strip() if comp.find('i') else 'Obrigatória'
            
            materias.append({
                'codigo': codigo_materia,
                'nome': nome_materia,
                'carga_horaria': int(carga_horaria)
            })
            
        if materias:
            niveis.append({
                'nivel': nivel,
                'natureza': 'Obrigatória' if 'Optativas' not in nivel else 'Optativa',
                'materias': materias
            })

    print(f"\nEncontrados {len(niveis)} níveis no relatório.")
    for nivel in niveis:
        print(f"- {nivel['nivel']} ({nivel['natureza']}): {len(nivel['materias'])} matérias")
    return niveis

# Teste a função
print("=== Iniciando verificação da página ===")
html = verificar_pagina_curriculo()
if html:
    print("\n=== Iniciando extração dos dados ===")
    dados = extract_dados_por_nivel(html)
    print("\n=== Resultado da extração ===")
    print(json.dumps(dados, indent=2, ensure_ascii=False)) 