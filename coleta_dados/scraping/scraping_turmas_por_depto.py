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
from pathlib import Path
"""
ESTE ARQUIVO CONTÉM O CODIGO DE SCRAPPING PARA TODAS OS DEPTOS
ESTE ARQUIVO UTILIZA DE FUNÇÕES PARA EXECUTAR O SCRAPPING EM PARALELO
PORTANTO, É MAIS RÁPIDO. UTILIZE SEMPRE ESSE ARRQUIVO!
"""


# Configurações
MAX_WORKERS = 3  # Reduzido para evitar bloqueios
REQUEST_DELAY = (2, 5)  # Intervalo maior entre requisições
MAX_RETRIES = 5  # Mais tentativas por departamento
OUTPUT_DIR = "dados_finais_teste_p_depto"
DEBUG = True  # Ativar para ver logs detalhados

def limpar_texto(texto):
    
    if isinstance(texto, str):
        texto = re.sub(r'\s+', ' ', texto)  # Remove múltiplos espaços
        return texto.strip()
    return texto

def extrair_equivalencias(cells):
    
    equivalencias = []
    for ac in cells[1].find_all("acronym"):
        codigo = ac.get_text(strip=True)
        descricao = ac.get("title", "").split(" - ")[-1]
        equivalencias.append(f"{codigo} ({descricao})")
    return ", ".join(equivalencias) if equivalencias else "Nenhuma"

def coleta_dados(session, component_id, viewstate, base_url, params):
    
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
        
        
        details = {}
        ementa = ""
        tables = details_soup.find_all("table")
        
        for table in tables:
            if "visualizacao" in table.get("class", []):
                rows = table.find_all("tr")
                for row in rows:
                    cells = row.find_all(["th", "td"])
                    if len(cells) >= 2:
                        label = cells[0].text.strip().rstrip(':')
                        value = cells[1].text.strip()
                        details[label] = value

                        if "Equivalências" in label and "Histórico de Equivalências" not in label:

                            equivalencias = []
                            for ac in cells[1].find_all("acronym"):
                                codigo = ac.get_text(strip=True)
                                #print(f'variavel código = {codigo}')
                                descricao = ac.get("title", "").split(" - ")[-1]
                                #print(f'variavel descricao = {descricao}')
                                equivalencias.append(f"{codigo} ({descricao})")
                            details["equivalencias"] = ", ".join(equivalencias) if equivalencias else "Nenhuma"
                            #print(f'lista equivalencias = {equivalencias}')
                            #print(details["Equivalências"])
                            
                        if "Ementa" in label or "Descrição" in label:
                            ementa = value

        return {
            "tipo_componente": details.get("Tipo do Componente Curricular", "Não informado"),
            "modalidade_educacao": details.get("Modalidade de Educação", "Não informado"),
            "unidade_responsavel": details.get("Unidade Responsável", "Não informado"),
            "codigo_componente": details.get("Código", "Não informado"),
            "nome_componente": details.get("Nome", "Não informado"),
            "pre_requisitos": details.get("Pré-Requisitos", "Não informado"),
            "co_requisitos": details.get("Co-Requisitos", "Não informado"),
            "equivalencias": details.get("Equivalências", "Não informado"),
            "excluir_avaliacao": details.get("Excluir da Avaliação Institucional", "Não informado"),
            "matriculavel_online": details.get("Matriculável On-Line", "Não informado"),
            "horario_flexivel": details.get("Horário Flexível da Turma", "Não informado"),
            "permite_multiplas_aprovacoes": details.get("Permite Múltiplas Aprovações", "Não informado"),
            "quantidade_avaliacoes": details.get("Quantidade de Avaliações", "Não informado"),
            "ementa": ementa or details.get("Ementa/Descrição", "Não informado"),
            "carga_horaria_total": details.get("Total de Carga Horária do Componente", "Não informado")
        }

    except Exception as e:
        if DEBUG:
            print(f"\n[ERRO] Falha ao coletar dados do componente {component_id}: {str(e)}")
        return {}

