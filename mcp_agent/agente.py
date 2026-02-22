import os
import json
import chromadb
from chromadb.utils import embedding_functions
import google.generativeai as genai

# Configurar a API do Gemini
API_KEY = os.environ.get("GEMINI_API_KEY")

if not API_KEY:
    raise ValueError("Por favor, configure a variável de ambiente GEMINI_API_KEY (ex: set GEMINI_API_KEY=sua_chave).")
genai.configure(api_key=API_KEY)

#  Conectar ao Banco Vetorial Local
client = chromadb.PersistentClient(path="./meu_banco_vetorial")
sentence_transformer_ef = embedding_functions.SentenceTransformerEmbeddingFunction(model_name="all-MiniLM-L6-v2")
collection = client.get_collection(name="materias_unb", embedding_function=sentence_transformer_ef)

#3.0 (TOOL inteligente)
def generalizar_materias(interesse_do_aluno: str) -> str:
    """
    Esta função é uma ferramenta auxiliar para ajudar a generalizar o interesse do aluno.
    Por exemplo, se o aluno disser "Quero aprender sobre Python", esta função pode transformar isso em "programação Python, desenvolvimento de software, linguagens de programação".
    Isso ajuda a aumentar as chances de encontrar matérias relevantes mesmo que o aluno use termos mais específicos ou genéricos.
    """

#3.1 (TOOL)
def buscar_materias_unb(interesse_do_aluno: str) -> str:
    """
    Busca matérias universitárias na base de dados com base no interesse do aluno.
    Sempre use esta ferramenta quando o aluno pedir recomendações de cursos ou disciplinas.
    
    Args:
        interesse_do_aluno: O tópico, assunto ou palavra-chave que o aluno quer estudar.
    """
    print(f"\n[  Consultando o Vector DB por: '{interesse_do_aluno}'... ]")
    
    # Busca as 5 matérias mais relevantes no banco
    resultados = collection.query(
        query_texts=[interesse_do_aluno],
        n_results=5 
    )
    
    lista_final = []
    
    if not resultados['documents'][0]:
        return "Nenhuma matéria encontrada na base de dados para este tema."

    # Extraindo os dados do ChromaDB
    for i in range(len(resultados['documents'][0])):
        documento = resultados['documents'][0][i]
        metadado = resultados['metadatas'][0][i]
        
        lista_final.append({
            "Codigo": metadado.get("codigo"),
            "Materia": metadado.get("disciplina"),
            "Departamento": metadado.get("unidade_responsavel"),
            "Ementa_Resumida": documento[:600] + "..." # Mandamos até 600 caracteres para economizar limite do Gemini
        })
                
    return json.dumps(lista_final, ensure_ascii=False, indent=2)

# 4. Iniciar o Agente Gemini
modelo = genai.GenerativeModel(
    model_name='gemini-2.5-flash',
    tools=[buscar_materias_unb],
    system_instruction=(
        "Você é um consultor acadêmico amigável da Universidade de Brasília (UnB). "
        "Sua função é recomendar disciplinas para os alunos com base em seus interesses. "
        "Use a ferramenta buscar_materias_unb SEMPRE que for recomendar algo. "
        "Ao responder, cite o nome da matéria, o código, de qual departamento ela é e faça um breve resumo do porquê ela é interessante para o aluno."
    )
)

chat = modelo.start_chat(enable_automatic_function_calling=True)

# 5. Interface do Terminal
print("\n" + "="*60)
print(" Agente de Recomendação da UnB Iniciado!")
print("Faça perguntas como: 'Quais matérias de programação Python tem?'")
print("Digite 'sair' para encerrar.")
print("="*60 + "\n")

while True:
    pergunta = input("\nVocê: ")
    if pergunta.lower() == 'sair':
        break
        
    try:
        resposta = chat.send_message(pergunta)
        print(f"\n Agente: {resposta.text}")
    except Exception as e:
        print(f"\n Ocorreu um erro: {e}")