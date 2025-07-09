import PyPDF2
import re
import json
import io
import os
import logging
import sys
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image # Importar a biblioteca Pillow (PIL)
from pdf2image import convert_from_bytes # Para converter PDF para imagem
from werkzeug.utils import secure_filename
import unicodedata
from datetime import datetime

# Configurar encoding UTF-8 para o console
if sys.platform.startswith('win'):
    import codecs
    sys.stdout = codecs.getwriter('utf-8')(sys.stdout.detach())
    sys.stderr = codecs.getwriter('utf-8')(sys.stderr.detach())

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s][%(levelname)s][PDF Parser] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Request logging middleware
@app.before_request
def log_request_info():
    logger.info('='*50)
    logger.info(f'Request Method: {request.method}')
    logger.info(f'Request URL: {request.url}')
    logger.info(f'Request Headers: {dict(request.headers)}')
    logger.info(f'Request Files: {request.files.keys() if request.files else "No files"}')
    logger.info('='*50)

# --- Configuração do Tesseract ---
tesseract_path = 'C:\\Program Files\\Tesseract-OCR\\tesseract.exe'
logger.info(f'Using Tesseract path: {tesseract_path}')

# Padrões de Expressão Regular (Regex) - Refatorados para trabalhar no texto completo
# --- Geral ---
padrao_ira = re.compile(r"IRA[:\s]+(\d+[\.,]\d+)", re.IGNORECASE)
padrao_mp = re.compile(r"MP[:\s]+(\d+[\.,]\d+)", re.IGNORECASE)
padrao_curriculo = re.compile(r'(\d{4}[\./]\d+(?:\s*-\s*\d{4}\.\d)?)', re.MULTILINE)
padrao_curso = re.compile(r'Curso[:\s]+([A-ZÀ-Ÿ\s/\\-]+?)(?:\s+Status:|$)', re.IGNORECASE | re.MULTILINE)

# --- Padrão alternativo para curso (formato novo) ---
padrao_curso_alt = re.compile(r'^([A-ZÀ-Ÿ\s]+(?:DE\s+[A-ZÀ-Ÿ\s]+)*)/[A-Z]+ - [A-ZÀ-Ÿ\s]+ - [A-ZÀ-Ÿ]+', re.MULTILINE | re.IGNORECASE)

# --- Padrão principal para disciplinas regulares (duas linhas) - Formato original ---
padrao_disciplina_linha1 = re.compile(
    r'(\d{4}\.\d)\s+([*&#e@§%]?)\s*([A-Z]{2,}\d{3,})\s+([A-ZÀ-Ÿ\s0-9]+?)\s*$',
    re.MULTILINE | re.IGNORECASE
)

# Linha 2: professor, carga horária, turma, frequência, nota, menção, situação
padrao_disciplina_linha2 = re.compile(
    r'(?:Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)?\s*([A-ZÀ-Ÿ\s\.]+?)\s*\((\d+)h\)\s*'
    r'(\d+)\s+(\d+|\-\-)\s+(\d+(?:,\d+)?|\-\-)\s+(SS|MS|MM|MI|II|SR|\-)\s+(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC)',
    re.IGNORECASE
)

# --- Novo padrão para formato alternativo (nome na primeira linha, dados na segunda) ---
padrao_disciplina_alt_linha1 = re.compile(
    r'(\d{4}\.\d)([A-ZÀ-Ÿ\s0-9]+(?:DE\s+[A-ZÀ-Ÿ\s0-9]*)*)\s*$',
    re.MULTILINE | re.IGNORECASE
)

padrao_disciplina_alt_linha2 = re.compile(
    r'(?:Dr\.|Dra\.|MSc\.|Prof\.)?\s*([A-ZÀ-Ÿ\s\.]+?)\s*\((\d+)h\)\s*'
    r'([A-Z0-9]+)\s+(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC)\s+([A-Z]{2,}\d{3,})\s+'
    r'(\d+)\s+(\d+(?:[,\.]\d+)?|\-\-)\s+(SS|MS|MM|MI|II|SR|\-)',
    re.IGNORECASE
)

