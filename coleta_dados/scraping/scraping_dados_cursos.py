import requests
import json

'''
Esse arquivo tem como objetivo extrair dados dos cursos da UnB, os dados serão estruturados na forma:

 "id_curso": 414112,
    "nome": "ADMINISTRAÇÃO",
    "id_servidor": 19007,
    "coordenador": "VANESSA CABRAL GOMES",
    "situacao_curso": "ATIVO",
    "nivel_ensino": null,
    "grau_academico": "Bacharelado",
    "modalidade_educacao": "Presencial",
    "area_conhecimento": "Ciências Sociais Aplicadas",
    "tipo_oferta": "Semestral",
    "turno": "Matutino e Vespertino",
    "tipo_ciclo_formacao": "Um ciclo",
    "municipio": "BRASÍLIA",
    "campus": "DARCY RIBEIRO",
    "id_unidade_responsavel": 327,
    "website": null,
    "data_funcionamento": "18/07/2018",
    "codigo_inep": "145",
    "portaria_reconhecimento": "271",
    "convenio_academico": null
    

'''


# URL do JSON
url = (
    "http://dados.unb.br/dataset/cbae3cab-650f-487e-b936-0a5576ff757b/resource/"
    "673b46a0-05f9-4686-9b0c-578c16bc85e0/download/cursos-de-graduacao-08-2024.json"
)

# Nome do arquivo para salvar o JSON
output_file = "cursos-de-graduacao.json"

# Fazendo o download do JSON
response = requests.get(url)

# Verificando se o download foi bem-sucedido
if response.status_code == 200:
    try:
        # Carregando o conteúdo como JSON
        data = response.json()
        
        # Salvando o JSON formatado
        with open(output_file, "w", encoding="utf-8") as file:
            json.dump(data, file, indent=4, ensure_ascii=False)
        
        print(f"Arquivo salvo como {output_file} (formatado)")
    except json.JSONDecodeError:
        print("Erro: O conteúdo baixado não é um JSON válido.")
else:
    print(
        f"Falha ao baixar o arquivo. "
        f"Código de status: {response.status_code}"
    )