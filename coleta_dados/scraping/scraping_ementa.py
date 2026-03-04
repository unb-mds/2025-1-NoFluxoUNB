import requests
from bs4 import BeautifulSoup
import json
import time
import os
import re
import unicodedata


def get_viewstate(soup):
    vs = soup.find('input', {'name': 'javax.faces.ViewState'})
    return vs['value'] if vs else None


def normalize(text):
    return ' '.join(text.strip().lower().split())


def normalizar_turno_para_arquivo(turno):
    """
    Normaliza o turno para uso no nome do arquivo.
    Mesmo ano/semestre com turnos diferentes = curriculos diferentes (ex: direito 2019.2 diurno vs noturno).
    """
    if not turno or not turno.strip():
        return 'sem-turno'
    t = turno.strip().upper()
    if 'NOTURNO' in t or t == 'NOTURNO':
        return 'noturno'
    if 'DIURNO' in t or 'MATUTINO' in t or 'VESPERTINO' in t:
        return 'diurno'
    if 'INTEGRAL' in t:
        return 'integral'
    return normalize(turno).replace(' ', '-')[:20]


def remover_acentos(texto):
    return unicodedata.normalize('NFKD', texto).encode('ASCII', 'ignore').decode('ASCII')


def extract_curriculo(relatorio_html):
    """Extrai o Código (curriculo) da tabela Estrutura Curricular, ex.: 60810/2"""
    soup = BeautifulSoup(relatorio_html, 'html.parser')
    for th in soup.find_all('th'):
        texto = th.get_text(strip=True)
        if texto.startswith('Código') or texto.lower().startswith('codigo'):
            td = th.find_next_sibling('td')
            if td:
                return td.get_text(strip=True)
    return ''


def _valor_celula(th):
    """Retorna o texto da célula <td> irmã do <th>, normalizado (strip)."""
    td = th.find_next_sibling('td')
    return td.get_text(strip=True) if td else ''


def extract_prazos_cargas(relatorio_html):
    """
    Extrai a seção Prazos e Cargas Horárias da tabela.
    Retorna dict com: total_minima, subtotal_ch_aula, subtotal_ch_orientacao,
    ch_obrigatoria_total, ch_optativa_minima, ch_complementar_minima.
    Valores no formato da página (ex: "3210h", "2010h").
    """
    soup = BeautifulSoup(relatorio_html, 'html.parser')
    out = {
        'total_minima': '',
        'subtotal_ch_aula': '',
        'subtotal_ch_orientacao': '',
        'ch_obrigatoria_total': '',
        'ch_optativa_minima': '',
        'ch_complementar_minima': ''
    }
    for th in soup.find_all('th'):
        texto = th.get_text(strip=True)
        t_lower = texto.lower()
        val = _valor_celula(th)
        if 'total m' in t_lower and 'nima' in t_lower and 'optativa' not in t_lower and 'complementar' not in t_lower and 'obrigat' not in t_lower:
            out['total_minima'] = val
        elif 'subtotal de ch de aula' in t_lower:
            out['subtotal_ch_aula'] = val
        elif 'subtotal de ch de orienta' in t_lower or 'orientação acadêmica' in t_lower:
            out['subtotal_ch_orientacao'] = val
        elif texto.strip() == 'Total:':
            out['ch_obrigatoria_total'] = val
        elif 'carga horária optativa m' in t_lower:
            out['ch_optativa_minima'] = val
        elif 'carga horária complementar m' in t_lower:
            out['ch_complementar_minima'] = val
    # Total: pode ser a linha com th "Total:" logo após Subtotal de Orientação
    if not out['ch_obrigatoria_total']:
        for th in soup.find_all('th'):
            if th.get_text(strip=True) == 'Total:':
                out['ch_obrigatoria_total'] = _valor_celula(th)
                break
    return out


def _extrair_natureza_da_celula(td):
    """Extrai 'Obrigatória' ou 'Optativa' da célula Natureza (segunda coluna)."""
    if not td:
        return 'Optativa'  # fallback
    texto = td.get_text(strip=True).lower()
    if 'obrigat' in texto:
        return 'Obrigatória'
    if 'optativa' in texto:
        return 'Optativa'
    return 'Optativa'  # fallback


def _parse_estrutura_celula(texto):
    """Parse 'CODIGO - NOME - Xh' retornando (codigo, nome, ch)."""
    m = re.match(r'^([A-Z0-9]+)\s*-\s*(.+?)\s*-\s*(\d+)h\s*$', texto, re.IGNORECASE | re.DOTALL)
    if m:
        codigo = remover_acentos(m.group(1)).upper()
        nome = remover_acentos(m.group(2)).upper().strip()
        ch = m.group(3)
        if 'CH TOTAL' in nome or 'CH MINIMA' in nome:
            return None
        return {'codigo': codigo, 'nome': nome, 'ch': ch}
    return None


