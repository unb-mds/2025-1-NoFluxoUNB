# Guia de Contribuição

Obrigado pelo seu interesse em contribuir para este projeto! Suas contribuições são muito bem-vindas e nos ajudam a melhorar continuamente.

Este guia tem como objetivo fornecer um passo a passo básico para que você possa contribuir de forma eficaz.

## Como Rodar o Projeto Localmente

Este guia detalha os passos necessários para configurar e executar o projeto em sua máquina local.

### Pré-requisitos

Certifique-se de ter os seguintes softwares instalados em seu ambiente:

* **Git:** Para clonar o repositório.
  [Download do Git](https://git-scm.com/downloads)
* **Python 3.x:** (Python 3.9 ou superior)
  [Download do Python](https://www.python.org/downloads/)
* **Flutter SDK:** (Flutter 3.19.0 ou superior)
  [Instalação do Flutter](https://flutter.dev/docs/get-started/install)
* **Node.js e npm/yarn:** Para gerenciar dependências do JavaScript (se aplicável para o backend ou outras ferramentas).
  [Download do Node.js](https://nodejs.org/en/download/)

---

### 1. Clonar o Repositório

Primeiro, clone o repositório do projeto para sua máquina local usando o Git e navegue até a pasta do projeto:

```bash
git clone https://github.com/unb-mds/2025-1-NoFluxoUNB.git
cd 2025-1-NoFluxoUNB
```

---

### 2. Configuração do Backend (Python)

Se o seu projeto tiver um backend em Python, siga estes passos:

#### 2.1. Criar e Ativar Ambiente Virtual

É altamente recomendável usar um ambiente virtual para gerenciar as dependências do Python. Execute os comandos abaixo na raiz do projeto (onde está o `venv` ou a pasta principal do backend):

```bash
python -m venv venv

# Para Windows:
.\venv\Scripts\activate

# Para macOS/Linux:
source venv/bin/activate
```

#### 2.2. Instalar Dependências

Com o ambiente virtual ativado, navegue até a pasta do seu backend (ex: `backend/`) e instale todas as dependências listadas no `requirements.txt`:

```bash
cd backend
pip install -r requirements.txt
```

#### 2.3. Configuração de Variáveis de Ambiente

Crie um arquivo `.env` na raiz da pasta do backend (ou na raiz do projeto, se centralizado) e adicione as variáveis de ambiente necessárias:

```ini
# Exemplo de variáveis para Supabase/Banco de Dados
SUPABASE_URL=sua_url_do_supabase
SUPABASE_KEY=sua_chave_anon_do_supabase
# Adicione outras variáveis necessárias aqui
```

> 💡 Para conseguir acesso às chaves do `.env`, entre em contato com os desenvolvedores do projeto.
> 🧹 É recomendável que o projeto contenha um arquivo `.env.example` como referência.

#### 2.4. Instalar Dependências e Iniciar o Backend (Node.js)

Se o seu backend também usa Node.js, navegue até a pasta do backend e execute:

```bash
cd backend
npm install
npm start
```

Certifique-se de que a pasta `backend` realmente é onde estão os arquivos `Node.js` e o `package.json`.

---

### 3. Configuração do Frontend (Flutter)

#### 3.1. Navegar para a Pasta do Frontend

Navegue até a pasta que contém os arquivos do seu aplicativo Flutter (ex: `frontend/` ou `flutter_app/`):

```bash
cd frontend # Ajuste para o nome real da sua pasta frontend
```

#### 3.2. Obter Dependências do Flutter e Rodar o Aplicativo

Na pasta do frontend, execute os seguintes comandos:

```bash
flutter pub get
flutter run
```

---

### 4. Executando o Parser de PDF

Se você precisa rodar o script de parser de PDF separadamente:

#### 4.1. Navegar para a Pasta de Coleta de Dados

Navegue até a pasta onde o arquivo `parser_pdf.py` está localizado:

```bash
cd coleta_de_dados # Ajuste para o nome real da sua pasta
```

#### 4.2. Executar o Parser

Com o ambiente virtual ativado (se aplicável ao parser), execute o arquivo Python:

```bash
python3 parser_pdf.py
```

---

## Observações Finais

* **Caminho do ********`cd`******** após ********`git clone`********:** Incluímos o `cd 2025-1-NoFluxoUNB` como passo explícito.
* **Separando Configurações do Backend:** Se o backend for apenas Python, remova a seção 2.4.
* **Ajuste de Caminhos:** Foram adicionados comentários do tipo `# Ajuste para o nome real da sua pasta` em locais críticos.
* **Ambiente Virtual para o Parser:** É necessário ativar o ambiente virtual se o parser depender das bibliotecas do `requirements.txt`.

---

Agradecemos novamente pelo seu interesse em contribuir com o projeto 🚀
