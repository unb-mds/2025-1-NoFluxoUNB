import requests
from bs4 import BeautifulSoup
import json
import time
import os
import re


def get_viewstate(soup):
    vs = soup.find('input', {'name': 'javax.faces.ViewState'})
    return vs['value'] if vs else None


def normalize(text):
    return ' '.join(text.strip().lower().split())


def extract_dados_por_nivel(relatorio_html):
    soup = BeautifulSoup(relatorio_html, 'html.parser')
    niveis = []
    materias = []
    optativas = []
    semestre_atual = 1
    modo_optativa = False

    tabela = soup.find('table')
    if not tabela:
        print("Tabela principal não encontrada!")
        return niveis

    for tr in tabela.find_all('tr'):
        td_colspan = tr.find('td', colspan="2")
        if td_colspan:
            # Salva matérias acumuladas no local correto
            if materias and not modo_optativa:
                niveis.append({
                    'nivel': f"{semestre_atual}º Semestre",
                    'materias': materias
                })
                materias = []
                semestre_atual += 1
            elif materias and modo_optativa:
                optativas.extend(materias)
                materias = []

            texto_divisor = td_colspan.get_text(strip=True).lower()
            if "optativa" in texto_divisor:
                modo_optativa = True
            else:
                modo_optativa = False
            continue

        if 'componentes' in (tr.get('class') or []):
            tds = tr.find_all('td')
            if tds and tds[0].text.strip():
                texto = tds[0].get_text(strip=True)
                match = re.match(r'([A-Z0-9]+)\s*-\s*(.*?)\s*-\s*(\d+)h', texto)
                if match:
                    codigo, nome, carga = match.groups()
                    # Natureza: tenta pegar do segundo <td>, senão usa o padrão
                    natureza = "Optativa" if modo_optativa else "Obrigatória"
                    if len(tds) > 1 and tds[1].text.strip():
                        natureza = tds[1].get_text(strip=True)
                    materia = {
                        'codigo': codigo,
                        'nome': nome.strip(),
                        'carga_horaria': f"{carga}h",
                        'natureza': natureza
                    }
                    materias.append(materia)
                else:
                    print("Regex não bateu para:", texto)

    # Salva o último grupo de matérias
    if materias and not modo_optativa:
        niveis.append({
            'nivel': f"{semestre_atual}º Semestre",
            'materias': materias
        })
    elif materias and modo_optativa:
        optativas.extend(materias)

    # Adiciona optativas como um nível separado, se houver
    if optativas:
        niveis.append({
            'nivel': "Optativas",
            'materias': optativas
        })

    print(f"=== FIM DO PARSER: {len(niveis)} níveis extraídos (incluindo optativas) ===")
    return niveis


def acessar_relatorio(session, soup, btn_name, btn_value, estrutura_id, estrutura_url):
    form = soup.find('form', {'name': 'formCurriculosCurso'})
    form_data = {}
    for input_tag in form.find_all('input'):
        name = input_tag.get('name')
        value = input_tag.get('value', '')
        if name:
            form_data[name] = value
    form_data[btn_name] = btn_value
    form_data['id'] = estrutura_id

    post_url = form.get('action')
    if not post_url.startswith('http'):
        post_url = requests.compat.urljoin(estrutura_url, post_url)

    print("DEBUG: POST para:", post_url)
    print("DEBUG: form_data:", form_data)

    resp = session.post(post_url, data=form_data)
    return resp.text