# --- Padrão para disciplinas CUMP (formato: ano prefixo codigo nome carga -- -- - CUMP) ---
padrao_disciplina_cump = re.compile(
    r'(\d{4}\.\d)\s+([*&#e@§%]?)\s*([A-Z]{2,}\d{3,})\s+([A-ZÀ-Ÿ\s0-9]+?)\s+(\d+)\s+\-\-\s+\-\-\s+\-\s+CUMP',
    re.MULTILINE | re.IGNORECASE
)

# --- Padrão para equivalências ---
padrao_equivalencias = re.compile(
    r'Cumpriu\s+([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)\s*através\s*de\s*([A-Z]{2,}\d{3,})\s*-\s*([A-ZÀ-Ÿ\s0-9]+?)\s*\((\d+)h\)',
    re.MULTILINE | re.IGNORECASE
)

# --- Padrão para disciplinas pendentes (formato novo) ---
padrao_pendentes_novo = re.compile(
    r'^\s+([A-ZÀ-Ÿ\s0-9]+(?:DE\s+[A-ZÀ-Ÿ\s0-9]*)*)\s+(\d+)\s*h\s+([A-Z]{2,}\d{3,})(?:\s+(Matriculado|Matriculado em Equivalente))?',
    re.MULTILINE | re.IGNORECASE
)

# --- Padrão para pendências (lista de status) ---
padrao_pendencias = re.compile(r'\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b', re.IGNORECASE)

def normalizar(s):
    return unicodedata.normalize('NFKD', s).encode('ASCII', 'ignore').decode('ASCII').upper()

def extrair_curso(texto):
    """
    Extrai o nome do curso usando regex otimizado - funciona com ambos os formatos
    """
    # Tenta o padrão original com regex
    match_curso = padrao_curso.search(texto)
    if match_curso:
        curso = match_curso.group(1).strip()
        # Limpa sufixos desnecessários como "/FCTE - BACHARELADO - DIURNO"
        curso = re.split(r'/|-', curso)[0].strip()
        print(f"[CURSO] Curso extraído (padrão original): {curso}")
        return curso
    
    # Tenta o padrão alternativo (novo formato)
    match_curso_alt = padrao_curso_alt.search(texto)
    if match_curso_alt:
        curso = match_curso_alt.group(1).strip()
        print(f"[CURSO] Curso extraído (padrão alternativo): {curso}")
        return curso
    
    # Fallback: busca linha por linha como antes (caso regex não funcione)
    linhas = texto.splitlines()
    for linha in linhas:
        norm = normalizar(linha)
        if re.match(r'^CURSO\s*[:\-]', norm):
            curso = re.split(r'[:\-]', linha, maxsplit=1)[1].strip()
            curso = re.split(r'/|-', curso)[0].strip()
            print(f"[CURSO] Curso extraído (fallback): {curso}")
            return curso
        
        # Procura por linhas que parecem ser nomes de curso
        if re.match(r'^[A-ZÀ-Ÿ\s]+(?:DE\s+[A-ZÀ-Ÿ\s]+)*/[A-Z]+ - [A-ZÀ-Ÿ\s]+ - [A-ZÀ-Ÿ]+', linha):
            curso = linha.split('/')[0].strip()
            print(f"[CURSO] Curso extraído (busca direta): {curso}")
            return curso
    
    print("[AVISO] Curso não encontrado no PDF")
    return None

def limpar_nome_disciplina(nome):
    """
    Remove períodos e outros elementos desnecessários do nome da disciplina
    """
    if not nome:
        return nome
    
    nome_original = nome
    
    # Remove padrões de período como "2023.1", "2024.2", etc.
    nome_limpo = re.sub(r'^\d{4}\.\d\s*', '', nome)
    
    # Remove outros padrões comuns que podem aparecer no início
    nome_limpo = re.sub(r'^--\s*', '', nome_limpo)
    nome_limpo = re.sub(r'^--\s*', '', nome_limpo)
    
    # Remove apenas caracteres especiais do início e fim, preservando letras, números e espaços
    nome_limpo = re.sub(r'^[^\w\s]+|[^\w\s]+$', '', nome_limpo)
    
    # Remove espaços extras
    nome_limpo = re.sub(r'\s+', ' ', nome_limpo).strip()
    
    # Debug: mostrar quando o nome foi alterado
    if nome_original != nome_limpo:
        print(f"[LIMPEZA] Limpeza: '{nome_original}' -> '{nome_limpo}'")
    
    return nome_limpo

