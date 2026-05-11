#!/usr/bin/env python3
"""Build a cached vanilla Minecraft index for a target Java Edition version."""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
import zipfile
from pathlib import Path
from typing import Any


MANIFEST_URL = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"


def cache_root(path: str | None) -> Path:
    return Path(path).expanduser() if path else Path.home() / ".cache" / "minecraft-vanilla-harness"


def fetch_json(url: str) -> dict[str, Any]:
    with urllib.request.urlopen(url) as response:
        return json.load(response)


def resolve_version(version: str | None, latest_release: bool, latest_snapshot: bool) -> dict[str, Any]:
    manifest = fetch_json(MANIFEST_URL)
    if latest_release:
        version = manifest["latest"]["release"]
    elif latest_snapshot:
        version = manifest["latest"]["snapshot"]
    elif not version:
        version = manifest["latest"]["release"]
    for entry in manifest["versions"]:
        if entry["id"] == version:
            version_json = fetch_json(entry["url"])
            return {"manifest_entry": entry, "version_json": version_json}
    raise SystemExit(f"Minecraft version not found in Mojang manifest: {version}")


def download(url: str, path: Path, force: bool = False) -> None:
    if path.exists() and not force:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with urllib.request.urlopen(url) as response:
        tmp.write_bytes(response.read())
    tmp.replace(path)


def strip_asset_id(path: str, prefix: str, suffix: str) -> str | None:
    if not path.startswith(prefix) or not path.endswith(suffix):
        return None
    return path[len(prefix) : -len(suffix)]


def display_from_lang(lang: dict[str, str], kind: str, entry_id: str) -> str | None:
    return lang.get(f"{kind}.minecraft.{entry_id}")


def add_entry(table: dict[str, dict[str, Any]], entry_id: str, source: str, display: str | None) -> None:
    if "/" in entry_id:
        return
    row = table.setdefault(entry_id, {"id": entry_id, "sources": []})
    row["sources"].append(source)
    if display and "display_name" not in row:
        row["display_name"] = display


def build_index(version: str | None, cache: Path, latest_release: bool, latest_snapshot: bool, force: bool) -> Path:
    resolved = resolve_version(version, latest_release, latest_snapshot)
    manifest_entry = resolved["manifest_entry"]
    version_json = resolved["version_json"]
    version_id = manifest_entry["id"]
    jar_url = version_json["downloads"]["client"]["url"]
    version_dir = cache / version_id
    jar_path = version_dir / "client.jar"
    index_path = version_dir / "vanilla-index.json"
    if index_path.exists() and not force:
        return index_path
    download(jar_url, jar_path, force=force)

    lang: dict[str, str] = {}
    items: dict[str, dict[str, Any]] = {}
    blocks: dict[str, dict[str, Any]] = {}
    entities: dict[str, dict[str, Any]] = {}
    with zipfile.ZipFile(jar_path) as jar:
        names = jar.namelist()
        if "assets/minecraft/lang/en_us.json" in names:
            lang = json.loads(jar.read("assets/minecraft/lang/en_us.json").decode("utf-8"))
        for name in names:
            item_id = (
                strip_asset_id(name, "assets/minecraft/items/", ".json")
                or strip_asset_id(name, "assets/minecraft/models/item/", ".json")
                or strip_asset_id(name, "assets/minecraft/textures/item/", ".png")
            )
            if item_id:
                add_entry(items, item_id, name, display_from_lang(lang, "item", item_id))
            block_id = (
                strip_asset_id(name, "assets/minecraft/blockstates/", ".json")
                or strip_asset_id(name, "assets/minecraft/models/block/", ".json")
                or strip_asset_id(name, "assets/minecraft/textures/block/", ".png")
            )
            if block_id:
                add_entry(blocks, block_id, name, display_from_lang(lang, "block", block_id))
        for key, value in lang.items():
            match = re.match(r"^(item|block|entity)\.minecraft\.([a-z0-9_./-]+)$", key)
            if not match:
                continue
            kind, entry_id = match.groups()
            if "/" in entry_id:
                continue
            if kind == "item":
                add_entry(items, entry_id, f"lang:{key}", value)
            elif kind == "block":
                add_entry(blocks, entry_id, f"lang:{key}", value)
            elif kind == "entity":
                add_entry(entities, entry_id, f"lang:{key}", value)

    index = {
        "schema": 1,
        "version": version_id,
        "type": manifest_entry["type"],
        "release_time": manifest_entry["releaseTime"],
        "manifest_url": MANIFEST_URL,
        "version_url": manifest_entry["url"],
        "client_jar_url": jar_url,
        "counts": {"items": len(items), "blocks": len(blocks), "entities": len(entities)},
        "items": dict(sorted(items.items())),
        "blocks": dict(sorted(blocks.items())),
        "entities": dict(sorted(entities.items())),
    }
    version_dir.mkdir(parents=True, exist_ok=True)
    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return index_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", help="Minecraft Java version. Defaults to latest release.")
    parser.add_argument("--latest-release", action="store_true")
    parser.add_argument("--latest-snapshot", action="store_true")
    parser.add_argument("--cache-dir")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    path = build_index(
        version=args.version,
        cache=cache_root(args.cache_dir),
        latest_release=args.latest_release,
        latest_snapshot=args.latest_snapshot,
        force=args.force,
    )
    index = json.loads(path.read_text(encoding="utf-8"))
    print(json.dumps({"index": str(path), "version": index["version"], "counts": index["counts"]}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
