import fitz  # PyMuPDF
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
    format='\b[%(levelname)s] %(message)s',
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
padrao_curso_alt = re.compile(r'^([A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+', re.MULTILINE | re.IGNORECASE)

# --- Padrão para curso no novo formato ---
padrao_curso_novo = re.compile(r'Curso:\s*\n([A-ZÀ-ÿ][A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*)/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+', re.MULTILINE | re.IGNORECASE)

# --- Padrões para novo formato SIGAA com PyMuPDF ---
# Captura nome da disciplina (linha separada) - mais flexível, incluindo hífens e outros caracteres
padrao_nome_disciplina = re.compile(
    r'^([A-ZÀ-ÿ][A-ZÀ-ÿ\s0-9\-]+(?:DE\s+[A-ZÀ-ÿ\s0-9\-]*)*(?:\s+[A-ZÀ-ÿ\s0-9\-]*)*)\s*$',
    re.MULTILINE | re.IGNORECASE
)

# Captura ano/período (cada campo em linha separada)
padrao_ano_periodo = re.compile(r'^(\d{4}\.\d)$', re.MULTILINE)

# Captura código da disciplina
padrao_codigo_disciplina = re.compile(r'^([A-Z]{2,}\d{3,})$', re.MULTILINE)

# Captura situação da disciplina
padrao_situacao = re.compile(r'^(MATR|APR|REP|REPF|REPMF|CANC|DISP|TRANC)$', re.MULTILINE)

# Captura menção
padrao_mencao = re.compile(r'^(SS|MS|MM|MI|II|SR|\-)$', re.MULTILINE)

# Captura turma (letras e números)
padrao_turma = re.compile(r'^([A-Z0-9]{1,3})$', re.MULTILINE)

# Captura carga horária
padrao_carga_horaria = re.compile(r'^(\d{1,3})$', re.MULTILINE)

# Captura frequência
padrao_frequencia = re.compile(r'^(\d{1,3}[,\.]\d+|--|\d{1,3})$', re.MULTILINE)

# Captura informações do professor com carga horária
padrao_professor = re.compile(
    r'(?:Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)?\s*([A-ZÀ-ÿ\s\.]+?)\s*\((\d+)h\)',
    re.IGNORECASE
)

# Padrão para símbolos especiais que indicam tipo de componente
padrao_simbolos = re.compile(r'^([*&#e@§%]+)\s*$', re.MULTILINE)



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

# --- Padrão específico para disciplinas pendentes SIGAA ---
padrao_pendentes_sigaa = re.compile(
    r'^\s+([A-ZÀ-Ÿ\sÇÃÕÁÉÍÓÚÂÊÎÔÛ0-9]+?)\s+(\d+)\s+h\s+([A-Z]{2,}\d{3,})(?:\s+(Matriculado|Matriculado em Equivalente))?$',
    re.MULTILINE | re.IGNORECASE
)

# --- Padrão para pendências (lista de status) ---
padrao_pendencias = re.compile(r'\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b', re.IGNORECASE)

# --- Padrão para matriz curricular específica do formato SIGAA ---
padrao_matriz_sigaa = re.compile(r'Ano/Período de Integralização[:\s]*(\d+/\d+)\s*-', re.MULTILINE | re.IGNORECASE)

# --- Padrão para currículo no novo formato ---
padrao_curriculo_novo = re.compile(r'Currículo:\s*\n(\d+/\d+)\s*-\s*(\d{4}\.\d)', re.MULTILINE | re.IGNORECASE)

# --- Padrão para suspensões ---
padrao_suspensoes = re.compile(r'Suspensões:\s*\n((?:\d{4}\.\d(?:\s*,\s*\d{4}\.\d)*)?)', re.MULTILINE | re.IGNORECASE)

