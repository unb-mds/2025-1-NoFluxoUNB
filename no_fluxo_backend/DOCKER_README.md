# Configuração Docker para o Backend No Fluxo

Este diretório contém arquivos de configuração Docker para containerizar a aplicação backend do No Fluxo com **HTTPS por padrão**.

## Início Rápido

1. **Crie seu arquivo de ambiente:**
   ```bash
   cp env.example .env
   # Edite o arquivo .env com seus valores de configuração reais
   ```

2. **Gere certificados SSL para desenvolvimento:**
   ```bash
   # Linux/Mac
   chmod +x generate-ssl.sh
   ./generate-ssl.sh
   
   # Windows
   generate-ssl.bat
   ```

3. **Construir e executar:**
   ```bash
   docker-compose up --build
   ```

3. **Ou construir e executar manualmente:**
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