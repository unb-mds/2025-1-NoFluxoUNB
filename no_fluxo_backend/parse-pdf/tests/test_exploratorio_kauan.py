"""
Sessão de teste exploratório do parser PDF SIGAA — Kauan.

Cada teste exercita o endpoint POST /upload-pdf rodando localmente em
http://127.0.0.1:3001 e grava a resposta como evidência JSON em
docs/testes/evidencias/. As assertions verificam a HIPÓTESE da sessão
(estudo estático em docs/testes/teste-exploratorio-kauan.md); falhas de
assert significam que o comportamento real diverge da hipótese — o
relatório foi atualizado para refletir o que de fato roda.

Rodar:
    cd no_fluxo_backend/parse-pdf
    source .venv/bin/activate
    pytest tests/test_exploratorio_kauan.py -v
"""
from __future__ import annotations

import json
import os
import re
from pathlib import Path

import pytest
import requests

BASE = "http://127.0.0.1:3001"
ROOT = Path(__file__).resolve().parents[3]
FIX = ROOT / "docs" / "testes" / "fixtures" / "kauan"
HAPPY = ROOT / "no_fluxo_backend" / "parse-pdf" / "testepdf2.pdf"
EVID = ROOT / "docs" / "testes" / "evidencias"
EVID.mkdir(parents=True, exist_ok=True)


def _save(slug: str, resp: requests.Response, extra: dict | None = None) -> Path:
    """Persiste status + body (JSON ou texto) como evidência reproduzível."""
    out = EVID / f"kauan-{slug}.json"
    try:
        body = resp.json()
    except Exception:
        body = {"_raw_text": resp.text[:2000]}
    payload = {
        "url": resp.url,
        "status_code": resp.status_code,
        "headers": dict(resp.headers),
        "body": body,
    }
    if extra:
        payload["extra"] = extra
    out.write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    return out


def _post(filename: str, path: Path, content_type: str = "application/pdf"):
    """Envia multipart POST /upload-pdf com filename controlado."""
    with path.open("rb") as f:
        return requests.post(
            f"{BASE}/upload-pdf",
            files={"pdf": (filename, f, content_type)},
            timeout=60,
        )


# ---------------------------------------------------------------- happy path
def test_01_eg_happy_path_testepdf2():
    """Error Guessing — fluxo positivo, baseline antes das bordas."""
    assert HAPPY.exists(), f"fixture happy-path ausente: {HAPPY}"
    r = _post("123_456789.pdf", HAPPY)
    _save("01-baseline-happy-path", r)
    assert r.status_code == 200
    body = r.json()
    assert body.get("matricula") == "456789"
    assert "extracted_data" in body


# ---------------------------------------------------------------- BVA tamanho
def test_02_bva_empty_pdf():
    """BVA limite inferior: arquivo de 0 byte deve ser rejeitado."""
    p = FIX / "empty.pdf"
    r = _post("0byte_999.pdf", p)
    _save("02-bva-empty-0byte", r)
    # hipótese D? : retorna 400 com mensagem técnica do MuPDF
    assert r.status_code in (400, 422, 500), f"unexpected status {r.status_code}"


def test_03_eg_pdf_corrompido():
    """Error Guessing: header %PDF- válido + bytes aleatórios."""
    p = FIX / "pdf_corrompido.pdf"
    r = _post("999_corrupt.pdf", p)
    _save("03-eg-pdf-corrompido", r)
    # D3: pattern matching frágil em str(exception). Esperamos 400 OU 500.
    assert r.status_code in (400, 422, 500)


# ---------------------------------------------------------------- D7 filename
def test_04_eg_filename_sem_underscore():
    """Error Guessing (D7): filename sem '_' → matricula='desconhecida' silenciosa."""
    p = FIX / "sem_underscore.pdf"
    # nome de arquivo sem underscore algum
    r = _post("historico.pdf", p)
    _save("04-eg-filename-sem-underscore", r)
    assert r.status_code == 200
    assert r.json().get("matricula") == "desconhecida"


def test_05_eg_filename_lixo_vira_matricula():
    """Error Guessing (D7/EG2): filename com '_' liderando aceita lixo como matrícula."""
    p = FIX / "sem_underscore.pdf"
    r = _post("_lixo123.pdf", p)
    _save("05-eg-filename-lixo-virou-matricula", r)
    assert r.status_code == 200
    # confirma que parser pega o que veio depois do primeiro '_'
    assert r.json().get("matricula") == "lixo123"


# ---------------------------------------------------------------- PE3 imagem
def test_06_pe_pdf_so_imagem():
    """Particionamento (PE3/D5): PDF só com imagem → 422 sem oferecer OCR."""
    p = FIX / "imagem_only.pdf"
    r = _post("123_imageonly.pdf", p)
    _save("06-pe-pdf-imagem-only", r)
    assert r.status_code == 422
    body = r.json()
    msg = body.get("error", "").lower()
    # D5 confirmação: a mensagem NÃO menciona OCR / endpoint alternativo
    assert "ocr" not in msg, "D5 rebaixado: mensagem agora menciona OCR"


