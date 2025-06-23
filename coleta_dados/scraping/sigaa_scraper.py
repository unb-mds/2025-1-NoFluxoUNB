from bs4 import BeautifulSoup
import re

def extrair_dados_curriculo(html):
    """Extrai os dados da estrutura curricular do HTML"""
    soup = BeautifulSoup(html, 'html.parser')
    
    # Encontra a tabela de estrutura curricular
    tabela = soup.find('table', {'class': 'formulario'})
    if not tabela:
        return None
        
    # Extrai informações do curso
    codigo = tabela.find('th', text='Código:').find_next('td').text.strip()
    nome_curso = tabela.find('th', text='Matriz Curricular:').find_next('td').text.strip()
    
    # Encontra todas as tabelas de componentes
    tabelas_componentes = soup.find_all('table', {'style': 'width: 100%'})
    
    dados = {
        'curso': nome_curso,
        'codigo': codigo,
        'niveis': []
    }
    
    for tabela in tabelas_componentes:
        # Verifica se é uma tabela de componentes
        titulo = tabela.find('tr', {'class': 'tituloRelatorio'})
        if not titulo:
            continue
            
        nivel = titulo.find('td').text.strip()
        
        # Encontra todas as linhas de componentes
        componentes = tabela.find_all('tr', {'class': 'componentes'})
        
        for comp in componentes:
            # Extrai código, nome e carga horária
            texto = comp.find('td').text.strip()
            match = re.match(r'([A-Z]{3}\d{4}) - (.*?) - (\d+)h', texto)
            if not match:
                continue
                
            codigo_materia, nome_materia, carga_horaria = match.groups()
            
            # Extrai natureza (obrigatória/optativa)
            natureza = comp.find('i').text.strip() if comp.find('i') else 'Obrigatória'
            
            # Adiciona ao nível correspondente
            nivel_existente = next((n for n in dados['niveis'] if n['nivel'] == nivel), None)
            if not nivel_existente:
                nivel_existente = {
                    'nivel': nivel,
                    'natureza': natureza,
                    'materias': []
                }
                dados['niveis'].append(nivel_existente)
                
            nivel_existente['materias'].append({
                'codigo': codigo_materia,
                'nome': nome_materia,
                'carga_horaria': int(carga_horaria)
            })
    
    return dados 