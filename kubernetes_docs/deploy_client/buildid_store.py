from __future__ import annotations

import json
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


DEFAULT_PATH = Path(".deploy") / "build-id.json"


@dataclass
class BuildIdState:
    repoUrl: str | None = None
    gitRef: str | None = None
    app: str | None = None
    namespace: str | None = None
    imageName: str | None = None
    imageTag: str | None = None
    buildId: str | None = None


def load_state(path: Path = DEFAULT_PATH) -> BuildIdState:
    if not path.exists():
        raise FileNotFoundError(str(path))
    raw = json.loads(path.read_text("utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("State file is not a JSON object")
    return BuildIdState(
        repoUrl=raw.get("repoUrl"),
        gitRef=raw.get("gitRef"),
        app=raw.get("app"),
        namespace=raw.get("namespace"),
        imageName=raw.get("imageName"),
        imageTag=raw.get("imageTag"),
        buildId=raw.get("buildId"),
    )


def save_state(state: BuildIdState, path: Path = DEFAULT_PATH) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data: dict[str, Any] = asdict(state)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", "utf-8")
