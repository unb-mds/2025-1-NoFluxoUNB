import PyPDF2
import re
import json
import io
import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image # Importar a biblioteca Pillow (PIL)
from pdf2image import convert_from_bytes # Para converter PDF para imagem
import pytesseract # Para o OCR

app = Flask(__name__)
CORS(app)

# --- Configuração do Tesseract ---
# ATENÇÃO: Você PRECISA especificar o caminho para o executável do Tesseract-OCR
# Se você instalou o Tesseract em um local padrão, pode não precisar desta linha.
# Exemplo para Windows:
# pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
# Exemplo para Linux/macOS (se não estiver no PATH):
# pytesseract.pytesseract.tesseract_cmd = r'/usr/local/bin/tesseract'
# Descomente e ajuste a linha abaixo se o Tesseract for encontrado:
# pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'


# Padrões de Expressão Regular (Regex)
# --- Geral ---
padrao_ira = re.compile(r"IRA[:\s]+(\d+\.\d+)", re.IGNORECASE)
padrao_curriculo = r'(\d+/\d+(?:\s*-\s*\d{4}\.\d)?)'
padrao_pend = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")
padrao_natureza = re.compile(r'(\*|e|&|#|@|§|%)')

# --- Disciplinas Padrão (com professor) ---
padrao_status = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")
padrao_mencao = re.compile(r"\b(SS|MS|MM|MI|II|SR)\b")
padrao_horas = re.compile(r"\((.+?)h\)") # Ajustado para garantir 'h' de horas
padrao_codigo = re.compile(r"\b[A-Z]{2,}\d{3,}\b") # Códigos como FGA0133, LET0331

# --- Disciplinas CUMP (Cumpridas) ---
padrao_cump = re.compile(r"--\s+CUMP\b")
# Regex para extrair carga horária de matérias CUMP (o número antes de "100,0")
padrao_horas_cump = re.compile(r"\b\w+\d+\s+(\d+)\s+\d{1,3},\d\b") # Ex: LET0331 60 100,0