def processar_departamento(id_atual):
    """Processa um departamento com todas as verificações originais"""
    for tentativa in range(MAX_RETRIES):
        try:
            session = requests.Session()
            #session.headers.update({
                #'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            #})

            # DELAY ANTIDDOS
            time.sleep(random.uniform(*REQUEST_DELAY))

            # PRIMEIRA REQUISIÇÃO (OBTER TOKENS)
            base_url = "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf"
            response = session.get(base_url, timeout=30)
            
            if response.status_code != 200:
                raise requests.exceptions.RequestException(f"Status {response.status_code}")

            soup = BeautifulSoup(response.text, "html.parser")
            viewstate = soup.find("input", {"name": "javax.faces.ViewState"})["value"]
            buscar_id = soup.find("input", {"value": "Buscar"}).get("id", "formTurma:j_id_jsp_1370969402_11")

            # ENVIAR FORMULÁRIO
            form_data = {
                "formTurma": "formTurma",
                "formTurma:inputNivel": "G",
                "formTurma:inputDepto": id_atual,
                "formTurma:inputAno": "2025",
                "formTurma:inputPeriodo": "1",
                buscar_id: "Buscar",
                "javax.faces.ViewState": viewstate,
            }

            search_response = session.post(
                base_url, 
                data=form_data, 
                timeout=60

            )

            # VERIFICAÇÃO DE RESULTADOS
            if "Nenhuma turma encontrada" in search_response.text:
                if DEBUG:
                    print(f"\n[INFO] Departamento {id_atual} sem turmas")
                return []

            results_soup = BeautifulSoup(search_response.text, "html.parser")
            tables = results_soup.find_all("table", {"class": "listagem"})
            
            turmas_depto = []
            for table_counter,table in enumerate(tables, 1):
                component_id = None
                #current_component_details = {}
                current_component_name = ""
                #current_component = {"departamento_id": id_atual}
                current_component = {}


                for row in table.find_all("tr"):
                    if "agrupador" in row.get("class", []):
                        link = row.find("a")
                        if link:
                            onclick = link.get("onclick", "")
                            id_match = re.search(r"'id':'(\d+)'", onclick)
                            params = re.search(r"\{([^}]+)\}", onclick).group(1)
                            params = dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'", params))
                            if id_match:
                                component_id = id_match.group(1)
                                title_span = link.find("span", {"class": "tituloDisciplina"})
                                if title_span:
                                    current_component_name = limpar_texto(title_span.text.strip())
                                #params = dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'", onclick))
                                viewstate = results_soup.find('input', {'name': 'javax.faces.ViewState'})['value']

                                # COLETA TODOS OS DETALHES
                                current_component = coleta_dados(
                                    session, component_id, 
                                    viewstate, base_url, params
                                )
                                #current_component.update(details)
                                
                

                    elif "linhaTitulo" not in row.get("class", []) and "agrupador" not in row.get("class", []):
                        cols = row.find_all("td")
                        if len(cols) >= 5:
                            turma = {
                                "codigo": limpar_texto(cols[0].text.strip()),
                                "disciplina": current_component_name or limpar_texto(cols[1].text.strip()),
                                "turma": limpar_texto(cols[2].text),
                                "horario": limpar_texto(cols[3].text.strip()),
                                "local": limpar_texto(cols[4].text.strip()),
                                "docente": limpar_texto(cols[5].text.strip()) if len(cols) > 5 else "Não informado"
                            }
                            turma.update(current_component)
                            turmas_depto.append(turma)

            #return turmas_depto

            #return para o salvamento de turmas por depto
            return {"departamento_id": id_atual, "turmas": turmas_depto}

        except Exception as e:
            if tentativa == MAX_RETRIES - 1:
                if DEBUG:
                    print(f"\n[FALHA] Departamento {id_atual} após {MAX_RETRIES} tentativas: {str(e)}")
                #return []
                #return para o salvamento de turmas por depto
                return {"departamento_id": id_atual, "turmas": []}
            wait_time = 10 * (tentativa + 1)
            if DEBUG:
                print(f"\n[RETRY] Tentativa {tentativa+1} para {id_atual} - Aguardando {wait_time}s")
            time.sleep(wait_time)
            
        finally:
            session.close()

