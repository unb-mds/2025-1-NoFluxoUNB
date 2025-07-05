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
import unicodedata # Importação necessária para remover acentos
from pathlib import Path
import sys
import datetime



"""
ESTE ARQUIVO CONTÉM O CODIGO DE SCRAPPING PARA TODAS OS DEPTOS
Ele extrai as disciplinas ativas de cada departamento.
Extraindo apenas : Nome, Unidade Responsavel, Codigo e Ementa.
"""

# Função auxiliar para remover acentos
def _remover_acentos(texto_com_acento):
    if not isinstance(texto_com_acento, str):
        return texto_com_acento
    nfkd_form = unicodedata.normalize('NFKD', texto_com_acento)
    texto_sem_acento = "".join([c for c in nfkd_form if not unicodedata.combining(c)])
    return texto_sem_acento

# Função limpar_texto CORRIGIDA E ÚNICA, agora com remoção de acentos
def limpar_texto(texto):
    if isinstance(texto, str):
        texto_processado = re.sub(r'\s+', ' ', texto)
        texto_processado = texto_processado.strip()
        texto_final_sem_acento = _remover_acentos(texto_processado)
        return texto_final_sem_acento
    return texto


# Configurações
MAX_WORKERS = 3
REQUEST_DELAY = (2, 5)
MAX_RETRIES = 5
#OUTPUT_DIR = "dados_finais" # Mantido do seu script original modificado
DEBUG = True

if len(sys.argv) < 2:
    print("Erro: Forneça o nome da pasta de saída como argumento.")
    print("Uso: python ateracao.py <pasta_de_saida>")
    sys.exit(1)
OUTPUT_DIR = sys.argv[1]

# Função extrair_equivalencias MODIFICADA para remover acentos
def extrair_equivalencias(cells):
    equivalencias_lista = [] # Renomeado para evitar conflito de nome com a variável string
    for ac in cells[1].find_all("acronym"):
        codigo_raw = ac.get_text(strip=True)
        # Tentativa de extrair a descrição de forma mais robusta
        title_text = ac.get("title", "")
        descricao_raw = title_text
        if " - " in title_text:
            parts = title_text.split(" - ", 1) # Divide no máximo uma vez
            if len(parts) > 1:
                descricao_raw = parts[1]

        # Aplica a remoção de acentos
        codigo = _remover_acentos(codigo_raw)
        descricao = _remover_acentos(descricao_raw.strip()) # .strip() para remover espaços extras da descrição

        equivalencias_lista.append(f"{codigo} ({descricao})")
    return ", ".join(equivalencias_lista) if equivalencias_lista else "Nenhuma"

