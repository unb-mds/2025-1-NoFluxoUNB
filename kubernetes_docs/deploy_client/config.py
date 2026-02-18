from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True)
class Config:
    api_url: str
    api_key: str
    timeout_s: float


def load_config(api_url: str | None, api_key: str | None, timeout_s: float | None) -> Config:
    env_url = os.environ.get("DEPLOY_API_URL")
    env_key = os.environ.get("DEPLOY_API_KEY")
    env_timeout = os.environ.get("DEPLOY_API_TIMEOUT")

    final_url = (api_url or env_url or "").strip().rstrip("/")
    final_key = (api_key or env_key or "").strip()

    if timeout_s is not None:
        final_timeout = float(timeout_s)
    elif env_timeout:
        final_timeout = float(env_timeout)
    else:
        final_timeout = 30.0

    if not final_url:
        raise SystemExit("Missing DEPLOY_API_URL (or --api-url)")

    if not final_key:
        raise SystemExit("Missing DEPLOY_API_KEY (or --api-key)")

    return Config(api_url=final_url, api_key=final_key, timeout_s=final_timeout)
