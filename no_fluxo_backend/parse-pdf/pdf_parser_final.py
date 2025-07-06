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
import pytesseract # Para o OCR
from werkzeug.utils import secure_filename
import unicodedata

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
pytesseract.pytesseract.tesseract_cmd = tesseract_path

# Padrões de Expressão Regular (Regex)
# --- Geral ---
padrao_ira = re.compile(r"IRA[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_curriculo = r'(\d+/\d+(?:\s*-\s*\d{4}\.\d)?)'
padrao_pend = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")
padrao_natureza = re.compile(r'(\*|e|&|#|@|§|%)')

# --- Novos padrões para informações adicionais ---
padrao_media_ponderada = re.compile(r"(?:MP|MEDIA PONDERADA)[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_frequencia = re.compile(r"(?:FREQ|FREQUENCIA)[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_matriz_curricular = re.compile(r"(?:MATRIZ|CURRICULO)[:\s]+([A-ZÀ-Ÿ\s\d\.\-]+?)(?:\n|$)", re.IGNORECASE)
padrao_professor = re.compile(r"^(?:Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)\s+([A-ZÀ-Ÿ\s\.]+?)(?:\s|$)", re.IGNORECASE)

# --- Extração de Curso ---
padrao_curso = re.compile(r'CURSO[:\s]+([A-ZÀ-Ÿ\s/\\-]+)', re.IGNORECASE)

# --- Disciplinas Padrão (com professor) ---
padrao_status = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")
padrao_mencao = re.compile(r"\b(SS|MS|MM|MI|II|SR)\b")
padrao_horas = re.compile(r"\((.+?)h\)") # Ajustado para garantir 'h' de horas
padrao_codigo = re.compile(r"\b[A-Z]{2,}\d{3,}\b") # Códigos como FGA0133, LET0331

# --- Disciplinas CUMP (Cumpridas) ---
padrao_cump = re.compile(r"--\s+CUMP\b")
# Regex para extrair carga horária de matérias CUMP (o número antes de "100,0")
padrao_horas_cump = re.compile(r"\b\w+\d+\s+(\d+)\s+\d{1,3},\d\b") # Ex: LET0331 60 100,0

def normalizar(s):
    return unicodedata.normalize('NFKD', s).encode('ASCII', 'ignore').decode('ASCII').upper()

def extrair_curso(texto):
    linhas = texto.splitlines()
    print("==== DEBUG: Primeiras 30 linhas do PDF extraído ====")
    for idx, linha in enumerate(linhas[:30]):
        print(f"{idx}: {repr(linha)}")
    print("====================================================")
    # 1. Tenta padrão tradicional (com ou sem acento, com espaços)
    for linha in linhas:
        print(f"Testando linha para CURSO: {repr(linha)}")
        norm = normalizar(linha)
        # Aceita 'CURSO:', 'CURSO :', 'CURSO-', etc.
        if re.match(r'^CURSO\s*[:\-]', norm):
            # Pega tudo depois do primeiro ':' ou '-'
            curso = re.split(r'[:\-]', linha, maxsplit=1)[1].strip()
            # Limpa sufixos após / ou -
            curso = re.split(r'/|-', curso)[0].strip()
            print(f"[CURSO] Curso extraído: {curso}")
            return curso
    # 2. Tenta padrão UnB: linha após 'DADOS DO VINCULO DO(A) DISCENTE'
    for i, linha in enumerate(linhas):
        print(f"Testando linha para VÍNCULO: {repr(linha)}")
        if "DADOS DO VINCULO DO(A) DISCENTE" in normalizar(linha):
            trecho = '\n'.join(linhas[i:i+40])
            print("--- Trecho após bloco de vínculo ---")
            print(trecho[:2000])
            print("------------------------------------")
            for j in range(i+1, min(i+10, len(linhas))):
                prox = linhas[j].strip()
                if prox and prox.isupper() and len(prox) > 10:
                    curso = re.split(r'/|-', prox)[0].strip()
                    print(f"[CURSO] Curso extraído (padrão UnB): {curso}")
                    return curso
                if prox and len(prox) > 15:
                    curso = re.split(r'/|-', prox)[0].strip()
                    print(f"[CURSO] Curso extraído (padrão UnB flex): {curso}")
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

def extrair_nome_professor(linha):
    """
    Extrai o nome do professor da linha
    """
    match_professor = padrao_professor.search(linha)
    if match_professor:
        nome_professor = match_professor.group(1).strip()
        # Remove títulos acadêmicos que podem ter ficado
        nome_limpo = re.sub(r'^(Dr\.|Dra\.|MSc\.|Prof\.|Professor|Professora)\s*', '', nome_professor, flags=re.IGNORECASE)
        return nome_limpo.strip()
    return None

# Função para extrair matriz curricular
def extrair_matriz_curricular(texto):
    linhas = texto.splitlines()
    # Debug: mostrar todas as linhas que contêm 'CURRICULO'
    for i, linha in enumerate(linhas):
        if "CURRICULO" in normalizar(linha):
            print(f"[DEBUG MATRIZ] Linha {i}: {repr(linha)}")
            if i + 1 < len(linhas):
                print(f"[DEBUG MATRIZ] Próxima linha {i+1}: {repr(linhas[i+1])}")
    for i, linha in enumerate(linhas):
        norm = normalizar(linha)
        # Procura por 'CURRICULO' na linha
        if "CURRICULO" in norm:
            # Tenta extrair o padrão na mesma linha
            match = re.search(r'(\d{4}\.\d)', linha)
            if match:
                matriz = match.group(1)
                print(f"[MATRIZ] Matriz Curricular extraída: {matriz}")
                return matriz
            # Se não encontrar, tenta na próxima linha
            if i + 1 < len(linhas):
                prox = linhas[i + 1]
                match_prox = re.search(r'(\d{4}\.\d)', prox)
                if match_prox:
                    matriz = match_prox.group(1)
                    print(f"[MATRIZ] Matriz Curricular extraída (linha seguinte): {matriz}")
                    return matriz
    print("[AVISO] Matriz Curricular não encontrada no PDF")
    return None

def extrair_media_ponderada(texto):
    linhas = texto.splitlines()
    for linha in linhas:
        if "MP" in normalizar(linha):
            # Busca o padrão MP: número
            match = re.search(r'MP[:\s]*([0-9]+[.,][0-9]+)', linha)
            if match:
                mp = match.group(1).replace(',', '.')
                print(f"[MEDIA] Média Ponderada extraída: {mp}")
                return float(mp)
    print("[AVISO] Média Ponderada não encontrada")
    return None

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
            # Se PyPDF2 não extraiu nada, tenta OCR
            images = convert_from_bytes(pdf_file.read(), dpi=300)
            logger.info(f'Converted PDF to {len(images)} images for OCR')
            
            for i, image in enumerate(images):
                logger.info(f'Applying OCR to page {i+1}')
                page_text = pytesseract.image_to_string(image, lang='por')
                texto_total += page_text + "\n"
                logger.info(f'Extracted {len(page_text)} characters via OCR from page {i+1}')
                
            if not texto_total.strip():
                logger.error('OCR extraction failed - no text found')
                return jsonify({'error': 'Nenhuma informação textual pôde ser extraída do PDF via PyPDF2 ou OCR. O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'}), 422
        else:
            logger.info('Successfully extracted text using PyPDF2')

        print("\n--- Texto Completo Extraído (Primeiras 500 chars) ---")
        print(texto_total[:500] + "..." if len(texto_total) > 500 else texto_total)
        print("----------------------------------------------------\n")

        # Extrair curso do texto
        curso_extraido = extrair_curso(texto_total)

        # Variáveis para informações gerais do histórico
        matriz_curricular = extrair_matriz_curricular(texto_total)
        media_ponderada = extrair_media_ponderada(texto_total)
        frequencia_geral = None
        
        disciplinas = [] # Lista para armazenar os dados extraídos das disciplinas
        lines = texto_total.splitlines()
        ultima_materia = None
        for i, linha in enumerate(lines):
            linha = linha.strip()
            if not linha:
                continue

            # 1. Encontrar o IRA
            match_ira = padrao_ira.search(linha)
            if match_ira:
                ira = match_ira.group(1)
                disciplinas.append({"IRA": "IRA", "valor": ira})
                print(f"  -> IRA encontrado: {ira}")

            # 6. Encontrar pendências (geralmente uma lista de status em uma linha)
            match_pend = padrao_pend.findall(linha)
            if match_pend:
                disciplinas.append({"tipo_dado": "Pendencias", "valores": match_pend})
                print(f"  -> Pendências encontradas: {match_pend}")

            # 3. Detectar linha de matéria (ex: 2022.2  & CIC0004  ALGORITMOS E PROGRAMAÇÃO DE COMPUTADORES)
            match_materia = re.match(r'^(\d{4}\.\d)\s+([&*#e@§%]?)\s*([A-Z]{2,}\d{3,})\s+(.+)$', linha)
            if match_materia:
                ultima_materia = {
                    "ano_periodo": match_materia.group(1),
                    "codigo": match_materia.group(3),
                    "nome": limpar_nome_disciplina(match_materia.group(4)),
                    "prefixo": match_materia.group(2)
                }
                continue

            # 4. Processar linhas com prefixos de professor ou padrões de disciplina
            is_professor_line = linha.startswith("Dr.") or linha.startswith("MSc.") or linha.startswith("Dra.")

            if is_professor_line and ultima_materia:
                nome_professor = extrair_nome_professor(linha)
                match_status = padrao_status.search(linha)
                match_mencao = padrao_mencao.findall(linha)
                match_horas = padrao_horas.search(linha)
                status = match_status.group(1) if match_status else None
                mencao = match_mencao[-1] if match_mencao else "-"
                carga_horaria = int(match_horas.group(1)) if match_horas else None
                creditos = int(carga_horaria / 15) if carga_horaria else None
                disciplina_data = {
                    "tipo_dado": "Disciplina Regular",
                    "nome": ultima_materia["nome"],
                    "status": status,
                    "mencao": mencao,
                    "creditos": creditos,
                    "codigo": ultima_materia["codigo"],
                    "carga_horaria": carga_horaria,
                    "ano_periodo": ultima_materia["ano_periodo"],
                    "prefixo": ultima_materia["prefixo"]
                }
                if nome_professor:
                    disciplina_data["professor"] = nome_professor
                    print(f"    [PROFESSOR] Professor: {nome_professor}")
                disciplinas.append(disciplina_data)
                print(f"  -> Disciplina Regular encontrada: '{ultima_materia['nome']}' (Status: {status})")
                ultima_materia = None
                continue

            # 5. Processar disciplinas com status 'CUMP'
            elif padrao_cump.search(linha):
                match_padrao_horas_cump = padrao_horas_cump.search(linha)
                match_codigo = padrao_codigo.search(linha)
                nome_materia_cump = "Nome da Disciplina CUMP N/A"
                carga_horaria = 0
                codigo = "Código CUMP N/A"
                creditos_cump = 0
                cump_name_match = re.search(r"^(?:--\s*|\d{4}\.\d\s*)(.*?)(?:\s+--|\s+—)\s*CUMP", linha, re.IGNORECASE)
                if cump_name_match:
                    nome_materia_cump = limpar_nome_disciplina(cump_name_match.group(1).strip())
                if match_padrao_horas_cump:
                    try:
                        carga_horaria = int(match_padrao_horas_cump.group(1))
                        creditos_cump = int(carga_horaria / 15)
                    except ValueError:
                        print(f"  -> Aviso: Carga horária CUMP inválida na linha: {linha}")
                if match_codigo:
                    codigo = match_codigo.group()
                if nome_materia_cump != "Nome da Disciplina CUMP N/A" or codigo != "Código CUMP N/A":
                    disciplinas.append({
                        "tipo_dado": "Disciplina CUMP",
                        "nome": nome_materia_cump,
                        "status": 'CUMP',
                        "mencao": '-',
                        "creditos": creditos_cump,
                        "codigo": codigo,
                        "carga_horaria": carga_horaria
                    })
                    print(f"  -> Disciplina CUMP encontrada: '{nome_materia_cump}' (Carga Horária: {carga_horaria})")

        print("\n--- Fim do processamento de linhas ---")
        print(f"Total de itens extraídos: {len(disciplinas)}")

        # Retorna os dados extraídos em formato JSON
        logger.info('PDF processing completed successfully')
        response_data = {
            'message': 'PDF processado com sucesso!',
            'filename': filename,
            'matricula': matricula,
            'curso_extraido': curso_extraido,
            'matriz_curricular': matriz_curricular,
            'media_ponderada': media_ponderada,
            'frequencia_geral': frequencia_geral,
            'full_text': texto_total,
            'extracted_data': disciplinas
        }
        logger.info(f'Sending response with {len(disciplinas)} extracted items')
        return jsonify(response_data)

    except pytesseract.TesseractNotFoundError as e:
        error_msg = f'Tesseract not found error: {str(e)}'
        logger.error(error_msg)
        return jsonify({'error': 'Tesseract OCR não encontrado no seu sistema. Por favor, instale-o seguindo as instruções.'}), 500
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