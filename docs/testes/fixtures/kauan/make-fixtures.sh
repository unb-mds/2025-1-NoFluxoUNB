#!/usr/bin/env bash
# Gera fixtures de PDF para o teste exploratório do parser SIGAA (Kauan).
# Cada PDF reproduz uma classe de equivalência ou caso de borda explorado em
# docs/testes/teste-exploratorio-kauan.md. Os arquivos ficam versionados aqui
# porque são pequenos (<1 KB cada, exceto o que envolve PyMuPDF).
#
# Uso: bash docs/testes/fixtures/kauan/make-fixtures.sh
set -euo pipefail
cd "$(dirname "$0")"

VENV="../../../../no_fluxo_backend/parse-pdf/.venv/bin/python"

# 1) PDF de 0 byte (BVA tamanho mínimo)
: > empty.pdf

# 2) PDF corrompido: header valido seguido de bytes aleatórios (EG PDF inválido)
{ printf '%%PDF-1.4\n'; head -c 256 /dev/urandom; } > pdf_corrompido.pdf

# 3) PDF mínimo sem "_" no nome (EG matrícula desconhecida) — gerado por PyMuPDF
"$VENV" - <<'PY'
import fitz
doc = fitz.open()
page = doc.new_page()
page.insert_text((72, 72), "Histórico SIGAA - exemplo curto")
doc.save("sem_underscore.pdf")
doc.close()
PY

# 4) PDF só com imagem (sem camada de texto) — EG/PE3
"$VENV" - <<'PY'
import fitz
from PIL import Image, ImageDraw
img = Image.new("RGB", (600, 200), "white")
d = ImageDraw.Draw(img)
d.text((20, 80), "ESTE TEXTO E IMAGEM - NAO HA CAMADA TEXTUAL", fill="black")
img.save("/tmp/kauan_img.png")
doc = fitz.open()
page = doc.new_page(width=600, height=200)
page.insert_image(page.rect, filename="/tmp/kauan_img.png")
doc.save("imagem_only.pdf")
doc.close()
PY

# 5) PDF com U+2013 (en-dash) em menção — D1 confirmação
"$VENV" - <<'PY'
import fitz
doc = fitz.open()
page = doc.new_page()
# Bloco de 8 linhas que o parser tenta casar (ano, nome, turma, sit, codigo, ch, freq, mencao)
linhas = [
    "Curso: ENGENHARIA DE SOFTWARE",
    "Currículo: 6360/2",
    "IRA: 4,5",
    "MP: 4,5",
    "2024.1",
    "CALCULO 1",
    "A",
    "APR",
    "MAT0025",
    "90",
    "100,0",
    "MM – APROVADO",  # en-dash em vez de hífen ASCII
]
y = 72
for ln in linhas:
    page.insert_text((72, y), ln)
    y += 16
doc.save("mencao_endash.pdf")
doc.close()
PY

# 6) PDF criptografado (com senha) — EG8 hipótese
"$VENV" - <<'PY'
import fitz
doc = fitz.open()
page = doc.new_page()
page.insert_text((72, 72), "Conteudo protegido")
doc.save(
    "encrypted.pdf",
    encryption=fitz.PDF_ENCRYPT_AES_256,
    owner_pw="owner123",
    user_pw="user123",
)
doc.close()
PY

ls -la empty.pdf pdf_corrompido.pdf sem_underscore.pdf imagem_only.pdf mencao_endash.pdf encrypted.pdf
echo "ok"
