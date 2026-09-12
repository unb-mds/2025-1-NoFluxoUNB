import requests
from bs4 import BeautifulSoup
from datetime import date
import json
import os
import re
import time

"""
ESSE SCRAPING EXTRAI OS PERÍODOS LETIVOS REGULARES (.1 e .2) DO CALENDÁRIO
ACADÊMICO DE GRADUAÇÃO DA UNB (https://saa.unb.br/calendario-academico-graduacao/).



Períodos especiais (verão ".4", inverno) são
ignorados; apenas ".1" e ".2" são extraídos.
"""

URL_CALENDARIO = "https://saa.unb.br/calendario-academico-graduacao/"


MAX_RETRIES = 4
RETRY_DELAY_SEC = 12

HEADERS = {"User-Agent": "Mozilla/5.0"}

# "Períodos letivos de 2026" / "Período letivo de 2027"
RE_ANO_HEADER = re.compile(
    r"per[ií]odos?\s+letivos?\s+de\s+(\d{4})", re.IGNORECASE
)

# "2026.1: 16/03 a 18/07/2026" -> captura só semestres regulares (1 ou 2).

RE_PERIODO = re.compile(
    r"(?P<ano>\d{4})\.(?P<sem>[12])\s*:?\s*"
    r"(?P<inicio>\d{1,2}/\d{1,2}(?:/\d{4})?)\s*a\s*"
    r"(?P<fim>\d{1,2}/\d{1,2}/\d{4})",
    re.IGNORECASE,
)


def request_with_retry(session, url, max_retries=MAX_RETRIES, delay=RETRY_DELAY_SEC):
    for attempt in range(max_retries):
        try:
            return session.get(url, timeout=30)
        except (
            requests.exceptions.SSLError,
            requests.exceptions.ConnectionError,
            requests.exceptions.ReadTimeout,
        ) as e:
            if attempt == max_retries - 1:
                raise
            print(
                f"Erro de conexão/SSL (tentativa {attempt + 1}/{max_retries}): "
                f"{type(e).__name__}. Aguardando {delay}s..."
            )
            time.sleep(delay)
    raise RuntimeError("max_retries deve ser maior que zero")


def _parse_data_parts(texto_data):
    """'16/03' -> (16, 3, None); '18/07/2026' -> (18, 7, 2026)."""
    partes = texto_data.strip().split("/")
    if len(partes) == 2:
        dia, mes = partes
        return int(dia), int(mes), None
    if len(partes) == 3:
        dia, mes, ano = partes
        return int(dia), int(mes), int(ano)
    raise ValueError(f"Formato de data inesperado: {texto_data!r}")


def resolver_datas(texto_inicio, texto_fim):
    """
    Faz o parse das datas de início/fim, resolvendo automaticamente o ano de
    início quando o texto só traz DD/MM para o início (usa o ano do fim; se o
    mês de início for maior que o mês de fim, assume que o início ocorreu no
    ano anterior ao do fim, cobrindo períodos que atravessam a virada do ano).
    Retorna (data_inicio: date, data_fim: date).
    """
    dia_i, mes_i, ano_i = _parse_data_parts(texto_inicio)
    dia_f, mes_f, ano_f = _parse_data_parts(texto_fim)

    if ano_f is None:
        raise ValueError(f"Data de fim sem ano: {texto_fim!r}")

    if ano_i is None:
        ano_i = ano_f - 1 if mes_i > mes_f else ano_f

    return date(ano_i, mes_i, dia_i), date(ano_f, mes_f, dia_f)


def _extrair_linhas(content_div):
    """
    Extrai as linhas de texto candidatas dentro do container de conteúdo do
    acordeão,
    """
    linhas = []
    itens = content_div.find_all(["li", "p"])
    if itens:
        for item in itens:
            texto = item.get_text(separator=" ", strip=True)
            if texto:
                linhas.append(texto)
    else:
        bruto = content_div.get_text(separator="\n")
        for linha in bruto.split("\n"):
            linha = linha.strip()
            if linha:
                linhas.append(linha)
    return linhas


