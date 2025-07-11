import requests
from bs4 import BeautifulSoup
import time
import pandas as pd
import re
import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import random
import unicodedata 
from pathlib import Path
import sys
import datetime

"""
ESTE ARQUIVO CONTÉM O CODIGO DE SCRAPPING PARA TODAS OS DEPTOS
Ele extrai as disciplinas ativas de cada departamento.
Extraindo apenas : Nome, Unidade Responsavel, Codigo e Ementa.
"""

# Configurações Globais
MAX_WORKERS = 3
REQUEST_DELAY = (2, 5)
MAX_RETRIES = 5
DEBUG = True


# --- Funções Auxiliares e de Processamento (Seguras para importar) ---

def _remover_acentos(texto_com_acento):
    """Função auxiliar para remover acentos de uma string."""
    if not isinstance(texto_com_acento, str):
        return texto_com_acento
    nfkd_form = unicodedata.normalize('NFKD', texto_com_acento)
    texto_sem_acento = "".join([c for c in nfkd_form if not unicodedata.combining(c)])
    return texto_sem_acento

def limpar_texto(texto):
    """Limpa uma string, removendo espaços excessivos, espaços nas pontas e acentos."""
    if isinstance(texto, str):
        texto_processado = re.sub(r'\s+', ' ', texto)
        texto_processado = texto_processado.strip()
        texto_final_sem_acento = _remover_acentos(texto_processado)
        return texto_final_sem_acento
    return texto

def extrair_equivalencias(cells):
    """Extrai e formata as equivalências de uma disciplina."""
    equivalencias_lista = [] 
    for ac in cells[1].find_all("acronym"):
        codigo_raw = ac.get_text(strip=True)
        title_text = ac.get("title", "")
        descricao_raw = title_text
        if " - " in title_text:
            parts = title_text.split(" - ", 1) 
            if len(parts) > 1:
                descricao_raw = parts[1]

        codigo = _remover_acentos(codigo_raw)
        descricao = _remover_acentos(descricao_raw.strip())

        equivalencias_lista.append(f"{codigo} ({descricao})")
    return ", ".join(equivalencias_lista) if equivalencias_lista else "Nenhuma"

def coleta_dados(session, component_id, viewstate, base_url, params):
    """Coleta os detalhes de uma disciplina específica."""
    try:
        form_data = {
            "javax.faces.ViewState": viewstate,
            "formTurma": "formTurma"
        }
        form_data.update(params)

        response = session.post(base_url, data=form_data, headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': base_url
        }, timeout=45)

        if DEBUG:
            Path("debug_html").mkdir(exist_ok=True)
            with open(f"debug_html/componente_{component_id}.html", "w", encoding="utf-8") as f:
                f.write(response.text)

        details_soup = BeautifulSoup(response.text, "html.parser")
        
        details_raw = {}
        ementa_raw = ""
        tables = details_soup.find_all("table")
        
        for table in tables:
            if "visualizacao" in table.get("class", []):
                rows = table.find_all("tr")
                for row in rows:
                    cells = row.find_all(["th", "td"])
                    if len(cells) >= 2:
                        label_raw = cells[0].text.strip().rstrip(':')
                        value_raw = cells[1].text.strip()
                        
                        label = _remover_acentos(label_raw)
                        value = _remover_acentos(value_raw)
                        details_raw[label] = value

                        if "Equivalencias" in label and "Historico de Equivalencias" not in label:
                            details_raw["equivalencias"] = extrair_equivalencias(cells)
                            
                        if "Ementa" in label or "Descricao" in label:
                            ementa_raw = value

        return {
            "unidade_responsavel": (_remover_acentos(details_raw.get("Unidade Responsavel", "Nao informado"))).split('-')[0],
            "ementa": _remover_acentos(ementa_raw or details_raw.get("Ementa/Descricao", "Nao informado"))
        }

    except Exception as e:
        if DEBUG:
            print(f"\n[ERRO] Falha ao coletar dados do componente {component_id}: {str(e)}")
        return {}

