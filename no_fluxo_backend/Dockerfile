# Use an official Node.js runtime with Python support
FROM node:18-bullseye

# Set working directory
WORKDIR /app

# Install system dependencies for PDF processing and other requirements
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-por \
    git \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a symbolic link for python command
RUN ln -s /usr/bin/python3 /usr/bin/python

# Copy package files for Node.js dependencies
COPY package*.json ./

# Install Node.js dependencies
RUN npm install

# Copy Python requirements files
COPY requirements.txt ./
COPY requirements_monitor.txt ./
COPY AI-agent/requirements.txt ./AI-agent/requirements.txt
COPY parse-pdf/requirements.txt ./parse-pdf/requirements.txt

# Install Python dependencies
RUN pip3 install -r requirements.txt && \
    pip3 install -r requirements_monitor.txt && \
    pip3 install -r AI-agent/requirements.txt && \
    pip3 install -r parse-pdf/requirements.txt

# Copy TypeScript configuration
COPY tsconfig.json ./
COPY nodemon.json ./

# Copy source code (as root to avoid permission issues)
COPY src/ ./src/
COPY AI-agent/ ./AI-agent/
COPY parse-pdf/ ./parse-pdf/
COPY scripts/ ./scripts/
COPY start_and_monitor.py ./
COPY docker-entrypoint.sh ./

# Copy other necessary files
COPY *.json ./
COPY env.example ./
COPY .env ./

# Create non-root user but keep some root permissions for git operations
RUN groupadd -r appuser && useradd -r -g appuser -s /bin/bash appuser
RUN usermod -aG sudo appuser
RUN echo 'appuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create necessary directories with proper permissions
RUN mkdir -p dist logs uploads fork_repo AI-agent/logs parse-pdf/logs
RUN chown -R appuser:appuser /app
RUN chmod -R 755 /app
RUN chmod +x docker-entrypoint.sh

# Ensure directories have proper permissions for runtime operations  
RUN chmod -R 775 dist logs uploads fork_repo AI-agent/logs parse-pdf/logs

# Build TypeScript code as root first, then change ownership
RUN npm run build || echo "Build failed, will retry as appuser"

# Set up git configuration for the container
RUN git config --global --add safe.directory /app
RUN git config --global --add safe.directory '*'
RUN git config --global user.email "docker@nofluxo.com"
RUN git config --global user.name "Docker Container"
RUN git config --global init.defaultBranch main

# Final ownership setup
RUN chown -R appuser:appuser /app

# Switch to app user
USER appuser

# Expose ports for HTTPS
EXPOSE 3325
EXPOSE 4652

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3325

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3325/health || exit 1

# Use the entrypoint script that handles conditional arguments
CMD ["/bin/bash", "./docker-entrypoint.sh"] 