def _localizar_content_div(soup, header_div, aria_controls):
    """Associa o cabeçalho do acordeão ao seu container de conteúdo."""
    content_div = None
    if aria_controls:
        content_div = soup.find(id=aria_controls)
    if content_div is None and header_div is not None:
        content_div = header_div.find_next_sibling(class_="eael-accordion-content")
    if content_div is None and header_div is not None:
        content_div = header_div.find_next_sibling("div")
    return content_div


def _encontrar_cabecalhos_de_ano(soup):
    """
    Localiza dinamicamente todos os cabeçalhos de acordeão cujo título
    corresponda a "Períodos letivos de <ANO>", sem fixar anos em hardcode.
    Retorna lista de tuplas (ano, header_div, aria_controls).
    """
    cabecalhos = []
    candidatos = soup.find_all(class_="eael-accordion-tab-title")
    if not candidatos:
        # Fallback: caso a classe do título mude, varre os próprios headers
        candidatos = soup.find_all(class_="eael-accordion-header")

    vistos = set()
    for elemento in candidatos:
        texto = elemento.get_text(strip=True)
        match_ano = RE_ANO_HEADER.search(texto)
        if not match_ano:
            continue

        ano = int(match_ano.group(1))
        header_div = elemento.find_parent(class_="eael-accordion-header") or elemento

        aria_controls = header_div.get("aria-controls")
        chave = aria_controls or id(header_div)
        if chave in vistos:
            continue
        vistos.add(chave)

        cabecalhos.append((ano, header_div, aria_controls))

    return cabecalhos


def parse_calendario(html):
    """
    Recebe o HTML da página do calendário acadêmico e retorna a lista de
    períodos letivos regulares (.1 e .2), no schema:
    {ano, periodo, data_inicio, data_fim, texto_bruto}.
    """
    soup = BeautifulSoup(html, "html.parser")
    cabecalhos = _encontrar_cabecalhos_de_ano(soup)

    if not cabecalhos:
        print("Aviso: nenhum cabeçalho 'Períodos letivos de <ANO>' encontrado.")

    resultados = []
    periodos_vistos = set()

    for ano_cabecalho, header_div, aria_controls in cabecalhos:
        content_div = _localizar_content_div(soup, header_div, aria_controls)
        if content_div is None:
            print(f"Aviso: conteúdo não encontrado para o ano {ano_cabecalho}.")
            continue

        for linha in _extrair_linhas(content_div):
            for match in RE_PERIODO.finditer(linha):
                sem = match.group("sem")
                if sem not in ("1", "2"):
                    continue  # ignora .4 (verão) e quaisquer outros especiais

                ano = int(match.group("ano"))
                periodo = f"{ano}.{sem}"
                if periodo in periodos_vistos:
                    continue

                try:
                    data_inicio, data_fim = resolver_datas(
                        match.group("inicio"), match.group("fim")
                    )
                except ValueError as e:
                    print(f"Aviso: falha ao parsear datas do período {periodo}: {e}")
                    continue

                periodos_vistos.add(periodo)
                resultados.append(
                    {
                        "ano": ano,
                        "periodo": periodo,
                        "data_inicio": data_inicio.strftime("%d/%m/%Y"),
                        "data_fim": data_fim.strftime("%d/%m/%Y"),
                        "texto_bruto": match.group(0).strip(),
                    }
                )

    resultados.sort(key=lambda r: (r["ano"], r["periodo"]))
    return resultados


def scrape_calendario_academico(url=URL_CALENDARIO, salvar=True):
    """Baixa a página, faz o parsing e (opcionalmente) salva o JSON resultante."""
    session = requests.Session()
    session.headers.update(HEADERS)

    print(f"Buscando calendário acadêmico em: {url}")
    resp = request_with_retry(session, url)
    resp.raise_for_status()

    resultados = parse_calendario(resp.text)
    print(f"Períodos letivos regulares encontrados: {len(resultados)}")
    for r in resultados:
        print(f"  {r['periodo']}: {r['data_inicio']} a {r['data_fim']}")

    if salvar:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        output_dir = os.path.join(script_dir, "..", "dados")
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, "calendario-academico-graduacao.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(resultados, f, ensure_ascii=False, indent=2)
        print(f"Dados salvos em: {output_path}")

    return resultados


if __name__ == "__main__":
    scrape_calendario_academico()
