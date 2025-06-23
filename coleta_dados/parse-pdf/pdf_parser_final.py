import PyPDF2

#coloque aqui o nome do arquivo pdf que quer extrair.
nome_pdf = "seu_historico"
with open(nome_pdf+'.pdf', "rb") as file:
    leitor = PyPDF2.PdfReader(file)
    texto_total = ""
    for pagina in leitor.pages:
        texto_total += pagina.extract_text() + "\n" 

#extrai a matricula do estudante, de acordo com o nome do arquivo
matricula = str(nome_pdf.split('_')[1])

#passa as informações extraidas do pdf, para um arquivo .txt
with open("historico_completo"+matricula+".txt", "w", encoding="utf-8") as output_file:
    output_file.write(texto_total)  

print("Arquivo 'historico_completo.txt' criado com sucesso!")

#aqui começa a extração de informações relevantes do arquivo .txt
import re
import json


#lê, linha por linha, o arquivo .txt
with open("historico_completo"+matricula+".txt", "r", encoding="utf-8") as f:
    linhas = f.readlines()

valor_do_ira = None
valor_pend = None
#padrão de caracteres em que se encontra os INDICES ACADEMICOS
padrao_ira = re.compile(r"IRA[:\s]+(\d+\.\d+)", re.IGNORECASE)

#padrão de caracteres em que se encontra o CURRICULO
padrao_curriculo = r'(\d+/\d+(?:\s*-\s*\d{4}\.\d)?)'

#encontra as pendencias
padrao_pend = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")

disciplinas = []

#padrão de caracteres em que se encontra o STATUS DA MATERIA
padrao_status = re.compile(r"\b(APR|CANC|DISP|MATR|REP|REPF|REPMF|TRANC|CUMP)\b")

#padrão de caracteres em que se encontra a MENCAO DA MATERIA
padrao_mencao = re.compile(r"\b(SS|MS|MM|MI|II|SR)\b")

#padrão de caracteres em que se encontra apenas o STATUS = CUMPRIDO
padrao_cump = re.compile(r"--\s+CUMP\b")

#padrão de caracteres em que se encontra  DADOS DA MATERIA CUMP
padrao_materia_cump = re.compile(r"\d{4}\.\d\s+(.+?)\s+--")

#padrão de caracteres em que se encontra a CARGAHORARIA DA MATERIA
padrao_horas = re.compile(r"\((.+?)\)")

#padrão de caracteres em que se encontra a CARGAHORARIA DA MATERIA de status CUMPRIDA
padrao_horas_cump = re.compile(r"[A-Za-z]+\d+\s+(\d+)\s+\d+,\d")


#padrão de caracteres em que se encontra o CODIGO DA MATERIA
padrao_codigo = re.compile(r"\b[A-Z]{2,}\d{3,}\b")

#exemplo de uma linha de materia: Dra. GLAUCENY CIRNE DE MEDEIROS (60h)03 REP FGA0133 60 89,0 MI
#exemplo de uma linha de materia CUMPRIDA: 2024.2 INGLÊS INSTRUMENTAL 1 -- CUMP LET0331 60 100,0 - #

