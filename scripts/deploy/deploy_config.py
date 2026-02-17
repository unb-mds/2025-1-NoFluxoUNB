"""
deploy_config.py — NoFluxo app configuration for local deploys.

This file defines the applications that can be deployed using deploy_local.py.
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

    key: str                # Short identifier used as CLI target (e.g. "backend")
    app_name: str           # Kubernetes deployment name
    namespace: str          # Kubernetes namespace (e.g. "non-business-apps")
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

    # --- App class (for node scheduling) ---
    app_class: str = "non-business"  # Route to non-business nodes


# ---------------------------------------------------------------------------
# NoFluxo Apps
# ---------------------------------------------------------------------------

APPS: dict[str, AppConfig] = {
    # ── Backend API ────────────────────────────────────────────────────────
    "backend": AppConfig(
        key="backend",
        app_name="nofluxo-backend",
        namespace="non-business-apps",
        image_name="nofluxo-backend",
        dockerfile="k8s.backend.Dockerfile",
        build_context=".",
        port=3325,
        replicas=1,
        health_path="/health",
        domain="api-nofluxo.crianex.com",
        app_class="non-business",
        deploy_env_keys=(
            "SUPABASE_URL",
            "SUPABASE_SERVICE_ROLE_KEY",
            "SUPABASE_ANON_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "PORT": "3325",
            "AI_AGENT_URL": "https://ai-nofluxo.crianex.com",
        },
    ),

    # ── AI Agent ───────────────────────────────────────────────────────────
    "ai-agent": AppConfig(
        key="ai-agent",
        app_name="nofluxo-ai-agent",
        namespace="non-business-apps",
        image_name="nofluxo-ai-agent",
        dockerfile="k8s.ai-agent.Dockerfile",
        build_context=".",
        port=4652,
        replicas=1,
        health_path="/health",
        domain="ai-nofluxo.crianex.com",
        app_class="non-business",
        deploy_env_keys=(
            "RAGFLOW_API_KEY",
            "RAGFLOW_URL",
            "SUPABASE_URL",
            "SUPABASE_ANON_KEY",
        ),
        deploy_env_static={
            "NODE_ENV": "production",
            "AI_AGENT_PORT": "4652",
        },
    ),
}


def get_app_config(key: str) -> AppConfig:
    """Get app config by key."""
    if key not in APPS:
        raise ValueError(f"Unknown app: {key}. Available: {list(APPS.keys())}")
    return APPS[key]
