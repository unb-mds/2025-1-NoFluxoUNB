# PDF Parser com OCR

Esta é uma versão alternativa do parser de PDF que usa **PyMuPDF** e **pytesseract** para extrair texto de PDFs através de OCR (Optical Character Recognition).

## Quando usar esta versão

Use esta versão quando:
- O PDF original é baseado em imagens (escaneado)
- O PDF tem problemas de codificação de texto
- A versão padrão (`pdf_parser_final.py`) não consegue extrair texto adequadamente
- Você precisa de maior precisão na extração de texto de documentos acadêmicos

## Pré-requisitos

### 1. Tesseract OCR

**Windows:**
```bash
# Baixe e instale o Tesseract do repositório oficial:
# https://github.com/UB-Mannheim/tesseract/wiki
# O instalador padrão instala em: C:\Program Files\Tesseract-OCR\tesseract.exe
```

**macOS:**
```bash
brew install tesseract
brew install tesseract-lang  # Para suporte a português
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install tesseract-ocr
sudo apt install tesseract-ocr-por  # Para suporte a português
```

### 2. Dependências Python

```bash
pip install -r requirements_ocr.txt
```

## Como usar

### 1. Executar o servidor

```bash
python pdf_parser_ocr.py
```

O servidor será iniciado na porta **3001** (mesma porta do parser original).

### 2. Fazer upload do PDF

```bash
curl -X POST \
  http://localhost:3001/upload-pdf \
  -H 'Content-Type: multipart/form-data' \
  -F 'pdf=@historico_escolar.pdf'
```

## Características do OCR Parser

### Vantagens
- ✅ Funciona com PDFs escaneados/baseados em imagem
- ✅ Maior precisão para documentos acadêmicos
- ✅ Suporte a caracteres especiais em português
- ✅ Mesma API e formato de resposta do parser original
- ✅ Detecção automática do caminho do Tesseract

### Limitações
- ⚠️ Mais lento que a extração direta de texto
- ⚠️ Requer instalação do Tesseract OCR
- ⚠️ Pode ter menor precisão em documentos de baixa qualidade
- ⚠️ Consome mais CPU e memória

## Configurações Avançadas

### Configuração do Tesseract

O parser tenta detectar automaticamente o Tesseract nos seguintes locais:

1. `tesseract` (comando do PATH)
2. `C:\Program Files\Tesseract-OCR\tesseract.exe` (Windows)
3. `C:\Program Files (x86)\Tesseract-OCR\tesseract.exe` (Windows 32-bit)
4. `/usr/bin/tesseract` (Linux)
5. `/usr/local/bin/tesseract` (Linux/macOS)
6. `/opt/homebrew/bin/tesseract` (macOS Homebrew)

### Configurações de OCR

O parser usa as seguintes configurações otimizadas:

```python
custom_config = r'--oem 3 --psm 6 -c tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ0123456789.,;:()\-/\s'
```

- `--oem 3`: Usa LSTM OCR Engine
- `--psm 6`: Assume um bloco uniforme de texto
- `tessedit_char_whitelist`: Restringe caracteres para melhor precisão

## Formato da Resposta

A resposta é idêntica ao parser original, com um campo adicional:

```json
{
  "message": "PDF processado com sucesso usando OCR!",
  "extraction_method": "OCR",
  "filename": "historico.pdf",
  "matricula": "12345678",
  "curso_extraido": "CIÊNCIA DA COMPUTAÇÃO",
  "matriz_curricular": "2020.1",
  "media_ponderada": 3.85,
  "ira": 3.92,
  "semestre_atual": "2024.2",
  "numero_semestre": 8,
  "extracted_data": [...],
  "equivalencias_pdf": [...],
  "full_text": "..."
}
```

## Troubleshooting

### Erro: "Tesseract not found"
Certifique-se de que o Tesseract está instalado e disponível no PATH do sistema.

### Erro: "No text extracted"
- Verifique a qualidade do PDF
- Tente aumentar a resolução (modificar o valor de `Matrix` no código)
- Verifique se o PDF não está corrompido

### Performance lenta
- PDFs com muitas páginas podem demorar para processar
- Considere usar a versão padrão se o texto pode ser extraído diretamente 