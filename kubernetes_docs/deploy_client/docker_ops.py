from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class CommandError(RuntimeError):
    cmd: list[str]
    exit_code: int
    stdout: str
    stderr: str


def run_cmd(cmd: list[str], *, cwd: Path | None = None) -> None:
    completed = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        text=True,
        capture_output=True,
    )
    if completed.returncode != 0:
        raise CommandError(
            cmd=cmd,
            exit_code=completed.returncode,
            stdout=completed.stdout or "",
            stderr=completed.stderr or "",
        )


def docker_build(
    docker_bin: str,
    *,
    image_ref: str,
    context_dir: str,
    dockerfile: str,
    build_args: Iterable[str] | None = None,
) -> None:
    cmd: list[str] = [docker_bin, "build", "-t", image_ref, "-f", dockerfile]
    if build_args:
        for arg in build_args:
            cmd.extend(["--build-arg", arg])
    cmd.append(context_dir)
    run_cmd(cmd)


def docker_push(docker_bin: str, *, image_ref: str) -> None:
    run_cmd([docker_bin, "push", image_ref])
