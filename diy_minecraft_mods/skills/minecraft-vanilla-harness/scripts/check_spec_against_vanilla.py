#!/usr/bin/env python3
"""Check a mod-spec against vanilla Minecraft items, blocks, entities, and display names."""

from __future__ import annotations

import argparse
import difflib
import importlib.util
import json
import re
import sys
from pathlib import Path
from typing import Any


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


def build_index_path(version: str, cache_dir: str | None, force: bool) -> Path:
    module_path = Path(__file__).with_name("build_vanilla_index.py")
    spec = importlib.util.spec_from_file_location("build_vanilla_index", module_path)
    if not spec or not spec.loader:
        raise SystemExit("Could not load build_vanilla_index.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.build_index(version=version, cache=module.cache_root(cache_dir), latest_release=False, latest_snapshot=False, force=force)


def normalize_name(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def vanilla_names(table: dict[str, dict[str, Any]]) -> dict[str, str]:
    out: dict[str, str] = {}
    for entry_id, row in table.items():
        display = row.get("display_name")
        if display:
            out[normalize_name(display)] = entry_id
    return out


def check_collection(spec: dict[str, Any], index: dict[str, Any], collection: str) -> list[dict[str, Any]]:
    spec_key = "items" if collection == "item" else "blocks"
    table_key = "items" if collection == "item" else "blocks"
    table = index[table_key]
    display_map = vanilla_names(table)
    display_names = list(display_map.keys())
    findings: list[dict[str, Any]] = []
    for entry in spec.get(spec_key, []) or []:
        entry_id = str(entry.get("id", ""))
        display = str(entry.get("display_name", entry_id))
        allow = bool(entry.get("allow_vanilla_overlap") or spec.get("allow_vanilla_overlap"))
        normalized_display = normalize_name(display)
        if entry_id in table:
            findings.append(
                {
                    "severity": "warning" if allow else "error",
                    "kind": "exact_id_duplicate",
                    "collection": collection,
                    "id": entry_id,
                    "display_name": display,
                    "vanilla": f"minecraft:{entry_id}",
                    "vanilla_display_name": table[entry_id].get("display_name"),
                    "allowed": allow,
                }
            )
        if normalized_display in display_map:
            vanilla_id = display_map[normalized_display]
            findings.append(
                {
                    "severity": "warning" if allow else "error",
                    "kind": "exact_display_duplicate",
                    "collection": collection,
                    "id": entry_id,
                    "display_name": display,
                    "vanilla": f"minecraft:{vanilla_id}",
                    "vanilla_display_name": table[vanilla_id].get("display_name"),
                    "allowed": allow,
                }
            )
        elif normalized_display:
            matches = difflib.get_close_matches(normalized_display, display_names, n=3, cutoff=0.89)
            for match in matches:
                vanilla_id = display_map[match]
                findings.append(
                    {
                        "severity": "info",
                        "kind": "similar_display_name",
                        "collection": collection,
                        "id": entry_id,
                        "display_name": display,
                        "vanilla": f"minecraft:{vanilla_id}",
                        "vanilla_display_name": table[vanilla_id].get("display_name"),
                    }
                )
    return findings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--version", help="Override spec.minecraft_version.")
    parser.add_argument("--index", help="Use a prebuilt vanilla-index.json.")
    parser.add_argument("--cache-dir")
    parser.add_argument("--force-index", action="store_true")
    parser.add_argument("--report", help="Report path. Defaults to <spec dir>/.minecraft-vanilla-check.json")
    parser.add_argument("--warnings-only", action="store_true", help="Never fail on duplicate findings.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).expanduser().resolve()
    spec = load_spec(spec_path)
    version = str(args.version or spec.get("minecraft_version") or "")
    if not version and not args.index:
        raise SystemExit("Missing Minecraft version. Set spec.minecraft_version or pass --version/--index.")
    index_path = Path(args.index).expanduser().resolve() if args.index else build_index_path(version, args.cache_dir, args.force_index)
    index = json.loads(index_path.read_text(encoding="utf-8"))
    findings = check_collection(spec, index, "item") + check_collection(spec, index, "block")
    report = {
        "spec": str(spec_path),
        "vanilla_index": str(index_path),
        "minecraft_version": index["version"],
        "counts": index.get("counts", {}),
        "findings": findings,
    }
    report_path = Path(args.report).expanduser().resolve() if args.report else spec_path.parent / ".minecraft-vanilla-check.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"report": str(report_path), **report}, indent=2, ensure_ascii=False))
    has_errors = any(f["severity"] == "error" for f in findings)
    return 1 if has_errors and not args.warnings_only else 0


if __name__ == "__main__":
    raise SystemExit(main())