def scrape_estruturas():
    # Caminho absoluto para o arquivo JSON
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, '..', 'dados', 'cursos-de-graduacao.json')
    output_dir = os.path.join(script_dir, '..', 'dados', 'estruturas-curriculares')
    os.makedirs(output_dir, exist_ok=True)

    with open(json_path, 'r', encoding='utf-8') as f:
        cursos = json.load(f)

    base_url = "https://sigaa.unb.br/sigaa/public/curso/lista.jsf?nivel=G&aba=p-graduacao"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }

    session = requests.Session()
    session.headers.update(headers)

    # 1. Acessar página inicial para pegar cookies e viewstate
    resp = session.get(base_url)
    soup = BeautifulSoup(resp.text, 'html.parser')
    viewstate = get_viewstate(soup)

    # 2. Iterar sobre os cursos na página inicial
    tabela = soup.find('table', {'class': 'listagem'})
    if not tabela:
        print("Erro: Tabela de cursos não encontrada.")
        return

    tbody = tabela.find('tbody')
    if not tbody:
        print("Erro: <tbody> não encontrado na tabela.")
        return

    for tr in tbody.find_all('tr', class_=['linhaImpar', 'linhaPar']):
        cols = tr.find_all('td')
        if len(cols) == 0:
            continue

        nome_curso = cols[0].get_text(strip=True)
        link_tag = tr.find('a', href=True, title="Visualizar Página do Curso")
        if not link_tag:
            print(f"Erro: Link não encontrado para o curso {nome_curso}.")
            continue

        curso_url = requests.compat.urljoin(base_url, link_tag['href'])
        print(f"Processando curso: {nome_curso}")
        print(f"DEBUG: Link do curso: {curso_url}")

        # 3. Acessar página do curso
        resp = session.get(curso_url)
        soup = BeautifulSoup(resp.text, 'html.parser')

        # 4. Procurar o sub-menu 'Estruturas Curriculares' dentro da aba 'Ensino'
        estrutura_link = None
        for a in soup.find_all('a', href=True):
            if 'estruturaCurricular.jsf' in a['href'] or 'curriculo.jsf' in a['href']:
                estrutura_link = a['href']
                break

        if not estrutura_link:
            print(f"Erro: Não encontrado link para estrutura curricular em {curso_url}.")
            continue

        estrutura_url = requests.compat.urljoin(curso_url, estrutura_link)
        print(f"DEBUG: Link de estrutura curricular encontrado: {estrutura_url}")

        # 5. Acessar página de estruturas curriculares
        resp = session.get(estrutura_url)
        soup = BeautifulSoup(resp.text, 'html.parser')

        # 6. Encontrar as duas primeiras estruturas curriculares (independente do status)
        linhas = soup.find_all('tr', class_=['linha_impar', 'linha_par'])
        relatorios = []
        for tr in linhas:
            if len(relatorios) == 2:
                break
            tds = tr.find_all('td')
            if len(tds) >= 2:
                texto_identificador = ''
                periodo_letivo = ''
                for txt in tds:
                    if 'Detalhes da Estrutura Curricular' in txt.text:
                        texto_identificador = txt.text.strip()
                    match_periodo = re.search(r'Período letivo em vigor:?\s*([0-9]{4}\.[12])', txt.text)
                    if match_periodo:
                        periodo_letivo = match_periodo.group(1)
                for a in tr.find_all('a', title="Relatório da Estrutura Curricular", onclick=True):
                    onclick = a['onclick']
                    btn_match = re.search(r"\{'([^']+)':'([^']+)'", onclick)
                    id_match = re.search(r"'id':'(\d+)'", onclick)
                    if btn_match and id_match:
                        btn_name = btn_match.group(1)
                        btn_value = btn_match.group(2)
                        estrutura_id = id_match.group(1)
                        id_arquivo = periodo_letivo if periodo_letivo else re.sub(r'[^\w]', '_', texto_identificador)
                        relatorios.append((btn_name, btn_value, estrutura_id, id_arquivo, periodo_letivo))
                        break

        # Para cada uma das duas primeiras matrizes, simular o clique, extrair e salvar
        for idx, (btn_name, btn_value, estrutura_id, id_arquivo, periodo_letivo) in enumerate(relatorios):
            relatorio_html = acessar_relatorio(session, soup, btn_name, btn_value, estrutura_id, estrutura_url)
            print(f"Relatório encontrado e baixado para: {nome_curso} - {id_arquivo if id_arquivo else f'estructura{idx+1}'}")
            # Extrair dados por nível
            dados_por_nivel = extract_dados_por_nivel(relatorio_html)

            # NOVO: Extrair período letivo de entrada em vigor do relatório
            periodo_letivo_vigor = ''
            relatorio_soup = BeautifulSoup(relatorio_html, 'html.parser')
            th = relatorio_soup.find('th', string=lambda s: s and 'Período Letivo de Entrada em Vigor' in s)
            if th:
                td = th.find_next_sibling('td')
                if td:
                    periodo_letivo_vigor = td.get_text(strip=True)

            # Salvar dados organizados em JSON
            nome_arquivo = periodo_letivo_vigor if periodo_letivo_vigor else (id_arquivo if id_arquivo else f'estructura{idx+1}')
            output_path = os.path.join(output_dir, f"{normalize(nome_curso)} - {nome_arquivo}.json")
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump({
                    'curso': nome_curso,
                    'periodo_letivo_vigor': periodo_letivo_vigor,
                    'niveis': dados_por_nivel
                }, f, ensure_ascii=False, indent=2)
            print(f"Dados organizados por nível salvos em: {output_path}")


    print("Scraping concluído!")


if __name__ == "__main__":
    scrape_estruturas()