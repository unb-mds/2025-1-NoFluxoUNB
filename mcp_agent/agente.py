import asyncio
import os
from google import genai
from google.genai import types
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    chave_api = os.environ.get("GEMINI_API_KEY")
    if not chave_api:
        print(" Erro: Chave da API não encontrada")
        return

    client = genai.Client(api_key=chave_api)
    
    # ferramenta a exigir um termo generalizado
    ferramenta_mcp = types.Tool(
        function_declarations=[
            types.FunctionDeclaration(
                name="buscar_materias_unb",
                description="Busca matérias na base de dados da UnB com base no interesse do aluno.",
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "interesse": types.Schema(
                            type="STRING",
                            description=(
                                "NÃO USE APENAS O TERMO ORIGINAL DO USUÁRIO. "
                                "Expanda o interesse incluindo 4 a 5 sinônimos, subáreas e termos técnicos relacionados, "
                                "separados por vírgula. Exemplo: se o usuário pedir 'inteligência artificial', "
                                "envie 'inteligência artificial, machine learning, redes neurais, deep learning, visão computacional'."
                            )
                        )
                    },
                    required=["interesse"]
                )
            )
        ]
    )
    
    # reforçamos a regra no prompt de sistema
    config = types.GenerateContentConfig(
        tools=[ferramenta_mcp],
        temperature=0.3, # temperatura a mais para ele ser criativo nos sinonimoss
        system_instruction=(
            "Você é o Coordenador Acadêmico da UnB. Sua missão é recomendar matérias de forma inteligente. "
            "Sempre use a ferramenta 'buscar_materias_unb' para obter os dados brutos. "
            "REGRA DE RANKEAMENTO: Analise as ementas recebidas e crie um ranking de importância (de 1 a 5) "
            "baseado no quanto a matéria realmente ajudará o aluno no tema escolhido. "
            "Atribua uma 'Nota de Relevância' de 0 a 10 para cada uma, baseada no seu julgamento técnico. "
            "REPOSTA ENXUTA: 'Rank # - Código - Nome | Motivo: [Máximo 10 palavras]'."
        )
    )
    
    chat = client.chats.create(model='gemini-2.5-flash', config=config)

    print(" Conectando ao Servidor MCP")
    
    server_params = StdioServerParameters(command="python", args=["servidor_mcp.py"])
    
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print(" Agente de IA Pronto(Digite 'sair' para encerrar)")
            
            while True:
                pergunta = input("\nVocê: ")
                if pergunta.lower() == 'sair': 
                    break
                
                print("Pensando...")
                resposta = chat.send_message(pergunta)
                
                if resposta.function_calls:
                    chamada = resposta.function_calls[0]
                    ferramenta = chamada.name
                    arg_interesse = chamada.args["interesse"]
                    
                    
                    print(f"Agente expandiu a busca para: '{arg_interesse}'")
                    
                    resultado_mcp = await session.call_tool(
                        ferramenta, 
                        arguments={"interesse": arg_interesse}
                    )
                    dados_json = resultado_mcp.content[0].text
                    
                    print("Dados recebidos do banco, formatando a resposta final")
                    
                    resposta_final = chat.send_message(
                        types.Part.from_function_response(
                            name=ferramenta,
                            response={"resultado": dados_json}
                        )
                    )
                    print(f"\n🤖 Coordenador UnB: {resposta_final.text}")

                    try:
                        tokens_entrada = resposta_final.usage_metadata.prompt_token_count
                        tokens_saida = resposta_final.usage_metadata.candidates_token_count
                        total_tokens = resposta_final.usage_metadata.total_token_count
                        
                        print("\n📊 --- AUDITORIA DE CUSTOS (Gemini) ---")
                        print(f"📥 Tokens de Entrada (Prompt + JSON do Banco): {tokens_entrada}")
                        print(f"📤 Tokens de Saída (Resposta gerada): {tokens_saida}")
                        print(f"💰 Total da Chamada: {total_tokens} tokens")
                        print("---------------------------------------")
                    except AttributeError:
                        print("📊 (Metadados de token não disponíveis nesta chamada)")
                        
                else:
                    print(f"\n🤖 Coordenador UnB: {resposta.text}")



if __name__ == "__main__":
    asyncio.run(main())