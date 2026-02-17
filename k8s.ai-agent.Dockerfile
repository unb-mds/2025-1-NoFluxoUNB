# NoFluxo AI Agent Kubernetes Dockerfile
# Python/Flask + RAGFlow

FROM registry.kubernetes.crianex.com/library/python:3.11-slim AS builder

WORKDIR /app

# Install dependencies
COPY no_fluxo_backend/ai_agent/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

# Production image
FROM registry.kubernetes.crianex.com/library/python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 -m appuser

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH

# Copy source code
COPY no_fluxo_backend/ai_agent/ ./

# Create log directory
RUN mkdir -p logs && chown -R appuser:appuser /app

USER appuser

EXPOSE 4652

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:4652/health')" || exit 1

CMD ["python", "app.py", "--port", "4652"]
