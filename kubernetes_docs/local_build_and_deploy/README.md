# Local Build & Deploy

Build Docker images on your own machine, push to the private registry, and deploy to the Kubernetes cluster via the Deploy API — **without** needing to push code to Git first.

This is the recommended workflow when you're iterating locally and want to deploy changes that haven't been committed yet.

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                    Developer Machine                          │
│                                                              │
│  1. docker build   (or docker buildx for multi-arch)         │
│  2. docker push    → private registry                        │
│  3. Resolve image digest (buildId) via Deploy API            │
│  4. Deploy by buildId via Deploy API                         │
│  5. Stream deployment logs until done                        │
└──────────────────────────────────────────────────────────────┘
         │                           │
         ▼                           ▼
┌─────────────────┐     ┌──────────────────────────┐
│  Docker Registry │     │     Deploy API Server     │
│  (private)       │     │  → creates K8s manifests  │
└─────────────────┘     │  → applies deployment     │
                        │  → configures ingress/TLS │
                        │  → sets up DNS            │
                        └──────────────────────────┘
```

## Files

| File                 | Purpose                                                               |
| -------------------- | --------------------------------------------------------------------- |
| `deploy_config.py`   | **Edit this.** Define your apps (name, port, Dockerfile, env vars…).  |
| `deploy_local.py`    | CLI script — orchestrates build, push, and deploy.                    |
| `requirements.txt`   | Python dependencies (`requests`, `python-dotenv`).                    |
| `.env.local.example` | Template for your Deploy API credentials.                             |
| `.gitignore.example` | Suggested gitignore entries (credentials + state files).              |

## Prerequisites

- **Python 3.10+**
- **Docker** installed and running
- **Registry credentials** — logged in to the private registry:
  ```bash
  docker login registry.kubernetes.crianex.com
  ```
- **Deploy API key** — ask an admin or retrieve from the cluster:
  ```bash
  kubectl get secret deploy-api-secrets -n deploy-system \
    -o jsonpath='{.data.DEPLOY_API_KEY}' | base64 -d
  ```
- **(Optional) Docker Buildx** — required for multi-architecture builds (linux/amd64 + linux/arm64). Comes bundled with Docker Desktop.

## Quick Start

### 1. Copy the scripts into your project

```bash
# From this repo
cp -r kubernetes/local_build_and_deploy/ /path/to/your-project/scripts/deploy/

# Or just the essentials
mkdir -p /path/to/your-project/scripts/deploy
cp kubernetes/local_build_and_deploy/deploy_config.py  /path/to/your-project/scripts/deploy/
cp kubernetes/local_build_and_deploy/deploy_local.py   /path/to/your-project/scripts/deploy/
cp kubernetes/local_build_and_deploy/requirements.txt  /path/to/your-project/scripts/deploy/
```

### 2. Install dependencies

```bash
pip install -r scripts/deploy/requirements.txt
```

### 3. Set up credentials

Create a `.env.local` file at your **repo root** (not inside the scripts folder):

```bash
cp scripts/deploy/.env.local.example .env.local
```

Edit `.env.local`:

```env
DEPLOY_API_URL=https://deploy.kubernetes.crianex.com
DEPLOY_API_KEY=your-key-here
```

Add to `.gitignore`:

```
.env.local
.deploy/
```

### 4. Edit `deploy_config.py`

Open `scripts/deploy/deploy_config.py` and configure the `APPS` dictionary to match your project. Each entry defines one deployable unit.

**Minimal single-app example:**

```python
APPS: dict[str, AppConfig] = {
    "app": AppConfig(
        key="app",
        app_name="my-cool-app",
        namespace="apps",
        image_name="my-cool-app",
        dockerfile="Dockerfile",
        build_context=".",
        port=3000,
        replicas=1,
        health_path="/health",
        domain="my-cool-app.kubernetes.crianex.com",
    ),
}
```

Also update the `choices` list in `deploy_local.py`'s `build_parser()` function to match your app keys:

```python
parser.add_argument(
    "target",
    choices=["app", "all"],   # ← must match your APPS keys
    help="Which app to deploy",
)
```

**Multi-app example (frontend + backend):**

```python
APPS: dict[str, AppConfig] = {
    "frontend": AppConfig(
        key="frontend",
        app_name="myproject-frontend",
        namespace="apps",
        image_name="myproject-frontend",
        dockerfile="frontend/Dockerfile",
        build_context="frontend",
        port=3000,
        replicas=1,
        health_path="/health",
        domain="myproject.example.com",
        build_arg_keys=(
            "VITE_SUPABASE_URL",       # read from env at build time
            "VITE_SUPABASE_ANON_KEY",
        ),
        build_arg_static={
            "VITE_API_URL": "https://api.myproject.example.com",  # hardcoded
        },
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "3000",
        },
    ),
    "backend": AppConfig(
        key="backend",
        app_name="myproject-backend",
        namespace="apps",
        image_name="myproject-backend",
        dockerfile="Dockerfile",
        build_context=".",
        port=8000,
        replicas=1,
        health_path="/health",
        domain="api.myproject.example.com",
        env_folder="backend",     # load .env from backend/ instead of repo root
        deploy_env_keys=(
            "DATABASE_URL",        # read from env at deploy time → K8s env var
            "SECRET_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "8000",
        },
    ),
}
```

### 5. Deploy!

```bash
# Deploy a single app
python scripts/deploy/deploy_local.py frontend