# Função para extrair matriz curricular
def extrair_matriz_curricular(texto):
    linhas = texto.splitlines()
    
    # Primeiro, tenta encontrar o padrão específico "número/número - ano.período"
    # que é o formato padrão da matriz curricular da UnB
    padrao_matriz_especifico = re.compile(r'(\d+/\d+\s*-\s*(\d{4}\.\d))', re.MULTILINE)
    match_especifico = padrao_matriz_especifico.search(texto)
    if match_especifico:
        matriz = match_especifico.group(2)  # Pega apenas a parte ano.período
        print(f"[MATRIZ] Matriz Curricular extraída (padrão específico): {matriz}")
        return matriz
    
    # Debug: mostrar todas as linhas que contêm 'CURRICULO' ou 'INTEGRALIZAÇÃO'
    for i, linha in enumerate(linhas):
        norm = normalizar(linha)
        if "CURRICULO" in norm or "INTEGRALIZACAO" in norm:
            print(f"[DEBUG MATRIZ] Linha {i}: {repr(linha)}")
            if i + 1 < len(linhas):
                print(f"[DEBUG MATRIZ] Próxima linha {i+1}: {repr(linhas[i+1])}")
    
    # Procura por linhas relacionadas à integralização ou currículo
    for i, linha in enumerate(linhas):
        norm = normalizar(linha)
        # Procura por 'CURRICULO' ou 'INTEGRALIZAÇÃO' na linha
        if "CURRICULO" in norm or "INTEGRALIZACAO" in norm:
            # Tenta extrair o padrão na mesma linha
            match = re.search(r'(\d{4}[\./]\d)', linha)
            if match:
                matriz = match.group(1).replace('/', '.')
                print(f"[MATRIZ] Matriz Curricular extraída: {matriz}")
                return matriz
            # Se não encontrar, tenta na próxima linha
            if i + 1 < len(linhas):
                prox = linhas[i + 1]
                match_prox = re.search(r'(\d{4}[\./]\d)', prox)
                if match_prox:
                    matriz = match_prox.group(1).replace('/', '.')
                    print(f"[MATRIZ] Matriz Curricular extraída (linha seguinte): {matriz}")
                    return matriz
    
    # Fallback: procura por linhas que contenham o padrão "número/número - ano.período"
    # mesmo sem contexto específico
    for linha in linhas:
        match_fallback = re.search(r'\d+/\d+\s*-\s*(\d{4}\.\d)', linha)
        if match_fallback:
            matriz = match_fallback.group(1)
            print(f"[MATRIZ] Matriz Curricular extraída (fallback): {matriz}")
            return matriz
    
    print("[AVISO] Matriz Curricular não encontrada no PDF")
    return None

def extrair_semestre_atual(disciplinas):
    """
    Extrai o semestre atual baseado nas disciplinas com status MATR ou Matriculado
    """
    semestres_matriculados = []
    
    # Procura por disciplinas com status de matrícula
    for disc in disciplinas:
        if isinstance(disc, dict) and disc.get('tipo_dado') == 'Disciplina Regular':
            status = disc.get('status', '').upper()
            ano_periodo = disc.get('ano_periodo', '')
            if status in ['MATR'] and ano_periodo:
                try:
                    # Converte para float para comparação (ex: 2024.1 -> 2024.1)
                    semestre_float = float(ano_periodo)
                    semestres_matriculados.append(semestre_float)
                except ValueError:
                    continue
        elif isinstance(disc, dict) and disc.get('tipo_dado') == 'Disciplina Pendente':
            status = disc.get('status', '').upper()
            observacao = disc.get('observacao', '').upper()
            if status == 'MATR' or 'MATRICULADO' in observacao:
                # Para disciplinas pendentes, usa o semestre atual
                hoje = datetime.now()
                semestre = 1 if hoje.month <= 6 else 2
                semestre_atual = f"{hoje.year}.{semestre}"
                try:
                    semestres_matriculados.append(float(semestre_atual))
                except ValueError:
                    continue
    
    # Retorna o semestre mais recente se houver algum
    if semestres_matriculados:
        semestre_atual = max(semestres_matriculados)
        return f"{semestre_atual:.1f}"  # Formata como string (ex: 2024.1)
    
    # Se não encontrar nenhum, retorna None
    return None

