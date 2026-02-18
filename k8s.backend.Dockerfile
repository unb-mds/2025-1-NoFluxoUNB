# NoFluxo Backend Kubernetes Dockerfile
# Node.js + TypeScript

FROM node:20-alpine AS builder

WORKDIR /app

# Install Node.js dependencies (include dev for tsc)
COPY no_fluxo_backend/package*.json ./
RUN npm ci

# Copy source code
COPY no_fluxo_backend/src/ ./src/
COPY no_fluxo_backend/tsconfig.json ./

# Build TypeScript
RUN npx tsc

# Production image
FROM node:20-alpine

WORKDIR /app

# Install wget for healthcheck
RUN apk add --no-cache wget

# Create non-root user
RUN adduser -D -u 1001 appuser

# Copy from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY no_fluxo_backend/package.json ./

# Create log directory
RUN mkdir -p logs \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 3325

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3325/health || exit 1

CMD ["node", "dist/index.js"]