# Deploy all apps
python scripts/deploy/deploy_local.py all

# Dry run (see what would happen without executing)
python scripts/deploy/deploy_local.py frontend --dry-run
```

## Usage Reference

### Full deploy (build → push → deploy)

```bash
python deploy_local.py <target> [options]
```

| Argument           | Default                          | Description                                    |
| ------------------ | -------------------------------- | ---------------------------------------------- |
| `target`           | *(required)*                     | App key from `deploy_config.APPS`, or `all`    |
| `--env-file`       | repo root `.env.local`           | Path to a custom .env file                     |
| `--api-url`        | `DEPLOY_API_URL` env var         | Deploy API base URL                            |
| `--api-key`        | `DEPLOY_API_KEY` env var         | Deploy API key                                 |
| `--registry`       | `registry.kubernetes.crianex.com`| Docker registry host                           |
| `--tag`            | `local-<timestamp>`              | Image tag                                      |
| `--platform`       | `linux/amd64,linux/arm64`        | Target platform(s) for buildx                  |
| `--no-push`        | `false`                          | Build only, don't push                         |
| `--dry-run`        | `false`                          | Print plan without executing                   |
| `--redeploy`       | `false`                          | Skip build; reuse last buildId                 |
| `--wait/--no-wait` | `--wait`                         | Wait for deployment to complete                |
| `--stream-logs`    | `true`                           | Stream build/deploy logs live                  |
| `--wait-timeout`   | `1800`                           | Max seconds to wait                            |
| `--docker`         | `docker`                         | Docker CLI binary path                         |
| `--state-file`     | `.deploy/build-id.<key>.json`    | Override state file location                   |

### Redeploy (skip build, reuse previous image)

When you only changed deploy configuration (env vars, replicas, domain) but not the code:

```bash
python deploy_local.py backend --redeploy
```

This reads the last `buildId` from `.deploy/build-id.backend.json` and deploys with the current config. No Docker build or push happens.

### Single-platform build (faster, no buildx)

The default is multi-arch (`linux/amd64,linux/arm64`). For faster iteration when you just want your native architecture:

```bash
python deploy_local.py frontend --platform native
```

## Environment Variable Handling

The scripts load `.env` files in a specific priority order:

| Priority | Source                         | Override behavior | Example                    |
| -------- | ------------------------------ | ----------------- | -------------------------- |
| 1 (low)  | Repo root `.env.local`         | Won't override    | `DEPLOY_API_KEY=...`       |
| 2 (med)  | Project-specific `.env`        | Overrides lower   | `frontend/.env`            |
| 3 (high) | Custom `--env-file`            | Overrides all     | `--env-file prod.env`      |

### Build args vs deploy env

| Config field         | When used           | Passed as                    |
| -------------------- | ------------------- | ---------------------------- |
| `build_arg_keys`     | `docker build` time | `--build-arg KEY=value`      |
| `build_arg_static`   | `docker build` time | `--build-arg KEY=value`      |
| `deploy_env_keys`    | Deploy time         | K8s container env vars       |
| `deploy_env_static`  | Deploy time         | K8s container env vars       |

- `*_keys` → value is read from the current environment (or `.env` files)
- `*_static` → value is hardcoded in `deploy_config.py`

## State Files

After a successful deploy, the script saves a state file at `.deploy/build-id.<key>.json`:

```json
{
  "app": "myproject-frontend",
  "buildId": "sha256:9b1dea...",
  "imageName": "myproject-frontend",
  "imageTag": "local-1707580800",
  "namespace": "apps"
}
```

This enables:
- **`--redeploy`** — reuse the `buildId` without rebuilding
- **Audit trail** — see what was last deployed for each app

## Recommended Project Layout

```
your-project/
├── .env.local                     # Deploy API credentials (gitignored)
├── .deploy/                       # State files (gitignored)
│   ├── build-id.frontend.json
│   └── build-id.backend.json
├── scripts/
│   └── deploy/
│       ├── deploy_config.py       # Your app definitions
│       ├── deploy_local.py        # Deploy CLI (no edits needed)
│       └── requirements.txt
├── frontend/
│   ├── Dockerfile
│   ├── .env                       # Frontend-specific env vars
│   └── ...
├── backend/
│   ├── .env                       # Backend-specific env vars
│   └── ...
└── Dockerfile                     # Backend Dockerfile (build_context=".")
```

## Comparison: Local Deploy vs GitHub Actions

| Aspect               | Local Deploy (this)                      | GitHub Actions (Kaniko)                  |
| -------------------- | ---------------------------------------- | ---------------------------------------- |
| **When to use**      | Iterating locally, code not pushed yet   | Production deploys, CI/CD pipeline       |
| **Build location**   | Your machine                             | In-cluster (Kaniko)                      |
| **Multi-arch**       | ✅ via Docker Buildx                      | ✅ via Kaniko                             |
| **Speed**            | Depends on your machine + upload speed   | Fast (build + registry are co-located)   |
| **Git required?**    | No                                       | Yes (needs repo URL + ref)               |
| **Redeploy**         | ✅ `--redeploy` from state file           | ✅ via `buildId` in workflow              |
| **Streaming logs**   | ✅ Built-in                               | ✅ Via workflow                           |

## Troubleshooting

### "Missing DEPLOY_API_URL"
- Ensure `.env.local` exists at the repo root with `DEPLOY_API_URL=...`
- Or pass `--api-url https://deploy.kubernetes.crianex.com`

### "docker login" errors
- Run `docker login registry.kubernetes.crianex.com` first
- See [REGISTRY_AUTH.md](../REGISTRY_AUTH.md) for credentials

### Multi-arch build fails
- Ensure Docker Buildx is installed: `docker buildx version`
- Create a builder if needed: `docker buildx create --use`
- For faster iteration, use `--platform native`

### "ERROR 404 resolving digest"
- The image was not found in the registry. Check that `docker push` succeeded.
- Verify `image_name` in `deploy_config.py` matches what was pushed.

### Redeploy fails with "State file not found"
- You need to do a full deploy at least once before `--redeploy` works.
- State file is saved at `.deploy/build-id.<key>.json`.

## See Also

- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) — Full deployment guide (GitHub Actions workflow)
- [BUILD_ID_REUSE_PYTHON.md](../BUILD_ID_REUSE_PYTHON.md) — How `buildId` reuse works
- [REGISTRY_AUTH.md](../REGISTRY_AUTH.md) — Registry credentials and access
- [deploy_client/](../deploy_client/) — Generic CLI (flag-driven, no config file needed)
- [templates/](../templates/) — Dockerfile and GitHub Actions workflow templates
