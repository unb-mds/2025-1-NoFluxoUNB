import requests
from bs4 import BeautifulSoup
import time
import pandas as pd
from urllib.parse import urljoin
import os
import re



url = 'https://sigaa.unb.br/sigaa/public/turmas/listar.jsf'

session = requests.Session()

response = session.get(url, timeout=30)


soup = BeautifulSoup(response.text,"html.parser")

viewstate = soup.find("input", {"name": "javax.faces.ViewState"})['value']

tabela = soup.find('select', {'id': 'formTurma:inputDepto'})

rows = tabela.find_all('option')

deptos_data = []





for row in rows:
    cond = row.get("value")
    if cond != 0 :

        id_depto = row.get("value")
        print(f'id = {id_depto}')

        nome_depto = row.get_text()
        print(f'nome = {nome_depto}\n')

        deptos_info = {
            'id':id_depto,
            #'nome': nome_depto,
        }

        if deptos_info:
            print('dados gravados com sucesso, proximo....\n\n')
            deptos_data.append(deptos_info)

        else:
            print(f'erro detectado, finalizando processo...\n\n')

if deptos_data:
    df = pd.DataFrame(deptos_data)
    # Ordenar por nome do departamento
    #df = df.sort_values('nome')
    # Exportar para CSV
    df.to_csv('departamentos_unb_2.csv', index=False, encoding='utf-8-sig')
    print("Dados salvos com sucesso em 'departamentos_unb_2.csv'")
else:
    print("Nenhum dado foi coletado.")

'''

import csv
csv = 'departamentos_unb_2.csv'

with open(csv,'r') as file:
    csv_reader = csv.reader(file)
    data_lista = []
    for row in csv_reader:
        data_lista.append(row)


print(data_lista)
'''


