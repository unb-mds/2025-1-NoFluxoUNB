# Dockerfile único para todo o projeto NoFluxo UNB
# Frontend Flutter Web + Backend TypeScript/Python

# Stage 1: Build do Frontend Flutter
FROM ubuntu:22.04 AS flutter-build

# Instalar dependências
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Instalar Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:$PATH"

# Habilitar Flutter Web
RUN flutter config --enable-web
RUN flutter precache --web

# Criar diretório de trabalho para o frontend
WORKDIR /flutter-app

# Copiar arquivos do Flutter
COPY no_fluxo_frontend/pubspec.* ./
RUN flutter pub get

COPY no_fluxo_frontend/ ./
RUN flutter build web --web-renderer=html --release

# Stage 2: Build e Runtime final
FROM node:18-bullseye

# Instalar dependências do sistema para Python, Tesseract e Nginx
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    tesseract-ocr \
    tesseract-ocr-por \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /app

# Configurar Backend TypeScript/Python
COPY no_fluxo_backend/package*.json ./backend/
WORKDIR /app/backend
RUN npm ci --only=production

# Copiar requirements.txt do Python
COPY no_fluxo_backend/AI-agent/requirements.txt ./AI-agent/
COPY no_fluxo_backend/parse-pdf/requirements.txt ./parse-pdf/

# Criar ambiente virtual Python e instalar dependências
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir -r AI-agent/requirements.txt
RUN pip install --no-cache-dir -r parse-pdf/requirements.txt

# Copiar código do backend
COPY no_fluxo_backend/ ./

# Instalar dependências de desenvolvimento e compilar TypeScript
RUN npm install --only=development
RUN npm run build
RUN npm prune --production

# Copiar arquivos buildados do Flutter para Nginx
COPY --from=flutter-build /flutter-app/build/web /var/www/html

# Configurar Nginx
COPY no_fluxo_frontend/nginx.conf /etc/nginx/sites-available/default

# Criar configuração do Supervisor para gerenciar múltiplos processos
RUN mkdir -p /var/log/supervisor
COPY <<EOF /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true
user=root

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/nginx.err.log
stdout_logfile=/var/log/supervisor/nginx.out.log

[program:backend]
command=npm start
directory=/app/backend
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/backend.err.log
stdout_logfile=/var/log/supervisor/backend.out.log
environment=NODE_ENV=production,PATH="/opt/venv/bin:%(ENV_PATH)s"
EOF

# Expor portas
EXPOSE 80 3000

# Variáveis de ambiente
ENV NODE_ENV=production
ENV PATH="/opt/venv/bin:$PATH"

# Comando para iniciar o Supervisor (gerencia Nginx + Backend)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"] 