def extract_structured_text(text_dict):
    """
    Extrai texto estruturado de um dicionário de texto do PyMuPDF
    Organiza os spans de texto por posição para formar linhas coerentes
    """
    if not text_dict or 'blocks' not in text_dict:
        return ""
    
    lines = []
    
    for block in text_dict['blocks']:
        if 'lines' not in block:
            continue
            
        for line in block['lines']:
            if 'spans' not in line:
                continue
                
            # Coletar todos os spans da linha ordenados por posição X
            spans = []
            for span in line['spans']:
                if 'text' in span and span['text'].strip():
                    spans.append({
                        'text': span['text'],
                        'x': span['bbox'][0],  # posição X
                        'y': span['bbox'][1],  # posição Y
                        'font': span.get('font', ''),
                        'size': span.get('size', 0)
                    })
            
            # Ordenar spans por posição X (da esquerda para direita)
            spans.sort(key=lambda s: s['x'])
            
            # Combinar spans em uma linha, adicionando espaços quando necessário
            line_text = ""
            last_x = 0
            
            for span in spans:
                text = span['text']
                x = span['x']
                
                # Adicionar espaçamento baseado na distância entre spans
                if line_text and x > last_x + 10:  # 10 pontos de distância mínima
                    # Calcular número aproximado de espaços baseado na distância
                    spaces_needed = max(1, int((x - last_x) / 6))  # ~6 pontos por espaço
                    line_text += " " * min(spaces_needed, 10)  # máximo 10 espaços
                
                line_text += text
                last_x = x + len(text) * 6  # estimativa da largura do texto
            
            if line_text.strip():
                lines.append((line['bbox'][1], line_text.strip()))  # (Y position, text)
    
    # Ordenar linhas por posição Y (de cima para baixo)
    lines.sort(key=lambda l: l[0])
    
    # Combinar todas as linhas
    return '\n'.join([line[1] for line in lines])

def normalizar(s):
    return unicodedata.normalize('NFKD', s).encode('ASCII', 'ignore').decode('ASCII').upper()

def extrair_curso(texto):
    """
    Extrai o nome do curso usando regex otimizado para formato PyMuPDF
    """
    # Tenta o padrão específico do novo formato estruturado
    match_curso_novo = padrao_curso_novo.search(texto)
    if match_curso_novo:
        curso = match_curso_novo.group(1).strip()
        print(f"[CURSO] Curso extraído (padrão novo): {curso}")
        return curso
    
    # Tenta o padrão alternativo (novo formato)
    match_curso_alt = padrao_curso_alt.search(texto)
    if match_curso_alt:
        curso = match_curso_alt.group(1).strip()
        print(f"[CURSO] Curso extraído (padrão alternativo): {curso}")
        return curso
    
    # Tenta o padrão original com regex
    match_curso = padrao_curso.search(texto)
    if match_curso:
        curso = match_curso.group(1).strip()
        # Limpa sufixos desnecessários como "/FCTE - BACHARELADO - DIURNO"
        curso = re.split(r'/|-', curso)[0].strip()
        print(f"[CURSO] Curso extraído (padrão original): {curso}")
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
        
        # Procura por linhas que parecem ser nomes de curso com o novo padrão
        if re.match(r'^[A-ZÀ-ÿ\s]+(?:DE\s+[A-ZÀ-ÿ\s]+)*/[A-Z]+ - [A-ZÀ-ÿ\s]+ - [A-ZÀ-ÿ]+', linha):
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

# Função para extrair suspensões
def extrair_suspensoes(texto):
    """
    Extrai as suspensões do histórico escolar
    Retorna uma lista com os períodos de suspensão
    """
    # Primeiro, tenta o padrão específico de suspensões
    match_suspensoes = padrao_suspensoes.search(texto)
    if match_suspensoes:
        suspensoes_str = match_suspensoes.group(1)
        if suspensoes_str and suspensoes_str.strip():
            # Divide as suspensões por vírgula e limpa espaços
            suspensoes = [s.strip() for s in suspensoes_str.split(',') if s.strip()]
            print(f"[SUSPENSÕES] Suspensões extraídas: {suspensoes}")
            return suspensoes
    
    # Fallback: busca linha por linha
    linhas = texto.splitlines()
    for i, linha in enumerate(linhas):
        norm = normalizar(linha)
        if "SUSPENSOES" in norm or "SUSPENSÃO" in norm:
            # Tenta extrair da mesma linha
            suspensoes_na_linha = re.findall(r'\d{4}\.\d', linha)
            if suspensoes_na_linha:
                print(f"[SUSPENSÕES] Suspensões extraídas (mesma linha): {suspensoes_na_linha}")
                return suspensoes_na_linha
            
            # Se não encontrar, tenta na próxima linha
            if i + 1 < len(linhas):
                prox = linhas[i + 1]
                suspensoes_prox = re.findall(r'\d{4}\.\d', prox)
                if suspensoes_prox:
                    print(f"[SUSPENSÕES] Suspensões extraídas (linha seguinte): {suspensoes_prox}")
                    return suspensoes_prox
    
    print("[AVISO] Suspensões não encontradas no PDF")
    return []

