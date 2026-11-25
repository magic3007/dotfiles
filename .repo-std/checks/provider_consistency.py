#!/usr/bin/env python3
"""A gateway is stated once, in .repo-std/providers.yml.

The same gateway is configured in several harnesses, and each harness joins its
base URL to a different path: an anthropic-messages client appends
`/v1/messages` (so its base has no `/v1`), while mcode's AI SDK appends
`/messages` and codex appends `/responses` (so theirs keep it). A base URL
copied between harnesses is therefore either wrong or silently tolerated —
omp strips a trailing `/v1` before joining, Pi does not.

This check holds every provider entry whose URL points at a manifest host to
two things: the manifest's URL for that file, and the manifest's credential
written in the reference style its file's tool expands (docs/REPO_GUIDE.md §3,
credentials row). A file absent from the tree is skipped, so the check also
runs on the minimal fixture.
"""

from __future__ import annotations

import json
import sys
import tomllib
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))

from _lib import report, repo_root  # noqa: E402

MANIFEST = ".repo-std/providers.yml"


def _grep_reference(var: str) -> str:
    """omp and its gateway plugin run `!command`, so the key is read at use."""
    return (
        f"!grep -m1 '^export {var}=' $HOME/.common_shell_setup_local.sh"
        " | cut -d= -f2- | tr -d '\"'"
    )


# file -> how that tool writes a credential reference around the variable name.
STYLES = {
    "omp/models.yml": _grep_reference,
    "omp/gateways-login.json": _grep_reference,
    "pi/models.json": lambda var: f"${var}",
    "mcode/config.yaml": lambda var: f"${{{var}}}",
    "codex/config.toml": lambda var: var,
}


def _omp_models(root: Path):
    data = yaml.safe_load((root / "omp/models.yml").read_text(encoding="utf-8")) or {}
    for name, provider in (data.get("providers") or {}).items():
        yield name, provider.get("baseUrl"), provider.get("apiKey")


def _omp_gateways(root: Path):
    data = json.loads((root / "omp/gateways-login.json").read_text(encoding="utf-8"))
    for provider in data.get("providers") or []:
        yield provider.get("name"), provider.get("baseUrl"), provider.get("apiKey")


def _pi(root: Path):
    data = json.loads((root / "pi/models.json").read_text(encoding="utf-8"))
    for name, provider in (data.get("providers") or {}).items():
        yield name, provider.get("baseUrl"), provider.get("apiKey")


def _mcode(root: Path):
    data = yaml.safe_load((root / "mcode/config.yaml").read_text(encoding="utf-8")) or {}
    for name, provider in (data.get("custom_provider") or {}).items():
        options = provider.get("options") or {}
        yield name, options.get("baseURL"), options.get("apiKey")


def _codex(root: Path):
    data = tomllib.loads((root / "codex/config.toml").read_text(encoding="utf-8"))
    for name, provider in (data.get("model_providers") or {}).items():
        yield name, provider.get("base_url"), provider.get("env_key")


LOADERS = {
    "omp/models.yml": _omp_models,
    "omp/gateways-login.json": _omp_gateways,
    "pi/models.json": _pi,
    "mcode/config.yaml": _mcode,
    "codex/config.toml": _codex,
}


def _gateway_of(manifest: dict, url: str) -> tuple[str, dict] | None:
    """The manifest entry whose host this URL sits under, if any."""
    bare = url.rstrip("/")
    for name, spec in manifest.items():
        host = spec["host"].rstrip("/")
        if bare == host or bare.startswith(host + "/"):
            return name, spec
    return None


def main() -> int:
    root = repo_root(sys.argv[1:])
    path = root / MANIFEST
    if not path.is_file():
        return report(
            [f"{MANIFEST}: missing — the gateway manifest is the source of truth"],
            f"{MANIFEST} is the source of truth",
        )
    manifest = (yaml.safe_load(path.read_text(encoding="utf-8")) or {}).get("providers") or {}

    violations: list[str] = []
    checked = 0
    for rel, load in LOADERS.items():
        if not (root / rel).is_file():
            continue
        for name, url, credential in load(root):
            if not url:
                continue
            found = _gateway_of(manifest, url)
            if found is None:
                continue
            gateway, spec = found
            checked += 1

            expected_url = (spec.get("urls") or {}).get(rel, spec["host"])
            if url.rstrip("/") != expected_url.rstrip("/"):
                violations.append(
                    f"{rel}: gateway {gateway} provider {name}: base URL {url} — "
                    f"{rel} takes {expected_url} as stated in {MANIFEST}"
                )

            expected_credential = STYLES[rel](spec["credential"])
            if credential != expected_credential:
                violations.append(
                    f"{rel}: gateway {gateway} provider {name}: credential {credential!r} — "
                    f"this file takes {expected_credential!r}"
                )

    return report(
        violations,
        f"{checked} gateway provider definition(s) agree with {MANIFEST}",
    )


if __name__ == "__main__":
    raise SystemExit(main())
