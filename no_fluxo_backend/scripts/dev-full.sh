#!/usr/bin/env bash
# dev-full.sh — Run backend + mcp-agent together for local development.
# Both processes share the same terminal with prefixed output.
# Usage: npm run dev:full  (from no_fluxo_backend/)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKEND_DIR="$REPO_ROOT/no_fluxo_backend"
MCP_AGENT_DIR="$REPO_ROOT/mcp_agent"

# Colors for distinguishing output
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

cleanup() {
    echo ""
    echo "Shutting down..."
    kill 0 2>/dev/null
    wait 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# --- Load backend .env so both processes share the same env vars ---
if [ -f "$BACKEND_DIR/.env" ]; then
    echo -e "${YELLOW}[env]${NC} Loading $BACKEND_DIR/.env..."
    set +u  # temporarily allow unset vars during source
    set -a
    source "$BACKEND_DIR/.env"
    set +a
    set -u
fi

# --- MCP Agent (Python/FastAPI) ---
echo -e "${YELLOW}[mcp-agent]${NC} Starting uvicorn on port 8000..."
(
    cd "$MCP_AGENT_DIR"
    uvicorn api_producao:app --host 0.0.0.0 --port 8000 --reload 2>&1 \
        | sed "s/^/$(printf "${YELLOW}[mcp-agent]${NC} ")/"
) &

# --- Backend (Node.js/Express) ---
echo -e "${CYAN}[backend]${NC}   Starting nodemon on port 3325..."
(
    cd "$BACKEND_DIR"
    NODE_ENV=development npx nodemon src/index.ts 2>&1 \
        | sed "s/^/$(printf "${CYAN}[backend]${NC}   ")/"
) &

wait
