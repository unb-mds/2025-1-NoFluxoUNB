#!/usr/bin/env python3
"""
Script de teste para o parser PDF
Testa o parser com uma lista de arquivos PDF e verifica os resultados
"""

import os
import sys
import json
import requests
import logging
from pathlib import Path
import argparse
from typing import List, Dict, Any

# Adicionar o diretório do parser ao path para importar o módulo
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Importar as funções do parser localmente
try:
    from pdf_parser_final import extrair_dados_academicos
    import PyPDF2
    import io
    LOCAL_IMPORT_AVAILABLE = True
except ImportError as e:
    print(f"[AVISO] Não foi possível importar o módulo local: {e}")
    print("[INFO] Apenas testes via HTTP estarão disponíveis")
    LOCAL_IMPORT_AVAILABLE = False

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class TestePDFParser:
    def __init__(self, servidor_url="http://localhost:3001"):
        self.servidor_url = servidor_url
        self.resultados = []
        
    def extrair_texto_pdf(self, caminho_pdf: str) -> str:
        """Extrai texto do PDF usando PyPDF2"""
        try:
            with open(caminho_pdf, 'rb') as arquivo:
                leitor = PyPDF2.PdfReader(arquivo)
                texto_total = ""
                
                for pagina in leitor.pages:
                    texto_pagina = pagina.extract_text()
                    if texto_pagina:
                        texto_total += texto_pagina + "\n"
                        
                return texto_total
        except Exception as e:
            logger.error(f"Erro ao extrair texto do PDF {caminho_pdf}: {e}")
            return ""
    
    def testar_local(self, caminho_pdf: str) -> Dict[str, Any]:
        """Testa o parser localmente (importando as funções diretamente)"""
        if not LOCAL_IMPORT_AVAILABLE:
            return {"erro": "Importação local não disponível"}
            
        try:
            logger.info(f"Testando localmente: {caminho_pdf}")
            
            # Extrair texto do PDF
            texto = self.extrair_texto_pdf(caminho_pdf)
            if not texto.strip():
                return {"erro": "Nenhum texto extraído do PDF"}
            
            # Processar com o parser
            resultado = extrair_dados_academicos(texto)
            
            return {
                "sucesso": True,
                "arquivo": caminho_pdf,
                "metodo": "local",
                "texto_extraido_chars": len(texto),
                "dados_extraidos": resultado
            }
            
        except Exception as e:
            logger.error(f"Erro no teste local para {caminho_pdf}: {e}")
            return {
                "sucesso": False,
                "arquivo": caminho_pdf,
                "metodo": "local",
                "erro": str(e)
            }
    
    def testar_http(self, caminho_pdf: str) -> Dict[str, Any]:
        """Testa o parser via requisição HTTP"""
        try:
            logger.info(f"Testando via HTTP: {caminho_pdf}")
            
            with open(caminho_pdf, 'rb') as arquivo:
                files = {'pdf': arquivo}
                
                # Fazer requisição para o servidor
                response = requests.post(
                    f"{self.servidor_url}/upload-pdf",
                    files=files,
                    timeout=30
                )
                
                if response.status_code == 200:
                    dados = response.json()
                    return {
                        "sucesso": True,
                        "arquivo": caminho_pdf,
                        "metodo": "http",
                        "status_code": response.status_code,
                        "dados_extraidos": dados
                    }
                else:
                    return {
                        "sucesso": False,
                        "arquivo": caminho_pdf,
                        "metodo": "http",
                        "status_code": response.status_code,
                        "erro": response.text
                    }
                    
        except requests.exceptions.ConnectionError:
            return {
                "sucesso": False,
                "arquivo": caminho_pdf,
                "metodo": "http",
                "erro": f"Não foi possível conectar ao servidor em {self.servidor_url}"
            }
        except Exception as e:
            logger.error(f"Erro no teste HTTP para {caminho_pdf}: {e}")
            return {
                "sucesso": False,
                "arquivo": caminho_pdf,
                "metodo": "http",
                "erro": str(e)
            }
    
    def verificar_qualidade_extracao(self, resultado: Dict[str, Any]) -> Dict[str, Any]:
        """Verifica a qualidade dos dados extraídos"""
        qualidade = {
            "curso_extraido": False,
            "matriz_curricular_extraida": False,
            "disciplinas_encontradas": 0,
            "ira_extraido": False,
            "mp_extraido": False,
            "pendentes_encontradas": 0,
            "equivalencias_encontradas": 0
        }
        
        if not resultado.get("sucesso", False):
            return qualidade
            
        dados = resultado.get("dados_extraidos", {})
        
        # Verificar dados básicos
        if resultado["metodo"] == "local":
            qualidade["curso_extraido"] = bool(dados.get("curso"))
            qualidade["matriz_curricular_extraida"] = bool(dados.get("matriz_curricular"))
            qualidade["ira_extraido"] = bool(dados.get("ira"))
            qualidade["mp_extraido"] = bool(dados.get("media_ponderada"))
            
            disciplinas = dados.get("disciplinas", [])
            qualidade["disciplinas_encontradas"] = len([d for d in disciplinas if isinstance(d, dict) and d.get("tipo_dado") == "Disciplina Regular"])
            qualidade["pendentes_encontradas"] = len([d for d in disciplinas if isinstance(d, dict) and d.get("tipo_dado") == "Disciplina Pendente"])
            qualidade["equivalencias_encontradas"] = len(dados.get("equivalencias", []))
            
        else:  # HTTP
            qualidade["curso_extraido"] = bool(dados.get("curso_extraido"))
            qualidade["matriz_curricular_extraida"] = bool(dados.get("matriz_curricular"))
            qualidade["ira_extraido"] = bool(dados.get("media_ponderada")) # IRA está dentro de extracted_data
            qualidade["mp_extraido"] = bool(dados.get("media_ponderada"))
            
            extracted_data = dados.get("extracted_data", [])
            qualidade["disciplinas_encontradas"] = len([d for d in extracted_data if isinstance(d, dict) and d.get("tipo_dado") == "Disciplina Regular"])
            qualidade["pendentes_encontradas"] = len([d for d in extracted_data if isinstance(d, dict) and d.get("tipo_dado") == "Disciplina Pendente"])
            qualidade["equivalencias_encontradas"] = len(dados.get("equivalencias_pdf", []))
        
        return qualidade
    
    def executar_testes(self, arquivos_pdf: List[str], metodos: List[str] = ["local", "http"]) -> List[Dict[str, Any]]:
        """Executa os testes para uma lista de arquivos PDF"""
        logger.info(f"Iniciando testes para {len(arquivos_pdf)} arquivos")
        logger.info(f"Métodos de teste: {metodos}")
        
        for arquivo in arquivos_pdf:
            if not os.path.exists(arquivo):
                logger.warning(f"Arquivo não encontrado: {arquivo}")
                continue
                
            logger.info(f"\n{'='*60}")
            logger.info(f"Testando arquivo: {Path(arquivo).name}")
            logger.info(f"{'='*60}")
            
            for metodo in metodos:
                if metodo == "local" and not LOCAL_IMPORT_AVAILABLE:
                    logger.warning("Teste local pulado - importação não disponível")
                    continue
                    
                if metodo == "local":
                    resultado = self.testar_local(arquivo)
                elif metodo == "http":
                    resultado = self.testar_http(arquivo)
                else:
                    logger.warning(f"Método desconhecido: {metodo}")
                    continue
                
                # Verificar qualidade da extração
                qualidade = self.verificar_qualidade_extracao(resultado)
                resultado["qualidade"] = qualidade
                
                self.resultados.append(resultado)
                
                # Mostrar resultado resumido
                self.mostrar_resultado_resumido(resultado)
    
    def mostrar_resultado_resumido(self, resultado: Dict[str, Any]):
        """Mostra um resumo do resultado do teste"""
        arquivo = Path(resultado["arquivo"]).name
        metodo = resultado["metodo"].upper()
        
        if resultado["sucesso"]:
            qualidade = resultado["qualidade"]
            print(f"\n[{metodo}] ✅ {arquivo}")
            print(f"  📚 Curso: {'✅' if qualidade['curso_extraido'] else '❌'}")
            print(f"  📋 Matriz: {'✅' if qualidade['matriz_curricular_extraida'] else '❌'}")
            print(f"  📊 IRA: {'✅' if qualidade['ira_extraido'] else '❌'}")
            print(f"  📈 MP: {'✅' if qualidade['mp_extraido'] else '❌'}")
            print(f"  📚 Disciplinas: {qualidade['disciplinas_encontradas']}")
            print(f"  ⏳ Pendentes: {qualidade['pendentes_encontradas']}")
            print(f"  🔄 Equivalências: {qualidade['equivalencias_encontradas']}")
        else:
            print(f"\n[{metodo}] ❌ {arquivo}")
            print(f"  Erro: {resultado.get('erro', 'Erro desconhecido')}")
    
    def gerar_relatorio_final(self):
        """Gera um relatório final dos testes"""
        if not self.resultados:
            print("\n❌ Nenhum teste foi executado")
            return
            
        total_testes = len(self.resultados)
        sucessos = len([r for r in self.resultados if r["sucesso"]])
        falhas = total_testes - sucessos
        
        print(f"\n{'='*60}")
        print(f"RELATÓRIO FINAL DOS TESTES")
        print(f"{'='*60}")
        print(f"📊 Total de testes: {total_testes}")
        print(f"✅ Sucessos: {sucessos}")
        print(f"❌ Falhas: {falhas}")
        print(f"📈 Taxa de sucesso: {(sucessos/total_testes)*100:.1f}%")
        
        if sucessos > 0:
            # Estatísticas de qualidade
            qualidades = [r["qualidade"] for r in self.resultados if r["sucesso"]]
            
            curso_ok = len([q for q in qualidades if q["curso_extraido"]])
            matriz_ok = len([q for q in qualidades if q["matriz_curricular_extraida"]])
            ira_ok = len([q for q in qualidades if q["ira_extraido"]])
            mp_ok = len([q for q in qualidades if q["mp_extraido"]])
            
            total_disciplinas = sum(q["disciplinas_encontradas"] for q in qualidades)
            total_pendentes = sum(q["pendentes_encontradas"] for q in qualidades)
            total_equivalencias = sum(q["equivalencias_encontradas"] for q in qualidades)
            
            print(f"\n📋 QUALIDADE DA EXTRAÇÃO:")
            print(f"  📚 Curso extraído: {curso_ok}/{sucessos} ({(curso_ok/sucessos)*100:.1f}%)")
            print(f"  📋 Matriz extraída: {matriz_ok}/{sucessos} ({(matriz_ok/sucessos)*100:.1f}%)")
            print(f"  📊 IRA extraído: {ira_ok}/{sucessos} ({(ira_ok/sucessos)*100:.1f}%)")
            print(f"  📈 MP extraído: {mp_ok}/{sucessos} ({(mp_ok/sucessos)*100:.1f}%)")
            print(f"  📚 Total de disciplinas: {total_disciplinas}")
            print(f"  ⏳ Total de pendentes: {total_pendentes}")
            print(f"  🔄 Total de equivalências: {total_equivalencias}")
    
    def salvar_resultados(self, arquivo_saida: str = "resultados_teste_parser.json"):
        """Salva os resultados detalhados em um arquivo JSON"""
        try:
            with open(arquivo_saida, 'w', encoding='utf-8') as f:
                json.dump(self.resultados, f, ensure_ascii=False, indent=2)
            logger.info(f"Resultados salvos em: {arquivo_saida}")
        except Exception as e:
            logger.error(f"Erro ao salvar resultados: {e}")

