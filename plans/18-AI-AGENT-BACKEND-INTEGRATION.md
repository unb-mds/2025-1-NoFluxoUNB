# 18 - AI Agent Integration into no_fluxo_backend

Merge the standalone Python/Flask AI agent (`no_fluxo_backend/ai_agent/`) into the Express.js backend (`no_fluxo_backend/src/`) as a native TypeScript controller, eliminating the need for two separate backend servers.

---

## Current Architecture

```
Frontend (SvelteKit)
  ├── API calls → Express backend (port 3000)
  │                  └── spawns Python child process (ai_agent/app.py on port 4652)
  └── AI calls → Flask AI agent (port 4652) ← Direct from frontend
```

### Problems with Current Setup

1. **Two separate servers**: Express spawns a Flask child process (`spawn('python', ['ai_agent/app.py'])`) — fragile process management
2. **Two separate Docker images in K8s**: `k8s.ai-agent.Dockerfile` (Python) + `k8s.backend.Dockerfile` (Node)
3. **Frontend calls AI agent directly**: `config.agentUrl` points to port 4652, bypassing the Express backend entirely
4. **Dual CORS configs**: Both Express and Flask configure CORS independently
5. **Python dependency overhead**: Flask, flask-cors, python-dotenv for a single endpoint
6. **No shared auth/middleware**: The AI agent endpoint has no authentication

### What the AI Agent Actually Does

The Flask server exposes a **single endpoint** (`POST /assistente`) that:
1. Receives `{ "materia": "topic string" }` from the frontend
2. Removes accents from the input and uppercases it
3. Calls the **RAGFlow API** (external service) to:
   - Create a session (`POST /api/v1/agents/{agent_id}/completions`)
   - Analyze the materia with that session (same endpoint, different payload)
4. Formats the response using `gerar_texto_ranking()` (parses the RAGFlow JSON into Markdown)
5. Returns `{ "resultado": "formatted markdown string" }`

The Python code makes **two HTTP requests** to RAGFlow and does **text processing** — all of which is trivially portable to TypeScript.

---

## Target Architecture

```
Frontend (SvelteKit)
  └── All calls → Express backend (port 3000)
                    ├── /assistente/analyze  (new TypeScript controller)
                    │     └── HTTP calls → RAGFlow API (external)
                    ├── /fluxograma/*
                    ├── /cursos/*
                    └── ...
```

**Single server, single port, single language.**

---

## Implementation Plan

### Phase 1: Create the RAGFlow Service in TypeScript
> Port the RAGFlow HTTP client logic from Python to TypeScript

- [ ] **1.1** Create `src/services/ragflow.service.ts`
  - Port `RagflowClient` class using `axios` (already a dependency)
  - `startSession(materia: string): Promise<string>` — calls RAGFlow completions endpoint, returns `session_id`
  - `analyzeMateria(materia: string, sessionId: string): Promise<RagflowResponse>` — calls RAGFlow with `question` + `session_id`
  - Read config from env vars: `RAGFLOW_API_KEY`, `RAGFLOW_BASE_URL`, `RAGFLOW_AGENT_ID`
  - Add proper timeout handling (30s for session, 60s for analysis)
  - Add typed interfaces for RAGFlow request/response payloads

```typescript
// src/services/ragflow.service.ts
import axios from 'axios';
import logger from '../logger';

interface RagflowResponse {
  code: number;
  data: {
    answer: string;
    session_id: string;
    [key: string]: any;
  };
  message?: string;
}

export class RagflowService {
  private readonly agentId: string;
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly url: string;

  constructor() {
    this.apiKey = process.env.RAGFLOW_API_KEY || '';
    this.baseUrl = process.env.RAGFLOW_BASE_URL || '';
    this.agentId = process.env.RAGFLOW_AGENT_ID || '';
    this.url = `${this.baseUrl}/api/v1/agents/${this.agentId}/completions`;

    if (!this.apiKey || !this.baseUrl || !this.agentId) {
      logger.warn('RAGFlow configuration incomplete — AI assistant will be unavailable');
    }
  }

  async startSession(materia: string): Promise<string> { /* ... */ }
  async analyzeMateria(materia: string, sessionId: string): Promise<RagflowResponse> { /* ... */ }
}
```

