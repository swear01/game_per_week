#!/usr/bin/env python3
"""Validate a Minecraft mod-spec JSON file."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
PACKAGE_RE = re.compile(r"^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)+$")
LOADERS = {"fabric", "neoforge", "architectury"}
DEFAULT_MODEL_KINDS = {"default", "generated", "handheld", "cube_all"}
CUSTOM_MODEL_KINDS = {"java_elements", "custom_block", "custom_item", "blockbench", "geckolib", "entity"}


def load_spec(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return json.loads(text)
    try:
        import yaml  # type: ignore
    except ImportError as exc:
        raise SystemExit("YAML spec requires PyYAML. Prefer JSON or install PyYAML.") from exc
    data = yaml.safe_load(text)
    if not isinstance(data, dict):
        raise SystemExit("Spec root must be an object.")
    return data


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def validate(spec: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    for key in ["mod_id", "display_name", "loader", "minecraft_version", "package"]:
        require(errors, key in spec, f"Missing required field: {key}")

    mod_id = str(spec.get("mod_id", ""))
    loader = str(spec.get("loader", ""))
    package = str(spec.get("package", ""))
    require(errors, bool(ID_RE.match(mod_id)), "mod_id must be lowercase snake_case.")
    require(errors, loader in LOADERS, f"loader must be one of: {', '.join(sorted(LOADERS))}.")
    require(errors, bool(PACKAGE_RE.match(package)), "package must be a lowercase Java package like com.example.modid.")

    for collection in ["items", "blocks"]:
        value = spec.get(collection, [])
        require(errors, isinstance(value, list), f"{collection} must be an array.")
        if not isinstance(value, list):
            continue
        seen: set[str] = set()
        for index, entry in enumerate(value):
            prefix = f"{collection}[{index}]"
            require(errors, isinstance(entry, dict), f"{prefix} must be an object.")
            if not isinstance(entry, dict):
                continue
            entry_id = str(entry.get("id", ""))
            require(errors, bool(ID_RE.match(entry_id)), f"{prefix}.id must be lowercase snake_case.")
            require(errors, entry_id not in seen, f"Duplicate id in {collection}: {entry_id}")
            seen.add(entry_id)
            require(errors, bool(entry.get("display_name")), f"{prefix}.display_name is required.")
            require(errors, bool(entry.get("texture_prompt")), f"{prefix}.texture_prompt is required.")
            model = entry.get("model")
            if model is not None:
                require(errors, isinstance(model, dict), f"{prefix}.model must be an object.")
                if isinstance(model, dict):
                    kind = str(model.get("kind", ""))
                    require(errors, bool(kind), f"{prefix}.model.kind is required when model is present.")
                    require(
                        errors,
                        kind in DEFAULT_MODEL_KINDS | CUSTOM_MODEL_KINDS,
                        f"{prefix}.model.kind is not supported: {kind}",
                    )
                    if kind in {"java_elements", "custom_block", "custom_item"}:
                        elements = model.get("elements")
                        require(errors, isinstance(elements, list) and bool(elements), f"{prefix}.model.elements is required for {kind}.")
                        if isinstance(elements, list):
                            for element_index, element in enumerate(elements):
                                eprefix = f"{prefix}.model.elements[{element_index}]"
                                require(errors, isinstance(element, dict), f"{eprefix} must be an object.")
                                if isinstance(element, dict):
                                    require(errors, isinstance(element.get("from"), list) and len(element.get("from")) == 3, f"{eprefix}.from must be [x,y,z].")
                                    require(errors, isinstance(element.get("to"), list) and len(element.get("to")) == 3, f"{eprefix}.to must be [x,y,z].")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_spec.py <mod-spec.json>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1]).expanduser()
    spec = load_spec(path)
    errors = validate(spec)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Spec is valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
