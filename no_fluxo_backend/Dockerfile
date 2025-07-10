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

# Copy source code
COPY src/ ./src/
COPY AI-agent/ ./AI-agent/
COPY parse-pdf/ ./parse-pdf/
COPY scripts/ ./scripts/
COPY start_and_monitor.py ./

# Copy other necessary files
COPY *.json ./
COPY env.example ./

# Build TypeScript code
RUN npm run build

# Create logs directory
RUN mkdir -p logs

# Expose ports for HTTPS
EXPOSE 3325
EXPOSE 4652

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3325

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3325/health || exit 1

# Start the application using the monitor script
CMD ["python", "start_and_monitor.py"] 