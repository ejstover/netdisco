#!/usr/bin/env python3
"""Quickstart helper for running Netdisco in Docker from a forked repo.

This script automates the steps described in the Netdisco documentation for
building the container stack from a fork or feature branch.  It will:

1. Clone or update the ``netdisco-docker`` packaging repository.
2. Clone or update your fork of ``netdisco``.
3. Build the images with Docker Compose, pointing the build to your branch.
4. Start the stack with ``docker compose up``.

The script assumes that ``docker`` (with Compose v2), ``git`` and ``python``
are installed on the host running it.  It also assumes that the Dockerfiles in
``netdisco-docker`` honour the ``COMMITTISH`` and ``GIT_URL`` build arguments.
If your local checkout of ``netdisco-docker`` diverges from upstream, adjust
``DEFAULT_PACKAGING_REPO`` below as needed.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List

DEFAULT_PACKAGING_REPO = "https://github.com/netdisco/netdisco-docker.git"
DEFAULT_BRANCH = "main"
DEFAULT_WORKSPACE = Path.home() / "netdisco-docker-workspace"


class CommandError(RuntimeError):
    """Raised when an external command fails."""


def run_command(cmd: Iterable[str], cwd: Path | None = None) -> None:
    """Run ``cmd`` and raise ``CommandError`` if it fails."""

    process = subprocess.run(cmd, cwd=cwd, check=False)
    if process.returncode != 0:
        joined = " ".join(cmd)
        raise CommandError(f"Command failed ({process.returncode}): {joined}")


def ensure_repo(url: str, destination: Path, branch: str) -> None:
    """Clone ``url`` into ``destination`` or update it if it already exists."""

    if destination.exists():
        print(f"Updating repository in {destination}")
        run_command(["git", "fetch", "--all"], cwd=destination)
        run_command(["git", "checkout", branch], cwd=destination)
        run_command(["git", "pull", "--ff-only"], cwd=destination)
    else:
        print(f"Cloning {url} into {destination}")
        run_command(["git", "clone", "--branch", branch, url, str(destination)])


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-url",
        required=True,
        help="HTTPS or SSH URL for your netdisco fork",
    )
    parser.add_argument(
        "--branch",
        default=DEFAULT_BRANCH,
        help="Branch name in your fork to build (default: %(default)s)",
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=DEFAULT_WORKSPACE,
        help="Directory to store the cloned repositories",
    )
    parser.add_argument(
        "--packaging-url",
        default=DEFAULT_PACKAGING_REPO,
        help="Alternate netdisco-docker repository URL",
    )
    parser.add_argument(
        "--compose-services",
        nargs="*",
        default=["netdisco-backend", "netdisco-web"],
        help="Services to pass to 'docker compose build' (default: %(default)s)",
    )
    parser.add_argument(
        "--no-start",
        action="store_true",
        help="Do not run 'docker compose up -d' after building",
    )
    return parser.parse_args(argv)


def build_and_run(
    packaging_dir: Path,
    compose_services: Iterable[str],
    branch: str,
    repo_url: str,
    start_after_build: bool,
) -> None:
    compose_cmd = [
        "docker",
        "compose",
        "build",
        "--build-arg",
        f"COMMITTISH={branch}",
        "--build-arg",
        f"GIT_URL={repo_url}",
    ]
    compose_cmd.extend(compose_services)
    print("Building Docker images…")
    run_command(compose_cmd, cwd=packaging_dir)

    if start_after_build:
        up_cmd = ["docker", "compose", "up", "-d"]
        print("Starting Docker stack…")
        run_command(up_cmd, cwd=packaging_dir)
        print("Stack started. Use 'docker compose logs -f' to watch output.")
    else:
        print("Build complete. Skipping 'docker compose up' as requested.")


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    workspace = args.workspace.expanduser().resolve()
    workspace.mkdir(parents=True, exist_ok=True)

    packaging_dir = workspace / "netdisco-docker"
    fork_dir = workspace / "netdisco"

    try:
        ensure_repo(args.packaging_url, packaging_dir, "main")
        ensure_repo(args.repo_url, fork_dir, args.branch)
        build_and_run(
            packaging_dir,
            args.compose_services,
            args.branch,
            args.repo_url,
            start_after_build=not args.no_start,
        )
    except CommandError as exc:
        print(exc, file=sys.stderr)
        return 1
    except FileNotFoundError as exc:
        print(
            f"Required executable not found: {exc}. Please install git and docker.",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