# Função coleta_dados MODIFICADA para remover acentos dos campos
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
        
        details_raw = {} # Renomeado para clareza
        ementa_raw = ""  # Renomeado para clareza
        tables = details_soup.find_all("table")
        
        for table in tables:
            if "visualizacao" in table.get("class", []):
                rows = table.find_all("tr")
                for row in rows:
                    cells = row.find_all(["th", "td"])
                    if len(cells) >= 2:
                        label_raw = cells[0].text.strip().rstrip(':')
                        value_raw = cells[1].text.strip()
                        
                        # Aplica remoção de acentos no label e no value antes de armazenar
                        label = _remover_acentos(label_raw)
                        value = _remover_acentos(value_raw)
                        details_raw[label] = value

                        if "Equivalencias" in label and "Historico de Equivalencias" not in label: # Comparar com label já sem acento
                            # A função extrair_equivalencias já foi modificada para retornar texto sem acentos
                            details_raw["equivalencias"] = extrair_equivalencias(cells)
                            
                        if "Ementa" in label or "Descricao" in label: # Comparar com label já sem acento
                            ementa_raw = value # value já está sem acento

        # Campos que estavam comentados foram reativados.
        # A remoção de acentos é aplicada novamente para garantir, caso algum campo venha de outra fonte.
        return {
            #"tipo_componente": _remover_acentos(details_raw.get("Tipo do Componente Curricular", "Nao informado")),
            #"modalidade_educacao": _remover_acentos(details_raw.get("Modalidade de Educacao", "Nao informado")),
            #"codigo_componente": _remover_acentos(details_raw.get("Codigo", "Nao informado")),
            #"nome_componente": _remover_acentos(details_raw.get("Nome", "Nao informado")),
            "unidade_responsavel": (_remover_acentos(details_raw.get("Unidade Responsavel", "Nao informado"))).split('-')[0],
            #"pre_requisitos": _remover_acentos(details_raw.get("Pre-Requisitos", "Nao informado")),
            #"co_requisitos": _remover_acentos(details_raw.get("Co-Requisitos", "Nao informado")),
            #"equivalencias": _remover_acentos(details_raw.get("equivalencias", "Nenhuma")), # 'equivalencias' já deve vir processado
            #"excluir_avaliacao": _remover_acentos(details_raw.get("Excluir da Avaliacao Institucional", "Nao informado")),
            #"matriculavel_online": _remover_acentos(details_raw.get("Matriculavel On-Line", "Nao informado")),
            #"horario_flexivel": _remover_acentos(details_raw.get("Horario Flexivel da Turma", "Nao informado")),
            #"permite_multiplas_aprovacoes": _remover_acentos(details_raw.get("Permite Multiplas Aprovacoes", "Nao informado")),
            #"quantidade_avaliacoes": _remover_acentos(details_raw.get("Quantidade de Avaliacoes", "Nao informado")),
            "ementa": _remover_acentos(ementa_raw or details_raw.get("Ementa/Descricao", "Nao informado"))
            #"carga_horaria_total": _remover_acentos(details_raw.get("Total de Carga Horaria do Componente", "Nao informado"))
        }

    except Exception as e:
        if DEBUG:
            print(f"\n[ERRO] Falha ao coletar dados do componente {component_id}: {str(e)}")
        return {}

