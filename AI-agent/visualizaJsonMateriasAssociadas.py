import re
import ast
import html

def gerar_texto_ranking(json_bruto: dict) -> str:
    """
    Parser universal que extrai, limpa e formata um ranking de disciplinas com Markdown.
    """
    try:
        answer_dict = ast.literal_eval(json_bruto['data']['answer'])
        content_str = answer_dict['content']['0']

        partes_bloco = re.split(r'INÍCIO DO RANKING', content_str, maxsplit=1)
        ranking_block = partes_bloco[1] if len(partes_bloco) > 1 else content_str
        ranking_block = re.sub(r'---\s*$', '', ranking_block).strip()

        if not ranking_block:
            return "Erro: Não foi possível extrair um bloco de ranking válido do JSON."

        # Ajuste no regex para capturar itens que podem ter ou não Ementa no final
        itens = re.findall(r'\d+\.\s*(.*?)(?=\n\s*\d+\.\s*|\Z)', ranking_block, re.DOTALL)

        # Usando Markdown para o título e separadores
        texto_final_partes = [
            "# 🏆 Ranking de Disciplinas",
            "",
            "## 🎯 **Análise Personalizada**",
            "",
            "> Baseado nos seus interesses e perfil acadêmico, analisamos centenas de disciplinas da UnB para encontrar as que melhor se alinham com seus objetivos.",
            "",
            "### 📋 **Como funciona a pontuação:**",
            "- **100 pontos:** Perfeita alinhamento com seus interesses",
            "- **80-99 pontos:** Excelente relevância",
            "- **60-79 pontos:** Boa relevância",
            "- **40-59 pontos:** Relevância moderada",
            "- **20-39 pontos:** Baixa relevância",
            "",
            "---",
            ""
        ]
        posicao_atual = 1

        for item_str in itens:
            disciplina_str, codigo_str, unidade_str, pontuacao_str, justificativa_str, ementa_str = ("N/A",) * 6

            # --- DETECÇÃO DE FORMATO ---
            # Identifica o formato de linha única ou multilinhas
            # Regex principal para extrair os campos.
            # Ementa agora é um grupo opcional no final
            main_line_match = re.search(
                r'\*\*Disciplina:\*\*\s*(.*?);\s*Codigo:\s*(\S+);\s*Unidade\sresponsavel:\s*(.*?)(?:;\s*Ementa:\s*(.*?))?\s*$',
                item_str,
                re.MULTILINE | re.DOTALL
            )

            if main_line_match: # Formato de linha única detectado
                disciplina_str = main_line_match.group(1).strip()
                codigo_str = main_line_match.group(2).strip()
                unidade_str = main_line_match.group(3).strip()
                ementa_raw = main_line_match.group(4) # Pode ser None
                ementa_str = ementa_raw.strip() if ementa_raw else "N/A"

                pontuacao_match = re.search(r'\*\*Pontuação:\*\*\s*(\d+)', item_str)
                justificativa_match = re.search(r'\*\*Justificativa:\*\*\s*(.*)', item_str, re.DOTALL) # Captura até o final do item

                if pontuacao_match:
                    pontuacao_str = pontuacao_match.group(1).strip()
                if justificativa_match:
                    justificativa_str = justificativa_match.group(1).strip()

            else: # Lógica para formatos antigos / alternativos (menos robusta, mas mantida para compatibilidade)
                codigo_match = re.search(r'\*\*Código:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                disciplina_match = re.search(r'\*\*Disciplina:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                unidade_match = re.search(r'\*\*Unidade Responsável:\*\* (.*?)\s*?$', item_str, re.MULTILINE)
                pontuacao_match = re.search(r'\*\*Pontuação:\*\* (.*?)\s*?$', item_str, re.MULTILINE)

                # A justificativa é a parte mais tricky em formatos mistos
                # Tenta pegar tudo entre "Justificativa" e "Pontuação" ou o fim
                justificativa_match = re.search(r'\*\*Justificativa:\*\*\s*(.*?)(?=\s*-\s*\*\*Pontuação:\*\*|\s*$)', item_str, re.DOTALL)


                codigo_bruto = codigo_match.group(1).strip() if codigo_match else "N/A"
                disciplina_bruta = disciplina_match.group(1).strip() if disciplina_match else "N/A"

                codigo_limpo_match = re.search(r'Codigo:\s*(\S+)', codigo_bruto)
                codigo_str = codigo_limpo_match.group(1) if codigo_limpo_match else codigo_bruto
                disciplina_str = re.sub(r';\s*Codigo:.*', '', disciplina_bruta).strip()
                unidade_str = unidade_match.group(1).strip() if unidade_match else "N/A"
                justificativa_str = justificativa_match.group(1).strip() if justificativa_match else "N/A"
                pontuacao_str = pontuacao_match.group(1).strip() if pontuacao_match else "0"


            # Limpeza final dos dados e unescape HTML
            justificativa_str = html.unescape(justificativa_str.replace('\\n', ' ')).strip()
            ementa_str = html.unescape(ementa_str.replace('\\n', ' ')).strip()


            # Montagem do bloco de texto formatado com Markdown e Emojis
            medal_emoji = "🥇" if posicao_atual == 1 else "🥈" if posicao_atual == 2 else "🥉" if posicao_atual == 3 else "📚"
            
            bloco_texto = (
                f"\n---\n\n" # Separador Markdown
                f"## {medal_emoji} **{posicao_atual}º Lugar** - Pontuação: **{pontuacao_str}/100**\n\n" # Título da posição com emoji e negrito
                f"### 📖 **{disciplina_str}**\n" # Nome da disciplina em destaque
                f"| Campo | Valor |\n" # Tabela para informações
                f"|-------|-------|\n"
                f"| **Código** | `{codigo_str}` |\n"
                f"| **Unidade** | {unidade_str} |\n\n"
            )
            
            if ementa_str and ementa_str != 'N/A':
                bloco_texto += (
                    f"### 📝 **Ementa**\n"
                    f"> {ementa_str}\n\n"
                )
            
            bloco_texto += (
                f"### 💡 **Por que esta disciplina?**\n"
                f"> {justificativa_str}\n"
            )

            texto_final_partes.append(bloco_texto)
            posicao_atual += 1
        
        # Calcular estatísticas para o resumo
        pontuacoes = []
        for item in texto_final_partes:
            if 'Pontuação: **' in item:
                try:
                    pontuacao = int(item.split('Pontuação: **')[1].split('/')[0])
                    pontuacoes.append(pontuacao)
                except:
                    continue
        
        max_pontuacao = max(pontuacoes) if pontuacoes else 0
        
        texto_final_partes.extend([
            "\n---",
            "",
            "## 📊 **Resumo da Análise**",
            "",
            "| Métrica | Valor |",
            "|---------|-------|",
            f"| **Total de disciplinas** | {posicao_atual - 1} |",
            f"| **Melhor pontuação** | {max_pontuacao}/100 |",
            f"| **Faixa de pontuação** | {min(pontuacoes) if pontuacoes else 0}-{max_pontuacao} |",
            "",
            "### 🎯 **Recomendações**",
            "",
            "> 🥇 **Disciplinas com pontuação 80-100:** Altamente recomendadas para seus interesses",
            "> 🥈 **Disciplinas com pontuação 60-79:** Boas opções para complementar sua formação",
            "> 🥉 **Disciplinas com pontuação 40-59:** Considerar se houver interesse específico",
            "",
            "---"
        ])
        return "\n".join(texto_final_partes)

    except (KeyError, TypeError, ValueError, SyntaxError) as e:
        return f"Erro ao processar o JSON: {e}"

# --- Exemplo de Uso com o JSON que causou o erro ---
json_exemplo = {'code': 0, 'data': {'answer': "{'content': {'0': '--- INÍCIO DO RANKING ---\\n\\n\\n1. **Disciplina:** HISTORIA DA AFRICA; Codigo: HIS0252; Unidade responsavel: DEPTO HISTORIA; Ementa: Processo historico das sociedades africanas. Historiografia com suas mudancas e desafios.\\n\\n**Pontuação:** 100 \\n\\n**Justificativa:** Aborda diretamente o conteúdo de referência, sendo a disciplina mais relevante.\\n\\n\\n2. **Disciplina:** LITERATURAS AFRICANAS DE LINGUA PORTUGUESA; Codigo: ILD0206; Unidade responsavel: INSTITUTO DE LETRAS; Ementa: Estudo da formacao das literaturas africanas de lingua portuguesa, com enfoque em obras e/ou autores representativos de questoes atinentes a forma estetica e a realidade nacional.\\n\\n**Pontuação:** 80 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à literatura africana em língua portuguesa.\\n\\n\\n3. **Disciplina:** RELACOES ETNICO; Codigo: LET0933; Unidade responsavel: DEPTO LINGUAS ESTRANGEIRAS E TRADUCAO; Ementa: Aquisicao de conhecimentos referentes a historia e cultura africana e afro-diasporica, com enfase em questoes sociolinguisticas e decoloniais.\\n\\n**Pontuação:** 70 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado às relações étnico.\\n\\n\\n4. **Disciplina:** RELACOES INTERNACIONAIS DA AFRICA; Codigo: IRI0184; Unidade responsavel: INSTITUTO DE RELACOES INTERNACIONAIS; Ementa: O curso tem o proposito de apresentar as linhas gerais da evolucao das relacoes internacionais da Africa, do seculo XIX ao inicio do seculo XXI.\\n\\n**Pontuação:** 60 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado às relações internacionais africanas.\\n\\n\\n5. **Disciplina:** GEOGRAFIA AFRICANA E AFROBRASILEIRA; Codigo: GEA0003; Unidade responsavel: DEPTO GEOGRAFIA\\n\\n**Pontuação:** 50 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à geografia africana e afro-brasileira.\\n\\n\\n6. **Disciplina:** DESENVOLVIMENTO E NECESSIDADES ESPECIAIS; Codigo: PED0036; Unidade responsavel: INSTITUTO DE PSICOLOGIA\\n\\n**Pontuação:** 40 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado ao desenvolvimento e necessidades especiais.\\n\\n\\n7. **Disciplina:** INFANCIA, CRIANCA E EDUCACAO; Codigo: TEF0002; Unidade responsavel: FACULDADE DE EDUCACAO\\n\\n**Pontuação:** 30 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado à infância e educação.\\n\\n\\n8. **Disciplina:** ENSINO DE HISTORIA, IDENTIDADE E CIDADANIA; Codigo: MTC0059; Unidade responsavel: FACULDADE DE EDUCACAO\\n\\n**Pontuação:** 20 \\n\\n**Justificativa:** Aborda o conteúdo de referência relacionado ao ensino de história e identidade.\\n\\n\\n--- FIM DO RANKING ---'}, 'component_id': {'0': 'Generate:TenTreesMix'}}", 'id': '5660685f-a1f7-40da-b720-35ee97a02c9c', 'param': [{'key': 'materia', 'name': 'materia', 'optional': False, 'type': 'paragraph', 'value': 'HISTORIA DA AFRICA'}], 'reference': {}, 'session_id': 'd2fad4a04b0211f0801c4e9adbd040ca'}}

texto_formatado = gerar_texto_ranking(json_exemplo)
print(texto_formatado)