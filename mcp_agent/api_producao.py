from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
import json
import re
from pydantic import BaseModel
from openai import OpenAI
import google.generativeai as genai
from supabase import create_client
from dotenv import load_dotenv

# 1. INICIALIZAÇÃO GLOBAL (Roda apenas quando o servidor liga)
load_dotenv()

# Clientes globais mantêm conexões persistentes ("quentes")
genai.configure(api_key=os.environ.get("GOOGLE_API_KEY"))
supabase = create_client(os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SERVICE_ROLE_KEY"))
client_maritaca = OpenAI(api_key=os.environ.get("MARITACA_API_KEY"), base_url="https://chat.maritaca.ai/api")

# Configuração do FastAPI
app = FastAPI(title="Darcy AI - API da UnB", version="1.0")

# CORS - Configurar origens permitidas em produção
ALLOWED_ORIGINS = os.environ.get("ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,  # Em produção, substituir por domínios reais
    allow_credentials=True,
    allow_methods=["POST"],
    allow_headers=["*"],
)

# Modelo de entrada de dados esperado do frontend/usuário
class Consulta(BaseModel):
    interesse: str

# Prompt do Sistema (mantido do seu código original)
SYSTEM_PROMPT = (
    "Você é o Darcy, assistente da UnB. Sua tarefa é listar as disciplinas encontradas no banco de dados.\n\n"
    "REGRAS CRÍTICAS:\n"
    "1. Liste as disciplinas retornadas pela ferramenta 'buscar_materias_unb', com limite máximo de 14 disciplinas.\n"
    "2. Use EXATAMENTE este formato: **CÓDIGO - NOME DA DISCIPLINA | Nota: X/10 | Motivo:** justificativa curta.\n"
    "3. Priorize as disciplinas mais relevantes (maior nota) se houver mais de 14.\n"
    "4. NÃO adicione introduções de respostas ou conclusões. Apenas a lista completa.\n"
    "5. EXCEÇÕES: ignore disciplinas genéricas como 'Práticas de Extensão', 'Projeto Integrador', 'Formação em...', ou que contenham 'MONITORIA' ou 'MONITORIA EM' no nome.\n"
    "6. Ordene por relevância (nota) decrescente."
)

TOOLS = [{
    "type": "function",
    "function": {
        "name": "buscar_materias_unb",
        "description": "Busca matérias na base de dados da UnB expandindo o termo de pesquisa.",
        "parameters": {
            "type": "object",
            "properties": {
                "termos_busca": {
                    "type": "array",
                    "items": {
                        "type": "string"
                    },
                    "description": "Lista com EXATAMENTE 4 strings obrigatórias: [termo_principal, sinônimo1, sinônimo2, termo_relacionado]. SEMPRE preencha os 4 campos, mesmo que repita termos similares."
                }
            },
            "required": ["termos_busca"]
        }
    }
}]

def parse_resposta_sabia(texto: str) -> list:
    """Extrai as disciplinas do texto da IA bloqueando qualquer duplicação."""
    disciplinas = []
    codigos_vistos = set() # O nosso rastreador de duplicatas
    
    linhas = texto.split('\n')
    for linha in linhas:
        linha = linha.strip().lstrip('*').lstrip('-').lstrip('•').strip()
        codigo_match = re.match(r'([A-Z]{3}\d{4})', linha)
        if not codigo_match: continue
            
        try:
            codigo = codigo_match.group(1).upper()
            
            # Se já vimos esse código pula para a próxima linha
            if codigo in codigos_vistos:
                continue
                
            codigos_vistos.add(codigo) # Registra que já pegou essa matéria
            
            resto = linha[len(codigo):].strip().lstrip('-').strip()
            
            nome = resto.split('|')[0].strip() if '|' in resto else resto.split('Nota:')[0].strip() if 'Nota:' in resto else resto.strip()
            nome = nome.strip('*').strip()
            
            nota = 7
            if 'Nota:' in linha:
                nota_texto = re.sub(r'[^\d]', '', linha.split('Nota:')[1].split('/')[0])
                if nota_texto: nota = int(nota_texto)
            
            justificativa = ""
            if 'Motivo:' in linha:
                justificativa = linha.split('Motivo:')[1].strip().strip('*').strip()
            
            disciplinas.append({"codigo": codigo, "nome": nome, "nota": nota, "justificativa": justificativa})
        except Exception:
            continue
            
    return disciplinas

def ferramenta_buscar_materias_unb(termos_busca: list) -> str:
    print(f"\n[DEBUG] 🧠 Termos recebidos da Maritaca: {termos_busca}")
    try:
        # Filtrar termos vazios antes de enviar para o Gemini
        termos_validos = [t.strip() for t in termos_busca if t and t.strip()]
        
        if not termos_validos:
            print("⚠️ Nenhum termo válido para busca.")
            return "Nenhum termo de busca válido foi fornecido."
        
        print(f"[DEBUG] ✅ Termos válidos após filtro: {termos_validos}")
        
        # 1. GERAÇÃO EM LOTE (BATCH EMBEDDING): 1 única chamada para a API do Gemini
        result = genai.embed_content(
            model="models/gemini-embedding-001",
            content=termos_validos, 
            task_type="retrieval_query",
            output_dimensionality=256
        )
        
        vetores = result.get('embeddings') or result.get('embedding')
        resultados_finais = {}

        # 2. BUSCA NO BANCO: 1 por 1 para cada palavra-chave gerada pela Maritaca
        for i, vetor in enumerate(vetores):
            termo_atual = termos_validos[i]
            print(f"[DEBUG] 🔍 Consultando Supabase para: '{termo_atual}'...")
            
            res = supabase.rpc("match_materias", {
                "query_embedding": vetor,
                "match_threshold": 0.6,
                "match_count": 20 # Puxa as 5 melhores de cada termo
            }).execute()
            
            print(f"[DEBUG] Resultados para '{termo_atual}': {len(res.data or [])} encontrados.")
            print(f"[DEBUG] Dados brutos: {res.data}\n\n\n")
            print(f'[DEBUG] {"-"*50}\n')
            for item in (res.data or []):
                # Pega o código, remove espaços em branco nas pontas e força MAIÚSCULA
                codigo_bruto = item.get("codigo_materia") or ""
                cod = str(codigo_bruto).strip().upper()
                sim = item.get("similaridade", 0)
                
                # Só adiciona se o código for válido (não vazio)
                if cod:
                    if cod not in resultados_finais or sim > resultados_finais[cod]["similaridade"]:
                        resultados_finais[cod] = item

        # Formatação final
        lista_retorno = [
            {
                "codigo": item.get("codigo_materia"),
                "nome": item.get("nome_materia"),
                "similaridade": round(item.get("similaridade", 0), 2)
            }
            for item in resultados_finais.values()
        ]
            
        # Ordena e limita a 15 para economizar tokens na resposta da Maritaca
        lista_retorno = sorted(lista_retorno, key=lambda x: x['similaridade'], reverse=True)[:25]
        #lista_final = []
        
        '''
        for item in lista_retorno:

            if item['codigo'] not in lista_final:
                lista_final.append(item)
        '''



        print(f"[DEBUG] ✅ Total de matérias únicas retornadas: {len(lista_retorno)}")

        for materia in lista_retorno:
            print(f"[DEBUG] {materia['codigo']} - {materia['nome']} | Similaridade: {materia['similaridade']}")


        return json.dumps(lista_retorno, ensure_ascii=False)
    
    except Exception as e:
        print(f"❌ Erro na ferramenta de busca: {e}")
        return json.dumps([])

# 3. ENDPOINT DE HEALTH CHECK (para monitoramento)
@app.get("/health")
async def health_check():
    """Endpoint para verificar se a API está funcionando"""
    return {
        "status": "healthy",
        "service": "Darcy AI",
        "version": "2.0"
    }

# 4. O ENDPOINT PRINCIPAL DA API
@app.post("/recomendar")
async def recomendar_materias(consulta: Consulta):
    if not consulta.interesse.strip():
        raise HTTPException(status_code=400, detail="O campo 'interesse' não pode estar vazio.")

    mensagens = [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": consulta.interesse}]

    try:
        # Passa a bola para o Sabiá analisar o interesse
        response = client_maritaca.chat.completions.create(
            model="sabiazinho-4", 
            messages=mensagens,
            tools=TOOLS,
            tool_choice="auto"
        )

        msg_ia = response.choices[0].message
        
        # Se o Sabiá decidir buscar no banco
        if msg_ia.tool_calls:
            mensagens.append(msg_ia)
            tool_call = msg_ia.tool_calls[0] # Usa apenas a primeira para economia extrema
            args = json.loads(tool_call.function.arguments)
            
            # ✅ CORREÇÃO: Extraindo 'termos_busca' em vez de 'interesse'
            termos = args.get("termos_busca", [])
            
            print(f"\n[DEBUG] Termos enviados para o banco: {termos}\n")
            
            # Chama a função Python passando a lista
            dados_banco = ferramenta_buscar_materias_unb(termos)
            
            mensagens.append({
                "tool_call_id": tool_call.id,
                "role": "tool",
                "name": "buscar_materias_unb",
                "content": dados_banco
            })

            # Resposta final do Sabiá com limite de tokens aumentado
            final_response = client_maritaca.chat.completions.create(
                model="sabia-4", 
                messages=mensagens,
                max_tokens=1000  # Aumentado para comportar mais disciplinas
            )
            resposta_texto = final_response.choices[0].message.content
            print(f"\n[DEBUG] Texto bruto da IA:\n{resposta_texto}\n")
        else:
            resposta_texto = msg_ia.content

        # Retorna o JSON estruturado pronto para o frontend
        return {
            "success": True,
            "disciplinas": parse_resposta_sabia(resposta_texto),
            "resposta_completa": resposta_texto
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
