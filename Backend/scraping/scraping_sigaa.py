import requests
from bs4 import BeautifulSoup
import json
import time
import re
import os

def get_discipline_details(session, discipline_id):
    """
    Busca a ementa de uma disciplina a partir de seu ID.
    
    Args:
        session: Sessão HTTP ativa
        discipline_id: ID da disciplina
    
    Returns:
        Dicionário com a ementa da disciplina
    """
    # URL base é a página de componentes
    base_url = "https://sigaa.unb.br/sigaa/public/componentes/busca_componentes.jsf"
    
    # Obter a página atual para extrair o ViewState
    try:
        response = session.get(base_url)
        soup = BeautifulSoup(response.text, 'html.parser')
        view_state = soup.find('input', {'name': 'javax.faces.ViewState'})['value']
        
        # Parâmetros para a requisição POST que simula o clique no link de detalhes
        data = {
            'formListagemComponentes': 'formListagemComponentes',
            'id': discipline_id,
            'publico': 'public',
            'javax.faces.ViewState': view_state
        }
        
        # Adicionar o parâmetro de ação correto
        link_id = None
        form = soup.find('form', {'id': 'formListagemComponentes'})
        if form:
            detail_links = form.find_all('a', {'title': 'Detalhes do Componente Curricular'})
            if detail_links and len(detail_links) > 0:
                onclick = detail_links[0].get('onclick', '')
                match = re.search(r"'(formListagemComponentes:[^']+)'", onclick)
                if match:
                    link_id = match.group(1)
        
        if link_id:
            data[link_id] = link_id
        else:
            # Fallback para o ID que funcionou antes
            data['formListagemComponentes:j_id_jsp_190531263_23'] = 'formListagemComponentes:j_id_jsp_190531263_23'
        
        # Fazer o POST para acessar os detalhes da disciplina
        response = session.post(base_url, data=data)
        response.raise_for_status()
        
        # Analisar a página de detalhes
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Inicializar dicionário para armazenar os detalhes
        details = {
            'ementa': ''
        }
        
        # Buscar a ementa - usando seletor mais flexível
        ementa_row = soup.find(lambda tag: tag.name == 'th' and 'Ementa' in tag.text)
        if ementa_row:
            next_td = ementa_row.find_next('td')
            if next_td:
                details['ementa'] = next_td.text.strip()
        
        return details
    
    except Exception as e:
        print(f"Erro ao processar disciplina ID {discipline_id}: {e}")
        return {'ementa': ''}

def get_department_disciplines(session, unidade_id, unidade_nome):
    """
    Busca todas as disciplinas de um departamento específico.
    Função separada para melhor gestão de sessão e estado.
    """
    url = "https://sigaa.unb.br/sigaa/public/componentes/busca_componentes.jsf"
    disciplines = []
    
    try:
        # Obter uma página nova para cada departamento
        response = session.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Extrair ViewState fresco para esta unidade
        view_state = soup.find('input', {'name': 'javax.faces.ViewState'})['value']
        
        # Parâmetros para a requisição POST
        data = {
            'form': 'form',
            'form:nivel': 'G',  # GRADUAÇÃO
            'form:checkTipo': 'on',
            'form:tipo': '2',   # DISCIPLINA
            'form:checkUnidade': 'on',
            'form:unidades': unidade_id,
            'form:btnBuscarComponentes': 'Buscar Componentes',
            'javax.faces.ViewState': view_state
        }
        
        # Fazer o POST para buscar disciplinas da unidade
        response = session.post(url, data=data)
        response.raise_for_status()
        
        result_soup = BeautifulSoup(response.text, 'html.parser')
        
        # Extrair as disciplinas da página de resultados
        rows = result_soup.select('tr.linhaPar, tr.linhaImpar')
        print(f"  Encontradas {len(rows)} disciplinas")
        
        if len(rows) == 0:
            # Para debugging - salvar a página quando não encontra disciplinas
            with open(f'debug_unidade_{unidade_id}.html', 'w', encoding='utf-8') as f:
                f.write(response.text)
            print(f"  Aviso: Página HTML salva para debug em debug_unidade_{unidade_id}.html")
        
        for row in rows:
            cols = row.find_all('td')
            if len(cols) >= 5:  # Verificar se tem colunas suficientes
                
                # Extrair ID da disciplina do onclick
                discipline_id = None
                link_element = cols[4].find('a', title='Detalhes do Componente Curricular')
                
                if link_element and 'onclick' in link_element.attrs:
                    onclick = link_element['onclick']
                    id_match = re.search(r"'id':'(\d+)'", onclick)
                    if id_match:
                        discipline_id = id_match.group(1)
                
                disciplina = {
                    "codigo": cols[0].text.strip(),
                    "nome": cols[1].text.strip(),
                    "tipo": cols[2].text.strip(),
                    "ch_total": cols[3].text.strip(),
                    "unidade": unidade_nome,
                    "id": discipline_id,
                    "ementa": ""
                }
                
                # Se encontrou o ID, buscar a ementa
                if discipline_id:
                    print(f"  Obtendo ementa de: {disciplina['codigo']} - {disciplina['nome']}")
                    
                    # Buscar detalhes da disciplina
                    details = get_discipline_details(session, discipline_id)
                    
                    if details and details['ementa']:
                        disciplina['ementa'] = details['ementa']
                        print(f"    Ementa: {details['ementa'][:30]}...")
                    else:
                        print("    Ementa: Não encontrada")
                    
                    # Pausa para não sobrecarregar o servidor
                    time.sleep(1)
                
                disciplines.append(disciplina)
        
        return disciplines
        
    except Exception as e:
        print(f"Erro ao processar unidade {unidade_nome}: {e}")
        return []