def processar_departamento(id_atual):
    """Processa um único departamento, coletando todas as suas turmas."""
    for tentativa in range(MAX_RETRIES):
        session = None 
        try:
            session = requests.Session()
            time.sleep(random.uniform(*REQUEST_DELAY))

            base_url = "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf"
            response = session.get(base_url, timeout=30)
            
            if response.status_code != 200:
                raise requests.exceptions.RequestException(f"Status {response.status_code}")

            soup = BeautifulSoup(response.text, "html.parser")
            viewstate_form = soup.find("input", {"name": "javax.faces.ViewState"})["value"]
            buscar_id = soup.find("input", {"value": "Buscar"}).get("id", "formTurma:j_id_jsp_1370969402_11")

            today = datetime.date.today()
            anoToday = str(today.year)
            semestreToday = str(1 if today.month <= 6 else 2)
            
            form_data = {
                "formTurma": "formTurma", "formTurma:inputNivel": "G",
                "formTurma:inputDepto": id_atual, "formTurma:inputAno": anoToday,
                "formTurma:inputPeriodo": semestreToday, buscar_id: "Buscar",
                "javax.faces.ViewState": viewstate_form,
            }

            search_response = session.post(base_url, data=form_data, timeout=60)

            if "Nenhuma turma encontrada" in search_response.text:
                if DEBUG:
                    print(f"\n[INFO] Departamento {id_atual} sem turmas")
                return {"departamento_id": id_atual, "turmas": []} 

            results_soup = BeautifulSoup(search_response.text, "html.parser")
            tables = results_soup.find_all("table", {"class": "listagem"})
            
            turmas_depto = []
            materias_com_turma_adicionada = set()

            for table in tables:
                current_component_name = ""
                current_component = {}
                for row in table.find_all("tr"):
                    if "agrupador" in row.get("class", []):
                        link = row.find("a")
                        if link:
                            onclick = link.get("onclick", "")
                            id_match = re.search(r"'id':'(\d+)'", onclick)
                            params_match = re.search(r"\{([^}]+)\}", onclick)
                            params = dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'", params_match.group(1))) if params_match else {}
                            
                            if id_match:
                                component_id = id_match.group(1)
                                title_span = link.find("span", {"class": "tituloDisciplina"})
                                if title_span:
                                    current_component_name = limpar_texto(title_span.text.strip())
                                
                                viewstate_input = results_soup.find('input', {'name': 'javax.faces.ViewState'})
                                if viewstate_input:
                                    viewstate_agrupador = viewstate_input['value']
                                    current_component = coleta_dados(session, component_id, viewstate_agrupador, base_url, params)
                                else:
                                    if DEBUG:
                                        print(f"\n[AVISO] ViewState não encontrado para componente {component_id}")
                                    current_component = {}
                            
                    elif "linhaTitulo" not in row.get("class", []) and "agrupador" not in row.get("class", []):
                        cols = row.find_all("td")
                        if len(cols) >= 5 and current_component_name and current_component_name not in materias_com_turma_adicionada:
                            turma = {
                                "disciplina": current_component_name.split('-')[1].strip() if '-' in current_component_name else current_component_name,
                                "codigo": current_component_name.split('-')[0].strip() if '-' in current_component_name else "N/A"
                            }
                            turma.update(current_component)
                            turmas_depto.append(turma)
                            materias_com_turma_adicionada.add(current_component_name) 

            return {"departamento_id": id_atual, "turmas": turmas_depto}

        except Exception as e:
            if tentativa == MAX_RETRIES - 1:
                if DEBUG:
                    print(f"\n[FALHA] Departamento {id_atual} após {MAX_RETRIES} tentativas: {str(e)}")
                return {"departamento_id": id_atual, "turmas": []}
            wait_time = 10 * (tentativa + 1)
            if DEBUG:
                print(f"\n[RETRY] Tentativa {tentativa+1} para {id_atual} - Aguardando {wait_time}s")
            time.sleep(wait_time)
            
        finally:
            if session:
                session.close()
    return {"departamento_id": id_atual, "turmas": []}

