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
"""
ESTE ARQUIVO CONTÉM O CODIGO DE SCRAPPING PARA TODAS OS DEPTOS
ESTE ARQUIVO UTILIZA DE FUNÇÕES PARA EXECUTAR O SCRAPPING EM PARALELO
PORTANTO, É MAIS RÁPIDO. UTILIZE SEMPRE ESSE ARRQUIVO!
"""

def _remover_acentos(texto_com_acento):
    if not isinstance(texto_com_acento, str):
        return texto_com_acento # Retorna o valor original se não for string
    # Normaliza a string para a forma NFKD (Normalization Form Compatibility Decomposition)
    # Isso separa os caracteres base dos seus diacríticos (acentos)
    nfkd_form = unicodedata.normalize('NFKD', texto_com_acento)
    # Filtra a string normalizada, mantendo apenas os caracteres que não são diacríticos combinantes
    texto_sem_acento = "".join([c for c in nfkd_form if not unicodedata.combining(c)])
    return texto_sem_acento

def limpar_texto(texto):
    if isinstance(texto, str):
        # 1. Limpeza de espaços múltiplos e das extremidades (como no seu código original)
        texto_processado = re.sub(r'\s+', ' ', texto) # Remove múltiplos espaços
        texto_processado = texto_processado.strip()   # Remove espaços das pontas

        # 2. Remoção de acentos do texto já processado
        texto_final_sem_acento = _remover_acentos(texto_processado)

        return texto_final_sem_acento
    return texto # Retorna o valor original se não for string (ex: None, int, etc.)




# Configurações
MAX_WORKERS = 3  # Reduzido para evitar bloqueios
REQUEST_DELAY = (2, 5)  # Intervalo maior entre requisições
MAX_RETRIES = 5  # Mais tentativas por departamento
OUTPUT_DIR = "dados_finais_teste_p_depto_20"
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

        lista_de_equivalencias_especificas = []
        for table in tables:
            # A busca é feita em todas as linhas de todas as tabelas
            for row in table.find_all('tr'):
                # O gatilho para identificar uma linha de equivalência é uma célula
                # com a classe "colMatriz" que contém uma tag "acronym".
                trigger_cell = row.find("td", class_="colMatriz")
                if trigger_cell and trigger_cell.find("acronym"):
                    
                    # Extrai a expressão da equivalência
                    expressao = _remover_acentos(trigger_cell.get_text(separator=' ', strip=True))
                    
                    # Extrai a matriz curricular da célula seguinte
                    matriz_cell = trigger_cell.find_next_sibling("td", class_="colMatriz")
                    matriz_curricular = _remover_acentos(matriz_cell.get_text(strip=True)) if matriz_cell else "Nao encontrado"
                    
                    # Extrai o currículo
                    curriculo_cell = row.find("td", class_="colCurriculo")
                    curriculo = _remover_acentos(curriculo_cell.get_text(strip=True)) if curriculo_cell else "Nao encontrado"
                    
                    # Extrai as datas de vigência
                    data_cells = row.find_all("td", class_="colData")
                    data_inicio = "Nao encontrado"
                    data_fim = "Nao encontrado"
                    if len(data_cells) > 0:
                        data_inicio = _remover_acentos(data_cells[0].get_text(strip=True))
                    if len(data_cells) > 1:
                        data_fim = _remover_acentos(data_cells[1].get_text(strip=True))

                    # Apenas adiciona à lista se a equivalência estiver vigente (data_fim vazia)
                    if data_fim == '':
                        dados_equivalencia = {
                            "expressao": expressao,
                            "matriz_curricular": matriz_curricular,
                            "curriculo": curriculo,
                            "data_vigencia": data_inicio,
                            "fim_vigencia" : data_fim # Será uma string vazia
                        }
                        lista_de_equivalencias_especificas.append(dados_equivalencia)

        return {
            #"tipo_componente": details.get("Tipo do Componente Curricular", "Não informado"),
            #"modalidade_educacao": details.get("Modalidade de Educação", "Não informado"),
            "nome": details.get("Nome", "Não informado"),
            "unidade_responsavel": details.get("Unidade Responsável", "Não informado").split('-')[0],
            #"codigo_componente": details.get("Código", "Não informado"),
            "pre_requisitos": details.get("Pré-Requisitos", "Não informado"),
            "co_requisitos": details.get("Co-Requisitos", "Não informado"),
            "equivalencias": details.get("Equivalências", "Não informado"),
            "equivalencias_especificas": lista_de_equivalencias_especificas,
            #"excluir_avaliacao": details.get("Excluir da Avaliação Institucional", "Não informado"),
            #"matriculavel_online": details.get("Matriculável On-Line", "Não informado"),
            #"horario_flexivel": details.get("Horário Flexível da Turma", "Não informado"),
            #"permite_multiplas_aprovacoes": details.get("Permite Múltiplas Aprovações", "Não informado"),
            #"quantidade_avaliacoes": details.get("Quantidade de Avaliações", "Não informado"),
            "ementa": ementa or details.get("Ementa/Descrição", "Não informado")
            #"carga_horaria_total": details.get("Total de Carga Horária do Componente", "Não informado")
        }

    except Exception as e:
        if DEBUG:
            print(f"\n[ERRO] Falha ao coletar dados do componente {component_id}: {str(e)}")
        return {}

