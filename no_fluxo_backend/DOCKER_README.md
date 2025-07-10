# Configuração Docker para o Backend No Fluxo

Este diretório contém arquivos de configuração Docker para containerizar a aplicação backend do No Fluxo com **HTTPS por padrão** e **auto-updates automáticos**.

## Início Rápido

1. **Crie seu arquivo de ambiente:**
   ```bash
   # Na pasta no_fluxo_backend (mesma pasta do Dockerfile)
   cd no_fluxo_backend
   cp docker.env.example .env
   # Edite o arquivo .env com seus valores de configuração reais
   # IMPORTANTE: Configure GIT_USERNAME e GIT_TOKEN para auto-updates
   ```

   **Estrutura de arquivos:**
   ```
   no_fluxo_backend/
   ├── Dockerfile              ← Aqui
   ├── docker-compose.yml      ← Aqui  
   ├── .env                    ← Aqui (criar a partir do .env.example)
   ├── docker.env.example      ← Template
   └── src/
   ```

2. **Configure certificados SSL:**

   **Para Produção (Let's Encrypt):**
   ```bash
   # Seus certificados já existem em:
   # /etc/letsencrypt/live/no-fluxo-api.shop/fullchain.pem
   # /etc/letsencrypt/live/no-fluxo-api.shop/privkey.pem
   # O docker-compose.yml já está configurado para usar esses caminhos
   ```

   **Para Desenvolvimento:**
   ```bash
   # Gere certificados auto-assinados
   chmod +x generate-ssl.sh
   ./generate-ssl.sh
   ```

3. **Construir e executar com auto-updates:**
   ```bash
   docker-compose up --build
   ```

## 🔄 Como Funciona o Auto-Update

O container monitora o repositório Git a cada 10 segundos e:

1. **Detecta mudanças** no branch configurado (default: main)
2. **Para os serviços** graciosamente  
3. **Puxa as atualizações** do repositório
4. **Reinstala dependências** se necessário
5. **Reconstrói o projeto** TypeScript
6. **Reinicia os serviços** automaticamente

### Configuração do Git

Para o auto-update funcionar, configure no `.env`:

```env
GIT_USERNAME=seu_usuario_github
GIT_TOKEN=seu_token_github
GIT_BRANCH=main

# Opcional: Para sincronizar com um fork
FORK_LOCATION=/path/to/your/fork/repository
```

**Parâmetros:**
- `GIT_USERNAME`: Seu usuário do GitHub
- `GIT_TOKEN`: Token de acesso pessoal do GitHub
- `GIT_BRANCH`: Branch a monitorar (default: main)
- `FORK_LOCATION`: *(Opcional)* Caminho para repositório fork local

**Gerando um Token GitHub:**
1. Vá em GitHub → Settings → Developer settings → Personal access tokens
2. Gere um token com permissões de `repo`
3. Use esse token no `GIT_TOKEN`

**Fork Location (Opcional):**
Se você tem um fork do repositório e quer que as mudanças sejam automaticamente sincronizadas:
1. Clone seu fork em algum local do servidor
2. Configure `FORK_LOCATION` com o caminho para esse clone
3. O sistema automaticamente enviará updates para o branch `main` do seu fork

## 🔧 Comandos Alternativos

**Executar manualmente:**
   ```bash
   # Construir a imagem
   docker build -t no-fluxo-backend .
   
   # Executar o container
   docker run -d \
     --name no-fluxo-backend \
     -p 3325:3325 \
     -p 4652:4652 \
     --env-file .env \
     -v $(pwd)/logs:/app/logs \
     no-fluxo-backend
   ```

## O que o Dockerfile faz

- Utiliza Node.js 18 com suporte a Python
- Instala dependências do sistema (Python, ferramentas de processamento de PDF, OCR)
- Instala todas as dependências npm e Python
- Compila o código TypeScript
- Expõe as portas 3325 e 4652 para HTTPS
- Executa `python start_and_monitor.py` como processo principal

## Portas

- **3325**: Porta principal da aplicação (HTTPS através do nginx)
- **4652**: Porta do serviço AI Agent (HTTPS através do nginx)

## Variáveis de Ambiente

Certifique-se de configurar seu arquivo `.env` com as variáveis de ambiente necessárias antes de executar o container.

## Verificação de Saúde

O container inclui uma verificação de saúde que confirma se a aplicação está rodando na porta 3325.

## Como Funciona o Setup HTTPS

### Arquitetura
```
Exterior (HTTPS) → nginx (SSL termination) → Backend (HTTP interno)
```

### Fluxo de Requisições
1. **Cliente externo** faz requisição HTTPS para `https://localhost:3325` ou `https://localhost:4652`
2. **nginx** recebe a requisição HTTPS, termina o SSL
3. **nginx** encaminha como HTTP para o backend interno (`http://no-fluxo-backend:3325` ou `http://no-fluxo-backend:4652`)
4. **Backend** processa e responde em HTTP
5. **nginx** encaminha a resposta de volta como HTTPS

### Testando a Configuração HTTPS

Após executar com `docker-compose up --build`:

```bash
# Teste a API principal (aceita certificado auto-assinado)
curl -k https://localhost:3325/

# Teste o AI Agent  
curl -k https://localhost:4652/assistente -H "Content-Type: application/json" -d '{"materia":"teste"}'

# No navegador (aceite o aviso de segurança):
https://localhost:3325/
https://localhost:4652/
```

⚠️ **Nota**: Os certificados auto-assinados causarão avisos de segurança no navegador. Isso é normal para desenvolvimento.

## 🏭 Production SSL Setup

For production deployment with real SSL certificates, see:
👉 **[PRODUCTION_SSL_GUIDE.md](./PRODUCTION_SSL_GUIDE.md)**

Quick summary for production:
- Use Let's Encrypt (free) or commercial SSL certificates
- Mount real certificates into the nginx container
- Update `server_name` in nginx.conf to your actual domain
- Set up automatic certificate renewal

## Logs

Os logs são persistidos no diretório `./logs` na máquina host.

## 🚀 Quick Test

Para testar rapidamente a configuração:

```bash
# Execute o script de teste
./test-docker.sh
```

O script irá:
- ✅ Verificar se o .env está configurado
- ✅ Verificar certificados SSL
- ✅ Verificar credenciais Git
- ✅ Oferecer para iniciar os containers

## 📊 Status do Container

### URLs de Acesso:
- **API Principal**: `https://no-fluxo-api.shop/` (ou `https://localhost:443/`)
- **AI Agent**: `https://no-fluxo-api.shop:4652/assistente`
- **Redirecionamento HTTP**: `http://no-fluxo-api.shop/` → `https://no-fluxo-api.shop/`

### Logs em Tempo Real:
```bash
# Ver logs de todos os serviços
docker-compose logs -f

# Ver logs apenas do backend
docker-compose logs -f no-fluxo-backend

# Ver logs apenas do nginx
docker-compose logs -f nginx
```

### Comandos Úteis:
```bash
# Reiniciar containers
docker-compose restart

# Parar containers
docker-compose down

# Rebuild completo
docker-compose down && docker-compose up --build

# Ver status dos containers
docker-compose ps
``` 