def carregar_ids_departamentos():
    """Carrega TODOS os 207 IDs do seu arquivo CSV"""
    try:
        import csv
        ids = []
        with open('dados/departamentos_unb_2.csv', 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            for row in csv_reader:
                if row and row[0].isdigit():
                    ids.append(int(row[0]))
        print(f"\nCarregados {len(ids)} departamentos")
        return ids
    except Exception as e:
        print(f"\n[ERRO CRÍTICO] Falha ao carregar IDs: {str(e)}")
        return []

def salvar_resultados(turmas, lote_num=None):

    Path(OUTPUT_DIR).mkdir(exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    filename = f"turmas_unb_{timestamp}_lote{lote_num}.json" if lote_num else f"turmas_unb_{timestamp}_FULL.json"
    
    with open(os.path.join(OUTPUT_DIR, filename), 'w', encoding='utf-8') as f:
        json.dump(turmas, f, ensure_ascii=False, indent=4, sort_keys=True)
    
    print(f"\n✓ Arquivo salvo: {filename} (Turmas: {len(turmas)})")


def salvar_resultados_individualmente(turmas, lote_num=None):
    """Salva cada turma em um arquivo JSON individual"""
    Path(OUTPUT_DIR).mkdir(exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    
    for idx, turma in enumerate(turmas, 1):
        # Cria um nome de arquivo único para cada turma
        codigo_turma = turma.get('codigo', 'sem_codigo').replace('/', '_')
        nome_disciplina = turma.get('disciplina', 'sem_nome').replace(' ', '_')[:50]
        filename = f"turma_{codigo_turma}_{nome_disciplina}_{timestamp}.json"
        
        # Remove caracteres inválidos do nome do arquivo
        filename = re.sub(r'[<>:"/\\|?*]', '', filename)
        
        filepath = os.path.join(OUTPUT_DIR, filename)
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(turma, f, ensure_ascii=False, indent=4, sort_keys=True)
    
    print(f"\n✓ {len(turmas)} arquivos individuais salvos no diretório {OUTPUT_DIR}")


def salvar_por_departamento(resultados, lote_num=None):
    """Salva as turmas de cada departamento em arquivos separados"""
    Path(OUTPUT_DIR).mkdir(exist_ok=True)
    
    for resultado in resultados:
        depto_id = resultado["departamento_id"]
        turmas = resultado["turmas"]
        
        if turmas:  # Só salva se houver turmas
            filename = f"turmas_depto_{depto_id}.json"
            filepath = os.path.join(OUTPUT_DIR, filename)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(turmas, f, ensure_ascii=False, indent=4)
    
    print(f"\n✓ {len(resultados)} arquivos de departamentos salvos no diretório {OUTPUT_DIR}")



def main():
    print("\n" + "="*60)
    print("SCRAPER UNB - VERSÃO COMPLETA (207 DEPARTAMENTOS)")
    print("="*60 + "\n")

    ids = carregar_ids_departamentos()
    #todos_ids = carregar_ids_departamentos()
    #ids = todos_ids[:3]
    if not ids:
        return

    #todos_dados = []
    #para salvamento por depto
    todos_dados_por_depto = []
    total_departamentos = len(ids)
    #total_departamentos = 3
    lote_size = 20  # Processa em lotes menores para maior segurança
    
    for i in range(0, total_departamentos, lote_size):
        lote = ids[i:i + lote_size]
        lote_num = (i // lote_size) + 1
        print(f"\n▶ Processando lote {lote_num} (Departamentos {i+1}-{min(i+lote_size, total_departamentos)})")
        dados_lote = []

        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [executor.submit(processar_departamento, id) for id in lote]
            
            resultados_lote = []
            for future in tqdm(as_completed(futures), total=len(lote), desc="Progresso"):
                resultado = future.result()
                                #resultado["turmas"] para salvamento por depto
                if resultado and resultado["turmas"]:

                    #dados_lote.extend(resultado)
                    #todos_dados.extend(resultado)

                    #para salvamento por depto
                    resultados_lote.append(resultado)
                    todos_dados_por_depto.append(resultado)

        # Salva a cada lote
        #salvar_resultados(todos_dados, lote_num)

        # Salva os dados individuais a cada lote
        #salvar_resultados_individualmente(dados_lote, lote_num)

        #para salvamento por depto
        salvar_por_departamento(resultados_lote, lote_num)
        
        # Intervalo anti-ban
        if i + lote_size < total_departamentos:
            wait_time = 15
            print(f"\n⏳ Aguardando {wait_time}s antes do próximo lote...")
            time.sleep(wait_time)
    
    '''
    print(f"Processando os seguintes departamentos: {ids}")
    
    with ThreadPoolExecutor(max_workers=3) as executor:  # Reduz workers para 3
        futures = [executor.submit(processar_departamento, id) for id in ids]
        
        for future in tqdm(as_completed(futures), total=len(ids), desc="Progresso"):
            resultado = future.result()
            if resultado:
                todos_dados.extend(resultado)
    '''
    # Salvamento final
    print("\n" + "="*60)
    print("PROCESSO CONCLUÍDO COM SUCESSO!")
    print(f"Total de departamentos processados: {len(ids)}")
    #print(f"Total de turmas coletadas: {len(todos_dados)}")
    
    #salvar_resultados(todos_dados)
    
    salvar_por_departamento(todos_dados_por_depto)

    # Opcional: gerar CSV também
    
    try:
        df = pd.DataFrame(todos_dados_por_depto)
        csv_path = os.path.join(OUTPUT_DIR, f"turmas_unb_{time.strftime('%Y%m%d')}_FULL.csv")
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"Arquivo CSV gerado: {csv_path}")
    except Exception as e:
        print(f"\n[AVISO] Falha ao gerar CSV: {str(e)}")

if __name__ == "__main__":
    main()
