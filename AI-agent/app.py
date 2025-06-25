import streamlit as st
from ragflow_agent_client import RagflowClient
import unicodedata
from visualizaJson import processar_json_disciplinas
from visualizaJsonMateriasAssociadas import gerar_texto_ranking
#from agent_api.config import AGENT_EXPLANATOR_ID

def remover_acentos_nativo(texto):
    # Normaliza para o formato NFD, que separa o caractere do acento
    texto_normalizado = unicodedata.normalize('NFD', texto)
    # Remove os caracteres de combinação (os acentos)
    texto_sem_acento = "".join(c for c in texto_normalizado if not unicodedata.combining(c))
    return texto_sem_acento


st.set_page_config(page_title="Assistente de Turmas UnB", layout="centered")
st.title("📚 Assistente de Turmas da UnB")
with st.expander("Instruções de Uso", expanded=True):
    st.markdown("""
        - **VÁ DIRETO AO PONTO:** DIGITE APENAS O CONCEITO/TEMA DE ESTUDO.
        - **EVITE CONVERSA:** NÃO USE "OI", "OLÁ", "POR FAVOR", ETC.
        - **NÃO DEU CERTO?** TENTE PALAVRAS-CHAVE DIFERENTES OU SINÔNIMOS.
    
        **Exemplo:** `FÍSICA QUÂNTICA` , `REDES NEURAIS`,  `HISTOLOGIA`
    """)
materia = st.text_area("Digite o conteudo:", height=300)
materia = remover_acentos_nativo(materia)
materia = materia.upper()
#Printando MATERIA DIGITADA
print(f'materia digitada : {materia}')

# Inicializa variáveis de estado
if "resposta_agente" not in st.session_state:
    st.session_state.resposta_agente = None
#if "mostrar_detalhes" not in st.session_state:
    #st.session_state.mostrar_detalhes = False
#if "detalhes_agente" not in st.session_state:
    #st.session_state.detalhes_agente = None

if st.button("Analisar"):
    if not materia.strip():
        st.warning("Por favor, cole uma matéria para análise.")
    else:
        with st.spinner("Analisando..."):
            try:
                client = RagflowClient()
                #conteudos_associados = client.gerar_palavrasChaves(materia)
                session_id = client.start_session(materia)
                print(f'Session ID ={session_id}')
                result = client.analyze_materia(materia, session_id)
                print(f'RESULT = {result}')

                if result.get("code") == 0:
                    #resposta = result["data"]["answer"]
                    resposta = gerar_texto_ranking(result)
                    #print(f'RESULT FORMATADO : {resposta}\n')
                    st.session_state.resposta_agente = resposta
                    print(f'Sessio State Resposta:  {st.session_state.resposta_agente}')
                    #st.session_state.detalhes_agente = None  # Limpa caso nova análise
                    #st.session_state.mostrar_detalhes = "FAKE" in resposta.upper()

                    print(f'RESPOTA = {resposta}')
                    st.success("Resposta do agente:")
                    st.write(resposta)
                else:
                    st.error(f"Erro da API: {result.get('message')}")

            except Exception as e:
                st.error(f"Erro ao conectar com o agente: {e}")