from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from .api import DeployApiClient, ApiError
from .buildid_store import BuildIdState, load_state, save_state, DEFAULT_PATH
from .config import load_config
from .docker_ops import CommandError, docker_build, docker_push


def _parse_env_list(pairs: list[str] | None) -> dict[str, str] | None:
    if not pairs:
        return None
    env: dict[str, str] = {}
    for item in pairs:
        if "=" not in item:
            raise SystemExit(f"Invalid --env entry (expected KEY=VALUE): {item}")
        key, value = item.split("=", 1)
        key = key.strip()
        if not key:
            raise SystemExit(f"Invalid --env key: {item}")
        env[key] = value
    return env


def _split_domains(domains: str | None) -> list[str] | None:
    if not domains:
        return None
    parts = [d.strip() for d in domains.split(",")]
    parts = [d for d in parts if d]
    return parts or None


def _parse_image_tag_from_image(image: str) -> tuple[str | None, str | None]:
    # Expected: <registry>/<name>:<tag>
    # If it contains '@', it's already a digest reference.
    if "@" in image:
        return None, None

    # Split from the right-most ':' which should separate the tag.
    if ":" not in image:
        return None, None

    name_and_tag = image.rsplit("/", 1)[-1]
    if ":" not in name_and_tag:
        return None, None

    _, tag = name_and_tag.rsplit(":", 1)

    # Also extract the image name without registry.
    # <registry>/<imageName>:<tag> -> <imageName>
    without_tag = image.rsplit(":", 1)[0]
    image_name = without_tag.split("/", 1)[1] if "/" in without_tag else None

    return image_name, tag


def _build_deploy_config_from_args(args: argparse.Namespace) -> dict[str, object]:
    if args.port is None:
        raise SystemExit("Missing --port (deployConfig requires port or ports)")

    deploy_config: dict[str, object] = {
        "port": int(args.port),
        "replicas": int(args.replicas),
        "healthPath": args.health_path,
        "tls": not args.no_tls,
        "appClass": getattr(args, "app_class", "business") or "business",
    }

    domains = _split_domains(args.domains)
    if domains:
        deploy_config["domains"] = domains
    elif args.domain:
        deploy_config["domain"] = args.domain

    env = _parse_env_list(args.env)
    if env:
        deploy_config["env"] = env

    return deploy_config


def _start_reuse_deploy(
    client: DeployApiClient,
    *,
    app: str,
    namespace: str,
    image_name: str | None,
    build_id: str,
    deploy_config: dict[str, object],
) -> dict[str, object]:
    payload: dict[str, object] = {
        "app": app,
        "namespace": namespace,
        "buildId": build_id,
        "deploy": True,
        "deployConfig": deploy_config,
    }

    if image_name:
        payload["imageName"] = image_name

    return client.start_build(payload)


def cmd_build(args: argparse.Namespace) -> int:
    cfg = load_config(args.api_url, args.api_key, args.timeout)
    client = DeployApiClient(cfg.api_url, cfg.api_key, timeout_s=cfg.timeout_s)

    payload: dict[str, object] = {
        "app": args.app,
        "namespace": args.namespace,
        "repoUrl": args.repo_url,
        "gitRef": args.git_ref,
        "dockerfile": args.dockerfile,
        "buildContext": args.build_context,
        "cache": not args.no_cache,
        "deploy": False,
    }

    if args.git_token:
        payload["gitToken"] = args.git_token
    if args.image_name:
        payload["imageName"] = args.image_name
    if args.image_tag:
        payload["imageTag"] = args.image_tag

    try:
        start = client.start_build(payload)
    except ApiError as e:
        print(f"ERROR {e.status_code} calling {e.url}:\n{e.body}", file=sys.stderr)
        return 2

    print(json.dumps(start, indent=2, sort_keys=True))

    job_name = start.get("jobName") if isinstance(start, dict) else None
    image = start.get("image") if isinstance(start, dict) else None

    if not args.wait:
        return 0

    if not job_name or not isinstance(job_name, str):
        print("ERROR: start build did not return jobName; cannot wait", file=sys.stderr)
        return 2

    try:
        wait_res = client.wait_build(job_name, timeout_s=args.wait_timeout)
    except ApiError as e:
        print(f"ERROR {e.status_code} waiting for build {job_name}:\n{e.body}", file=sys.stderr)
        return 2

    print(json.dumps(wait_res, indent=2, sort_keys=True))

    # Resolve digest for the tag we built.
    image_name = args.image_name
    image_tag = args.image_tag

    if isinstance(image, str) and (not image_name or not image_tag):
        inferred_name, inferred_tag = _parse_image_tag_from_image(image)
        image_name = image_name or inferred_name
        image_tag = image_tag or inferred_tag

    if not image_name or not image_tag:
        print(
            "ERROR: could not determine imageName/imageTag to resolve digest. "
            "Pass --image-name and --image-tag explicitly.",
            file=sys.stderr,
        )
        return 2

    try:
        build_id = client.resolve_digest(image_name, image_tag)
    except ApiError as e:
        print(f"ERROR {e.status_code} resolving digest for {image_name}:{image_tag}:\n{e.body}", file=sys.stderr)
        return 2

    state = BuildIdState(
        repoUrl=args.repo_url,
        gitRef=args.git_ref,
        app=args.app,
        namespace=args.namespace,
        imageName=image_name,
        imageTag=image_tag,
        buildId=build_id,
    )

    path = Path(args.state_file) if args.state_file else DEFAULT_PATH
    save_state(state, path)

    print(f"Saved buildId to {path}: {build_id}")
    return 0


