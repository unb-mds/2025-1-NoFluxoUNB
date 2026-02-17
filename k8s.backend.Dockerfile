# NoFluxo Backend Kubernetes Dockerfile
# Node.js + TypeScript + PDF Parser

FROM registry.kubernetes.crianex.com/library/node:20-bullseye AS builder

WORKDIR /app

# Install Python for PDF parser
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Install Node.js dependencies
COPY no_fluxo_backend/package*.json ./
RUN npm ci --omit=dev || (npm install --omit=dev && npm ci --omit=dev)

# Install Python dependencies for PDF parser
COPY no_fluxo_backend/parse-pdf/requirements.txt ./parse-pdf/
RUN pip3 install --no-cache-dir -r parse-pdf/requirements.txt

# Copy source code
COPY no_fluxo_backend/src/ ./src/
COPY no_fluxo_backend/parse-pdf/ ./parse-pdf/
COPY no_fluxo_backend/tsconfig.json ./

# Build TypeScript
RUN npm run build

# Production image
FROM registry.kubernetes.crianex.com/library/node:20-bullseye-slim

WORKDIR /app

# Install Python runtime for PDF parser
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    wget \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Create non-root user
RUN useradd -r -u 1001 -m appuser

# Copy Python packages (use shell to handle if dir doesn't exist)
RUN mkdir -p /usr/local/lib/python3.11/dist-packages
COPY --from=builder /usr/local/lib/python3.11/dist-packages/ /usr/local/lib/python3.11/dist-packages/

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/parse-pdf ./parse-pdf
COPY no_fluxo_backend/package.json ./

# Create log directories
RUN mkdir -p logs parse-pdf/logs \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 3325

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3325/health || exit 1

CMD ["node", "dist/index.js"]