- [ ] **1.2** Create `src/services/ragflow.types.ts` for shared interfaces

### Phase 2: Port Text Processing Utilities
> Port Python string utilities and response formatter to TypeScript

- [ ] **2.1** Create `src/utils/text.utils.ts`
  - Port `remover_acentos_nativo()` — use `String.normalize('NFD').replace(/[\u0300-\u036f]/g, '')` (one-liner in JS)

```typescript
export function removeAccents(text: string): string {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}
```

- [ ] **2.2** Create `src/utils/ranking.formatter.ts`
  - Port `gerar_texto_ranking()` from `visualizaJsonMateriasAssociadas.py`
  - Parse the RAGFlow response: `ast.literal_eval(data.answer)` → in TS, use `JSON.parse()` or regex extraction since the content is a Python dict literal string
  - Extract ranking block between `INÍCIO DO RANKING` and `FIM DO RANKING`
  - Parse individual items with regex (same patterns, adapted for JS regex syntax)
  - Build Markdown output with medal emojis, tables, and summary statistics
  - **Key concern**: the Python code uses `ast.literal_eval()` to parse a Python dict literal inside the JSON — in TypeScript, we'll need a custom parser or regex-based extraction since it's not valid JSON

```typescript
// Approach for parsing the Python dict literal in the answer field:
// The answer looks like: "{'content': {'0': '...'}, 'component_id': {'0': '...'}}"
// Option A: Replace single quotes with double quotes and parse as JSON
// Option B: Use regex to extract the content directly
function extractContent(answer: string): string {
  // Replace Python-style single-quoted dict with JSON-compatible format
  const jsonCompatible = answer
    .replace(/'/g, '"')
    .replace(/None/g, 'null')
    .replace(/True/g, 'true')
    .replace(/False/g, 'false');
  const parsed = JSON.parse(jsonCompatible);
  return parsed.content['0'];
}
```

### Phase 3: Create the Assistente Controller
> Expose the `/assistente` endpoint through the existing Express controller pattern

- [ ] **3.1** Create `src/controllers/assistente_controller.ts`
  - Follow the existing `EndpointController` pattern used by `FluxogramaController`, `CursosController`, etc.
  - Single route: `analyze` → `POST /assistente/analyze`
  - Request body: `{ "materia": string }`
  - Response: `{ "resultado": string }` (success) or `{ "erro": string }` (error)
  - Validate input (non-empty `materia` field)
  - Call `RagflowService.startSession()` then `RagflowService.analyzeMateria()`
  - Format response with `gerarTextoRanking()`
  - Add graceful handling when RAGFlow config is missing (return 503 Service Unavailable)

```typescript
// src/controllers/assistente_controller.ts
import { EndpointController, RequestType } from "../interfaces";
import { Pair } from "../utils";
import { Request, Response } from "express";
import { RagflowService } from "../services/ragflow.service";
import { removeAccents } from "../utils/text.utils";
import { formatRanking } from "../utils/ranking.formatter";
import logger from "../logger";

const ragflow = new RagflowService();

export const AssistenteController: EndpointController = {
  name: "assistente",
  routes: {
    analyze: new Pair(RequestType.POST, async (req: Request, res: Response) => {
      const { materia } = req.body;
      if (!materia || !materia.trim()) {
        return res.status(400).json({ erro: "O campo 'materia' é obrigatório." });
      }
      try {
        const processed = removeAccents(materia).toUpperCase();
        const sessionId = await ragflow.startSession(processed);
        const result = await ragflow.analyzeMateria(processed, sessionId);
        if (result.code !== 0) {
          return res.status(500).json({ erro: `Erro na API do agente: ${result.message}` });
        }
        const formatted = formatRanking(result);
        return res.json({ resultado: formatted });
      } catch (error) {
        logger.error(`[Assistente] Error: ${error}`);
        return res.status(500).json({ erro: "Erro interno no servidor." });
      }
    })
  }
};
```

