# Build ID Reuse (Python Helper Script)

This document describes a simple Python CLI workflow to:

1. Trigger an in-cluster Kaniko build via Deploy API (`POST /build`)
2. Capture the resulting `buildId` (image manifest digest: `sha256:...`)
3. Reuse that `buildId` to skip future builds and deploy instantly (deploy-by-digest)

This is intended to be run from a developer/operator machine.

The repo includes a minimal reference implementation at:

- `kubernetes/deploy_client/` (run from repo root with `PYTHONPATH=kubernetes python -m deploy_client ...`)

If you want to deploy local changes that are not pushed to Git yet, use the CLI's `local-deploy` command (build locally, push, then deploy via `buildId`).

---

## Background: what is `buildId`?

`buildId` is the Docker Registry v2 manifest digest (content address), e.g.:

- `sha256:9b1d...` (64 hex chars)

When you call `POST /build` with a `buildId`, the server should:

- Verify the manifest exists in the registry for that app image
- **Fail hard** with `404` if it does not exist (no fallback build)
- If it exists, **skip** the Kaniko Job and deploy using:

`<registry>/<imageName>@<buildId>`

Example:

- `registry.kubernetes.crianex.com/myapp@sha256:...`

---

## Prerequisites

- Python 3.10+
- A Deploy API key
- Network access to the Deploy API
- Docker installed (for `local-deploy`)
- Registry credentials on your machine (for `local-deploy`), e.g. `docker login registry.kubernetes.crianex.com`

Suggested libraries:
- `requests` (HTTP client)

---

## Environment variables

- `DEPLOY_API_URL` (example: `https://deploy.kubernetes.crianex.com`)
- `DEPLOY_API_KEY` (value for `X-API-Key`)

Optional:
- `DEPLOY_API_TIMEOUT` (seconds; default 30)

For local image builds:
- `DEPLOY_REGISTRY` (registry host; default `registry.kubernetes.crianex.com`)

---

## Local state file

Store the resolved build id in a repo-local file so you can reuse it later.

Suggested path:
- `.deploy/build-id.json`

Suggested format:

```json
{
  "repoUrl": "https://github.com/org/repo",
  "gitRef": "<sha-or-branch>",
  "app": "myapp",
  "namespace": "apps",
  "imageName": "myapp",
  "imageTag": "<tag-used-for-initial-build>",
  "buildId": "sha256:..."
}
```

---

## CLI structure (recommended)

Directory layout:

- `kubernetes/deploy_client/`
  - `config.py` (reads env/flags)
  - `api.py` (HTTP calls)
  - `buildid_store.py` (read/write `.deploy/build-id.json`)
  - `__main__.py` (argparse entrypoint)

Commands (minimal):

- `build`: trigger build, wait, resolve digest, store to `.deploy/build-id.json`
- `reuse-deploy`: deploy by `buildId` (strict), skipping build

All deploy commands accept `--app-class business|non-business` (default `business`) to choose which node pool gets the pods.

---

## API calls the script should make

### 1) Start build (first time)

`POST /build`

Payload (example):

```json
{
  "app": "myapp",
  "namespace": "apps",
  "repoUrl": "https://github.com/org/repo",
  "gitRef": "<sha>",
  "gitToken": "<optional>",
  "imageTag": "<sha>",
  "cache": true,
  "deploy": false
}
```

Capture `jobName` from the response.

### 2) Wait for completion

`POST /build/:jobName/wait?timeout=1800`

### 3) Resolve `buildId` (digest)

Recommended approach: use the Deploy API endpoint that returns the digest for an image tag (so the script doesn’t need registry credentials).

Endpoint:

- `GET /registry/<imageName>/digest?tag=<imageTag>` → `{ "buildId": "sha256:..." }`

Store that `buildId` in `.deploy/build-id.json`.

### 4) Reuse deploy (skip build)

`POST /build` with `buildId` and `deploy: true`.

```json
{
  "app": "myapp",
  "namespace": "apps",
  "buildId": "sha256:...",
  "deploy": true,
  "deployConfig": {
    "port": 3000,
    "replicas": 2,
    "domain": "myapp.kubernetes.crianex.com",
    "healthPath": "/health",
    "appClass": "business"
  }
}
```

Expected behavior:
- If `buildId` exists: return success, `skipped: true`, and deploy using `image@sha256:...`
- If `buildId` does not exist: return `404` and do not start a build

---

## Notes and caveats

- `buildId` reuse should be scoped to the app’s `imageName` (avoid cross-app digest reuse).
- Deploy-by-digest is deterministic and avoids retagging, but you won’t see a “pretty” tag in the Deployment image field.
- If you rebuild the same `imageTag`, the digest may change; always treat the digest as the source of truth.
