# ragflow_agent_client.py (VERSÃO FINAL E FUNCIONAL)
import requests
import json
from config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID
#import formataResposta

API_KEY = RAGFLOW_API_KEY
BASE_URL = RAGFLOW_BASE_URL
AGENT_ID = RAGFLOW_AGENT_ID

class RagflowClient:
    def __init__(self, agent_id=AGENT_ID):
        self.agent_id = agent_id
        self.url = f"{BASE_URL}/api/v1/agents/{self.agent_id}/completions"
        self.headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        }

    def start_session(self, materia):
        resp = requests.post(self.url, headers=self.headers, json={"materia": materia, "stream": False})
        #Printando 'resp'
        print(f'resp:  {resp}\n')

        resp.raise_for_status()
        print("nao deu ERROR RAISE")

        print(f'Printando data = {resp.json()}')
        data = resp.json()
        print(f'data: {data}\n')
        return data["data"]["session_id"]
    
    '''
    def gerar_palavrasChaves(self, materia: str):

        payload = {
            "materia": materia,
            "stream": False
        }
        resp = requests.post(self.url, headers=self.headers, json=payload)
        print(f'resp GERAR PALAVRA CHAVE :  {resp}\n\n')
        resp.raise_for_status()
        print(f'RESP JSON GERAR PALAVRA CHAVE = {resp.json()}\n')
        return resp.json()

    '''

    def analyze_materia(self, materia: str, session_id: str):
        payload = {
            "question": materia,
            "session_id": session_id,
            "stream": False
        }
        resp = requests.post(self.url, headers=self.headers, json=payload)
        #Printando 'resp  analyze_materia'
        print(f'resp analyze_materia :  {resp}\n\n')
        resp.raise_for_status()
        print(f'RESP JSON = {resp.json()}\n')
        return resp.json()