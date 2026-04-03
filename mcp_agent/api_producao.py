from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
import os
import json
import re
from pydantic import BaseModel
from openai import OpenAI
import google.generativeai as genai
from supabase import create_client
from dotenv import load_dotenv

import time

# 1. INICIALIZAÇÃO GLOBAL (Roda apenas quando o servidor liga)
load_dotenv()

# Print env vars on startup for debugging
print("\n--- MCP Agent env vars at startup ---")
for key in ("GOOGLE_API_KEY", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "MARITACA_API_KEY", "ALLOWED_ORIGINS"):
    value = os.environ.get(key)
    if value:
        preview = value[:8] + "..." if len(value) > 8 else value
        print(f"  {key} = {preview} (len={len(value)})")
    else:
        print(f"  {key} = NOT SET")
print("---\n")

# Clientes globais mantêm conexões persistentes
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
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)

# Modelo de entrada de dados esperado do frontend/usuário
# Modelo de entrada de dados esperado do frontend/usuário
class Consulta(BaseModel):
    interesse: str
    matriz_curricular: str = ""

# Prompt do Sistema
SYSTEM_PROMPT = (
    "Você é o Darcy, assistente da UnB. Sua tarefa é listar as disciplinas encontradas no banco de dados.\n\n"
    "REGRAS CRÍTICAS:\n"
    "1. SE BUSCAR OPTATIVAS ('buscar_optativas_curso'):\n"
    "   - Liste no MÁXIMO 50 disciplinas.\n"
    "   - Use o formato: **CÓDIGO - NOME DA DISCIPLINA\n"
    "2. SE BUSCAR ASSUNTO ('buscar_materias_unb'):\n"
    "   - Liste no MÁXIMO 15 disciplinas.\n"
    "   - Use o formato detalhado: **CÓDIGO - NOME DA DISCIPLINA | Nota: X/10 | Motivo:** justificativa curta sobre o assunto.\n"
    "3. NÃO adicione introduções de respostas ou conclusões. Apenas a lista completa.\n"
    "4. EXCEÇÕES: ignore disciplinas genéricas como 'Práticas de Extensão', 'Projeto Integrador', 'Formação em...', ou que contenham 'MONITORIA' ou 'MONITORIA EM' no nome.\n"
    "5. Ordene por relevância (nota) decrescente."
    "6. Não responda a perguntas que não sejam sobre disciplinas. Exemplo: 'Qual é a capital do Brasil?', ou 'O que é um vector?', ou 'Quanto é 2+2'"
)

TOOLS = [
    {
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
    },
    {
        "type": "function",
        "function": {
            "name": "buscar_optativas_curso",
            "description": "Busca as disciplinas OPTATIVAS específicas da matriz curricular do usuário logado.",
            "parameters": {
                "type": "object",
                "properties": {
                    "aviso": {
                        "type": "string",
                        "description": "Apenas envie 'ok' para prosseguir."
                    }
                },
                "required": ["aviso"]
            }
        }
    }
]

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

import re # Certifique-se de que o 'import re' está no topo do seu ficheiro (já deve estar)

import re # Certifique-se de que o 'import re' está no topo do seu ficheiro (já deve estar)