def carregar_ids_departamentos():
    """Carrega os IDs de departamentos de um arquivo CSV."""
    try:
        import csv
        ids = []
        with open('coleta_dados/dados/departamentos_ID_unb.csv', 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            next(csv_reader, None)
            for row in csv_reader:
                if row and row[0].isdigit():
                    ids.append(int(row[0]))
        print(f"\nCarregados {len(ids)} departamentos")
        return ids
    except FileNotFoundError:
        print(f"\n[ERRO CRÍTICO] Arquivo 'departamentos_ID_unb.csv' não encontrado.")
        return []
    except Exception as e:
        print(f"\n[ERRO CRÍTICO] Falha ao carregar IDs: {str(e)}")
        return []

### ALTERAÇÃO ###
# Todas as funções de salvar agora recebem 'output_dir' como parâmetro
# para não dependerem de uma variável global.

def salvar_por_departamento(resultados, output_dir, lote_num=None):
    """Salva as turmas de cada departamento em arquivos separados."""
    Path(output_dir).mkdir(exist_ok=True)
    count_salvos = 0
    for resultado in resultados:
        depto_id = resultado["departamento_id"]
        turmas = resultado["turmas"]
        if turmas:
            filename = f"turmas_depto_{depto_id}.json"
            filepath = os.path.join(output_dir, filename)
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(turmas, f, ensure_ascii=False, indent=4)
            count_salvos +=1
    
    if lote_num:
        print(f"\n✓ Lote {lote_num}: {count_salvos} arquivos de departamentos salvos em {output_dir}")
    else:
        print(f"\n✓ {count_salvos} arquivos de departamentos salvos em {output_dir}")


# --- Função Principal de Orquestração ---

def main():
    """Função principal que orquestra todo o processo de scraping."""
    ### ALTERAÇÃO ###
    # A verificação de argumentos e definição da pasta de saída
    # foi movida para DENTRO da função main.
    if len(sys.argv) < 2:
        print("Erro: Forneça o nome da pasta de saída como argumento.")
        print("Uso: python seu_script.py <nome_da_pasta_de_saida>")
        sys.exit(1)
    output_dir = sys.argv[1]

    print("\n" + "="*60)
    print("SCRAPER UNB - VERSÃO COMPLETA")
    print("="*60 + "\n")

    ids = carregar_ids_departamentos()
    if not ids:
        return

    todos_dados_por_depto = []
    total_departamentos = len(ids)
    lote_size = 20 
    
    for i in range(0, total_departamentos, lote_size):
        lote_ids = ids[i:i + lote_size]
        lote_num = (i // lote_size) + 1
        print(f"\n▶ Processando lote {lote_num} (Departamentos {i+1}-{min(i+lote_size, total_departamentos)})")
        
        resultados_do_lote_atual = []

        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [executor.submit(processar_departamento, id_depto) for id_depto in lote_ids]
            
            for future in tqdm(as_completed(futures), total=len(lote_ids), desc="Progresso do Lote"):
                resultado_departamento = future.result()
                if resultado_departamento:
                    resultados_do_lote_atual.append(resultado_departamento)
                    if resultado_departamento["turmas"]:
                        todos_dados_por_depto.append(resultado_departamento)

        if resultados_do_lote_atual:
            ### ALTERAÇÃO ###
            # Passando 'output_dir' como argumento para a função de salvar.
            salvar_por_departamento(resultados_do_lote_atual, output_dir, lote_num)
        
        if i + lote_size < total_departamentos:
            wait_time = 15
            print(f"\n⏳ Aguardando {wait_time}s antes do próximo lote...")
            time.sleep(wait_time)
    
    print("\n" + "="*60)
    print("PROCESSO CONCLUÍDO COM SUCESSO!")
    print(f"Total de departamentos processados: {len(ids)}")
    
    turmas_flat_list = []
    for resultado_depto in todos_dados_por_depto:
        for turma_info in resultado_depto['turmas']:
            turma_com_depto_id = {'departamento_id': resultado_depto['departamento_id'], **turma_info}
            turmas_flat_list.append(turma_com_depto_id)

    if turmas_flat_list:
        try:
            df = pd.DataFrame(turmas_flat_list)
            ### ALTERAÇÃO ###
            # Usando a variável local 'output_dir' para salvar o CSV.
            csv_path = os.path.join(output_dir, f"turmas_unb_{time.strftime('%Y%m%d_%H%M%S')}_FULL.csv")
            df.to_csv(csv_path, index=False, encoding='utf-8-sig')
            print(f"Arquivo CSV consolidado gerado: {csv_path}")
        except Exception as e:
            print(f"\n[AVISO] Falha ao gerar CSV consolidado: {str(e)}")
    else:
        print("\n[INFO] Nenhuma turma coletada para gerar o CSV consolidado.")

# --- Ponto de Entrada do Script ---
# Este bloco só é executado quando o arquivo é chamado diretamente.
# python seu_script.py <argumentos>
if __name__ == "__main__":
    main()