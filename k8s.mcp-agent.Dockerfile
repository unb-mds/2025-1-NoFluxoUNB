# NoFluxo MCP Agent (Darcy AI) Kubernetes Dockerfile
# FastAPI + Python — production API only (no legacy MCP deps)

FROM python:3.11-slim AS builder

WORKDIR /app

# Install only production dependencies (skip legacy sentence-transformers/PyTorch)
COPY mcp_agent/requirements.txt ./requirements-full.txt
RUN grep -vE 'sentence-transformers|maritalk|fastmcp' requirements-full.txt > requirements.txt \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# Copy source code
COPY mcp_agent/ ./src/

# Production image
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 appuser

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy only the production API source
COPY --from=builder /app/src/api_producao.py ./

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "api_producao:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