def cmd_reuse_deploy(args: argparse.Namespace) -> int:
    cfg = load_config(args.api_url, args.api_key, args.timeout)
    client = DeployApiClient(cfg.api_url, cfg.api_key, timeout_s=cfg.timeout_s)

    path = Path(args.state_file) if args.state_file else DEFAULT_PATH
    state = None
    if not args.build_id or not args.image_name or not args.app or not args.namespace:
        try:
            state = load_state(path)
        except FileNotFoundError:
            state = None

    app = args.app or (state.app if state else None)
    namespace = args.namespace or (state.namespace if state else None)
    image_name = args.image_name or (state.imageName if state else None)
    build_id = args.build_id or (state.buildId if state else None)

    if not app:
        raise SystemExit("Missing --app (or state file app)")
    if not namespace:
        raise SystemExit("Missing --namespace (or state file namespace)")
    if not build_id:
        raise SystemExit("Missing --build-id (or state file buildId)")

    deploy_config = _build_deploy_config_from_args(args)

    try:
        res = _start_reuse_deploy(
            client,
            app=app,
            namespace=namespace,
            image_name=image_name,
            build_id=build_id,
            deploy_config=deploy_config,
        )
    except ApiError as e:
        print(f"ERROR {e.status_code} calling {e.url}:\n{e.body}", file=sys.stderr)
        return 2

    print(json.dumps(res, indent=2, sort_keys=True))
    return 0