def calcular_numero_semestre(disciplinas):
    """
    Calcula o número do semestre baseado na quantidade de semestres onde houve conclusão de disciplinas
    Considera apenas semestres onde houve aprovação, reprovação ou cumprimento de disciplinas
    """
    if not disciplinas:
        return None
        
    # Conjunto para armazenar semestres únicos onde o aluno concluiu disciplinas
    semestres_cursados = set()
    
    for disc in disciplinas:
        if isinstance(disc, dict):
            status = disc.get('status', '').upper()
            ano_periodo = disc.get('ano_periodo', '')
            
            # Considera apenas disciplinas efetivamente concluídas
            # APR = Aprovado
            # REP/REPF/REPMF = Reprovado (por nota, falta ou média/falta)
            # CUMP = Cumpriu por equivalência
            if (status in ['APR', 'REP', 'REPF', 'REPMF', 'CUMP'] and 
                ano_periodo and ano_periodo.strip()):
                try:
                    semestres_cursados.add(ano_periodo)
                except:
                    continue
    
    # Debug: mostrar os semestres encontrados
    semestres_ordenados = sorted(list(semestres_cursados))
    print(f"[DEBUG] Semestres com disciplinas concluídas: {semestres_ordenados}")
    
    # Retorna o número de semestres únicos + 1 (para o semestre atual)
    if semestres_cursados:
        return len(semestres_cursados) + 1
    
    return 1  # Se não encontrou nenhum semestre cursado, assume primeiro semestre

