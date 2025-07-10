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

# Copy package files for Node.js dependencies (from backend directory)
COPY no_fluxo_backend/package*.json ./no_fluxo_backend/

# Install Node.js dependencies
WORKDIR /app/no_fluxo_backend
RUN npm install

# Copy Python requirements files
COPY no_fluxo_backend/requirements.txt ./
COPY no_fluxo_backend/requirements_monitor.txt ./
COPY no_fluxo_backend/AI-agent/requirements.txt ./AI-agent/requirements.txt
COPY no_fluxo_backend/parse-pdf/requirements.txt ./parse-pdf/requirements.txt

# Install Python dependencies
RUN pip3 install -r requirements.txt && \
    pip3 install -r requirements_monitor.txt && \
    pip3 install -r AI-agent/requirements.txt && \
    pip3 install -r parse-pdf/requirements.txt

# Copy TypeScript configuration
COPY no_fluxo_backend/tsconfig.json ./
COPY no_fluxo_backend/nodemon.json ./

# Copy source code (as root to avoid permission issues)
COPY no_fluxo_backend/src/ ./src/
COPY no_fluxo_backend/AI-agent/ ./AI-agent/
COPY no_fluxo_backend/parse-pdf/ ./parse-pdf/
COPY no_fluxo_backend/scripts/ ./scripts/
COPY no_fluxo_backend/start_and_monitor.py ./
# Copy docker-entrypoint.sh to /app (parent directory)
COPY docker-entrypoint.sh /app/

# Copy other necessary files
COPY no_fluxo_backend/*.json ./

# Create non-root user but keep some root permissions for git operations
RUN groupadd -r appuser && useradd -r -g appuser -s /bin/bash appuser
RUN usermod -aG sudo appuser
RUN echo 'appuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Create necessary directories with proper permissions
RUN mkdir -p dist logs uploads fork_repo AI-agent/logs parse-pdf/logs

# Set up git configuration for the container (before changing ownership)
RUN git config --global --add safe.directory /app
RUN git config --global --add safe.directory '/app/*'
RUN git config --global --add safe.directory '*'
RUN git config --global user.email "docker@nofluxo.com"
RUN git config --global user.name "Docker Container"
RUN git config --global init.defaultBranch main

# Change ownership and set permissions
RUN chown -R appuser:appuser /app
RUN chmod -R 755 /app
RUN chmod +x /app/docker-entrypoint.sh

# Ensure directories have proper permissions for runtime operations  
RUN chmod -R 775 /app/dist /app/logs /app/uploads /app/fork_repo /app/no_fluxo_backend/AI-agent/logs /app/no_fluxo_backend/parse-pdf/logs


# Build TypeScript code as root first, then change ownership
RUN npm run build-docker || echo "Build failed, will retry as appuser"

# Final ownership setup after build
RUN chown -R appuser:appuser /app

# Switch to app user
USER appuser

# Set git environment variables for runtime
ENV GIT_DISCOVERY_ACROSS_FILESYSTEM=1

# Expose ports for HTTPS
EXPOSE 3325
EXPOSE 4652

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3325

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3325/health || exit 1

# Switch back to /app directory for entrypoint script
WORKDIR /app

# Use the entrypoint script that handles conditional arguments
CMD ["/bin/bash", "./docker-entrypoint.sh"] 