- [ ] **3.2** Register `AssistenteController` in `src/index.ts`
  - Add to the `controllers` array alongside existing controllers

```typescript
import { AssistenteController } from './controllers/assistente_controller';

const controllers: EndpointController[] = [
  FluxogramaController,
  TestesController,
  UsersController,
  CursosController,
  MateriasController,
  AssistenteController,  // ← new
];
```

### Phase 4: Update Frontend to Use Unified Backend
> Point the frontend AI service at the Express backend instead of the Flask server

- [ ] **4.1** Update `no_fluxo_frontend_svelte/src/lib/services/assistente.service.ts`
  - Change `config.agentUrl` → `config.apiUrl`
  - Update endpoint from `/assistente` → `/assistente/analyze` (to match the controller pattern)

```typescript
// Before:
const url = `${config.agentUrl}${this.endpoint}`;
// After:
const url = `${config.apiUrl}/assistente/analyze`;
```

- [ ] **4.2** Remove `PUBLIC_AGENT_URL` from frontend config
  - Update `src/lib/config.ts` — remove `agentUrl` field
  - Remove `PUBLIC_AGENT_URL` from `.env` / `.env.example` files
  - Clean up any other references to `agentUrl`

### Phase 5: Remove Python AI Agent Infrastructure
> Clean up all Python/Flask AI agent code and infrastructure

- [ ] **5.1** Remove the child process spawning from `src/index.ts`
  - Delete the entire `ragflowAgentProcess` block (lines ~24-60)
  - Remove `spawn` and `path` imports if no longer needed (PDF parser still uses them)
  - Remove `ragflowAgentProcess.kill()` from `cleanup()`
  - Keep `AI_AGENT_URL` env var check removed — it's no longer needed

- [ ] **5.2** Delete `k8s.ai-agent.Dockerfile`
  - The separate AI agent Docker image is no longer needed

- [ ] **5.3** Update main `Dockerfile`
  - Remove `COPY no_fluxo_backend/ai_agent/ ./ai_agent/`
  - Remove `pip3 install -r ai_agent/requirements.txt`
  - Remove `EXPOSE 4652`

- [ ] **5.4** Update `docker-compose.yml`
  - Remove AI agent service if defined separately
  - Remove port 4652 mapping

- [ ] **5.5** Update Kubernetes manifests
  - Remove AI agent deployment/service from `kubernetes_docs/`
  - Remove `AI_AGENT_URL` env var from backend deployment

- [ ] **5.6** Update `no_fluxo_backend/package.json` build scripts
  - Remove `pip install -r ai_agent/requirements.txt` from `build` and `dev` scripts

- [ ] **5.7** Archive or delete the Python AI agent folder
  - Move `no_fluxo_backend/ai_agent/` to a backup branch or delete it
  - Keep `agente_noFluxo.json` (RAGFlow agent config) and `prompts/` (documentation) if useful — move them to `documentacao/` or a `docs/ai-agent/` folder

### Phase 6: Add Environment Variable Documentation
> Ensure RAGFlow config is documented for the Express backend

- [ ] **6.1** Update `.env.example` in `no_fluxo_backend/`
  - Add: `RAGFLOW_API_KEY=`, `RAGFLOW_BASE_URL=`, `RAGFLOW_AGENT_ID=`
  - Remove: `AI_AGENT_PORT`, `AI_AGENT_URL`
  - Remove: `PUBLIC_AGENT_URL` from frontend env examples

- [ ] **6.2** Update `README.md` to reflect the unified architecture
  - Remove references to the separate Python AI agent server
  - Document that the `/assistente/analyze` endpoint is part of the Express backend

### Phase 7: Testing
> Verify the integration works end to end

- [ ] **7.1** Create `tests-ts/assistente_controller.test.ts`
  - Test input validation (missing materia, empty materia)
  - Mock `RagflowService` to test controller logic without external API
  - Test error handling (RAGFlow unavailable, timeout, non-zero response code)