def extrair_dados_academicos(texto_total):
    """
    Extrai todos os dados acadêmicos do texto usando regex patterns otimizados
    Funciona com ambos os formatos de histórico escolar
    """
    print("\n=== INICIANDO EXTRAÇÃO COM REGEX OTIMIZADO ===")
    
    # Debug: mostrar alguns trechos do texto para identificar o formato
    print("[DEBUG] Primeiras 500 chars do texto:")
    print(repr(texto_total[:500]))
    print("[DEBUG] Procurando por padrões de disciplinas...")
    
    # Extrair informações básicas
    curso = extrair_curso(texto_total)
    matriz_curricular = extrair_matriz_curricular(texto_total)
    
    # Extrair IRA e MP (aceita vírgula ou ponto como separador decimal)
    ira_match = padrao_ira.search(texto_total)
    ira = None
    if ira_match:
        ira_str = ira_match.group(1).replace(',', '.')
        ira = float(ira_str)
    print(f"[IRA] Extraído: {ira}")
    
    mp_match = padrao_mp.search(texto_total)
    mp = None
    if mp_match:
        mp_str = mp_match.group(1).replace(',', '.')
        mp = float(mp_str)
    print(f"[MP] Extraído: {mp}")
    
    disciplinas = []
    
    # Adicionar IRA como item se encontrado
    if ira:
        disciplinas.append({"IRA": "IRA", "valor": ira})
    
    # Extrair disciplinas regulares (processamento de duas linhas)
    linhas = texto_total.splitlines()
    disciplinas_encontradas = 0
    
    print("[DISCIPLINAS] Processando formato original...")
    for i, linha in enumerate(linhas):
        # Buscar linha 1 (disciplina) - formato original
        match_linha1 = padrao_disciplina_linha1.search(linha)
        if match_linha1 and i + 1 < len(linhas):
            # Buscar linha 2 (professor e dados) na próxima linha
            linha_seguinte = linhas[i + 1]
            match_linha2 = padrao_disciplina_linha2.search(linha_seguinte)
            
            if match_linha2:
                # Extrair dados da linha 1
                ano_periodo, prefixo, codigo, nome = match_linha1.groups()
                
                # Extrair dados da linha 2
                professor, carga_h, turma, freq, nota, mencao, situacao = match_linha2.groups()
                
                disciplina_data = {
                    "tipo_dado": "Disciplina Regular",
                    "nome": limpar_nome_disciplina(nome.strip()),
                    "status": situacao,
                    "mencao": mencao if mencao != '-' else '-',
                    "creditos": int(int(carga_h) / 15) if carga_h.isdigit() else 0,
                    "codigo": codigo,
                    "carga_horaria": int(carga_h) if carga_h.isdigit() else 0,
                    "ano_periodo": ano_periodo,
                    "prefixo": prefixo,
                    "professor": limpar_nome_professor(professor.strip()),
                    "turma": turma,
                    "frequencia": freq if freq != '--' else None,
                    "nota": nota if nota != '--' else None
                }
                disciplinas.append(disciplina_data)
                disciplinas_encontradas += 1
                print(f"  -> Disciplina (formato original): {codigo} - {nome.strip()[:30]}... (Status: {situacao})")
    
    # Se não encontrou disciplinas no formato original, tenta o formato alternativo
    if disciplinas_encontradas == 0:
        print("[DISCIPLINAS] Tentando formato alternativo...")
        
        # Debug: procurar por padrões que indicam o formato alternativo
        sample_lines = []
        for i, linha in enumerate(linhas[:20]):  # Primeiras 20 linhas para debug
            if re.search(r'\d{4}\.\d[A-ZÀ-Ÿ]', linha):
                sample_lines.append((i, linha))
        
        print(f"[DEBUG] Encontradas {len(sample_lines)} linhas com padrão alternativo nas primeiras 20:")
        for line_num, line_content in sample_lines[:3]:  # Mostrar apenas as primeiras 3
            print(f"  Linha {line_num}: {repr(line_content[:80])}")
        
        for i, linha in enumerate(linhas):
            # Buscar linha 1 (ano/período + nome da disciplina) - formato alternativo
            match_alt_linha1 = padrao_disciplina_alt_linha1.search(linha)
            if match_alt_linha1 and i + 1 < len(linhas):
                linha_seguinte = linhas[i + 1]
                
                print(f"[DEBUG] Linha {i}: {repr(linha[:80])}")
                print(f"[DEBUG] Linha {i+1}: {repr(linha_seguinte[:80])}")
                
                # Buscar linha 2 (professor, dados) na próxima linha
                match_alt_linha2 = padrao_disciplina_alt_linha2.search(linha_seguinte)
                
                if match_alt_linha2:
                    # Extrair dados da linha 1
                    ano_periodo, nome = match_alt_linha1.groups()
                    
                    # Extrair dados da linha 2
                    professor, carga_h, turma, situacao, codigo, carga_h2, freq, mencao = match_alt_linha2.groups()
                    
                    print(f"[DEBUG] Match encontrado: {codigo} - {nome[:30]}")
                    
                    disciplina_data = {
                        "tipo_dado": "Disciplina Regular",
                        "nome": limpar_nome_disciplina(nome.strip()),
                        "status": situacao,
                        "mencao": mencao if mencao != '-' else '-',
                        "creditos": int(int(carga_h) / 15) if carga_h.isdigit() else 0,
                        "codigo": codigo,
                        "carga_horaria": int(carga_h) if carga_h.isdigit() else 0,
                        "ano_periodo": ano_periodo,
                        "prefixo": "",
                        "professor": limpar_nome_professor(professor.strip()),
                        "turma": turma,
                        "frequencia": freq if freq != '--' else None,
                        "nota": None  # Nota não está disponível neste formato, usar mencao
                    }
                    disciplinas.append(disciplina_data)
                    disciplinas_encontradas += 1
                    print(f"  -> Disciplina (formato alternativo): {codigo} - {nome.strip()[:30]}... (Status: {situacao})")
                else:
                    print(f"[DEBUG] Linha 2 não fez match: {repr(linha_seguinte[:80])}")
    
    print(f"[DISCIPLINAS] Encontradas {disciplinas_encontradas} disciplinas regulares")
    
    # Extrair disciplinas CUMP
    disciplinas_cump = padrao_disciplina_cump.findall(texto_total)
    print(f"[CUMP] Encontradas {len(disciplinas_cump)} disciplinas CUMP")
    
    for disc in disciplinas_cump:
        ano_periodo, prefixo, codigo, nome, carga_h = disc
        
        disciplina_data = {
            "tipo_dado": "Disciplina CUMP",
            "nome": limpar_nome_disciplina(nome.strip()),
            "status": 'CUMP',
            "mencao": '-',
            "creditos": int(int(carga_h) / 15) if carga_h.isdigit() else 0,
            "codigo": codigo,
            "carga_horaria": int(carga_h) if carga_h.isdigit() else 0,
            "ano_periodo": ano_periodo,
            "prefixo": prefixo
        }
        disciplinas.append(disciplina_data)
        print(f"  -> CUMP: {codigo} - {nome.strip()[:30]}...")
    
    # Extrair disciplinas pendentes (formato novo)
    disciplinas_pendentes = padrao_pendentes_novo.findall(texto_total)
    print(f"[PENDENTES] Encontradas {len(disciplinas_pendentes)} disciplinas pendentes (formato novo)")
    
    for pend in disciplinas_pendentes:
        nome, carga_h, codigo = pend[:3]
        status_matricula = pend[3] if len(pend) > 3 else None
        
        status = 'MATR' if status_matricula else 'PENDENTE'
        
        disciplina_data = {
            "tipo_dado": "Disciplina Pendente",
            "nome": limpar_nome_disciplina(nome.strip()),
            "status": status,
            "mencao": '-',
            "creditos": int(int(carga_h) / 15) if carga_h.isdigit() else 0,
            "codigo": codigo,
            "carga_horaria": int(carga_h) if carga_h.isdigit() else 0,
            "ano_periodo": "",
            "prefixo": "",
            "observacao": status_matricula
        }
        disciplinas.append(disciplina_data)
        print(f"  -> Pendente: {codigo} - {nome.strip()[:30]}... (Status: {status})")
    
    # Extrair equivalências
    equivalencias = []
    equivalencias_match = padrao_equivalencias.findall(texto_total)
    print(f"[EQUIVALENCIAS] Encontradas {len(equivalencias_match)} equivalências")
    
    for eq in equivalencias_match:
        codigo_cumpriu, nome_cumpriu, ch_cumpriu, codigo_equivalente, nome_equivalente, ch_equivalente = eq
        equivalencias.append({
            "cumpriu": codigo_cumpriu,
            "nome_cumpriu": nome_cumpriu.strip(),
            "atraves_de": codigo_equivalente, 
            "nome_equivalente": nome_equivalente.strip(),
            "ch_cumpriu": ch_cumpriu,
            "ch_equivalente": ch_equivalente
        })
        print(f"  -> Equivalência: {codigo_cumpriu} ← {codigo_equivalente}")
    
    # Extrair pendências (apenas contar ocorrências)
    pendencias = padrao_pendencias.findall(texto_total)
    if pendencias:
        # Contar ocorrências de cada status
        from collections import Counter
        contagem_pendencias = Counter(pendencias)
        disciplinas.append({"tipo_dado": "Pendencias", "valores": dict(contagem_pendencias)})
        print(f"[PENDENCIAS] Encontradas: {dict(contagem_pendencias)}")
    
    # Extrair o semestre atual
    semestre_atual = extrair_semestre_atual(disciplinas)
    print(f"[SEMESTRE] Semestre atual extraído: {semestre_atual}")
    
    # Calcular o número do semestre baseado em semestres cursados
    numero_semestre = calcular_numero_semestre(disciplinas)
    print(f"[SEMESTRE] Número do semestre calculado: {numero_semestre}º semestre")
    
    print(f"=== EXTRAÇÃO CONCLUÍDA: {len(disciplinas)} itens extraídos ===\n")
    
    return {
        'disciplinas': disciplinas,
        'equivalencias': equivalencias,
        'curso': curso,
        'matriz_curricular': matriz_curricular,
        'media_ponderada': mp,
        'ira': ira,
        'semestre_atual': semestre_atual,
        'numero_semestre': numero_semestre
    }

