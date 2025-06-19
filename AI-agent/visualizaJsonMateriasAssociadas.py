import re
import ast
import html

def gerar_texto_ranking(json_bruto: dict) -> str:
    """
    Parser universal que extrai, limpa e formata um ranking de disciplinas.
    Esta versão corrige o bug que pulava matérias quando a Ementa
    era opcional no formato de linha única.
    """
    try:
        answer_dict = ast.literal_eval(json_bruto['data']['answer'])
        content_str = answer_dict['content']['0']

        partes_bloco = re.split(r'INÍCIO DO RANKING', content_str, maxsplit=1)
        ranking_block = partes_bloco[1] if len(partes_bloco) > 1 else content_str
        ranking_block = re.sub(r'---\s*$', '', ranking_block).strip()

        if not ranking_block:
            return "Erro: Não foi possível extrair um bloco de ranking válido do JSON."

        itens = re.findall(r'\d+\.\s*(.*?)(?=\n\s*\d+\.\s*|\Z)', ranking_block, re.DOTALL)

        texto_final_partes = ["--- RANKING DE DISCIPLINAS ---"]
        posicao_atual = 1

        for item_str in itens:
            disciplina_str, codigo_str, unidade_str, pontuacao_str, justificativa_str, ementa_str = ("N/A",) * 6

            # --- DETECÇÃO DE FORMATO ---
            if '; Codigo:' in item_str: # Identifica o formato de linha única
                # --- REGEX CORRIGIDA: EMENTA AGORA É OPCIONAL ---
                main_line_match = re.search(
                    r'\*\*Disciplina:\*\*\s*(.*?);\s*Codigo:\s*(\S+);\s*Unidade\sresponsavel:\s*(.*?)(?:;\s*Ementa:\s*(.*))?$',
                    item_str,
                    re.MULTILINE | re.DOTALL
                )
                if main_line_match:
                    disciplina_str = main_line_match.group(1).strip()
                    codigo_str = main_line_match.group(2).strip()
                    unidade_str = main_line_match.group(3).strip()
                    # A Ementa é o grupo 4 e pode não existir (ser None)
                    if main_line_match.group(4):
                        ementa_str = main_line_match.group(4).strip()

                pontuacao_match = re.search(r'\*\*Pontuação:\*\*\s*(\d+)', item_str)
                justificativa_match = re.search(r'\*\*Justificativa:\*\*\s*(.*)', item_str, re.DOTALL)
                
                if pontuacao_match:
                    pontuacao_str = pontuacao_match.group(1).strip()
                if justificativa_match:
                    justificativa_str = justificativa_match.group(1).strip()

            # Senão, usa a lógica para os formatos antigos
            else:
                codigo_match = re.search(r'\*\*Código:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                disciplina_match = re.search(r'\*\*Disciplina:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                unidade_match = re.search(r'\*\*Unidade Responsável:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                justificativa_match = re.search(r'\*\*Justificativa:\*\* (.*?)(?=\s*-\\s*\*\*Pontuação:\*\*|\Z)', item_str, re.DOTALL)
                pontuacao_match = re.search(r'\*\*Pontuação:\*\* (.*?)\s*?$', item_str, re.MULTILINE)

                codigo_bruto = codigo_match.group(1).strip() if codigo_match else "N/A"
                disciplina_bruta = disciplina_match.group(1).strip() if disciplina_match else "N/A"
                
                codigo_limpo_match = re.search(r'Codigo:\s*(\S+)', codigo_bruto)
                codigo_str = codigo_limpo_match.group(1) if codigo_limpo_match else codigo_bruto
                disciplina_str = re.sub(r';\s*Codigo:.*', '', disciplina_bruta).strip()
                unidade_str = unidade_match.group(1).strip() if unidade_match else "N/A"
                justificativa_str = justificativa_match.group(1).strip() if justificativa_match else "N/A"
                pontuacao_str = pontuacao_match.group(1).strip() if pontuacao_match else "0"

            # Limpeza final dos dados
            justificativa_str = html.unescape(justificativa_str.replace('\\n', ' ')).strip()
            ementa_str = html.unescape(ementa_str.replace('\\n', ' ')).strip()

            # Montagem do bloco de texto formatado
            bloco_texto = (
                f"\nPosição: {posicao_atual} (Pontuação: {pontuacao_str})\n\n"
                f"  \nDisciplina: {disciplina_str} ({codigo_str})\n\n"
                f"  \nUnidade: {unidade_str}"
            )
            if ementa_str and ementa_str != 'N/A':
                bloco_texto += f"\n  Ementa: {ementa_str}"
            bloco_texto += f"\n\n  Justificativa: {justificativa_str}"
            bloco_texto += f"\n\n __________________________________"
            
            texto_final_partes.append(bloco_texto)
            posicao_atual += 1
        
        texto_final_partes.append("\n--- FIM DO RANKING ---")
        return "\n".join(texto_final_partes)

    except (KeyError, TypeError, ValueError, SyntaxError) as e:
        return f"Erro ao processar o JSON: {e}"

# --- Exemplo de Uso com o JSON que causou o erro ---
json_exemplo = {'code': 0, 'data': {'answer': "{'content': {'0': '--- INÍCIO DO RANKING ---\\n\\n\\n1. **Disciplina:** HISTORIA DA AFRICA; Codigo: HIS0252; Unidade responsavel: DEPTO HISTORIA; Ementa: Processo historico das sociedades africanas. Historiografia com suas mudancas e desafios.\\n\\n**Pontuação:** 100 \\n\\n**Justificativa:** Aborda diretamente o conteúdo de referência, sendo a disciplina mais relevante.\\n\\n\\n2. **Disciplina:** LITERATURAS AFRICANAS DE LINGUA PORTUGUESA; Codigo: ILD0206; Unidade responsavel: INSTITUTO DE LETRAS; Ementa: Estudo da formacao das literaturas africanas de lingua portuguesa, com enfoque em obras e/ou autores representativos de questoes atinentes a forma estetica e a realidade nacional.\\n\\n**Pontuação:** 80 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à literatura africana em língua portuguesa.\\n\\n\\n3. **Disciplina:** RELACOES ETNICO; Codigo: LET0933; Unidade responsavel: DEPTO LINGUAS ESTRANGEIRAS E TRADUCAO; Ementa: Aquisicao de conhecimentos referentes a historia e cultura africana e afro-diasporica, com enfase em questoes sociolinguisticas e decoloniais.\\n\\n**Pontuação:** 70 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado às relações étnico.\\n\\n\\n4. **Disciplina:** RELACOES INTERNACIONAIS DA AFRICA; Codigo: IRI0184; Unidade responsavel: INSTITUTO DE RELACOES INTERNACIONAIS; Ementa: O curso tem o proposito de apresentar as linhas gerais da evolucao das relacoes internacionais da Africa, do seculo XIX ao inicio do seculo XXI.\\n\\n**Pontuação:** 60 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado às relações internacionais africanas.\\n\\n\\n5. **Disciplina:** GEOGRAFIA AFRICANA E AFROBRASILEIRA; Codigo: GEA0003; Unidade responsavel: DEPTO GEOGRAFIA\\n\\n**Pontuação:** 50 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à geografia africana e afro-brasileira.\\n\\n\\n6. **Disciplina:** DESENVOLVIMENTO E NECESSIDADES ESPECIAIS; Codigo: PED0036; Unidade responsavel: INSTITUTO DE PSICOLOGIA\\n\\n**Pontuação:** 40 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado ao desenvolvimento e necessidades especiais.\\n\\n\\n7. **Disciplina:** INFANCIA, CRIANCA E EDUCACAO; Codigo: TEF0002; Unidade responsavel: FACULDADE DE EDUCACAO\\n\\n**Pontuação:** 30 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à infância e educação.\\n\\n\\n8. **Disciplina:** ENSINO DE HISTORIA, IDENTIDADE E CIDADANIA; Codigo: MTC0059; Unidade responsavel: FACULDADE DE EDUCACAO\\n\\n**Pontuação:** 20 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado ao ensino de história e identidade.\\n\\n\\n--- FIM DO RANKING ---'}, 'component_id': {'0': 'Generate:TenTreesMix'}}", 'id': '5660685f-a1f7-40da-b720-35ee97a02c9c', 'param': [{'key': 'materia', 'name': 'materia', 'optional': False, 'type': 'paragraph', 'value': 'HISTORIA DA AFRICA'}], 'reference': {}, 'session_id': 'd2fad4a04b0211f0801c4e9adbd040ca'}}

texto_formatado = gerar_texto_ranking(json_exemplo)
print(texto_formatado)