def processar_departamento(id_atual):
    """Processa um departamento com Extração Dinâmica de JSF e Prevenção de ViewExpiredException"""
    
    if id_atual == 0:
        return {"departamento_id": id_atual, "turmas": []}
        
    for tentativa in range(MAX_RETRIES):
        try:
            session = requests.Session()
            session.headers.update({
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
                'Connection': 'keep-alive',
                'Origin': 'https://sigaa.unb.br',
                'Referer': 'https://sigaa.unb.br/sigaa/public/turmas/listar.jsf'
            })

            time.sleep(random.uniform(*REQUEST_DELAY))

            # --- CORREÇÃO 1: INICIALIZA O COOKIE NA HOME ANTES DE TUDO ---
            session.get("https://sigaa.unb.br/sigaa/public/home.jsf", timeout=30)
            
            # PRIMEIRA REQUISIÇÃO (OBTER TOKENS E FORMULÁRIO)
            base_url = "https://sigaa.unb.br/sigaa/public/turmas/listar.jsf"
            response = session.get(base_url, timeout=30)
            
            if response.status_code != 200:
                raise requests.exceptions.RequestException(f"Status {response.status_code}")

            soup = BeautifulSoup(response.text, "html.parser")
            
            # --- CORREÇÃO 2: CAPTURA A URL EXATA DO ACTION DO FORMULÁRIO ---
            form_data = {}
            post_url = base_url # Fallback caso não ache a action
            form_turma = soup.find("form", {"id": "formTurma"})
            
            if form_turma:
                action_url = form_turma.get("action")
                if action_url:
                    post_url = f"https://sigaa.unb.br{action_url}" if action_url.startswith("/") else action_url

                for hidden in form_turma.find_all("input", type="hidden"):
                    name = hidden.get("name")
                    if name:
                        form_data[name] = hidden.get("value", "")

            botao_buscar = soup.find("input", attrs={"value": re.compile(r"^\s*Buscar\s*$", re.IGNORECASE)})
            buscar_nome = botao_buscar.get("name") if botao_buscar else "formTurma:j_id_jsp_1370969402_11"

            form_data.update({
                "formTurma:inputNivel": "G",
                "formTurma:inputDepto": str(id_atual), 
                "formTurma:inputAno": "2026", 
                "formTurma:inputPeriodo": "1",
                buscar_nome: "Buscar"
            })

            # --- CORREÇÃO 3: O PULO DO GATO (PAUSA PARA SINCRONIZAÇÃO DA SESSÃO) ---
            # Dá tempo ao servidor da UnB para propagar o seu ViewState antes de enviarmos o POST
            time.sleep(1.5)

            search_response = session.post(
                post_url, # Usa a URL que o próprio SIGAA mandou usar
                data=form_data, 
                timeout=60
            )

            results_soup = BeautifulSoup(search_response.text, "html.parser")

            # Detectar mensagens escondidas ou recusas silenciosas
            msg_sistema = results_soup.find(class_=re.compile(r"(info|erro)", re.IGNORECASE))
            if msg_sistema:
                texto_msg = msg_sistema.text.strip()
                if "nenhum" in texto_msg.lower() or "inválido" in texto_msg.lower() or "não encontrad" in texto_msg.lower():
                    if DEBUG:
                        print(f"\n[INFO] Depto {id_atual} vazio ou sem oferta: {texto_msg}")
                    return {"departamento_id": id_atual, "turmas": []}

            tables = results_soup.find_all("table", {"class": "listagem"})
            
            # Sistema de Debug Visual
            if not tables:
                if DEBUG:
                    Path("debug_html").mkdir(exist_ok=True)
                    debug_file = f"debug_html/erro_depto_{id_atual}.html"
                    with open(debug_file, "w", encoding="utf-8") as f:
                        f.write(search_response.text)
                    print(f"\n[FALHA SILENCIOSA] Depto {id_atual}: POST recusado. HTML salvo em {debug_file}")
                return {"departamento_id": id_atual, "turmas": []}

            turmas_depto = []

            for table_counter, table in enumerate(tables, 1):
                current_component_name = ""

                for row in table.find_all("tr"):
                    if "agrupador" in row.get("class", []):
                        link = row.find("a")
                        if link:
                            title_span = link.find("span", {"class": "tituloDisciplina"})
                            if title_span:
                                current_component_name = limpar_texto(title_span.text.strip())
                                continue

                    elif "linhaTitulo" not in row.get("class", []) and "agrupador" not in row.get("class", []):
                        cols = row.find_all("td")
                        
                        if len(cols) >= 8:
                            if current_component_name:
                                turma = {
                                    "codigo": current_component_name.split()[0],
                                    "nome": current_component_name,
                                    "turma": limpar_texto(cols[0].text),
                                    "docente": ((limpar_texto(cols[2].text)).split('('))[0],
                                    "horario": ((limpar_texto(cols[3].text)).split('('))[0],
                                    "qnt_vagas": limpar_texto(cols[5].text),
                                    "local": limpar_texto(cols[7].text)
                                }
                                turmas_depto.append(turma)

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
            session.close()