def limpar_nome_professor(nome):
    """
    Limpa o nome do professor removendo títulos e formatação
    """
    if not nome:
        return nome
    
    # Remove títulos acadêmicos
    nome_limpo = re.sub(r'^(Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)\s*', '', nome, flags=re.IGNORECASE)
    
    # Remove caracteres especiais no final
    nome_limpo = re.sub(r'[^A-ZÀ-Ÿa-zà-ÿ\s]+$', '', nome_limpo)
    
    # Remove espaços extras
    nome_limpo = re.sub(r'\s+', ' ', nome_limpo).strip()
    
    return nome_limpo

@app.route('/upload-pdf', methods=['POST'])
def upload_pdf():
    """
    Rota para receber e processar o arquivo PDF.
    Tenta extrair texto com PyPDF2, se falhar, usa OCR.
    Extrai IRA, currículo, pendências e dados de disciplinas do texto.
    """
    logger.info('Received PDF upload request')
    
    if 'pdf' not in request.files:
        logger.error('No PDF file in request')
        return jsonify({'error': 'Nenhum arquivo PDF enviado.'}), 400

    pdf_file = request.files['pdf']
    filename = pdf_file.filename
    logger.info(f'Processing file: {filename}')
    logger.info(f'File content type: {pdf_file.content_type}')
    logger.info(f'File size: {len(pdf_file.read())} bytes')
    pdf_file.seek(0)  # Reset file pointer after reading size

    # Tenta extrair a matrícula do nome do arquivo
    matricula = "desconhecida"
    if '_' in filename:
        try:
            matricula = filename.split('_', 1)[1].split('.')[0]
            logger.info(f'Extracted matricula: {matricula}')
        except IndexError:
            logger.warning('Could not extract matricula from filename')

    texto_total = ""
    try:
        # Tentar extração de texto normal com PyPDF2 primeiro
        logger.info('Attempting text extraction with PyPDF2')
        pdf_content_stream = io.BytesIO(pdf_file.read())
        pdf_file.seek(0)
        leitor = PyPDF2.PdfReader(pdf_content_stream)
        
        logger.info(f'PDF has {len(leitor.pages)} pages')
        
        # Tenta extrair texto de todas as páginas
        for i, pagina in enumerate(leitor.pages):
            logger.info(f'Processing page {i+1}')
            pagina_texto = pagina.extract_text()
            if pagina_texto:
                texto_total += pagina_texto + "\n"
                logger.info(f'Extracted {len(pagina_texto)} characters from page {i+1}')
        
        if not texto_total.strip():
            logger.info('No text extracted with PyPDF2, attempting OCR')
            
            logger.error('OCR extraction failed, not available')
            return jsonify({'error': 'Nenhuma informação textual pôde ser extraída do PDF via PyPDF2. O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'}), 422
        else:
            logger.info('Successfully extracted text using PyPDF2')

        print("\n--- Texto Completo Extraído (Primeiras 500 chars) ---")
        print(texto_total[:500] + "..." if len(texto_total) > 500 else texto_total)
        print("----------------------------------------------------\n")

        # Extrair dados acadêmicos usando regex otimizado
        dados_extraidos = extrair_dados_academicos(texto_total)

        # Retorna os dados extraídos em formato JSON (mantendo a estrutura original)
        logger.info('PDF processing completed successfully')
        response_data = {
            'message': 'PDF processado com sucesso!',
            'filename': filename,
            'matricula': matricula,
            'curso_extraido': dados_extraidos['curso'],
            'matriz_curricular': dados_extraidos['matriz_curricular'],
            'media_ponderada': dados_extraidos['media_ponderada'],
            'frequencia_geral': None,  # Mantido para compatibilidade
            'full_text': texto_total,
            'extracted_data': dados_extraidos['disciplinas'],
            'equivalencias_pdf': dados_extraidos['equivalencias'],
            'semestre_atual': dados_extraidos['semestre_atual'],
            'numero_semestre': dados_extraidos['numero_semestre']
        }
        logger.info(f'Sending response with {len(dados_extraidos["disciplinas"])} extracted items')
        return jsonify(response_data)

    
    except PyPDF2.errors.PdfReadError as e:
        error_msg = f'PDF read error: {str(e)}'
        logger.error(error_msg)
        return jsonify({'error': f'Erro ao ler o PDF. Certifique-se de que é um PDF válido e não está corrompido: {str(e)}'}), 400
    except Exception as e:
        error_msg = f'Unexpected error: {str(e)}'
        logger.error(error_msg)
        import traceback
        logger.error(traceback.format_exc())
        return jsonify({'error': f'Ocorreu um erro interno ao processar o PDF: {str(e)}'}), 500

if __name__ == '__main__':
    logger.info('Starting PDF parser service on port 3001')
    app.run(debug=True, port=3001)