import asyncio
import os
import json
from google import genai
from google.genai import types
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    chave_api = os.environ.get("GEMINI_API_KEY")
    if not chave_api:
        print("Chave da API não encontrada.")
        return

    client = genai.Client(api_key=chave_api)
    
    # Configuração da Ferramenta (Tool)
    ferramenta_mcp = types.Tool(
        function_declarations=[
            types.FunctionDeclaration(
                name="buscar_materias_unb",
                description="Busca matérias na base de dados da UnB.",
                parameters=types.Schema(
                    type="OBJECT",
                    properties={
                        "interesse": types.Schema(
                            type="STRING",
                            description="Forneça de 3 a 4 termos técnicos ou sinônimos separados por vírgula. Ex: 'deep learning, redes neurais, machine learning'."
                        )
                    },
                    required=["interesse"]
                )
            )
        ]
    )
    
    # Prompt de Sistema Otimizado
    config = types.GenerateContentConfig(
        tools=[ferramenta_mcp],
        temperature=0.2,
        system_instruction=(
            "Você é o Coordenador Acadêmico da UnB. Sua missão é recomendar matérias de forma inteligente. "
            "REGRA DE EXPANSÃO: Ao usar a ferramenta, gere EXATAMENTE 3 a 4 termos complementares. "
            "REGRA DE RANKEAMENTO: Analise as ementas e crie um ranking baseado no seu julgamento técnico. "
            "Ignore o 'Score_DB' do banco para o seu ranking; use sua própria percepção de relevância. "
            "Ignore disciplinas genéricas como 'Praticas de Extensão' ou 'Projeto Integrador', etc. "
            "RESPOSTA ENXUTA: 'Código - Nome |  Motivo: [Máximo 10 palavras]'."
        )
    )
    
    chat = client.chats.create(model='gemini-2.5-flash', config=config)

    print(" Conectando ao Servidor MCP...")
    server_params = StdioServerParameters(command="python", args=["servidor_mcp.py"])
    
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            print(" Agente de IA Pronto (Digite 'sair' para encerrar)")
            
            while True:
                pergunta = input("\nVocê: ")
                if pergunta.lower() == 'sair': break
                
                print("Pensando...")
                resposta = chat.send_message(pergunta)
                
                if resposta.function_calls:
                    chamada = resposta.function_calls[0]
                    # Pega a expansão da IA e garante o termo original do usuário na lista
                    expansao = [t.strip() for t in chamada.args["interesse"].split(",")]
                    termos_busca = list(dict.fromkeys([pergunta.strip()] + expansao))
                    
                    resultados_totais = {}
                    print(f"Executando busca múltipla ({len(termos_busca)} termos)")

                    for termo in termos_busca:
                        try:
                            print(f" Buscando por: '{termo}'...")
                            res_mcp = await session.call_tool("buscar_materias_unb", arguments={"interesse": termo})
                            if not res_mcp.content: continue
                            
                            lista_mats = json.loads(res_mcp.content[0].text)
                            if isinstance(lista_mats, list):
                                for mat in lista_mats:
                                    # Evita duplicatas usando o Código como chave
                                    resultados_totais[mat.get("Codigo", "")] = mat
                        except:
                            continue

                    # Prepara o pacote final para a IA julgar
                    lista_final = list(resultados_totais.values())
                    
                    resposta_final = chat.send_message(
                        types.Part.from_function_response(
                            name="buscar_materias_unb",
                            response={"resultado": json.dumps(lista_final)}
                        )
                    )
                    print(f"\n🤖 Coordenador UnB: {resposta_final.text}")
                    
                    # Auditoria de custos rápida
                    usage = resposta_final.usage_metadata
                    print(f"📥 Tokens de Entrada (Prompt + JSON do Banco): {usage.prompt_token_count}")
                    print(f"📤 Tokens de Saída (Resposta gerada): {usage.candidates_token_count}")
                    print(f"📊 [Tokens] Total: {usage.total_token_count}")
                else:
                    print(f"\n🤖 Coordenador UnB: {resposta.text}")

if __name__ == "__main__":
    asyncio.run(main())