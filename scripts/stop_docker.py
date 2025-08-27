#!/usr/bin/env python3
"""
Stop the running project in Docker.

This script searches for a docker-compose file starting from its own location
and moving up the directory tree until it finds one. Once found, it will
attempt to stop the project using Docker Compose. It supports both the legacy
`docker-compose` and the newer `docker compose` subcommand.

Usage:
  - Default (graceful stop and remove containers):
      python scripts/stop_docker.py

  - Stop containers without removing them (compose stop):
      python scripts/stop_docker.py --mode stop

  - Force remove with volumes and orphans:
      python scripts/stop_docker.py --mode down --with-volumes --remove-orphans
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple


COMPOSE_FILENAMES = (
    "docker-compose.yml",
    "docker-compose.yaml",
)


def find_repo_root_with_compose(start_dir: Path) -> Optional[Tuple[Path, str]]:
    """Walk up from start_dir to find a directory containing a compose file.

    Returns a tuple of (directory_path, compose_filename) or None if not found.
    """
    current = start_dir.resolve()
    while True:
        for name in COMPOSE_FILENAMES:
            candidate = current / name
            if candidate.is_file():
                return current, name

        if current.parent == current:
            # Reached filesystem root
            return None
        current = current.parent


def which(cmd: str) -> Optional[str]:
    """A tiny wrapper for shutil.which without importing it globally."""
    from shutil import which as _which

    return _which(cmd)


def build_compose_commands(mode: str, with_volumes: bool, remove_orphans: bool) -> List[List[str]]:
    """Build a list of candidate compose commands to try, in order.

    We try legacy `docker-compose` first to match existing project docs/scripts,
    then fall back to `docker compose`.
    """
    base_args: List[str] = [mode]
    if mode == "down":
        if with_volumes:
            base_args.append("-v")
        if remove_orphans:
            base_args.append("--remove-orphans")

    cmds: List[List[str]] = []

    if which("docker-compose"):
        cmds.append(["docker-compose", *base_args])

    if which("docker"):
        # Prefer plugin subcommand if docker is available
        cmds.append(["docker", "compose", *base_args])

    return cmds


def run_command(cmd: List[str], cwd: Path) -> int:
    """Run a command and stream output to the terminal, returning exit code."""
    print(f"$ {' '.join(cmd)} (cwd={cwd})")
    try:
        proc = subprocess.run(cmd, cwd=str(cwd), check=False)
        return proc.returncode
    except FileNotFoundError:
        return 127
    except KeyboardInterrupt:
        print("Interrupted by user.")
        return 130


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Stop the running project in Docker")
    parser.add_argument(
        "--mode",
        choices=["down", "stop"],
        default="down",
        help="Use 'down' to stop and remove containers (default) or 'stop' to stop without removing.",
    )
    parser.add_argument(
        "--with-volumes",
        action="store_true",
        help="When using --mode down, also remove named and anonymous volumes (-v).",
    )
    parser.add_argument(
        "--remove-orphans",
        action="store_true",
        help="When using --mode down, remove containers for services not defined in the Compose file.",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)

    # Start search from this script's directory
    script_dir = Path(__file__).resolve().parent
    found = find_repo_root_with_compose(script_dir)
    if not found:
        print("Error: Could not find docker-compose.yml or docker-compose.yaml in this repository.")
        print("Hint: Ensure you run this from within the project and that the compose file exists at the root.")
        return 2

    repo_root, compose_filename = found
    os.environ.setdefault("COMPOSE_FILE", str(repo_root / compose_filename))

    commands = build_compose_commands(
        mode=args.mode, with_volumes=args.with_volumes, remove_orphans=args.remove_orphans
    )

    if not commands:
        print("Error: Neither 'docker-compose' nor 'docker' was found in PATH.")
        print("Install Docker Desktop and ensure the CLI is available.")
        return 127

    print(f"Found compose file: {repo_root / compose_filename}")
    print(f"Using mode: {args.mode}")

    last_code = 1
    for cmd in commands:
        code = run_command(cmd, cwd=repo_root)
        last_code = code
        if code == 0:
            # Success
            action_desc = "stopped and removed" if args.mode == "down" else "stopped"
            print(f"Success: Docker services {action_desc} for project at {repo_root}.")
            return 0
        else:
            print(f"Command failed with exit code {code}: {' '.join(cmd)}")

    print("All stop attempts failed. See output above for details.")
    return last_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))





