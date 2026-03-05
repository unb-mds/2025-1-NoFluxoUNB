import asyncio
import os
import json
import sys
import io
from openai import OpenAI
from dotenv import load_dotenv
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from pathlib import Path

# Configura encoding UTF-8 para stdin/stdout no Windows
if sys.platform == 'win32':
    sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


async def processar_consulta(pergunta: str, client, session, system_prompt, tools):
    """Processa uma única consulta e retorna o resultado."""
    mensagens = [{"role": "system", "content": system_prompt}]
    mensagens.append({"role": "user", "content": pergunta})

    # Chamada inicial para expansão de termos
    response = client.chat.completions.create(
        model="sabiazinho-4", 
        messages=mensagens,
        tools=tools,
        tool_choice="auto"
    )

    response_message = response.choices[0].message
    
    # Se o Sabiá decidir usar a ferramenta de busca
    if response_message.tool_calls:
        mensagens.append(response_message)
        
        for tool_call in response_message.tool_calls:
            args = json.loads(tool_call.function.arguments)
            expansao = [t.strip() for t in args["interesse"].split(",")]
            termos_busca = expansao
            
            # Log dos termos escolhidos pelo Sabiá
            import sys
            print(f"[SABIÁ] Termos de busca escolhidos: {termos_busca}", file=sys.stderr)
            
            resultados_totais = {}

            for idx, termo in enumerate(termos_busca):
                try:
                    # Timeout maior para o primeiro termo (inicialização do servidor)
                    timeout = 30.0 if idx == 0 else 10.0
                    res_mcp = await asyncio.wait_for(
                        session.call_tool("buscar_materias_unb", arguments={"interesse": termo}),
                        timeout=timeout
                    )
                    if not res_mcp.content: continue

                    dados_brutos = res_mcp.content[0].text
                    lista_mats = json.loads(dados_brutos)
                    for mat in lista_mats:
                        resultados_totais[mat.get("Codigo", "")] = mat
                except asyncio.TimeoutError:
                    continue
                except Exception:
                    continue

            # Adiciona o resultado da ferramenta ao histórico
            mensagens.append({
                "tool_call_id": tool_call.id,
                "role": "tool",
                "name": "buscar_materias_unb",
                "content": json.dumps(list(resultados_totais.values()))
            })

        # Gera a resposta final rankeada
        final_response = client.chat.completions.create(
            model="sabia-4",
            messages=mensagens
        )
        
        return final_response.choices[0].message.content
    else:
        return response_message.content

def parse_resposta_sabia(texto: str) -> list:
    """Parse da resposta do Sabiá para extrair disciplinas estruturadas."""
    import sys
    import re
    
    disciplinas = []
    linhas = texto.split('\n')
    
    for idx, linha in enumerate(linhas):
        linha_original = linha
        linha = linha.strip()
        
        # Ignora linhas vazias ou sem código de disciplina
        if not linha or '-' not in linha:
            continue
        
        # Remove markdown (**, -, etc no início)
        linha = linha.lstrip('*').lstrip('-').lstrip('•').strip()
        
        # Verifica se tem padrão de código (letras seguidas de números)
        codigo_match = re.match(r'([A-Z]{3}\d{4})', linha)
        if not codigo_match:
            continue
            
        try:
            codigo = codigo_match.group(1)
            
            # Extrai o resto após o código
            resto = linha[len(codigo):].strip()
            if resto.startswith('-'):
                resto = resto[1:].strip()
            
            # Extrai nome (até o primeiro |)
            if '|' in resto:
                nome = resto.split('|')[0].strip()
            elif 'Nota:' in resto:
                nome = resto.split('Nota:')[0].strip()
            else:
                nome = resto.strip()
            
            # Remove ** do nome se houver
            nome = nome.strip('*').strip()
            
            # Extrai nota
            nota = 7  # Default
            if 'Nota:' in linha:
                try:
                    nota_parte = linha.split('Nota:')[1]
                    nota_texto = nota_parte.split('/')[0].strip()
                    # Remove caracteres não numéricos
                    nota_texto = re.sub(r'[^\d]', '', nota_texto)
                    if nota_texto:
                        nota = int(nota_texto)
                except:
                    pass
            
            # Extrai justificativa
            justificativa = ""
            if 'Motivo:' in linha:
                just_texto = linha.split('Motivo:')[1].strip()
                # Remove ** do final se houver
                justificativa = just_texto.strip('*').strip()
            
            disc = {
                "codigo": codigo,
                "nome": nome,
                "nota": nota,
                "justificativa": justificativa
            }
            disciplinas.append(disc)
        except Exception as e:
            continue
    
    return disciplinas