# extrai informações
for i, linha in enumerate(linhas):
    creditos = 0
    #print(i)
    linha = linha.strip()

    match_ira = padrao_ira.search(linha)

    #encontra o IRA
    if match_ira:
            print(linha)
            ira = match_ira.group(1)
            print("ACHOU O IRA!!")
            print("--------------------------")
            print("IRA", ira)
            disciplinas.append({"ira": ira})

    match_curriculo = re.search(padrao_curriculo, linha)

    if "Currículo" in linha or "Ano/Período de Integralização" in linha:
        #print("Linha Currículo encontrada:", repr(linha))

        # Tentar achar na mesma linha primeiro
        match_curriculo = re.search(padrao_curriculo, linha)
        
        # Se não achar, tenta na próxima linha
        if not match_curriculo and i + 1 < len(linhas):
            proxima_linha = linhas[i + 1].replace('\xa0', ' ').strip()
            proxima_linha = re.sub(r'\s+', ' ', proxima_linha)
            #print("Próxima linha para análise:", repr(proxima_linha))
            match_curriculo = re.search(padrao_curriculo, proxima_linha)

        if match_curriculo:
            curriculo = match_curriculo.group(1)
            print("ACHOU O CURRÍCULO!!")
            print("--------------------------")
            print("CURRÍCULO:", curriculo)
            disciplinas.append({"curriculo": curriculo})

    match_pend = padrao_pend.findall(linha)
    
    #encontra as variaveis pendentes
    if match_pend:
            print(linha)
            pend = match_pend
            print("ACHOU PENDENCIAS")
            print("----------------------")
            disciplinas.append({"pendencias": pend})


    # Verifica se a linha tem prefixo de professor
    if linha.startswith("Dr.") or linha.startswith("MSc.") or linha.startswith("Dra."):
        print(linha)
        match_status = padrao_status.search(linha)
        print(f'matchSTATUS == {match_status}')
        #match_status ==  #<re.Match object; span=(41, 44), match='REP'>

        match_mencao = padrao_mencao.findall(linha)
        #match_mencao == ['MI']
        #print('------------------------------------------------')
        match_codigo = padrao_codigo.search(linha)

        if match_status:

            #encontra o STATUS (aprovado,reprovado)
            status = match_status.group(1)

            #encontra a MENCAO (SS,MS,etc...)
            mencao = match_mencao[-1] if match_mencao else "-"

            #encontra o Nome da disciplina
            nome_disciplina = linhas[i - 1].strip()  # A disciplina está na linha anterior
            texto_aux = ''

            #encontra a CARGAHORARIA
            match_horas = padrao_horas.findall(linha)
            #formata a CARGAHORARIA
            match_horas_formatadas = int(match_horas[0].strip('h'))

            #faz o calculo de CREDITOS, com base na CARGAHORARIA (15h = 1crédito)
            creditos = int(match_horas_formatadas/15)

            #encontra o CODIGO da matéria
            codigo = match_codigo.group()
            print("Código da matéria:", codigo)

            try:
                for m in range(len(nome_disciplina)):
                    if nome_disciplina[m].isalpha():
                        #nome_disciplina = nome_disciplina.strip(texto_aux)
                        nome_disciplina = (nome_disciplina.split(texto_aux))[1]
                        break

                    else:
                        texto_aux += nome_disciplina[m]
                        
            #tratamento se o nome da disciplina se encontra -2 antes da atual (geralmente é -1 linha, por isso estamos tratando dessa forma)
            except:
                print(i)
                print(f'linhas = {linhas[i - 2]}')
                nome_disciplina = linhas[i - 2].strip()  # A disciplina está na linha anterior
                print(f'nome disciplina = {nome_disciplina}')
                texto_aux = ''
                m =0
                for m in range(len(nome_disciplina)):
                    if nome_disciplina[m].isalpha():
                        #nome_disciplina = nome_disciplina.strip(texto_aux)
                        nome_disciplina = (nome_disciplina.split(texto_aux))[1]
                        break

                    else:
                        texto_aux += nome_disciplina[m]


            #adiciona os dados extraidos da disciplina

            print('FINALMENTE')
            disciplinas.append({"nome_disciplina": nome_disciplina, "status": status, "mencao": mencao, "creditos":creditos, "codigo":codigo, "ch":match_horas_formatadas})

        #Tratamento para situações de matérias com >=2 professores / ou qualquer outra linha que fugir do padrao.
        else:
            linha = linhas[i + 1]

            match_status = padrao_status.search(linha)
            print(f'matchSTATUS == {match_status}')
            #match_status ==  #<re.Match object; span=(41, 44), match='REP'>

            match_mencao = padrao_mencao.findall(linha)
            #match_mencao == ['MI']
            #print('------------------------------------------------')
            match_codigo = padrao_codigo.search(linha)

            if match_status:

                #encontra o STATUS (aprovado,reprovado)
                status = match_status.group(1)

                #encontra a MENCAO (SS,MS,etc...)
                mencao = match_mencao[-1] if match_mencao else "-"

                #encontra o Nome da disciplina
                nome_disciplina = linhas[i - 1].strip()  # A disciplina está na linha anterior
                texto_aux = ''

                #encontra a CARGAHORARIA
                match_horas = padrao_horas.findall(linha)
                #formata a CARGAHORARIA
                match_horas_formatadas = int(match_horas[0].strip('h'))

                #faz o calculo de CREDITOS, com base na CARGAHORARIA (15h = 1crédito)
                creditos = int(match_horas_formatadas/15)

                #encontra o CODIGO da matéria
                codigo = match_codigo.group()
                print('2 doutores')
                print("Código da matéria:", codigo)
                
                linha_i = i

                try:
                    for i in range(len(nome_disciplina)):
                        if nome_disciplina[i].isalpha():
                            #nome_disciplina = nome_disciplina.strip(texto_aux)
                            nome_disciplina = (nome_disciplina.split(texto_aux))[1]
                            break

                        else:
                            texto_aux += nome_disciplina[i]

                #tratamento se o nome da disciplina se encontra -2 antes da atual (geralmente é -1 linha, por isso estamos tratando dessa forma)
                except:
                    print(i)
                    print(f'linhas = {linhas[linha_i - 2]}')
                    nome_disciplina = linhas[linha_i - 2].strip()  # A disciplina está na linha anterior
                    print(f'nome disciplina = {nome_disciplina}')
                    texto_aux = ''
                    for i in range(len(nome_disciplina)):
                        if nome_disciplina[i].isalpha():
                            #nome_disciplina = nome_disciplina.strip(texto_aux)
                            nome_disciplina = (nome_disciplina.split(texto_aux))[1]
                            break

                        else:
                            texto_aux += nome_disciplina[i]

                disciplinas.append({"nome_disciplina": nome_disciplina, "status": status, "mencao": mencao, "creditos":creditos, "codigo":codigo, "ch":match_horas_formatadas})

            #tratamento para caso em que : 2024.1 INTRODUÇÃO À SOCIOLOGIA 04 APR SOL0042 60 100,0 SS *   ----> texto aleatorio --->   Dra. GABRIELA BORGES ANTUNES (60h)
            else:

                for k in range(20):
                    linha = linhas[i - k]

                    match_status = padrao_status.search(linha)
                    print(f'matchSTATUS == {match_status}')
                    if match_status:
                        status = match_status.group(1)

                        match_mencao = padrao_mencao.findall(linha)
                        mencao = match_mencao[-1] if match_mencao else "-"


                        match_codigo = padrao_codigo.search(linha)
                        #encontra o CODIGO da matéria
                        codigo = match_codigo.group()

                        #encontra o Nome da disciplina
                        nome_disciplina = linhas[i - 1].strip()  # A disciplina está na linha anterior
                        texto_aux = ''

                        ###########################################################
                        #x = "2024.1INTRODUÇÃO À SOCIOLOGIA 04 APR SOL0042 60 100,0 SS *"

                        linha = linha.replace(".", '')
                        print(linha)
                        print(f'mencao = {status}')
                        nome_disciplina = ''

                        linha = linha.split(status)
                        linha = linha[0]

                        remover = linha[-3:]

                        linha = linha.split(remover)[0]
                        #print(y)
                                                                    #passar enquanto isnumeric, pegar quando for isalpha  (enquanto for isalpha interruptos, contagem que estava =0, vira 1),
                                                                    #ao chegar em outro isnumeric, contagem vira 2, acaba o programa

                        for p in range(len(linha)):
                            if (linha[p].isnumeric()):
                                texto_aux += linha[p]
                                
                            
                            else:
                                break

                        nome_disciplina = linha.split(texto_aux)[1]

                        ###########################################################

                        #encontra a CARGAHORARIA
                        match_horas = padrao_horas.findall(linhas[i])
                        #formata a CARGAHORARIA
                        match_horas_formatadas = int(match_horas[0].strip('h'))

                        #faz o calculo de CREDITOS, com base na CARGAHORARIA (15h = 1crédito)
                        creditos = int(match_horas_formatadas/15)
                        print(nome_disciplina)
                        break

                disciplinas.append({"nome_disciplina": nome_disciplina, "status": status, "mencao": mencao, "creditos":creditos, "codigo":codigo, "ch":match_horas_formatadas})   
                        



    else:
        creditos_cump = 0

        #acha disciplinas que possuem status == CUMP.
        if padrao_cump.search(linha):
            print(linha)
            #encontra o status de CUMP
            match_mencao = padrao_mencao.findall(linha)
            print('ACHOU CUMP!!!!!!!')
            print('--------------------------------------------')

            #extrai os dados da matéria que foi CUMP
            match_cump = padrao_materia_cump.search(linha)

            #extrai a CARGAHORARIA da matéria que foi CUMP
            match_padrao_horas_cump = padrao_horas_cump.search(linha)

            #extrai o CODIGO da matéria que foi CUMP
            match_codigo = padrao_codigo.search(linha)

            print(f'PASSOU AQUI!!: {match_padrao_horas_cump}')

            print(f"match cump == {match_cump}")
            if match_cump:
                try:
                    nome_materia_cump = match_cump.group(1).strip()  # Remove espaços extras
                    print(nome_materia_cump)  # Saída: "INGLÊS INSTRUMENTAL 1"
                    carga_horaria = int(match_padrao_horas_cump.group(1))
                    print("Carga horária:", carga_horaria)

                    #faz o calculo de CREDITOS, com base na CARGAHORARIA (15h = 1crédito)
                    creditos_cump = int((carga_horaria)/15)

                    #encontra o CODIGO da matéria
                    codigo = match_codigo.group()
                    print("Código da matéria:", codigo)

                    #adiciona os dados extraidos da disciplina
                    disciplinas.append({"nome_disciplina": nome_materia_cump, "status": 'CUMP', "mencao": '-', "creditos": creditos_cump, "codigo":codigo, "ch":carga_horaria})
            
                #trata uma forma diferente de aparecer o nome da matéria , ex:-- ATIVIDADE DE EXTENSÃO -- CUMP DEX0196 15 100,0 - *
                except:
                    padrao_materia_cump = re.compile(r'--(.*?)--')
                    match_cump = padrao_materia_cump.search(linha)
                    print('\n')
                    print(match_cump)

                    if match_cump:

                        nome_materia_cump = match_cump.group(1).strip()

                        carga_horaria = int(match_padrao_horas_cump.group(1))
                        print("Carga horária:", carga_horaria)

                        creditos_cump = int((carga_horaria)/15)

                        codigo = match_codigo.group()
                        print("Código da matéria:", codigo)

                        disciplinas.append({"nome_disciplina": nome_materia_cump, "status": 'CUMP', "mencao": '-', "creditos": creditos_cump, "codigo":codigo, "ch":carga_horaria})

                        padrao_materia_cump = re.compile(r"--\s+CUMP\b")

            #trata uma forma diferente de aparecer o nome da matéria , ex:-- ATIVIDADE DE EXTENSÃO -- CUMP DEX0196 15 100,0 - *
            elif match_cump == None:
                padrao_materia_cump = re.compile(r'--(.*?)--')
                match_cump = padrao_materia_cump.search(linha)
                print('\n')
                print(match_cump)

                if match_cump:

                    nome_materia_cump = match_cump.group(1).strip()

                    carga_horaria = int(match_padrao_horas_cump.group(1))
                    print("Carga horária:", carga_horaria)

                    creditos_cump = int((carga_horaria)/15)

                    codigo = match_codigo.group()
                    print("Código da matéria:", codigo)

                    disciplinas.append({"nome_disciplina": nome_materia_cump, "status": 'CUMP', "mencao": '-', "creditos": creditos_cump, "codigo":codigo, "ch":carga_horaria})

    
                padrao_materia_cump = re.compile(r"--\s+CUMP\b")
            
            
            
            else:
                print("Nome da matéria não encontrado.")



# Salva os resultados em um arquivo JSON
with open("disciplinas" + "_" + matricula + ".json", "w", encoding="utf-8") as json_file:
    json.dump(disciplinas, json_file, ensure_ascii=False, indent=4)

# Exibe os resultados
for disciplina in disciplinas:
    ...
    #print(f"{disciplina['nome_disciplina']} | Status: {disciplina['status']} | Menção: {disciplina['mencao']}")
