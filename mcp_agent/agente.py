import asyncio
import os
from google import genai
from google.genai import types
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    chave_api = os.environ.get("GEMINI_API_KEY")
    if not chave_api:
        print(" Chave da API não encontrada.")
        return

    client = genai.Client(api_key=chave_api)
    

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
                            description="A palavra-chave ou assunto de interesse (ex: banco de dados, sustentabilidade)."
                        )
                    },
                    required=["interesse"]
                )
            )
        ]
    )
    
    config = types.GenerateContentConfig(
        tools=[ferramenta_mcp],
        temperature=0.2, 
        system_instruction=(
            "Você é o Coordenador Acadêmico virtual da Universidade de Brasília (UnB). "
            "Sua função é ajudar os alunos a encontrarem disciplinas legais para cursar. "
            "REGRA ABSOLUTA: Sempre que o usuário mencionar um assunto, palavra ou área de interesse "
            "(exemplo: 'banco de dados', 'inteligencia artificial', 'matemática'), "
            "você DEVE OBRIGATORIAMENTE acionar a ferramenta 'buscar_materias_unb'. "
            "Quando a ferramenta devolver o JSON, leia os dados e apresente as opções de forma "
            "amigável, citando o código, nome da matéria e um resumo da ementa."
        )
    )
    
    chat = client.chats.create(model='gemini-2.5-flash', config=config)

    print("Conectando ao Servidor MCP ")
    
    server_params = StdioServerParameters(command="python", args=["servidor_mcp.py"])
    
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print(" Agente de IA Pronto (Digite 'sair' paarrrraa sair)")
            
            while True:
                pergunta = input("\nVocê: ")
                if pergunta.lower() == 'sair': 
                    break
                
                print("Pensando...")
                resposta = chat.send_message(pergunta)
                
                # pedido da IA
                if resposta.function_calls:
                    chamada = resposta.function_calls[0]
                    ferramenta = chamada.name
                    arg_interesse = chamada.args["interesse"]
                    
                    print(f"Agente acionou o banco de dados buscando por: '{arg_interesse}'")
                    
                    # servidor MCP que vai bater no Supabase
                    resultado_mcp = await session.call_tool(
                        ferramenta, 
                        arguments={"interesse": arg_interesse}
                    )
                    dados_json = resultado_mcp.content[0].text
                    
                    print("Dados recebidos do banco formatando a resposta final")

                    
                    print(f"\n DEBUG -----o que o servidor devolveu:\n{dados_json}\n")
                    
                    # IA ler e falar
                    resposta_final = chat.send_message(
                        types.Part.from_function_response(
                            name=ferramenta,
                            response={"resultado": dados_json}
                        )
                    )
                    print(f"\n🤖 Coordenador UnB: {resposta_final.text}")
                else:
                    print(f"\n🤖 Coordenador UnB: {resposta.text}")

if __name__ == "__main__":
    asyncio.run(main())