def get_all_disciplines():
    url = "https://sigaa.unb.br/sigaa/public/componentes/busca_componentes.jsf"
    
    # Lista para armazenar todas as disciplinas
    all_disciplines = []
    
    # Obter a lista de unidades acadêmicas
    session = requests.Session()
    session.timeout = 30
    
    try:
        response = session.get(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Extrair as unidades acadêmicas
        unidades = soup.select('#form\\:unidades option')
        
        # Remover a opção "-- SELECIONE UMA UNIDADE ACADÊMICA --"
        unidades = [u for u in unidades if u['value'] != '0']
        
        # Para testes, usar apenas algumas unidades
        # unidades = unidades[:3]
        
        # Processar cada unidade acadêmica individualmente
        for unidade in unidades:
            unidade_id = unidade['value']
            unidade_nome = unidade.text
            
            print(f"Buscando disciplinas de: {unidade_nome}")
            
            # Criar uma nova sessão para cada unidade para evitar problemas de estado
            department_session = requests.Session()
            department_session.timeout = 30
            
            # Processar o departamento e obter suas disciplinas
            disciplines = get_department_disciplines(department_session, unidade_id, unidade_nome)
            
            # Adicionar à lista completa
            all_disciplines.extend(disciplines)
            
            # Salvamento parcial após cada unidade
            script_dir = os.path.dirname(os.path.abspath(__file__))
            json_path = os.path.join(script_dir, '..', 'dados', 'cursos-de-graduacao.json')
            output_dir = os.path.join(script_dir, '..', 'dados', 'estruturas-curriculares')
            os.makedirs(output_dir, exist_ok=True)
            output_path = os.path.join(output_dir, f"{unidade_nome}.json")
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(disciplines, f, ensure_ascii=False, indent=4)
            
            # Pausa entre unidades
            time.sleep(2)
            
    except Exception as e:
        print(f"Erro ao processar lista de unidades: {e}")
    
    return all_disciplines

def main():
    print("Iniciando scraping das disciplinas da UnB...")
    disciplines = get_all_disciplines()
    
    # Salvando em um arquivo JSON
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, '..', 'dados', 'cursos-de-graduacao.json')
    output_dir = os.path.join(script_dir, '..', 'dados', 'estruturas-curriculares')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"CIÊNCIA DA COMPUTAÇÃO.json")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(disciplines, f, ensure_ascii=False, indent=4)
    
    print(f"Total de disciplinas encontradas: {len(disciplines)}")
    print(f"Salvando JSON em: {os.path.abspath(output_path)}")

if __name__ == "__main__":
    main()