def extract_dados_por_nivel(relatorio_html):
    """
    Extrai dados por nível a partir do HTML da estrutura curricular.
    Usa a estrutura de tabelas (tr.tituloRelatorio, tr.componentes) para obter
    codigo, nome, ch e natureza (Obrigatória/Optativa) de cada matéria.
    """
    soup = BeautifulSoup(relatorio_html, 'html.parser')
    niveis = []

    # Encontra todas as linhas tr na página
    all_trs = soup.find_all('tr')
    i = 0
    while i < len(all_trs):
        tr = all_trs[i]
        classes = tr.get('class', [])

        # tr.tituloRelatorio define o início de uma seção (ex: "1º Nível", "Optativas")
        if 'tituloRelatorio' in classes:
            td_titulo = tr.find('td')
            if td_titulo:
                nome_nivel = td_titulo.get_text(strip=True)
                nome_nivel_norm = remover_acentos(nome_nivel).upper()
                nome_nivel_norm = re.sub(r'(\d+)O NIVEL', r'\1° NIVEL', nome_nivel_norm)

                # Coleta as linhas tr.componentes seguintes até outra seção
                materias = []
                j = i + 1
                while j < len(all_trs):
                    tr_comp = all_trs[j]
                    if 'tituloRelatorio' in (tr_comp.get('class') or []):
                        break
                    if 'header' in (tr_comp.get('class') or []):
                        j += 1
                        continue
                    if 'componentes' in (tr_comp.get('class') or []):
                        tds = tr_comp.find_all('td')
                        if len(tds) >= 2:
                            texto_estrutura = tds[0].get_text(strip=True)
                            parsed = _parse_estrutura_celula(texto_estrutura)
                            if parsed:
                                natureza = _extrair_natureza_da_celula(tds[1] if len(tds) > 1 else None)
                                parsed['natureza'] = natureza
                                materias.append(parsed)
                    else:
                        # Linha sem classe componentes (ex: CH Total) - para esta seção
                        txt = tr_comp.get_text(strip=True)
                        if 'CH Total' in txt or 'CH Mínima' in txt:
                            pass  # ignora, continua
                        else:
                            break
                    j += 1

                if materias:
                    niveis.append({'nivel': nome_nivel_norm, 'materias': materias})
                i = j - 1  # pula até a última linha processada
        i += 1

    # Fallback: se não encontrou via HTML estruturado, usa regex no texto (sem natureza)
    if not niveis:
        texto = soup.get_text(separator=' ', strip=True).lower()
        blocos = re.split(r'(\d+º nível)', texto, flags=re.IGNORECASE)
        for idx in range(1, len(blocos), 2):
            nome_nivel = remover_acentos(blocos[idx]).upper()
            nome_nivel = re.sub(r'(\d+)O NIVEL', r'\1° NIVEL', nome_nivel)
            conteudo = blocos[idx + 1]
            conteudo = re.split(r'cadeia|grupo de componentes', conteudo, flags=re.IGNORECASE)[0]
            materias = []
            for m in re.findall(r'([a-z0-9]+)\s*-\s*(.*?)\s*-\s*(\d+)h', conteudo, flags=re.IGNORECASE):
                nome_materia = remover_acentos(m[1]).upper()
                if 'CH TOTAL' in nome_materia or 'CH MINIMA' in nome_materia:
                    continue
                materias.append({
                    'codigo': remover_acentos(m[0]).upper(),
                    'nome': nome_materia,
                    'ch': m[2],
                    'natureza': 'Obrigatória' if 'nivel' in nome_nivel.lower() and 'optativa' not in nome_nivel.lower() else 'Optativa'
                })
            if materias:
                niveis.append({'nivel': nome_nivel, 'materias': materias})

        match_optativas = re.search(r'(optativas[\w\s]*)(.*)', texto, flags=re.IGNORECASE)
        if match_optativas:
            conteudo_opt = match_optativas.group(2)
            conteudo_opt = re.split(r'cadeia|grupo de componentes', conteudo_opt, flags=re.IGNORECASE)[0]
            materias_opt = []
            for m in re.findall(r'([a-z0-9]+)\s*-\s*(.*?)\s*-\s*(\d+)h', conteudo_opt, flags=re.IGNORECASE):
                nome_materia = remover_acentos(m[1]).upper()
                if 'CH TOTAL' in nome_materia or 'CH MINIMA' in nome_materia:
                    continue
                materias_opt.append({
                    'codigo': remover_acentos(m[0]).upper(),
                    'nome': nome_materia,
                    'ch': m[2],
                    'natureza': 'Optativa'
                })
            if materias_opt:
                niveis.append({'nivel': 'OPTATIVAS', 'materias': materias_opt})

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
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, '..', 'dados', 'cursos-de-graduacao.json')
    output_dir = os.path.join(script_dir, '..', 'dados', 'estruturas-curriculares')
    os.makedirs(output_dir, exist_ok=True)

    with open(json_path, 'r', encoding='utf-8') as f:
        cursos = json.load(f)

    base_url = "https://sigaa.unb.br/sigaa/public/curso/lista.jsf?nivel=G&aba=p-graduacao"
    headers = {
        'User-Agent': 'Mozilla/5.0'
    }

    session = requests.Session()
    session.headers.update(headers)

    resp = session.get(base_url)
    soup = BeautifulSoup(resp.text, 'html.parser')
    viewstate = get_viewstate(soup)

    tabela = soup.find('table', {'class': 'listagem'})
    if not tabela:
        print("Erro: Tabela de cursos não encontrada.")
        return

    tbody = tabela.find('tbody')
    if not tbody:
        print("Erro: <tbody> não encontrado na tabela.")
        return

    # Cada <tr> com linhaImpar/linhaPar é uma linha de curso (Nome, Grau, Turno, Sede, etc.)
    # Processar CADA linha individualmente - curriculo muda conforme DIURNO/NOTURNO
    linhas_curso = tbody.find_all('tr', class_=['linhaImpar', 'linhaPar'])
    print(f"Total de linhas de curso a processar: {len(linhas_curso)}")

    for idx, tr in enumerate(linhas_curso):
        cols = tr.find_all('td')
        if len(cols) == 0:
            continue

        nome_curso = cols[0].get_text(strip=True)
        tipo_curso = cols[1].get_text(strip=True)
        turno = cols[2].get_text(strip=True) if len(cols) > 2 else ''
        turno_arquivo = normalizar_turno_para_arquivo(turno)

        link_tag = tr.find('a', href=True, title="Visualizar Página do Curso")
        if not link_tag:
            print(f"Erro: Link não encontrado para o curso {nome_curso}.")
            continue

        curso_url = requests.compat.urljoin(base_url, link_tag['href'])
        print(f"[{idx + 1}/{len(linhas_curso)}] Processando: {nome_curso} ({turno or 'sem turno'})")
        print(f"DEBUG: Link do curso: {curso_url}")

        resp = session.get(curso_url)
        soup = BeautifulSoup(resp.text, 'html.parser')

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

        resp = session.get(estrutura_url)
        soup = BeautifulSoup(resp.text, 'html.parser')

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

        for idx, (btn_name, btn_value, estrutura_id, id_arquivo, periodo_letivo) in enumerate(relatorios):
            relatorio_html = acessar_relatorio(session, soup, btn_name, btn_value, estrutura_id, estrutura_url)
            print(f"Relatório encontrado e baixado para: {nome_curso} - {id_arquivo if id_arquivo else f'estructura{idx+1}'}")
            curriculo = extract_curriculo(relatorio_html)
            dados_por_nivel = extract_dados_por_nivel(relatorio_html)
            prazos_cargas = extract_prazos_cargas(relatorio_html)

            periodo_letivo_vigor = ''
            relatorio_soup = BeautifulSoup(relatorio_html, 'html.parser')
            th = relatorio_soup.find('th', string=lambda s: s and 'Período Letivo de Entrada em Vigor' in s)
            if th:
                td = th.find_next_sibling('td')
                if td:
                    periodo_letivo_vigor = td.get_text(strip=True)

            nome_arquivo = periodo_letivo_vigor if periodo_letivo_vigor else (id_arquivo if id_arquivo else f'estructura{idx+1}')
            nome_base = f"{normalize(nome_curso)} - {nome_arquivo}"
            if turno_arquivo and turno_arquivo != 'sem-turno':
                nome_base += f" - {turno_arquivo}"
            output_path = os.path.join(output_dir, f"{nome_base}.json")
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump({
                    'curso': nome_curso,
                    'tipo_curso': tipo_curso,
                    'turno': turno,
                    'curriculo': curriculo,
                    'periodo_letivo_vigor': periodo_letivo_vigor,
                    'prazos_cargas': prazos_cargas,
                    'niveis': dados_por_nivel
                }, f, ensure_ascii=False, indent=2)
            print(f"Dados organizados por nível salvos em: {output_path}")

    print("Scraping concluído!")


if __name__ == "__main__":
    scrape_estruturas()