def cmd_local_deploy(args: argparse.Namespace) -> int:
    cfg = load_config(args.api_url, args.api_key, args.timeout)
    client = DeployApiClient(cfg.api_url, cfg.api_key, timeout_s=cfg.timeout_s)

    image_name = args.image_name or args.app
    tag = args.image_tag or f"local-{int(time.time())}"
    image_ref = f"{args.registry.rstrip('/')}/{image_name}:{tag}"

    try:
        docker_build(
            args.docker,
            image_ref=image_ref,
            context_dir=args.context,
            dockerfile=args.dockerfile,
            build_args=args.build_arg,
        )
        if not args.no_push:
            docker_push(args.docker, image_ref=image_ref)
    except CommandError as e:
        print(
            "ERROR running local container build/push. "
            "Ensure Docker is installed and you are logged in to the registry (e.g. `docker login`).",
            file=sys.stderr,
        )
        print(f"Command: {' '.join(e.cmd)}\nExit code: {e.exit_code}", file=sys.stderr)
        if e.stdout:
            print(f"--- stdout ---\n{e.stdout}", file=sys.stderr)
        if e.stderr:
            print(f"--- stderr ---\n{e.stderr}", file=sys.stderr)
        return 2

    try:
        build_id = client.resolve_digest(image_name, tag)
    except ApiError as e:
        print(f"ERROR {e.status_code} resolving digest for {image_name}:{tag}:\n{e.body}", file=sys.stderr)
        return 2

    state = BuildIdState(
        repoUrl=None,
        gitRef=None,
        app=args.app,
        namespace=args.namespace,
        imageName=image_name,
        imageTag=tag,
        buildId=build_id,
    )

    path = Path(args.state_file) if args.state_file else DEFAULT_PATH
    save_state(state, path)

    deploy_config = _build_deploy_config_from_args(args)

    try:
        res = _start_reuse_deploy(
            client,
            app=args.app,
            namespace=args.namespace,
            image_name=image_name,
            build_id=build_id,
            deploy_config=deploy_config,
        )
    except ApiError as e:
        print(f"ERROR {e.status_code} calling {e.url}:\n{e.body}", file=sys.stderr)
        return 2

    print(json.dumps(res, indent=2, sort_keys=True))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="deploy_client", description="Deploy API helper (buildId reuse)")
    parser.add_argument("--api-url", default=None, help="Deploy API base URL (or DEPLOY_API_URL)")
    parser.add_argument("--api-key", default=None, help="Deploy API key (or DEPLOY_API_KEY)")
    parser.add_argument("--timeout", type=float, default=None, help="HTTP timeout seconds (or DEPLOY_API_TIMEOUT)")
    parser.add_argument("--state-file", default=None, help=f"State file path (default: {DEFAULT_PATH})")

    sub = parser.add_subparsers(dest="command", required=True)

    p_build = sub.add_parser("build", help="Trigger a Kaniko build and store buildId")
    p_build.add_argument("--app", required=True)
    p_build.add_argument("--namespace", default="default")
    p_build.add_argument("--repo-url", required=True)
    p_build.add_argument("--git-ref", default="main")
    p_build.add_argument("--git-token", default=None)
    p_build.add_argument("--dockerfile", default="Dockerfile")
    p_build.add_argument("--build-context", default=".")
    p_build.add_argument("--image-name", default=None)
    p_build.add_argument("--image-tag", default=None)
    p_build.add_argument("--no-cache", action="store_true")
    p_build.add_argument("--app-class", default="business", choices=["business", "non-business"],
                         help="Workload class: business (default) or non-business")
    p_build.add_argument("--wait", action=argparse.BooleanOptionalAction, default=True)
    p_build.add_argument("--wait-timeout", type=int, default=1800)
    p_build.set_defaults(func=cmd_build)

    p_reuse = sub.add_parser("reuse-deploy", help="Deploy using an existing buildId (skip Kaniko)")
    p_reuse.add_argument("--app", default=None)
    p_reuse.add_argument("--namespace", default=None)
    p_reuse.add_argument("--image-name", default=None)
    p_reuse.add_argument("--build-id", default=None)
    p_reuse.add_argument("--port", type=int, required=False)
    p_reuse.add_argument("--replicas", type=int, default=1)
    p_reuse.add_argument("--domain", default=None)
    p_reuse.add_argument("--domains", default=None, help="Comma-separated list")
    p_reuse.add_argument("--health-path", default="/health")
    p_reuse.add_argument("--no-tls", action="store_true")
    p_reuse.add_argument("--app-class", default="business", choices=["business", "non-business"],
                         help="Workload class: business (default) or non-business")
    p_reuse.add_argument("--env", action="append", default=None, help="Repeatable KEY=VALUE")
    p_reuse.set_defaults(func=cmd_reuse_deploy)

    p_local = sub.add_parser("local-deploy", help="Build locally, push to registry, then deploy via buildId")
    p_local.add_argument("--app", required=True)
    p_local.add_argument("--namespace", default="default")
    p_local.add_argument(
        "--registry",
        default=None,
        help="Registry host (or DEPLOY_REGISTRY; default registry.kubernetes.crianex.com)",
    )
    p_local.add_argument("--docker", default="docker", help="Docker CLI binary (default: docker)")
    p_local.add_argument("--context", default=".", help="Build context directory (default: .)")
    p_local.add_argument("--dockerfile", default="Dockerfile", help="Dockerfile path (default: Dockerfile)")
    p_local.add_argument("--build-arg", action="append", default=None, help="Repeatable KEY=VALUE")
    p_local.add_argument("--image-name", default=None, help="Image name in registry (default: app)")
    p_local.add_argument("--image-tag", default=None, help="Image tag to push (default: local-<timestamp>)")
    p_local.add_argument("--no-push", action="store_true", help="Build but do not push")
    p_local.add_argument("--port", type=int, required=False)
    p_local.add_argument("--replicas", type=int, default=1)
    p_local.add_argument("--domain", default=None)
    p_local.add_argument("--domains", default=None, help="Comma-separated list")
    p_local.add_argument("--health-path", default="/health")
    p_local.add_argument("--no-tls", action="store_true")
    p_local.add_argument("--app-class", default="business", choices=["business", "non-business"],
                         help="Workload class: business (default) or non-business")
    p_local.add_argument("--env", action="append", default=None, help="Repeatable KEY=VALUE")
    p_local.set_defaults(func=cmd_local_deploy)

    args = parser.parse_args(argv)
    if getattr(args, "registry", None) is None and getattr(args, "command", None) == "local-deploy":
        import os

        args.registry = os.environ.get("DEPLOY_REGISTRY") or "registry.kubernetes.crianex.com"
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
