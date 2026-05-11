#!/usr/bin/env python3
"""Scaffold a Minecraft mod project from a mod-spec and a web template."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print("+ " + " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def load_spec(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        data = json.loads(text)
    else:
        try:
            import yaml  # type: ignore
        except ImportError as exc:
            raise SystemExit("YAML spec requires PyYAML. Prefer JSON or install PyYAML.") from exc
        data = yaml.safe_load(text)
    if not isinstance(data, dict):
        raise SystemExit("Spec root must be an object.")
    return data


def validate_minimal(spec: dict[str, Any]) -> None:
    for key in ["mod_id", "display_name", "loader", "minecraft_version", "package"]:
        if not spec.get(key):
            raise SystemExit(f"Missing required spec field: {key}")
    if not ID_RE.match(str(spec["mod_id"])):
        raise SystemExit("mod_id must be lowercase snake_case.")
    if spec["loader"] not in {"fabric", "neoforge", "architectury"}:
        raise SystemExit("loader must be fabric, neoforge, or architectury.")


def git_repo_exists(url: str) -> bool:
    result = subprocess.run(
        ["git", "ls-remote", "--heads", "--tags", url],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def resolve_template_url(spec: dict[str, Any], explicit: str | None) -> str:
    if explicit:
        return explicit
    loader = str(spec["loader"])
    mc = str(spec["minecraft_version"])
    if loader == "fabric":
        return "https://github.com/FabricMC/fabric-example-mod.git"
    if loader == "neoforge":
        candidates = [
            f"https://github.com/NeoForgeMDKs/MDK-{mc}-ModDevGradle.git",
            f"https://github.com/NeoForgeMDKs/MDK-{mc}-NeoGradle.git",
            "https://github.com/NeoForgeMDKs/MDK-1.21-ModDevGradle.git",
        ]
        for candidate in candidates:
            if git_repo_exists(candidate):
                return candidate
        raise SystemExit(
            "Could not resolve an official NeoForge MDK automatically. "
            "Search NeoForgeMDKs and rerun with --template-url."
        )
    raise SystemExit("Architectury requires a current --template-url after checking official docs/template guidance.")


def replace_text(path: Path, replacements: dict[str, str]) -> None:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return
    original = text
    for old, new in replacements.items():
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")


def patch_common_template_values(project: Path, spec: dict[str, Any]) -> None:
    mod_id = str(spec["mod_id"])
    display = str(spec["display_name"])
    package = str(spec["package"])
    replacements = {
        "modid": mod_id,
        "examplemod": mod_id,
        "Example Mod": display,
        "ExampleMod": "".join(part.capitalize() for part in mod_id.split("_")),
        "com.example": package,
        "net.fabricmc.example": package,
    }
    for path in project.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".java", ".kt", ".json", ".toml", ".properties", ".gradle", ".md"}:
            replace_text(path, replacements)


def merge_move(source: Path, target: Path) -> None:
    if source == target:
        return
    if source.is_dir() and target.exists():
        for child in source.iterdir():
            merge_move(child, target / child.name)
        source.rmdir()
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()
    shutil.move(str(source), str(target))


def rename_template_paths(project: Path, spec: dict[str, Any]) -> None:
    mod_id = str(spec["mod_id"])
    replacements = {
        "modid": mod_id,
        "examplemod": mod_id,
    }
    for path in sorted(project.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        new_name = path.name
        for old, new in replacements.items():
            new_name = new_name.replace(old, new)
        if new_name != path.name:
            merge_move(path, path.with_name(new_name))


def relocate_source_files(project: Path) -> None:
    source_roots = [
        project / "src" / "main" / "java",
        project / "src" / "client" / "java",
        project / "common" / "src" / "main" / "java",
        project / "fabric" / "src" / "main" / "java",
        project / "neoforge" / "src" / "main" / "java",
    ]
    package_re = re.compile(r"^\s*package\s+([a-zA-Z_][\w.]*)\s*;", re.MULTILINE)
    public_type_re = re.compile(r"\bpublic\s+(?:final\s+|abstract\s+)?(?:class|interface|enum|record)\s+([A-Za-z_]\w*)")
    for root in source_roots:
        if not root.exists():
            continue
        for path in list(root.rglob("*.java")):
            text = path.read_text(encoding="utf-8")
            package_match = package_re.search(text)
            if not package_match:
                continue
            package_path = Path(*package_match.group(1).split("."))
            class_match = public_type_re.search(text)
            filename = f"{class_match.group(1)}.java" if class_match else path.name
            target = root / package_path / filename
            if target != path:
                merge_move(path, target)
        for directory in sorted(root.rglob("*"), key=lambda p: len(p.parts), reverse=True):
            if directory.is_dir() and not any(directory.iterdir()):
                directory.rmdir()


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def emit_assets(project: Path, spec: dict[str, Any]) -> None:
    mod_id = str(spec["mod_id"])
    res = project / "src" / "main" / "resources"
    assets = res / "assets" / mod_id
    data_root = res / "data" / mod_id
    lang: dict[str, str] = {}

    for item in spec.get("items", []) or []:
        item_id = item["id"]
        lang[f"item.{mod_id}.{item_id}"] = item.get("display_name", item_id)
        parent = "minecraft:item/handheld" if item.get("type") == "tool" else "minecraft:item/generated"
        write_json(
            assets / "models" / "item" / f"{item_id}.json",
            {"parent": parent, "textures": {"layer0": f"{mod_id}:item/{item_id}"}},
        )
        (assets / "textures" / "item").mkdir(parents=True, exist_ok=True)

    for block in spec.get("blocks", []) or []:
        block_id = block["id"]
        lang[f"block.{mod_id}.{block_id}"] = block.get("display_name", block_id)
        write_json(
            assets / "blockstates" / f"{block_id}.json",
            {"variants": {"": {"model": f"{mod_id}:block/{block_id}"}}},
        )
        write_json(
            assets / "models" / "block" / f"{block_id}.json",
            {"parent": "minecraft:block/cube_all", "textures": {"all": f"{mod_id}:block/{block_id}"}},
        )
        write_json(assets / "models" / "item" / f"{block_id}.json", {"parent": f"{mod_id}:block/{block_id}"})
        write_json(
            data_root / "loot_table" / "blocks" / f"{block_id}.json",
            {
                "type": "minecraft:block",
                "pools": [
                    {
                        "rolls": 1,
                        "entries": [{"type": "minecraft:item", "name": f"{mod_id}:{block_id}"}],
                        "conditions": [{"condition": "minecraft:survives_explosion"}],
                    }
                ],
            },
        )
        (assets / "textures" / "block").mkdir(parents=True, exist_ok=True)

    if lang:
        write_json(assets / "lang" / "en_us.json", dict(sorted(lang.items())))


def write_scaffold_metadata(project: Path, spec: dict[str, Any], template_url: str) -> None:
    write_json(project / ".minecraft-mod-spec.json", spec)
    note = {
        "template_source": template_url,
        "loader": spec["loader"],
        "minecraft_version": spec["minecraft_version"],
        "next_steps": [
            "Use minecraft-modding to add loader-specific registration code.",
            "Use minecraft-texture-replicate to generate PNG textures.",
            "Run Gradle datagen/build tasks available in this template.",
        ],
    }
    write_json(project / ".minecraft-scaffold.json", note)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, help="Path to mod-spec JSON/YAML.")
    parser.add_argument("--output", required=True, help="Output project directory.")
    parser.add_argument("--template-url", help="Git template URL. Required for Architectury.")
    parser.add_argument("--force", action="store_true", help="Delete output directory if it exists.")
    parser.add_argument("--skip-assets", action="store_true", help="Do not emit initial JSON resource assets.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    spec = load_spec(spec_path)
    validate_minimal(spec)
    template_url = resolve_template_url(spec, args.template_url)

    if output.exists():
        if not args.force:
            raise SystemExit(f"Output already exists: {output}. Use --force to replace it.")
        shutil.rmtree(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    run(["git", "clone", "--depth", "1", template_url, str(output)])
    git_dir = output / ".git"
    if git_dir.exists():
        shutil.rmtree(git_dir)

    patch_common_template_values(output, spec)
    rename_template_paths(output, spec)
    relocate_source_files(output)
    if not args.skip_assets:
        emit_assets(output, spec)
    write_scaffold_metadata(output, spec, template_url)
    print(json.dumps({"project": str(output), "template_source": template_url}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
