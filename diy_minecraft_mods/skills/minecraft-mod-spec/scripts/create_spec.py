#!/usr/bin/env python3
"""Create a starter Minecraft mod-spec JSON file."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_asset(value: str) -> dict[str, object]:
    parts = value.split(":", 2)
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("Use id:Display Name:texture prompt")
    asset_id, display_name, prompt = parts
    return {
        "id": asset_id,
        "display_name": display_name,
        "type": "basic",
        "texture_prompt": prompt,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mod-id", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--loader", choices=["fabric", "neoforge", "architectury"], default="fabric")
    parser.add_argument("--minecraft-version", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--texture-size", type=int, default=32)
    parser.add_argument("--item", action="append", type=parse_asset, default=[], metavar="id:Name:prompt")
    parser.add_argument("--block", action="append", type=parse_asset, default=[], metavar="id:Name:prompt")
    parser.add_argument("--output", default="mod-spec.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    items = []
    for item in args.item:
        item["transparent_texture"] = True
        items.append(item)
    blocks = []
    for block in args.block:
        block["material_hint"] = "stone"
        block["loot"] = {"drops_self": True}
        blocks.append(block)
    spec = {
        "mod_id": args.mod_id,
        "display_name": args.display_name,
        "loader": args.loader,
        "minecraft_version": args.minecraft_version,
        "package": args.package,
        "java_version": 21,
        "texture_size": args.texture_size,
        "items": items,
        "blocks": blocks,
    }
    path = Path(args.output).expanduser()
    path.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