- [ ] **7.2** Create `tests-ts/ragflow.service.test.ts`
  - Test `startSession()` with mocked HTTP responses
  - Test `analyzeMateria()` with mocked HTTP responses
  - Test error cases (timeout, connection refused, invalid response)

- [ ] **7.3** Create `tests-ts/ranking.formatter.test.ts`
  - Use the example JSON from `visualizaJsonMateriasAssociadas.py` as test fixture
  - Verify Markdown output structure (headings, tables, emojis)
  - Test edge cases (empty ranking, malformed data)

- [ ] **7.4** End-to-end integration test
  - Start the Express server
  - Send `POST /assistente/analyze` with a test materia
  - Verify response format matches what the frontend expects

---

## File Changes Summary

### New Files
| File | Purpose |
|------|---------|
| `src/services/ragflow.service.ts` | RAGFlow API client (HTTP calls) |
| `src/services/ragflow.types.ts` | TypeScript interfaces for RAGFlow |
| `src/utils/text.utils.ts` | Accent removal and text normalization |
| `src/utils/ranking.formatter.ts` | RAGFlow response → Markdown formatter |
| `src/controllers/assistente_controller.ts` | Express endpoint for `/assistente/analyze` |
| `tests-ts/assistente_controller.test.ts` | Controller tests |
| `tests-ts/ragflow.service.test.ts` | RAGFlow service tests |
| `tests-ts/ranking.formatter.test.ts` | Formatter tests |

### Modified Files
| File | Change |
|------|--------|
| `src/index.ts` | Add `AssistenteController`, remove Python process spawning |
| `frontend/src/lib/services/assistente.service.ts` | Point to Express backend |
| `frontend/src/lib/config.ts` | Remove `agentUrl` |
| `Dockerfile` | Remove AI agent Python deps and files |
| `package.json` | Remove `pip install ai_agent/requirements.txt` from build scripts |

### Deleted Files
| File | Reason |
|------|--------|
| `k8s.ai-agent.Dockerfile` | No longer needed |
| `no_fluxo_backend/ai_agent/` (entire folder) | Replaced by TypeScript implementation |

---

## Environment Variables

### Before
```env
# Backend
AI_AGENT_PORT=4652
AI_AGENT_URL=          # Only in K8s to point to separate AI service

# Frontend
PUBLIC_AGENT_URL=http://localhost:4652

# RAGFlow (read by Python ai_agent)
RAGFLOW_API_KEY=...
RAGFLOW_BASE_URL=...
RAGFLOW_AGENT_ID=...
```

### After
```env
# Backend (reads RAGFlow config directly)
RAGFLOW_API_KEY=...
RAGFLOW_BASE_URL=...
RAGFLOW_AGENT_ID=...

# Frontend (no more agent URL — uses same API URL)
PUBLIC_API_URL=http://localhost:3000
```

---

## Migration Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Python `ast.literal_eval()` parses a Python dict literal that isn't valid JSON | Use regex or string replacement to convert Python dict syntax to JSON before `JSON.parse()` |
| RAGFlow API response format changes | Add comprehensive typing and validation in `ragflow.types.ts` |
| Regex differences between Python and JavaScript | Port regex patterns carefully — JS doesn't support `re.DOTALL` by default, use `/s` flag instead |
| Loss of Python-specific libs (`unicodedata2`) | JS native `String.normalize('NFD')` handles accent removal identically |
| Frontend caching `agentUrl` | Clear any env/build caches when switching; update all `.env` files |

---

## Execution Order

Recommended implementation sequence:

1. **Phases 1-3** first (create TS implementation alongside existing Python) — the system works with both
2. **Phase 4** (update frontend) — switch traffic to Express backend
3. **Phase 7** (testing) — verify everything works
4. **Phase 5-6** (cleanup) — remove Python code and update docs

This allows incremental rollout: the Python agent can remain as a fallback until the TypeScript version is verified in production.
