# NoFluxo Frontend (SvelteKit) Kubernetes Dockerfile
# SvelteKit + adapter-node for SSR

# ── Builder ────────────────────────────────────────────────────────────────
FROM node:20-bullseye AS builder

# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

WORKDIR /app

# Copy package files and install dependencies
COPY no_fluxo_frontend_svelte/package.json no_fluxo_frontend_svelte/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Add adapter-node for production builds (overrides adapter-auto)
RUN pnpm add -D @sveltejs/adapter-node

# Copy source code
COPY no_fluxo_frontend_svelte/ ./

# Override svelte.config.js to use adapter-node for production
RUN cat > svelte.config.js <<'SVELTE_CFG'
import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter(),
		alias: {
			$components: 'src/lib/components',
			$lib: 'src/lib',
			$stores: 'src/lib/stores',
			$types: 'src/lib/types',
			$services: 'src/lib/services',
			$utils: 'src/lib/utils'
		}
	}
};

export default config;
SVELTE_CFG

# Build-time environment variables (baked into the bundle via $env/static/public)
ARG PUBLIC_SUPABASE_URL
ARG PUBLIC_SUPABASE_ANON_KEY
ARG PUBLIC_API_URL=https://api-nofluxo.crianex.com
ARG PUBLIC_REDIRECT_URL=https://no-fluxo.crianex.com
ARG PUBLIC_ENVIRONMENT=production

# Build the SvelteKit app
RUN pnpm build

# ── Production ─────────────────────────────────────────────────────────────
FROM node:20-bullseye-slim

WORKDIR /app

# Create non-root user
RUN useradd -r -u 1001 -m appuser

# Copy built output and production dependencies
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json /app/pnpm-lock.yaml ./

# Install only production runtime dependencies (e.g. clsx, tailwind-merge)
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate \
    && pnpm install --prod --frozen-lockfile \
    && pnpm store prune

# Change ownership
RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 3000

ENV PORT=3000
ENV HOST=0.0.0.0
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD node -e "const http = require('http'); const req = http.get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }); req.on('error', () => process.exit(1))" || exit 1

CMD ["node", "build/index.js"]
