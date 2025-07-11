# Docker Setup for NoFluxo

The Docker configuration has been moved to the **repository root** to properly access the `.git` directory for auto-updates.

## Quick Start

1. **Copy environment configuration:**
   ```bash
   # From the repository root
   cp no_fluxo_backend/.env.example no_fluxo_backend/.env
   # Edit no_fluxo_backend/.env with your actual values
   ```

2. **Run the Docker setup:**
   ```bash
   # From the repository root
   docker-compose up --build
   ```

## File Structure

```
2025-1-NoFluxoUNB/               # Repository root (you are here)
├── .git/                        # Git repository (properly accessible now!)
├── Dockerfile                   # Main Docker configuration
├── docker-compose.yml          # Docker Compose setup
├── docker-entrypoint.sh        # Container startup script
├── nginx.conf                  # Nginx configuration
├── DOCKER_README.md            # This file
└── no_fluxo_backend/           # Backend code
    ├── .env                    # Environment configuration (create this)
    ├── .env.example            # Environment template
    ├── start_and_monitor.py    # Auto-update monitoring script
    ├── src/                    # TypeScript source code
    ├── ai_agent/               # AI agent code
    └── ...                     # Other backend files
```

## What Changed?

### ✅ Fixed Issues:
- **Git repository access**: `.git` directory is now properly mounted and accessible
- **Auto-updates**: Git operations work correctly from the container
- **Fork synchronization**: Fork repositories can be properly cloned and updated

### 📁 File Movements:
**Moved to root:**
- `Dockerfile` (was in `no_fluxo_backend/`)
- `docker-compose.yml` (was in `no_fluxo_backend/`)
- `docker-entrypoint.sh` (was in `no_fluxo_backend/`)
- `nginx.conf` (was in `no_fluxo_backend/`)

**Stayed in `no_fluxo_backend/`:**
- `start_and_monitor.py` (runs from backend context)
- All source code and application files
- `.env` configuration file

## Environment Configuration

Create your environment file:
```bash
cp no_fluxo_backend/.env.example no_fluxo_backend/.env
```

Key variables for auto-updates:
```env
GIT_USERNAME=your_github_username
GIT_TOKEN=your_github_personal_access_token
GIT_BRANCH=dev
FORK_URL=https://github.com/yourusername/2025-1-NoFluxoUNB.git
```

## How It Works

1. **Repository Mounting**: The entire repository root (including `.git`) is mounted to `/app`
2. **Backend Context**: The application runs from `/app/no_fluxo_backend/`
3. **Git Operations**: Auto-update script accesses `/app/.git` properly
4. **Volume Persistence**: Logs, builds, and fork data persist across container restarts

## URLs

- **Main API**: `https://localhost:443/` (or `https://no-fluxo-api.shop/`)
- **AI Agent**: `https://localhost:4652/` (or `https://no-fluxo-api.shop:4652/`)

## Development

For local development without Docker, continue using the scripts in `no_fluxo_backend/`.

For production deployment with auto-updates, use this root-level Docker setup.

## Troubleshooting

**Git operations fail:**
- Ensure you're running `docker-compose` from the repository root
- Check that `.git` directory exists and has content
- Verify git credentials in `no_fluxo_backend/.env`

**Permission issues:**
- The container automatically fixes ownership of mounted directories
- Logs will show detailed permission debugging information

**Build issues:**
- Check that all files exist in `no_fluxo_backend/`
- Review build logs for missing dependencies 