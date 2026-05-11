#!/usr/bin/env python3
"""Download and cache a vanilla Minecraft Java texture PNG for a given version.

Primary source: InventivetalentDev/minecraft-assets tags matching minecraft_version.
Fallback: objects inside ~/.cache/minecraft-vanilla-harness/<version>/client.jar (no assets path in thin jar — try assets index if present).

Prints absolute path to cached PNG on success (single line, no extra noise).
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path


def cache_root() -> Path:
    return Path.home() / ".cache" / "minecraft-texture-replicate" / "vanilla"


def github_raw_url(version: str, namespace: str, texture_rel: str) -> str:
    rel = texture_rel.removeprefix("/").removesuffix(".png")
    path = f"assets/{namespace}/textures/{rel}.png"
    return f"https://raw.githubusercontent.com/InventivetalentDev/minecraft-assets/{version}/{path}"


def fetch_github(version: str, namespace: str, texture_rel: str, dest: Path) -> bool:
    url = github_raw_url(version, namespace, texture_rel)
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "minecraft-texture-replicate/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            if resp.status != 200:
                return False
            dest.write_bytes(resp.read())
        return dest.exists() and dest.stat().st_size > 0
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError):
        return False


def try_jar_assets(version: str, namespace: str, texture_rel: str, dest: Path) -> bool:
    jar = Path.home() / ".cache" / "minecraft-vanilla-harness" / version / "client.jar"
    if not jar.is_file():
        return False
    rel = texture_rel.removeprefix("/").removesuffix(".png")
    entry = f"assets/{namespace}/textures/{rel}.png"
    try:
        with zipfile.ZipFile(jar) as jar_zip:
            if entry not in jar_zip.namelist():
                return False
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(jar_zip.read(entry))
        return dest.stat().st_size > 0
    except (zipfile.BadZipFile, KeyError, OSError):
        return False


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--version", required=True, help="Minecraft Java version, e.g. 1.21.1")
    p.add_argument("--namespace", default="minecraft", help="Asset namespace, default minecraft")
    p.add_argument(
        "--texture-rel",
        required=True,
        help="Path under textures/, with or without .png (e.g. entity/zombie/zombie)",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()
    rel = str(args.texture_rel).strip().removesuffix(".png")
    version = str(args.version).strip()
    ns = str(args.namespace).strip()
    dest = cache_root() / version / ns / "textures" / f"{rel}.png"

    if dest.is_file():
        print(dest.resolve(), flush=True)
        return 0
    if fetch_github(version, ns, rel, dest):
        print(dest.resolve(), flush=True)
        return 0
    if try_jar_assets(version, ns, rel, dest):
        print(dest.resolve(), flush=True)
        return 0
    print(f"No vanilla texture found for {ns}:textures/{rel} at version {version}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