async def main():
    # Configuração da API Maritaca
    script_dir = Path(__file__).parent
    dotenv_path = script_dir / ".env"
    load_dotenv(dotenv_path)
    
    maritaca_key = os.getenv("MARITACA_API_KEY")
    if not maritaca_key:
        print("Erro: Chave MARITACA_API_KEY não encontrada no .env")
        print(f"Procurando em: {dotenv_path}")
        return

    # A maritaca utiliza o padrao da OpenAI
    client = OpenAI(
        api_key=maritaca_key,
        base_url="https://chat.maritaca.ai/api"
    )

    # Definição da Ferramenta pro sabia-4
    tools = [{
        "type": "function",
        "function": {
            "name": "buscar_materias_unb",
            "description": "Busca matérias na base de dados da UnB.",
            "parameters": {
                "type": "object",
                "properties": {
                    "interesse": {
                        "type": "string",
                        "description": "Gere exatamente 4 termos técnicos ou sinônimos separados por vírgula."
                    }
                },
                "required": ["interesse"]
            }
        }
    }]

    system_prompt = (
        "Você é um assistente acadêmico da UnB. "
        "Quando usar 'buscar_materias_unb', extraia o tema central e gere 3-4 termos técnicos relacionados. "
        "\n\n"
        "IMPORTANTE: Você DEVE listar TODAS as disciplinas retornadas pela ferramenta no seguinte formato OBRIGATÓRIO:\n"
        "**CÓDIGO - NOME DA DISCIPLINA | Nota: X/10 | Motivo:** Justificativa técnica concisa\n"
        "\n"
        "Exemplo de formato correto:\n"
        "**CIC0269 - PROCESSAMENTO DE LINGUAGEM NATURAL | Nota: 9/10 | Motivo:** Aplica técnicas de IA para análise de texto\n"
        "**CIC0087 - APRENDIZADO DE MÁQUINA | Nota: 10/10 | Motivo:** Fundamentos essenciais de ML e algoritmos\n"
        "\n"
        "REGRAS:\n"
        "- Liste SEMPRE entre 5-8 disciplinas (use todas as retornadas pela ferramenta se relevantes)\n"
        "- Ignore disciplinas de extensão ou 'projeto integrador'\n"
        "- Priorize sobreposição técnica direta com o interesse do aluno\n"
        "- Nota de 1-10 baseada na relevância para o tema pesquisado\n"
        "- Justificativa deve ter no máximo 15 palavras\n"
        "- Se o conteúdo digitado não tiver nenhuma relação com o meio acadêmico, responda de forma educada e neutra\n"
        "- SEMPRE use o formato exato: **CÓDIGO - NOME | Nota: X/10 | Motivo:** texto"
    )

    # MODO API: Se receber dados via stdin, processa uma vez e sai
    if not sys.stdin.isatty():
        try:
            input_data = json.loads(sys.stdin.read())
            interesse = input_data.get("interesse", "")
            
            if not interesse:
                print(json.dumps({"success": False, "error": "Campo 'interesse' é obrigatório"}))
                return
            
            # Usa o mesmo Python que está rodando este script
            script_dir = Path(__file__).parent
            venv_python = script_dir.parent / "venv" / "Scripts" / "python.exe"
            python_exe = str(venv_python) if venv_python.exists() else sys.executable
            server_script = script_dir / "servidor_mcp_sabia.py"
            
            server_params = StdioServerParameters(
                command=python_exe,
                args=[str(server_script)]
            )
            
            async with stdio_client(server_params) as (read, write):
                async with ClientSession(read, write) as session:
                    await session.initialize()
                    
                    resposta_texto = await processar_consulta(interesse, client, session, system_prompt, tools)
                    disciplinas = parse_resposta_sabia(resposta_texto)
                    
                    resultado = {
                        "success": True,
                        "disciplinas": disciplinas,
                        "resposta_completa": resposta_texto
                    }
                    
                    print(json.dumps(resultado, ensure_ascii=False))
            return
            
        except json.JSONDecodeError:
            print(json.dumps({"success": False, "error": "JSON inválido no input"}))
            return
        except Exception as e:
            print(json.dumps({"success": False, "error": str(e)}))
            return

    # MODO INTERATIVO: Interface de linha de comando
    print("Conectando ao Servidor MCP...")
    
    # Usa o Python atual (sys.executable) para garantir mesmo ambiente
    script_dir = Path(__file__).parent
    venv_python = script_dir.parent / "venv" / "Scripts" / "python.exe"
    python_exe = str(venv_python) if venv_python.exists() else sys.executable
    server_script = script_dir / "servidor_mcp_sabia.py"
    
    server_params = StdioServerParameters(
        command=python_exe,
        args=[str(server_script)]
    )
    
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print("✅ Agente Sabiá-4 Pronto!")
            
            # historico de mensagens para manter o contexto
            mensagens = [{"role": "system", "content": system_prompt}]

            while True:
                pergunta = input("\nVocê: ")
                if pergunta.lower() == 'sair': break
                
                mensagens.append({"role": "user", "content": pergunta})
                print("Pensando (Sabiázinho-4)...")

                # chamada inicial para expansão de termos
                response = client.chat.completions.create(
                    model="sabiazinho-4", 
                    messages=mensagens,
                    tools=tools,
                    tool_choice="auto"
                )

                response_message = response.choices[0].message
                
                # Se o Sabiá decidir usar a ferramenta de busca
                if response_message.tool_calls:
                    mensagens.append(response_message)
                    
                    for tool_call in response_message.tool_calls:
                        args = json.loads(tool_call.function.arguments)
                        expansao = [t.strip() for t in args["interesse"].split(",")]
                        # Garante a busca pelo termo original + expansao
                        #termos_busca = list(dict.fromkeys([pergunta.strip()] + expansao))
                        termos_busca = expansao
                        
                        resultados_totais = {}
                        print(f"Busca múltipla com Sabiá-4 ({len(termos_busca)} termos)")

                        for idx, termo in enumerate(termos_busca):
                            print(f'      🔍 [TERMO]: {termo}')
                            try:
                                # Timeout maior para o primeiro termo (inicialização do servidor)
                                timeout = 30.0 if idx == 0 else 10.0
                                print(f'esperando mcp (timeout: {timeout}s)...')
                                res_mcp = await asyncio.wait_for(
                                    session.call_tool("buscar_materias_unb", arguments={"interesse": termo}),
                                    timeout=timeout
                                )
                                print('mcp respondeu!')
                                
                                if not res_mcp.content: 
                                    print(f'      ⚠️ [BANCO -> {termo}]: Sem conteúdo')
                                    continue

                                # --- RETORNO DO BANCO ---
                                dados_brutos = res_mcp.content[0].text
                                print(f"      📥 [BANCO -> {termo}]: {dados_brutos}\n")
                                # -------------------------------------------------------

                                lista_mats = json.loads(dados_brutos)
                                for mat in lista_mats:
                                    resultados_totais[mat.get("Codigo", "")] = mat
                            except asyncio.TimeoutError:
                                print(f'      ❌ [BANCO -> {termo}]: Timeout ({timeout}s)')
                                continue
                            except Exception as e:
                                print(f'      ❌ [BANCO -> {termo}]: Error - {str(e)}')
                                continue

                        # Adiciona o resultado da ferramenta ao histórico
                        mensagens.append({
                            "tool_call_id": tool_call.id,
                            "role": "tool",
                            "name": "buscar_materias_unb",
                            "content": json.dumps(list(resultados_totais.values()))
                        })

                    # Gera a resposta final rankeada
                    final_response = client.chat.completions.create(
                        model="sabia-4",
                        messages=mensagens
                    )
                    
                    final_text = final_response.choices[0].message.content
                    print(f"\n🤖 Coordenador UnB (Sabiá-4): {final_text}")
                    mensagens.append({"role": "assistant", "content": final_text})
                else:
                    print(f"\n🤖 Coordenador UnB (Sabiá-4): {response_message.content}")
                    mensagens.append(response_message)

if __name__ == "__main__":
    asyncio.run(main())