# ---------------------------------------------------------------- D1 en-dash
def test_07_eg_mencao_endash():
    """Error Guessing (D1): U+2013 em menção faz padrao_mencao falhar."""
    import fitz

    p = FIX / "mencao_endash.pdf"
    # Sanity-check: o caractere está mesmo no texto extraído?
    doc = fitz.open(p)
    raw = "".join(page.get_text() for page in doc)
    doc.close()
    has_endash = "–" in raw
    r = _post("123_endash.pdf", p)
    out = _save("07-eg-mencao-endash", r, extra={"endash_no_texto_extraido": has_endash})
    assert r.status_code == 200
    body = r.json()
    # Hipótese D1 (atualizada após execução): PyMuPDF normaliza U+2013 para outro
    # glifo (no nosso caso "·"), mas o efeito observável continua: o bloco de
    # disciplina NÃO é extraído porque a linha de menção tem texto extra.
    # Verificamos que nenhum item com chave "codigo" (= disciplina) saiu.
    disciplinas = [
        d for d in body.get("extracted_data", [])
        if isinstance(d, dict) and "codigo" in d
    ]
    assert disciplinas == [], (
        f"D1 rebaixado: bloco com menção fora do regex ainda foi extraído: {disciplinas}"
    )


# ---------------------------------------------------------------- EG8 criptografado
def test_08_eg_pdf_criptografado():
    """Error Guessing (EG8): PDF protegido por senha — sem try/except específico."""
    p = FIX / "encrypted.pdf"
    r = _post("123_encrypted.pdf", p)
    _save("08-eg-pdf-criptografado", r)
    # hipótese: cai no 422 (texto vazio) ou 400 (erro fitz). Documentamos qual.
    assert r.status_code in (400, 422, 500)


# ---------------------------------------------------------------- TD2 sem campo
def test_09_td_sem_campo_pdf():
    """Tabela de Decisão (TD2): request sem o campo 'pdf' → 400."""
    r = requests.post(f"{BASE}/upload-pdf", data={"foo": "bar"}, timeout=10)
    _save("09-td-sem-campo-pdf", r)
    assert r.status_code == 400
    assert "Nenhum arquivo" in r.json().get("error", "")


# ---------------------------------------------------------------- D10 CORS
def test_10_eg_cors_aberto():
    """Error Guessing (D10): preflight de origem arbitrária deve passar (CORS *)."""
    r = requests.options(
        f"{BASE}/upload-pdf",
        headers={
            "Origin": "https://evil.example.com",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
        timeout=10,
    )
    _save("10-eg-cors-preflight-evil", r)
    aco = r.headers.get("Access-Control-Allow-Origin", "")
    # D10 confirma se eco a origem evil OU devolve "*"
    assert aco in ("*", "https://evil.example.com"), f"CORS = {aco!r}"


# ---------------------------------------------------------------- D4 sem MAX_CONTENT_LENGTH
def test_11_bva_sem_max_content_length():
    """BVA/D4: Flask app não declara MAX_CONTENT_LENGTH — qualquer tamanho passa.

    Não enviamos 200 MB de verdade (CI/dev). Apenas confirmamos que 5 MB de
    bytes 'A' (sem header PDF) chegam ao parser e disparam o ramo de erro
    do MuPDF (em vez de serem rejeitados por tamanho antes de ler).
    """
    big = b"A" * (5 * 1024 * 1024)  # 5 MB
    r = requests.post(
        f"{BASE}/upload-pdf",
        files={"pdf": ("123_big.pdf", big, "application/pdf")},
        timeout=60,
    )
    _save("11-bva-5mb-no-max-content-length", r, extra={"payload_bytes": len(big)})
    # Hipótese D4: passou da camada de upload, falhou só ao tentar abrir PDF
    assert r.status_code in (400, 422, 500)


# ---------------------------------------------------------------- D9 não-SIGAA
def test_12_pe_pdf_nao_sigaa_retorna_200_vazio():
    """Particionamento (PE6/D9): PDF válido mas sem marcadores SIGAA → 200 vazio."""
    p = FIX / "sem_underscore.pdf"  # PDF mínimo com texto não-SIGAA
    r = _post("123_naosigaa.pdf", p)
    out = _save("12-pe-pdf-nao-sigaa", r)
    assert r.status_code == 200
    body = r.json()
    # D9: silêncio — sem warning, curso/ira nulos, extracted_data vazio
    assert body.get("curso_extraido") in (None, "", "Não identificado")
    assert body.get("extracted_data") == []
    assert "warning" not in body and "warnings" not in body
