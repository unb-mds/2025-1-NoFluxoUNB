import asyncio
import os
import json
from openai import OpenAI
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    # Configuração da API Maritaca
    maritaca_key = os.environ.get("MARITACA_API_KEY")
    if not maritaca_key:
        print("Erro: Chave MARITACA_API_KEY não encontrada.")
        return

    # a maritaca utiliza o padrao daOpenAI
    client = OpenAI(
        api_key=maritaca_key,
        base_url="https://chat.maritaca.ai/api"
    )

    # definicao da Ferramenta pro sabia-4 (testar o sabia-3)
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
        "Aja como Coordenador UnB. Ferramenta 'buscar_materias_unb': extraia o TEMA CENTRAL e gere 3-4 termos técnicos. "
        "FILTRO: Ignore disciplinas de extensão ou de 'projeto integrador'. "
        "RANKING: Priorize sobreposição técnica direta, mas inclua matérias correlatas se forem úteis para o tema. "
        "Tente sempre listar entre 5 e 8 disciplinas para dar opções variadas ao aluno. "
        "SAÍDA: 'Código - Nome | Nota: X/10 | Motivo: [Justificativa técnica de até 15 palavras]'."
    )

    print("Conectando ao Servidor MCP...")
    server_params = StdioServerParameters(command="python", args=["servidor_mcp.py"])
    
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

                        for termo in termos_busca:
                            try:
                                res_mcp = await session.call_tool("buscar_materias_unb", arguments={"interesse": termo})
                                if not res_mcp.content: continue

                                # --- RETORNO DO BANCO ---
                                dados_brutos = res_mcp.content[0].text
                                print(f"      📥 [BANCO -> {termo}]: {dados_brutos}\n")
                                # -------------------------------------------------------

                                lista_mats = json.loads(res_mcp.content[0].text)
                                for mat in lista_mats:
                                    resultados_totais[mat.get("Codigo", "")] = mat
                            except: continue

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