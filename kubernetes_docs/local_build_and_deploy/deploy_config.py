"""
deploy_config.py — Project-specific app configuration for local deploys.

Copy this file into your project's scripts/ (or root) folder and edit the
APPS dictionary to match your applications.

Each AppConfig entry describes one deployable unit: its Docker build settings,
the environment variables it needs at build-time and run-time, and the
Kubernetes deploy parameters (port, replicas, domain, etc.).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Sequence


@dataclass(frozen=True)
class AppConfig:
    """Configuration for a single deployable application."""

    key: str                # Short identifier used as CLI target (e.g. "frontend")
    app_name: str           # Kubernetes deployment name
    namespace: str          # Kubernetes namespace (e.g. "apps")
    image_name: str         # Image name in the registry (no registry prefix)
    dockerfile: str         # Path to Dockerfile relative to repo root
    build_context: str      # Docker build context relative to repo root
    port: int               # Container port
    replicas: int           # Number of pod replicas
    health_path: str        # Health-check endpoint (e.g. "/health")

    # --- Domain routing (pick one) ---
    domain: str | None = None               # Single domain
    domains: Sequence[str] | None = None    # Multiple domains (including wildcards)

    # --- Environment file loading ---
    env_folder: str | None = None  # Folder to load .env from (defaults to build_context)

    # --- Build-time args ---
    # Keys to read from the environment and pass as --build-arg to Docker
    build_arg_keys: Sequence[str] = ()
    # Static build args (hardcoded values, not from env)
    build_arg_static: Mapping[str, str] | None = None

    # --- Runtime env vars (injected into the K8s deployment) ---
    # Keys to read from the environment
    deploy_env_keys: Sequence[str] = ()
    # Static env vars (hardcoded values)
    deploy_env_static: Mapping[str, str] | None = None


# ---------------------------------------------------------------------------
# Define your apps here.  The dict key is the CLI target name.
#
# Usage:
#   python deploy_local.py frontend          # deploy one app
#   python deploy_local.py backend           # deploy another
#   python deploy_local.py all               # deploy everything
# ---------------------------------------------------------------------------

APPS: dict[str, AppConfig] = {
    # ── Example: Node.js frontend ──────────────────────────────────────────
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
            # These will be read from your .env / environment at build time
            # "VITE_SUPABASE_URL",
            # "VITE_SUPABASE_ANON_KEY",
        ),
        build_arg_static={
            # Hardcoded build args (not read from env)
            # "VITE_API_URL": "https://api.myproject.example.com",
        },
        deploy_env_keys=(),
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "3000",
            # "ORIGIN": "https://myproject.example.com",
        },
    ),
    # ── Example: Python / Node backend ─────────────────────────────────────
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
        env_folder="backend",  # load .env from backend/ folder instead of build_context
        build_arg_keys=(),
        deploy_env_keys=(
            # These will be read from your .env / environment at deploy time
            # and injected as K8s env vars
            # "DATABASE_URL",
            # "SECRET_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "8000",
        },
    ),
}


def get_app_config(key: str) -> AppConfig:
    """Look up an app config by key. Exits with a helpful message if not found."""
    try:
        return APPS[key]
    except KeyError:
        raise SystemExit(
            f"Unknown app '{key}'. Expected one of: {', '.join(sorted(APPS.keys()))}"
        )
