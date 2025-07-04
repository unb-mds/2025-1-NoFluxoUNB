import PyPDF2
import re
import json
import io
import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image # Importar a biblioteca Pillow (PIL)
from pdf2image import convert_from_bytes # Para converter PDF para imagem
import pytesseract # Para o OCR
from werkzeug.utils import secure_filename
import unicodedata

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
padrao_media_ponderada = re.compile(r"(?:MP|MÉDIA PONDERADA|MEDIA PONDERADA)[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_frequencia = re.compile(r"(?:FREQ|FREQUÊNCIA|FREQUENCIA)[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_matriz_curricular = re.compile(r"(?:MATRIZ|CURRÍCULO|CURRICULO)[:\s]+([A-ZÀ-Ÿ\s\d\.\-]+?)(?:\n|$)", re.IGNORECASE)
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
    # 1. Tenta padrão tradicional
    for linha in linhas:
        if re.match(r'^\s*CURSO\s*:', normalizar(linha)):
            curso = linha.split(":", 1)[1].strip()
            print(f"🎓 Curso extraído: {curso}")
            return curso
    # 2. Tenta padrão UnB: linha após 'DADOS DO VINCULO DO(A) DISCENTE'
    for i, linha in enumerate(linhas):
        if "DADOS DO VINCULO DO(A) DISCENTE" in normalizar(linha):
            # Mostra as próximas 1000 caracteres para debug visual
            trecho = '\n'.join(linhas[i:i+20])
            print("--- Trecho após bloco de vínculo ---")
            print(trecho[:1000])
            print("------------------------------------")
            # Pega a próxima linha não vazia
            for j in range(i+1, min(i+10, len(linhas))):
                prox = linhas[j].strip()
                if prox and prox.isupper() and len(prox) > 10:
                    curso = prox.split('/')[0].strip() if '/' in prox else prox
                    print(f"🎓 Curso extraído (padrão UnB): {curso}")
                    return curso
                # Se não for tudo maiúsculo, mas for longa, ainda pode ser o curso
                if prox and len(prox) > 15:
                    curso = prox.split('/')[0].strip() if '/' in prox else prox
                    print(f"🎓 Curso extraído (padrão UnB flex): {curso}")
                    return curso
    print("⚠️ Curso não encontrado no PDF")
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
    nome_limpo = re.sub(r'^—\s*', '', nome_limpo)
    
    # Remove apenas caracteres especiais do início e fim, preservando letras, números e espaços
    nome_limpo = re.sub(r'^[^\w\s]+|[^\w\s]+$', '', nome_limpo)
    
    # Remove espaços extras
    nome_limpo = re.sub(r'\s+', ' ', nome_limpo).strip()
    
    # Debug: mostrar quando o nome foi alterado
    if nome_original != nome_limpo:
        print(f"🔧 Limpeza: '{nome_original}' → '{nome_limpo}'")
    
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
    """
    Extrai a matriz curricular do texto do PDF no formato 'YYYY.N' (ex: 2017.1),
    procurando nas linhas 'Currículo:' e 'Ano/Período de Integralização:'.
    """
    for linha in texto.splitlines():
        norm = normalizar(linha)
        if norm.startswith("CURRICULO:") or norm.startswith("ANO/PERIODO DE INTEGRALIZACAO:"):
            match = re.search(r'(\d{4}\.\d)', linha)
            if match:
                matriz = match.group(1)
                print(f"📋 Matriz Curricular extraída: {matriz}")
                return matriz
    print("⚠️ Matriz Curricular não encontrada no PDF")
    return None

def extrair_media_ponderada(texto):
    """
    Extrai a média ponderada (MP) do texto do PDF.
    """
    padrao_mp = re.compile(r'MP[:\s]*([0-9]+[.,][0-9]+)', re.IGNORECASE)
    match_mp = padrao_mp.search(texto)
    if match_mp:
        mp = match_mp.group(1).replace(',', '.')
        print(f"📊 Média Ponderada extraída: {mp}")
        return float(mp)
    print("⚠️ Média Ponderada não encontrada")
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

        for i, linha in enumerate(lines):
            linha = linha.strip()
            if not linha: # Pula linhas vazias
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

            # 4. Processar linhas com prefixos de professor ou padrões de disciplina
            is_professor_line = linha.startswith("Dr.") or linha.startswith("MSc.") or linha.startswith("Dra.")

            if is_professor_line:
                # Extrair nome do professor
                nome_professor = extrair_nome_professor(linha)
                
                # Tenta extrair da linha atual
                match_status = padrao_status.search(linha)
                match_mencao = padrao_mencao.findall(linha)
                match_codigo = padrao_codigo.search(linha)
                match_horas = padrao_horas.search(linha) # Usar search para pegar o primeiro match
                match_natureza = padrao_natureza.findall(linha)

                if match_status and match_codigo and match_horas:
                    status = match_status.group(1)
                    mencao = match_mencao[-1] if match_mencao else "-"
                    codigo = match_codigo.group()
                    carga_horaria = int(match_horas.group(1))
                    creditos = int(carga_horaria / 15)
                    natureza = match_natureza[-1] if match_natureza else " "
                    

                    nome_disciplina = "Nome da Disciplina N/A"
                    if i - 1 >= 0:
                        prev_line = lines[i - 1].strip()
                        # Regex melhorada para capturar o nome da disciplina incluindo números
                        # Captura tudo até encontrar status no final da linha
                        name_match = re.search(r'^(?:\d{4}\.\d\s+)?([\wÀ-Ÿ\s.&,()\-\d]+?)(?:\s+(?:APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP|--|—))?$', prev_line, re.IGNORECASE)
                        if name_match:
                            nome_disciplina = name_match.group(1).strip()
                            # Aplica a função de limpeza para remover períodos e outros elementos
                            nome_disciplina = limpar_nome_disciplina(nome_disciplina)
                        else:
                            # Fallback se o padrão mais específico não funcionar
                            fallback_name_match = re.search(r'^(?:\d{4}\.\d\s+)?(.+?)(?:\s+(?:APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP|--|—))?$', prev_line, re.IGNORECASE)
                            if fallback_name_match:
                                nome_disciplina = fallback_name_match.group(1).strip()
                                # Aplica a função de limpeza para remover períodos e outros elementos
                                nome_disciplina = limpar_nome_disciplina(nome_disciplina)
                            else:
                                nome_disciplina = prev_line # Último recurso: usa a linha anterior inteira
                                # Aplica a função de limpeza mesmo no fallback
                                nome_disciplina = limpar_nome_disciplina(nome_disciplina)
                    
                    disciplina_data = {
                        "tipo_dado": "Disciplina Regular",
                        "nome": nome_disciplina,
                        "status": status,
                        "mencao": mencao,
                        "creditos": creditos,
                        "codigo": codigo,
                        "carga_horaria": carga_horaria,
                        "natureza": natureza
                    }
                    
                    # Adicionar professor se encontrado
                    if nome_professor:
                        disciplina_data["professor"] = nome_professor
                        print(f"    👨‍🏫 Professor: {nome_professor}")
                    
                    disciplinas.append(disciplina_data)
                    print(f"  -> Disciplina Regular encontrada: '{nome_disciplina}' (Status: {status})")
                    
                    # Debug: verificar se a disciplina contém números
                    if re.search(r'\d', nome_disciplina):
                        print(f"    📊 Disciplina com números: '{nome_disciplina}'")
                # else:
                    # print(f"  -> Linha de professor, mas dados insuficientes para disciplina regular. Status: {match_status}, Codigo: {match_codigo}, Horas: {match_horas}")

            # 5. Processar disciplinas com status 'CUMP'
            elif padrao_cump.search(linha):
                match_padrao_horas_cump = padrao_horas_cump.search(linha)
                match_codigo = padrao_codigo.search(linha)

                nome_materia_cump = "Nome da Disciplina CUMP N/A"
                carga_horaria = 0
                codigo = "Código CUMP N/A"
                creditos_cump = 0

                # Nova regex para capturar o nome da matéria CUMP
                # Lida com '-- NOME -- CUMP' ou 'ANO.PERÍODO NOME -- CUMP'
                cump_name_match = re.search(r"^(?:--\s*|\d{4}\.\d\s*)(.*?)(?:\s+--|\s+—)\s*CUMP", linha, re.IGNORECASE)
                if cump_name_match:
                    nome_materia_cump = cump_name_match.group(1).strip()
                    # Aplica a função de limpeza para remover períodos e outros elementos
                    nome_materia_cump = limpar_nome_disciplina(nome_materia_cump)


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
                # else:
                    # print(f"  -> Linha CUMP, mas nome ou código não encontrados: '{linha}'")

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