import requests
import json

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