def processar_departamento(id_atual):
    """Processa um departamento, aplicando filtro para turma única e remoção de acentos."""
    for tentativa in range(MAX_RETRIES):
        session = None # Inicializa session como None para o bloco finally
        try:
            session = requests.Session()
            time.sleep(random.uniform(*REQUEST_DELAY))

            base_url = "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf"
            response = session.get(base_url, timeout=30)
            
            if response.status_code != 200:
                raise requests.exceptions.RequestException(f"Status {response.status_code}")

            soup = BeautifulSoup(response.text, "html.parser")
            viewstate_form = soup.find("input", {"name": "javax.faces.ViewState"})["value"] # Renomeado para clareza
            buscar_id = soup.find("input", {"value": "Buscar"}).get("id", "formTurma:j_id_jsp_1370969402_11")

            today = datetime.date.today()
            anoToday = today.year
            # Define o semestre: 1 para meses de 1 a 6, 2 para meses de 7 a 12
            semestreToday = 1 if today.month <= 6 else 2
            anoToday = str(anoToday)
            semestreToday = str(semestreToday)
            
            #sufixo_semestre = f"{ano}_{semestre}"

            form_data = {
                "formTurma": "formTurma",
                "formTurma:inputNivel": "G",
                "formTurma:inputDepto": id_atual,
                "formTurma:inputAno": anoToday,
                "formTurma:inputPeriodo": semestreToday,
                buscar_id: "Buscar",
                "javax.faces.ViewState": viewstate_form,
            }

            search_response = session.post(base_url, data=form_data, timeout=60)

            # CORREÇÃO: Retorno consistente para "Nenhuma turma encontrada"
            if "Nenhuma turma encontrada" in search_response.text:
                if DEBUG:
                    print(f"\n[INFO] Departamento {id_atual} sem turmas")
                return {"departamento_id": id_atual, "turmas": []} 

            results_soup = BeautifulSoup(search_response.text, "html.parser")
            tables = results_soup.find_all("table", {"class": "listagem"})
            
            turmas_depto = []
            materias_com_turma_adicionada = set() # Filtro para turma única

            for table_counter,table in enumerate(tables, 1):
                component_id = None
                current_component_name = ""
                current_component = {}

                for row in table.find_all("tr"):
                    if "agrupador" in row.get("class", []):
                        link = row.find("a")
                        if link:
                            onclick = link.get("onclick", "")
                            id_match = re.search(r"'id':'(\d+)'", onclick)
                            
                            # MELHORIA: Extração de params mais robusta
                            params_match = re.search(r"\{([^}]+)\}", onclick)
                            params = {}
                            if params_match:
                                params_str = params_match.group(1)
                                params = dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'", params_str))
                            
                            if id_match:
                                component_id = id_match.group(1)
                                title_span = link.find("span", {"class": "tituloDisciplina"})
                                if title_span:
                                    # current_component_name já será limpo e sem acentos por limpar_texto
                                    current_component_name = limpar_texto(title_span.text.strip())
                                
                                # MELHORIA: Coleta de viewstate para coleta_dados mais robusta
                                viewstate_agrupador_input = results_soup.find('input', {'name': 'javax.faces.ViewState'})
                                if viewstate_agrupador_input:
                                    viewstate_agrupador = viewstate_agrupador_input['value']
                                    current_component = coleta_dados(
                                        session, component_id, 
                                        viewstate_agrupador, base_url, params
                                    )
                                else:
                                    if DEBUG:
                                        print(f"\n[AVISO] ViewState não encontrado para componente {component_id} em depto {id_atual} (detalhes da matéria podem estar incompletos).")
                                    current_component = {}
                                
                    elif "linhaTitulo" not in row.get("class", []) and "agrupador" not in row.get("class", []):
                        cols = row.find_all("td")
                        if len(cols) >= 5:
                            # Lógica para adicionar apenas uma turma por matéria
                            if current_component_name and current_component_name not in materias_com_turma_adicionada:
                                # Campos da turma que estavam comentados foram reativados
                                # A função limpar_texto já remove acentos
                                #print(f"current_component_name: {current_component_name}")
                                #print(f"cols : {cols[1].text.strip()}")
                                turma = {
                                    "disciplina": current_component_name.split('-')[1] or (limpar_texto(cols[1].text.strip())).split('-')[1],
                                    "codigo": current_component_name.split('-')[0]
                                    #"turma": limpar_texto(cols[2].text),
                                    #"horario": limpar_texto(cols[3].text.strip()),
                                    #"local": limpar_texto(cols[4].text.strip()),
                                    #"docente": limpar_texto(cols[5].text.strip()) if len(cols) > 5 else "Nao informado"
                                }
                                turma.update(current_component) # Adiciona detalhes da matéria
                                turmas_depto.append(turma)
                                materias_com_turma_adicionada.add(current_component_name) 

            return {"departamento_id": id_atual, "turmas": turmas_depto}

        except Exception as e:
            if tentativa == MAX_RETRIES - 1:
                if DEBUG:
                    print(f"\n[FALHA] Departamento {id_atual} após {MAX_RETRIES} tentativas: {str(e)}")
                return {"departamento_id": id_atual, "turmas": []} # Retorno consistente
            wait_time = 10 * (tentativa + 1)
            if DEBUG:
                print(f"\n[RETRY] Tentativa {tentativa+1} para {id_atual} - Aguardando {wait_time}s")
            time.sleep(wait_time)
            
        finally:
            # MELHORIA: Fechar sessão apenas se ela existir
            if session:
                session.close()
    return {"departamento_id": id_atual, "turmas": []} # Retorno em caso de falha em todas as tentativas