# --- NOVA FUNÇÃO: O FLUXO DIRETO PELA MATRIZ (COM LIMPEZA REGEX) ---
def ferramenta_buscar_optativas(matriz_curricular: str) -> str:
    # (REGEX):
    # " - XXXX.X" (ex: " - 2025.1") no final da string e remove
    # Se receber "8117/-3 - 2025.1", transforma em "8117/-3"
    # Se receber "1856/3 - 2024.2", transforma em "1856/3"
    # Se já vier "8117/-3" sem o ano não altera nada.
    matriz_limpa = re.sub(r'\s*-\s*\d{4}\.\d+$', '', matriz_curricular).strip()
    
    print(f"\n[DEBUG] 🎓 Frontend enviou: '{matriz_curricular}' | Buscando no BD por: '{matriz_limpa}'")
    
    if not matriz_limpa:
        return json.dumps([{"codigo": "ERRO", "nome": "Matriz curricular não informada. Peça ao aluno para enviar o currículo ou fazer upload do histórico."}])
        
    try:
        #pegar ID da matriz no banco
        mat_id_res = supabase.table("matrizes").select("id_matriz").ilike("curriculo_completo", f"%{matriz_limpa}%").execute()
        
        if not mat_id_res.data: 
            return json.dumps([{"codigo": "ERRO", "nome": f"A matriz '{matriz_limpa}' não foi encontrada na base de dados."}])
            
        id_matriz = mat_id_res.data[0]['id_matriz']
        print(f"[DEBUG] ID da Matriz encontrada: {id_matriz}")

        # pegar matérias por curso onde tipo_natureza == 1 (Optativas)
        materias_res = supabase.table("materias_por_curso").select("id_materia").eq("id_matriz", id_matriz).eq("tipo_natureza", 1).execute()

        if not materias_res.data:
            print("[DEBUG] Nenhuma optativa encontrada para esta matriz.")
            return json.dumps([])

        ids_optativas = [item["id_materia"] for item in materias_res.data]
        
        detalhes_res = supabase.table("materias").select("codigo_materia, nome_materia").in_("id_materia", ids_optativas).execute()


        #print(f"[DEBUG] ✅ Encontradas {len(materias_res.data)} optativas na matriz.")

        '''
        for i in range(3):
            print(f"[DEBUG] ✅ Optativa {i+1}: {materias_res.data[i]}\n")
            materiaEncontrada= supabase.table("materias").select("nome_materia","codigo_materia").eq("id_materia", materias_res.data[i]["id_materia"])
            materiaEncontrada = materiaEncontrada.data
            time.sleep(2)
            print(f"disciplina: {materiaEncontrada}\n")
        '''
        #x = json.dumps(detalhes_res.data,ensure_ascii=False)

        
        print(f"[DEBUG] ✅ Encontradas {len(detalhes_res.data)} optativas na matriz.")

       
        nomes_ignorados = ["ATIVIDADE DE EXTENSÃO", "ATIVIDADE COMPLEMENTAR"]
        detalhes_res.data = [m for m in detalhes_res.data if m.get("nome_materia") not in nomes_ignorados]
            #print(f"[DEBUG] ✅ Optativa {i+1}: {detalhes_res.data[i]}\n")


        return json.dumps(detalhes_res.data, ensure_ascii=False)
        
    except Exception as e:
        print(f"❌ Erro no fluxo de optativas: {e}")
        return json.dumps([])

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
            
        # Ordena e limita a 25 para economizar tokens na resposta da Maritaca
        lista_retorno = sorted(lista_retorno, key=lambda x: x['similaridade'], reverse=True)[:25]

        print(f"[DEBUG] ✅ Total de matérias únicas retornadas: {len(lista_retorno)}")

        return json.dumps(lista_retorno, ensure_ascii=False)
    
    except Exception as e:
        print(f"❌ Erro na ferramenta de busca, tente novamente mais tarde: {e}")
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
            nome_ferramenta = tool_call.function.name
            
            # --- ROTEAMENTO ---
            if nome_ferramenta == "buscar_optativas_curso":
                print(f"\n[DEBUG] 🎓 IA escolheu buscar optativas do curso.")
                # Passa a string da matriz direto da consulta!
                dados_banco = ferramenta_buscar_optativas(consulta.matriz_curricular)
            elif nome_ferramenta == "buscar_materias_unb":
                termos = args.get("termos_busca", [])
                print(f"\n[DEBUG] Termos enviados para o banco: {termos}\n")
                dados_banco = ferramenta_buscar_materias_unb(termos)
            else:
                dados_banco = "[]"
            
            mensagens.append({
                "tool_call_id": tool_call.id,
                "role": "tool",
                "name": nome_ferramenta,
                "content": dados_banco
            })

            # Resposta final do Sabiá com limite de tokens aumentado
            final_response = client_maritaca.chat.completions.create(
                model="sabia-4", 
                messages=mensagens,
                max_tokens=5000  # Aumentado para comportar mais disciplinas
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


# 5. ENDPOINT DE STREAMING (SSE)
def _sse_event(stage: str, **kwargs) -> str:
    """Format a Server-Sent Event."""
    data = {"stage": stage, **kwargs}
    return f"data: {json.dumps(data, ensure_ascii=False)}\n\n"


@app.post("/recomendar-stream")
async def recomendar_materias_stream(consulta: Consulta):
    if not consulta.interesse.strip():
        raise HTTPException(status_code=400, detail="O campo 'interesse' não pode estar vazio.")

    def generate():
        mensagens = [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": consulta.interesse}]

        try:
            # Stage 1: Thinking
            yield _sse_event("thinking", message="Analisando seu interesse...")

            response = client_maritaca.chat.completions.create(
                model="sabiazinho-4",
                messages=mensagens,
                tools=TOOLS,
                tool_choice="auto"
            )

            msg_ia = response.choices[0].message

            if msg_ia.tool_calls:
                mensagens.append(msg_ia)
                tool_call = msg_ia.tool_calls[0]
                args = json.loads(tool_call.function.arguments)
                nome_ferramenta = tool_call.function.name

                # Stage 2: Searching & Roteamento
                if nome_ferramenta == "buscar_optativas_curso":
                    yield _sse_event("searching", message="Consultando sua matriz curricular...")
                    dados_banco = ferramenta_buscar_optativas(consulta.matriz_curricular)
                else:
                    termos = args.get("termos_busca", [])
                    yield _sse_event("searching", message="Buscando disciplinas no banco de dados...")
                    dados_banco = ferramenta_buscar_materias_unb(termos)

                mensagens.append({
                    "tool_call_id": tool_call.id,
                    "role": "tool",
                    "name": nome_ferramenta,
                    "content": dados_banco
                })

                # Stage 3: Generating (with streaming)
                yield _sse_event("generating", message="Gerando recomendações...")

                stream = client_maritaca.chat.completions.create(
                    model="sabia-4",
                    messages=mensagens,
                    max_tokens=5000,
                    stream=True
                )

                resposta_texto = ""
                codigos_emitidos = set()

                for chunk in stream:
                    delta = chunk.choices[0].delta
                    if delta.content:
                        resposta_texto += delta.content

                        # Only parse complete lines to avoid emitting partial names
                        last_newline = resposta_texto.rfind('\n')
                        if last_newline == -1:
                            continue
                        complete_text = resposta_texto[:last_newline]

                        disciplinas = parse_resposta_sabia(complete_text)
                        for disc in disciplinas:
                            if disc["codigo"] not in codigos_emitidos:
                                codigos_emitidos.add(disc["codigo"])
                                yield _sse_event("disciplina", data=disc)

                # Parse any remaining text after stream ends
                disciplinas = parse_resposta_sabia(resposta_texto)
                for disc in disciplinas:
                    if disc["codigo"] not in codigos_emitidos:
                        codigos_emitidos.add(disc["codigo"])
                        yield _sse_event("disciplina", data=disc)
            else:
                resposta_texto = msg_ia.content

            # Stage 4: Done
            yield _sse_event("done", resultado=resposta_texto)

        except Exception as e:
            yield _sse_event("error", message=str(e))

    return StreamingResponse(generate(), media_type="text/event-stream")