@app.route('/upload-pdf', methods=['POST'])
def upload_pdf():
    """
    Rota para receber e processar o arquivo PDF.
    Tenta extrair texto com PyPDF2, se falhar, usa OCR.
    Extrai IRA, currículo, pendências e dados de disciplinas do texto.
    """
    if 'pdf' not in request.files:
        print("Erro: Nenhum arquivo PDF enviado.")
        return jsonify({'error': 'Nenhum arquivo PDF enviado.'}), 400

    pdf_file = request.files['pdf']
    filename = pdf_file.filename
    print(f"Recebido arquivo: {filename}")

    # Tenta extrair a matrícula do nome do arquivo
    matricula = "desconhecida"
    if '_' in filename:
        try:
            matricula = filename.split('_', 1)[1].split('.')[0]
            print(f"Matrícula extraída: {matricula}")
        except IndexError:
            print("Aviso: Não foi possível extrair a matrícula do nome do arquivo.")

    texto_total = ""
    try:
        # Tentar extração de texto normal com PyPDF2 primeiro
        pdf_content_stream = io.BytesIO(pdf_file.read())
        # IMPORTANTE: Resetar o ponteiro do arquivo para o início para o OCR, se necessário
        pdf_file.seek(0) 
        leitor = PyPDF2.PdfReader(pdf_content_stream)
        
        # Tenta extrair texto de todas as páginas
        for i, pagina in enumerate(leitor.pages):
            pagina_texto = pagina.extract_text()
            if pagina_texto:
                texto_total += pagina_texto + "\n"
        
        if not texto_total.strip():
            print("PyPDF2 não encontrou texto. Tentando OCR...")
            # Se PyPDF2 não extraiu nada, tenta OCR
            images = convert_from_bytes(pdf_file.read(), dpi=300) # Converte PDF para imagens (300 DPI para melhor OCR)
            for i, image in enumerate(images):
                print(f"Aplicando OCR na página {i+1}...")
                # lang='por' especifica o idioma português para melhor precisão
                texto_total += pytesseract.image_to_string(image, lang='por') + "\n"
                
            if not texto_total.strip():
                print("Erro: OCR também não encontrou texto. O PDF pode ser uma imagem de baixa qualidade ou estar vazio.")
                return jsonify({'error': 'Nenhuma informação textual pôde ser extraída do PDF via PyPDF2 ou OCR. O PDF pode ser uma imagem de baixa qualidade, estar vazio ou corrompido.'}), 422
        else:
            print("Texto extraído com sucesso usando PyPDF2.")


        print("\n--- Texto Completo Extraído (Primeiras 500 chars) ---")
        print(texto_total[:500] + "..." if len(texto_total) > 500 else texto_total)
        print("----------------------------------------------------\n")

        disciplinas = [] # Lista para armazenar os dados extraídos das disciplinas
        lines = texto_total.splitlines()

        for i, linha in enumerate(lines):
            linha = linha.strip()
            if not linha: # Pula linhas vazias
                continue

            # print(f"Processando linha {i+1}: '{linha}'") # Descomente para depuração linha a linha

            # 1. Encontrar o IRA
            match_ira = padrao_ira.search(linha)
            if match_ira:
                ira = match_ira.group(1)
                disciplinas.append({"IRA": "IRA", "valor": ira})
                print(f"  -> IRA encontrado: {ira}")

            # 2. Encontrar o Currículo
            if "Currículo" in linha or "Ano/Período de Integralização" in linha:
                match_curriculo = re.search(padrao_curriculo, linha)
                if not match_curriculo and i + 1 < len(lines):
                    proxima_linha = lines[i + 1].replace('\xa0', ' ').strip()
                    proxima_linha = re.sub(r'\s+', ' ', proxima_linha)
                    match_curriculo = re.search(padrao_curriculo, proxima_linha)
                if match_curriculo:
                    curriculo = match_curriculo.group(1)
                    disciplinas.append({"tipo_dado": "Curriculo", "valor": curriculo})
                    print(f"  -> Currículo encontrado: {curriculo}")

            # 3. Encontrar pendências (geralmente uma lista de status em uma linha)
            match_pend = padrao_pend.findall(linha)
            if match_pend:
                disciplinas.append({"tipo_dado": "Pendencias", "valores": match_pend})
                print(f"  -> Pendências encontradas: {match_pend}")

            # 4. Processar linhas com prefixos de professor ou padrões de disciplina
            is_professor_line = linha.startswith("Dr.") or linha.startswith("MSc.") or linha.startswith("Dra.")

            if is_professor_line:
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
                        # Nova regex para capturar o nome da disciplina, lidando com formatos variados
                        # Tenta capturar tudo que pareça um nome, antes de números ou status no final da linha.
                        name_match = re.search(r'^(?:\d{4}\.\d\s+)?([\wÀ-Ÿ\s.&,()\-]+?)(?:\s+\d+\s*(?:APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP|--|—)?)?$', prev_line, re.IGNORECASE)
                        if name_match:
                            nome_disciplina = name_match.group(1).strip()
                            # Limpa potenciais caracteres não-alfabéticos que sobraram no início/fim do nome
                            nome_disciplina = re.sub(r'^\s*[^A-ZÀ-Ÿ\w]+|\s*[^A-ZÀ-Ÿ\w]+$', '', nome_disciplina).strip()
                        else:
                            # Fallback se o padrão mais específico não funcionar
                            fallback_name_match = re.search(r'^(?:\d{4}\.\d\s+)?(.+?)(?:\s+\d+)?(?:\s+(?:APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP|--|—))?$', prev_line, re.IGNORECASE)
                            if fallback_name_match:
                                nome_disciplina = fallback_name_match.group(1).strip()
                                nome_disciplina = re.sub(r'^\s*[^A-ZÀ-Ÿ\w]+|\s*[^A-ZÀ-Ÿ\w]+$', '', nome_disciplina).strip()
                            else:
                                nome_disciplina = prev_line # Último recurso: usa a linha anterior inteira
                    
                    disciplinas.append({
                        "tipo_dado": "Disciplina Regular",
                        "nome": nome_disciplina,
                        "status": status,
                        "mencao": mencao,
                        "creditos": creditos,
                        "codigo": codigo,
                        "carga_horaria": carga_horaria,
                        "natureza": natureza
                    })
                    print(f"  -> Disciplina Regular encontrada: '{nome_disciplina}' (Status: {status})")
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
                    # Limpa potenciais caracteres não-alfabéticos que sobraram no início/fim do nome
                    nome_materia_cump = re.sub(r'^\s*[^A-ZÀ-Ÿ\w]+|\s*[^A-ZÀ-Ÿ\w]+$', '', nome_materia_cump).strip()


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
        return jsonify({
            'message': 'PDF processado com sucesso!',
            'filename': filename,
            'matricula': matricula,
            'full_text': texto_total,
            'extracted_data': disciplinas
        })

    except pytesseract.TesseractNotFoundError:
        print("Erro: Tesseract OCR não encontrado. Por favor, instale o Tesseract-OCR.")
        print("Veja as instruções em: https://tesseract-ocr.github.io/tessdoc/Installation.html")
        return jsonify({'error': 'Tesseract OCR não encontrado no seu sistema. Por favor, instale-o seguindo as instruções.'}), 500
    except PyPDF2.errors.PdfReadError as e:
        print(f"Erro ao ler o PDF (PyPDF2): {str(e)}")
        return jsonify({'error': f'Erro ao ler o PDF. Certifique-se de que é um PDF válido e não está corrompido: {str(e)}'}), 400
    except Exception as e:
        print(f"Erro inesperado no servidor: {str(e)}")
        import traceback
        traceback.print_exc() # Imprime o stack trace completo para depuração
        return jsonify({'error': f'Ocorreu um erro interno ao processar o PDF: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(debug=True, port=3001)