def carregar_ids_departamentos():
    """Carrega TODOS os 207 IDs do seu arquivo CSV"""
    try:
        import csv
        ids = []
        # Certifique-se que o arquivo 'departamentos_unb_2.csv' está no mesmo diretório
        # ou forneça o caminho completo.
        with open('dados/departamentos_ID_unb.csv', 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            next(csv_reader, None) # Pula o cabeçalho, se houver
            for row in csv_reader:
                if row and row[0].isdigit(): # Assume que o ID está na primeira coluna
                    ids.append(int(row[0]))
        print(f"\nCarregados {len(ids)} departamentos")
        return ids
    except FileNotFoundError:
        print(f"\n[ERRO CRÍTICO] Arquivo 'departamentos_unb_2.csv' não encontrado.")
        return []
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
    
    count_salvos = 0
    for resultado in resultados:
        depto_id = resultado["departamento_id"]
        turmas = resultado["turmas"]
        
        if turmas:  # Só salva se houver turmas
            filename = f"turmas_depto_{depto_id}.json"
            filepath = os.path.join(OUTPUT_DIR, filename)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(turmas, f, ensure_ascii=False, indent=4)
            count_salvos +=1
    
    if lote_num:
        print(f"\n✓ Lote {lote_num}: {count_salvos} arquivos de departamentos salvos em {OUTPUT_DIR}")
    else:
        print(f"\n✓ {count_salvos} arquivos de departamentos salvos em {OUTPUT_DIR}")


def main():
    print("\n" + "="*60)
    print("SCRAPER UNB - VERSÃO COMPLETA") # Atualizei o print para refletir o objetivo
    print("="*60 + "\n")

    ids = carregar_ids_departamentos()
    if not ids:
        return

    todos_dados_por_depto = [] # Para acumular todos os resultados para o CSV final
    total_departamentos = len(ids)
    #total_departamentos = 1
    lote_size = 20 
    
    for i in range(0, total_departamentos, lote_size):
        lote_ids = ids[i:i + lote_size] # Renomeado para clareza
        lote_num = (i // lote_size) + 1
        print(f"\n▶ Processando lote {lote_num} (Departamentos {i+1}-{min(i+lote_size, total_departamentos)})")
        
        resultados_do_lote_atual = [] # Resultados apenas deste lote para salvar

        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            futures = [executor.submit(processar_departamento, id_depto) for id_depto in lote_ids] # Renomeado para clareza
            
            for future in tqdm(as_completed(futures), total=len(lote_ids), desc="Progresso do Lote"):
                resultado_departamento = future.result() # Renomeado para clareza
                if resultado_departamento: # Verifica se não é None (em caso de erro inesperado não tratado)
                    # Adiciona ao resultado do lote atual para salvamento imediato por departamento
                    resultados_do_lote_atual.append(resultado_departamento)
                    # Acumula para o CSV final se houver turmas
                    if resultado_departamento["turmas"]:
                         todos_dados_por_depto.append(resultado_departamento)


        # Salva os arquivos JSON por departamento PARA O LOTE ATUAL
        if resultados_do_lote_atual:
            salvar_por_departamento(resultados_do_lote_atual, lote_num)
        
        if i + lote_size < total_departamentos:
            wait_time = 15
            print(f"\n⏳ Aguardando {wait_time}s antes do próximo lote...")
            time.sleep(wait_time)
    
    print("\n" + "="*60)
    print("PROCESSO CONCLUÍDO COM SUCESSO!")
    print(f"Total de departamentos processados: {len(ids)}")
    
    # Geração do CSV final com todos os dados acumulados
    # O CSV será uma lista de dicionários, onde cada dicionário é um departamento com suas turmas.
    # Para um CSV "plano" de turmas, você precisaria reestruturar 'todos_dados_por_depto'.
    # Por ora, vou manter a estrutura que você tinha, que salva o resultado direto.
    # Se precisar de um CSV com cada turma como uma linha, me diga.
    
    # Para criar um CSV onde cada linha é uma turma (flat list):
    turmas_flat_list = []
    for resultado_depto in todos_dados_por_depto:
        for turma_info in resultado_depto['turmas']:
            # Adiciona o ID do departamento a cada turma para referência no CSV
            turma_com_depto_id = {'departamento_id': resultado_depto['departamento_id'], **turma_info}
            turmas_flat_list.append(turma_com_depto_id)

    if turmas_flat_list:
        try:
            df = pd.DataFrame(turmas_flat_list)
            csv_path = os.path.join(OUTPUT_DIR, f"turmas_unb_{time.strftime('%Y%m%d_%H%M%S')}_FULL.csv")
            df.to_csv(csv_path, index=False, encoding='utf-8-sig')
            print(f"Arquivo CSV consolidado gerado: {csv_path}")
        except Exception as e:
            print(f"\n[AVISO] Falha ao gerar CSV consolidado: {str(e)}")
    else:
        print("\n[INFO] Nenhuma turma coletada para gerar o CSV consolidado.")

if __name__ == "__main__":
    main()
