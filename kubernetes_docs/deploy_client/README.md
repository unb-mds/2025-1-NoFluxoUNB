# Deploy API Python CLI (`deploy_client`)

Minimal Python CLI to:

- trigger an in-cluster Kaniko build via Deploy API
- resolve and store the resulting image digest (`buildId`)
- reuse `buildId` to skip future builds and deploy instantly (deploy-by-digest)

## Install

```bash
python3 -m pip install -r kubernetes/deploy_client/requirements.txt
```

## Environment

- `DEPLOY_API_URL` (e.g. `https://deploy.kubernetes.crianex.com`)
- `DEPLOY_API_KEY` (sent as `X-API-Key`)

Optional:
- `DEPLOY_API_TIMEOUT` (seconds)

## Run

Because this lives under `kubernetes/` (to be copied into other repos), run it from a repo root using `PYTHONPATH=kubernetes`:

```bash
PYTHONPATH=kubernetes python3 -m deploy_client --help
```

This writes `.deploy/build-id.json` relative to your current working directory.

## Commands

### Deploy local changes (build on your machine)

This is the recommended path when your code is not pushed to Git yet.

Prereqs:
- Docker installed
- Logged into the registry (e.g. `docker login registry.kubernetes.crianex.com`)

```bash
export DEPLOY_REGISTRY=registry.kubernetes.crianex.com

PYTHONPATH=kubernetes python3 -m deploy_client local-deploy \
  --app my-app \
  --namespace apps \
  --port 3000 \
  --domains my-app.example.com
```

To deploy to the non-business node pool:

```bash
PYTHONPATH=kubernetes python3 -m deploy_client local-deploy \
  --app my-tool \
  --namespace apps \
  --port 3000 \
  --domains my-tool.example.com \
  --app-class non-business
```

Notes:
- This runs `docker build` + `docker push`, then resolves the digest via the Deploy API and deploys via `buildId`.
- The resulting digest is stored in `.deploy/build-id.json`.
- Use `--app-class non-business` to schedule pods on non-business nodes (defaults to `business`).

### Build once (stores buildId)

```bash
PYTHONPATH=kubernetes python3 -m deploy_client build \
  --app my-app \
  --namespace apps \
  --repo-url https://github.com/org/repo \
  --git-ref main \
  --app-class business          # optional, default
```

### Reuse deploy (skip Kaniko)

```bash
PYTHONPATH=kubernetes python3 -m deploy_client reuse-deploy \
  --port 3000 \
  --domains my-app.example.com \
  --app-class business          # optional, default
```

If you don't pass `--build-id`, it will use `.deploy/build-id.json`.

### App Class

All deploy commands accept `--app-class` (`business` | `non-business`, default `business`).

- **`business`** — pods land in the `apps` namespace on the default node pool.
- **`non-business`** — pods land in the `non-business-apps` namespace and are scheduled only on nodes labelled `workload-class=non-business` (with matching tolerations).
