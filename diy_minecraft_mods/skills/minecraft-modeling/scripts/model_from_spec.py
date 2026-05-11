#!/usr/bin/env python3
"""Generate non-default Minecraft Java model JSON files from mod-spec model fields."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_KINDS = {"", "default", "generated", "handheld", "cube_all"}
JAVA_KINDS = {"java_elements", "custom_block", "custom_item"}
HANDOFF_KINDS = {"blockbench", "geckolib", "entity"}
FACES = ["north", "south", "east", "west", "up", "down"]


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


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def default_faces(texture_ref: str) -> dict[str, dict[str, str]]:
    return {face: {"texture": texture_ref} for face in FACES}


def normalize_element(element: dict[str, Any], texture_ref: str) -> dict[str, Any]:
    out: dict[str, Any] = {
        "from": element["from"],
        "to": element["to"],
        "faces": element.get("faces") or default_faces(texture_ref),
    }
    for key in ["rotation", "shade", "light_emission"]:
        if key in element:
            out[key] = element[key]
    return out


def model_path(project: Path, mod_id: str, collection: str, entry_id: str) -> Path:
    return project / "src" / "main" / "resources" / "assets" / mod_id / "models" / collection / f"{entry_id}.json"


def generate_java_model(project: Path, mod_id: str, collection: str, entry: dict[str, Any]) -> dict[str, Any]:
    model = entry["model"]
    entry_id = entry["id"]
    texture_path = model.get("texture") or f"{collection}/{entry_id}"
    texture_ref = model.get("texture_ref") or "#all"
    elements = model.get("elements") or []
    if not elements:
        raise SystemExit(f"{collection}.{entry_id} custom model requires model.elements.")
    model_json = {
        "textures": {"all": f"{mod_id}:{texture_path}"},
        "elements": [normalize_element(element, texture_ref) for element in elements],
    }
    if "display" in model:
        model_json["display"] = model["display"]
    out_path = model_path(project, mod_id, collection, entry_id)
    write_json(out_path, model_json)
    if collection == "block":
        write_json(model_path(project, mod_id, "item", entry_id), {"parent": f"{mod_id}:block/{entry_id}"})
    return {"id": entry_id, "collection": collection, "kind": model.get("kind"), "model_json": str(out_path)}


def needs_model(entry: dict[str, Any]) -> bool:
    model = entry.get("model")
    if not isinstance(model, dict):
        return False
    return str(model.get("kind", "")).lower() not in DEFAULT_KINDS


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--report", help="Defaults to <project>/.minecraft-models.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).expanduser().resolve()
    project = Path(args.project).expanduser().resolve()
    spec = load_spec(spec_path)
    mod_id = str(spec["mod_id"])
    results: list[dict[str, Any]] = []
    required_handoff: list[dict[str, Any]] = []

    for collection in ["item", "block"]:
        spec_key = "items" if collection == "item" else "blocks"
        for entry in spec.get(spec_key, []) or []:
            if not needs_model(entry):
                continue
            kind = str(entry["model"].get("kind", "")).lower()
            if kind in JAVA_KINDS:
                results.append(generate_java_model(project, mod_id, collection, entry))
            elif kind in HANDOFF_KINDS:
                required_handoff.append(
                    {
                        "id": entry["id"],
                        "collection": collection,
                        "kind": kind,
                        "status": "requires_blockbench_or_modding_work",
                        "note": "Use Blockbench MCP/file workflow and then minecraft-modding for renderer/model integration.",
                    }
                )
            else:
                required_handoff.append(
                    {
                        "id": entry["id"],
                        "collection": collection,
                        "kind": kind,
                        "status": "unknown_model_kind",
                    }
                )

    report = {
        "spec": str(spec_path),
        "project": str(project),
        "generated": results,
        "handoff_required": required_handoff,
    }
    report_path = Path(args.report).expanduser().resolve() if args.report else project / ".minecraft-models.json"
    write_json(report_path, report)
    print(json.dumps({"report": str(report_path), **report}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