def encontrar_arquivos_pdf(diretorio: str) -> List[str]:
    """Encontra todos os arquivos PDF em um diretório"""
    pdf_files = []
    path = Path(diretorio)
    
    if path.is_file() and path.suffix.lower() == '.pdf':
        return [str(path)]
    
    if path.is_dir():
        pdf_files = [str(p) for p in path.rglob("*.pdf")]
        
    return pdf_files

def main():
    parser = argparse.ArgumentParser(description="Teste do parser PDF")
    parser.add_argument("arquivos", nargs="+", help="Arquivos PDF ou diretório com PDFs para testar")
    parser.add_argument("--servidor", default="http://localhost:3001", help="URL do servidor (padrão: http://localhost:3001)")
    parser.add_argument("--metodos", nargs="+", choices=["local", "http"], default=["local", "http"], help="Métodos de teste")
    parser.add_argument("--salvar", help="Arquivo para salvar resultados detalhados")
    parser.add_argument("--verbose", "-v", action="store_true", help="Saída verbosa")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Coletar arquivos PDF
    arquivos_pdf = []
    for item in args.arquivos:
        if os.path.isdir(item):
            arquivos_encontrados = encontrar_arquivos_pdf(item)
            arquivos_pdf.extend(arquivos_encontrados)
            print(f"📁 Encontrados {len(arquivos_encontrados)} PDFs em {item}")
        elif os.path.isfile(item) and item.lower().endswith('.pdf'):
            arquivos_pdf.append(item)
        else:
            print(f"⚠️  Item ignorado (não é PDF ou não existe): {item}")
    
    if not arquivos_pdf:
        print("❌ Nenhum arquivo PDF encontrado para testar")
        return
    
    print(f"🎯 Total de {len(arquivos_pdf)} arquivos PDF para testar")
    
    # Executar testes
    teste = TestePDFParser(args.servidor)
    teste.executar_testes(arquivos_pdf, args.metodos)
    
    # Gerar relatório
    teste.gerar_relatorio_final()
    
    # Salvar resultados se solicitado
    if args.salvar:
        teste.salvar_resultados(args.salvar)

if __name__ == "__main__":
    main() 