# Função para extrair matriz curricular
def extrair_matriz_curricular(texto):
    # Primeiro, tenta o padrão específico do novo formato estruturado
    match_curriculo_novo = padrao_curriculo_novo.search(texto)
    if match_curriculo_novo:
        matriz = match_curriculo_novo.group(2)  # Pega a parte ano.período
        print(f"[MATRIZ] Matriz Curricular extraída (padrão novo): {matriz}")
        return matriz
    
    linhas = texto.splitlines()
    
    # Segundo, tenta encontrar o padrão específico "número/número - ano.período"
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

def processar_disciplina_encontrada(nome, ano_periodo, turma, situacao, codigo, carga_h, freq, mencao, linhas, start_idx, disciplinas_list):
    """
    Processa uma disciplina encontrada e adiciona aos dados
    Retorna True se processada com sucesso, False se ignorada
    """
    
    # Ignorar matérias com menções II, MI e SR
    if mencao.upper() in ['II', 'MI', 'SR']:
        print(f"  -> Ignorando disciplina com menção {mencao}: {codigo} - {nome.strip()[:30]}...")
        return False
    
    # Procurar símbolos e professor nas próximas linhas
    simbolos = ""
    professor = ""
    carga_h_prof = ""
    
    for j in range(start_idx, min(len(linhas), start_idx + 4)):
        linha_extra = linhas[j].strip()
        
        # Procurar por símbolos
        match_simb = padrao_simbolos.search(linha_extra)
        if match_simb:
            simbolos = match_simb.group(1)
            continue
        
        # Procurar por professor
        match_prof = padrao_professor.search(linha_extra)
        if match_prof:
            professor = match_prof.group(1)
            carga_h_prof = match_prof.group(2)
            break
    
    # Usar a carga horária do professor se disponível, senão usar a da disciplina
    carga_final = carga_h_prof if carga_h_prof else carga_h
    
    disciplina_data = {
        "tipo_dado": "Disciplina Regular",
        "nome": limpar_nome_disciplina(nome.strip()),
        "status": situacao,
        "mencao": mencao if mencao != '-' else '-',
        "creditos": int(int(carga_final) / 15) if carga_final and carga_final.isdigit() else 0,
        "codigo": codigo,
        "carga_horaria": int(carga_final) if carga_final and carga_final.isdigit() else 0,
        "ano_periodo": ano_periodo,
        "prefixo": simbolos,
        "professor": limpar_nome_professor(professor.strip()) if professor else "",
        "turma": turma,
        "frequencia": freq if freq != '--' else None,
        "nota": None  # No novo formato, usa menção em vez de nota
    }
    disciplinas_list.append(disciplina_data)
    print(f"  -> Disciplina: {codigo} - {nome.strip()[:30]}... (Status: {situacao})")
    return True