def carregar_ids_departamentos():
    """Carrega TODOS os 207 IDs do seu arquivo CSV"""
    try:
        import csv
        ids = []
        with open('departamentos_ID_unb.csv', 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file)
            for row in csv_reader:
                if row and row[0].isdigit():
                    print(f"Departamento ID: {row[0]}")
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
    #ids = ids[:3]
    #todos_ids = carregar_ids_departamentos()
    #ids = todos_ids[:3]
    if not ids:
        return

    todos_dados = []
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
    
    # Opcional: gerar CSV também
    try:
        # Achatando a lista para o CSV: extraindo cada turma de dentro do departamento
        lista_plana_turmas = []
        for depto in todos_dados_por_depto:
            id_depto = depto.get("departamento_id")
            for t in depto.get("turmas", []):
                t_copia = t.copy()
                t_copia["departamento_id"] = id_depto # Adiciona o ID do depto na linha da turma
                lista_plana_turmas.append(t_copia)

        df = pd.DataFrame(lista_plana_turmas)
        csv_path = os.path.join(OUTPUT_DIR, f"turmas_unb_{time.strftime('%Y%m%d')}_FULL.csv")
        df.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"Arquivo CSV gerado com sucesso: {csv_path}")
    except Exception as e:
        print(f"\n[AVISO] Falha ao gerar CSV: {str(e)}")

if __name__ == "__main__":
    main()