def extrair_dados_academicos(texto_total):
    """
    Extrai todos os dados acadêmicos do texto usando regex patterns otimizados
    Funciona com ambos os formatos de histórico escolar
    
    Nota: Ignora automaticamente disciplinas com menções II, MI e SR:
    - II: Incomparável por Infrequência
    - MI: Média Insuficiente  
    - SR: Sem Rendimento
    """
    print("\n=== INICIANDO EXTRAÇÃO COM REGEX OTIMIZADO ===")
    
    # Debug: mostrar alguns trechos do texto para identificar o formato
    print("[DEBUG] Primeiras 500 chars do texto:")
    print(repr(texto_total[:500]))
    print("[DEBUG] Procurando por padrões de disciplinas...")
    
    # Extrair informações básicas
    curso = extrair_curso(texto_total)
    matriz_curricular = extrair_matriz_curricular(texto_total)
    suspensoes = extrair_suspensoes(texto_total)
    
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
    
    # Extrair disciplinas usando processamento linha por linha (mais eficiente)
    disciplinas_encontradas = 0
    disciplinas_ignoradas = 0
    
    print("[DISCIPLINAS] Processando novo formato SIGAA com PyMuPDF...")
    
    # Capturar dados de disciplinas linha por linha (novo formato estruturado)
    linhas = texto_total.splitlines()
    print(f"[DEBUG] Total de linhas a processar: {len(linhas)}")
    
    i = 0
    while i < len(linhas):
        if i % 100 == 0:  # Progress indicator every 100 lines
            print(f"[DEBUG] Processadas {i}/{len(linhas)} linhas...")
        
        linha = linhas[i].strip()
        
        # Primeiro, verificar se a linha atual é ano/período (padrão alternativo)
        ano_periodo_match = padrao_ano_periodo.search(linha)
        if ano_periodo_match and i + 7 < len(linhas):
            ano_periodo = ano_periodo_match.group(1)
            
            # Verificar se a próxima linha é nome da disciplina
            nome_match = padrao_nome_disciplina.search(linhas[i+1].strip())
            if nome_match:
                nome = nome_match.group(1)
                print(f"[DEBUG] Disciplina encontrada (padrão alternativo) na linha {i}: {repr(linha)} -> {repr(linhas[i+1])}")
                
                # Verificar o restante do padrão
                try:
                    # Linha i+2: turma
                    turma_match = padrao_turma.search(linhas[i+2].strip())
                    if not turma_match:
                        i += 1
                        continue
                    turma = turma_match.group(1)
                    
                    # Linha i+3: situação
                    situacao_match = padrao_situacao.search(linhas[i+3].strip())
                    if not situacao_match:
                        i += 1
                        continue
                    situacao = situacao_match.group(1)
                    
                    # Linha i+4: código
                    codigo_match = padrao_codigo_disciplina.search(linhas[i+4].strip())
                    if not codigo_match:
                        i += 1
                        continue
                    codigo = codigo_match.group(1)
                    
                    # Linha i+5: carga horária
                    carga_match = padrao_carga_horaria.search(linhas[i+5].strip())
                    if not carga_match:
                        i += 1
                        continue
                    carga_h = carga_match.group(1)
                    
                    # Linha i+6: frequência
                    freq_match = padrao_frequencia.search(linhas[i+6].strip())
                    if not freq_match:
                        i += 1
                        continue
                    freq = freq_match.group(1)
                    
                    # Linha i+7: menção
                    mencao_match = padrao_mencao.search(linhas[i+7].strip())
                    if not mencao_match:
                        i += 1
                        continue
                    mencao = mencao_match.group(1)
                    
                    # Processar disciplina encontrada
                    if not processar_disciplina_encontrada(nome, ano_periodo, turma, situacao, codigo, carga_h, freq, mencao, linhas, i+8, disciplinas):
                        disciplinas_ignoradas += 1
                    else:
                        disciplinas_encontradas += 1
                    
                    i += 8
                    continue
                    
                except (IndexError, AttributeError):
                    pass
        
        # Segundo, procurar por nome da disciplina (padrão original)
        match_nome = padrao_nome_disciplina.search(linha)
        if match_nome and i + 8 < len(linhas):  # Verificar se há linhas suficientes
            nome = match_nome.group(1)
            
            # Verificar se as próximas linhas seguem o padrão esperado
            try:
                # Linha i+1: ano/período
                ano_periodo_match = padrao_ano_periodo.search(linhas[i+1].strip())
                if not ano_periodo_match:
                    i += 1
                    continue
                ano_periodo = ano_periodo_match.group(1)
                
                # Linha i+2: turma
                turma_match = padrao_turma.search(linhas[i+2].strip())
                if not turma_match:
                    i += 1
                    continue
                turma = turma_match.group(1)
                
                # Linha i+3: situação
                situacao_match = padrao_situacao.search(linhas[i+3].strip())
                if not situacao_match:
                    i += 1
                    continue
                situacao = situacao_match.group(1)
                
                print(f"[DEBUG] Disciplina encontrada (padrão original) na linha {i}: {nome[:30]}...")
                
                # Linha i+4: código
                codigo_match = padrao_codigo_disciplina.search(linhas[i+4].strip())
                if not codigo_match:
                    i += 1
                    continue
                codigo = codigo_match.group(1)
                
                # Linha i+5: carga horária
                carga_match = padrao_carga_horaria.search(linhas[i+5].strip())
                if not carga_match:
                    i += 1
                    continue
                carga_h = carga_match.group(1)
                
                # Linha i+6: frequência
                freq_match = padrao_frequencia.search(linhas[i+6].strip())
                if not freq_match:
                    i += 1
                    continue
                freq = freq_match.group(1)
                
                # Linha i+7: menção
                mencao_match = padrao_mencao.search(linhas[i+7].strip())
                if not mencao_match:
                    i += 1
                    continue
                mencao = mencao_match.group(1)
                
                # Processar disciplina encontrada
                if not processar_disciplina_encontrada(nome, ano_periodo, turma, situacao, codigo, carga_h, freq, mencao, linhas, i+8, disciplinas):
                    disciplinas_ignoradas += 1
                else:
                    disciplinas_encontradas += 1
                
                # Pular para depois desta disciplina completa
                i += 8
                continue
                
            except (IndexError, AttributeError):
                # Se houver erro ao processar, continuar para próxima linha
                pass
        
        i += 1
    
    print(f"[DISCIPLINAS] Encontradas {disciplinas_encontradas} disciplinas regulares")
    if disciplinas_ignoradas > 0:
        print(f"[DISCIPLINAS] Ignoradas {disciplinas_ignoradas} disciplinas com menções II, MI ou SR")
    
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
        'numero_semestre': numero_semestre,
        'suspensoes': suspensoes
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
        # Tentar extração de texto com PyMuPDF usando posicionamento
        logger.info('Attempting text extraction with PyMuPDF positional extraction')
        pdf_bytes = pdf_file.read()
        pdf_file.seek(0)
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        
        logger.info(f'PDF has {doc.page_count} pages')
        
        # Extrair texto de todas as páginas usando posicionamento
        for page_num in range(doc.page_count):
            logger.info(f'Processing page {page_num + 1}')
            page = doc[page_num]
            
            # Extrair texto com informações de posição
            text_dict = page.get_text("dict")
            page_text = extract_structured_text(text_dict)
            
            if page_text:
                texto_total += page_text + "\n"
                logger.info(f'Extracted {len(page_text)} characters from page {page_num + 1}')
        
        doc.close()
        
        if not texto_total.strip():
            logger.info('No text extracted with PyMuPDF, attempting OCR')
            
            logger.error('OCR extraction failed, not available')
            return jsonify({'error': 'Nenhuma informação textual pôde ser extraída do PDF via PyMuPDF. O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'}), 422
        else:
            logger.info('Successfully extracted text using PyMuPDF')

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

    
    except Exception as pdf_error:
        # Handle PyMuPDF specific errors
        if "fitz" in str(type(pdf_error)) or "mupdf" in str(pdf_error).lower():
            error_msg = f'PDF read error: {str(pdf_error)}'
            logger.error(error_msg)
            return jsonify({'error': f'Erro ao ler o PDF. Certifique-se de que é um PDF válido e não está corrompido: {str(pdf_error)}'}), 400
    except Exception as e:
        error_msg = f'Unexpected error: {str(e)}'
        logger.error(error_msg)
        import traceback
        logger.error(traceback.format_exc())
        return jsonify({'error': f'Ocorreu um erro interno ao processar o PDF: {str(e)}'}), 500

if __name__ == '__main__':
    logger.info('Starting PDF parser service on port 3001')
    app.run(debug=True, port=3001)