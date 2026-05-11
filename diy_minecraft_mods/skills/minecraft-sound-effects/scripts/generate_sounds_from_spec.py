#!/usr/bin/env python3
"""Generate Minecraft sound assets from a spec and merge sounds.json."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def namespace_from_spec(spec: dict[str, Any], override: str | None) -> str:
    if override:
        return override
    rp = spec.get("resource_pack") if isinstance(spec.get("resource_pack"), dict) else {}
    return str(rp.get("namespace") or spec.get("namespace") or spec.get("mod_id") or "minecraft")


def merge_lang(lang_path: Path, updates: dict[str, str]) -> None:
    data = load_json(lang_path) if lang_path.exists() else {}
    data.update(updates)
    write_json(lang_path, dict(sorted(data.items())))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--assets-root", required=True, help="Directory containing namespace folders, e.g. ResourcePack/assets.")
    parser.add_argument("--namespace")
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--report", help="Defaults to <assets root parent>/.minecraft-sounds.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).expanduser().resolve()
    assets_root = Path(args.assets_root).expanduser().resolve()
    spec = load_json(spec_path)
    namespace = namespace_from_spec(spec, args.namespace)
    sound_script = Path(__file__).with_name("generate_sound.py")
    sounds_json_path = assets_root / namespace / "sounds.json"
    sounds_json = load_json(sounds_json_path) if sounds_json_path.exists() else {}
    lang_updates: dict[str, str] = {}
    results: list[dict[str, Any]] = []

    for entry in spec.get("sounds", []) or []:
        sound_id = str(entry["id"])
        file_path = str(entry.get("file") or sound_id.replace(".", "/"))
        prompt = str(entry.get("prompt") or entry.get("text") or sound_id)
        ogg = assets_root / namespace / "sounds" / f"{file_path}.ogg"
        if args.skip_existing and ogg.exists():
            status = "skipped_existing"
            code = 0
        else:
            cmd = ["python3", str(sound_script), "--text", prompt, "--output", str(ogg)]
            if entry.get("duration_seconds") is not None:
                cmd += ["--duration-seconds", str(entry["duration_seconds"])]
            if entry.get("prompt_influence") is not None:
                cmd += ["--prompt-influence", str(entry["prompt_influence"])]
            code = subprocess.run(cmd, check=False).returncode
            status = "ok" if code == 0 else "failed"
        subtitle_text = entry.get("subtitle")
        subtitle_key = entry.get("subtitle_key")
        if subtitle_text and not subtitle_key:
            subtitle_key = f"subtitles.{namespace}.{sound_id}"
        if subtitle_key and subtitle_text:
            lang_updates[str(subtitle_key)] = str(subtitle_text)
        record: dict[str, Any] = {"sounds": [f"{namespace}:{file_path}"]}
        if subtitle_key:
            record["subtitle"] = str(subtitle_key)
        sounds_json[sound_id] = record
        results.append({"id": sound_id, "file": str(ogg), "status": status, "exit_code": code})

    write_json(sounds_json_path, dict(sorted(sounds_json.items())))
    if lang_updates:
        merge_lang(assets_root / namespace / "lang" / "en_us.json", lang_updates)
    report_path = Path(args.report).expanduser().resolve() if args.report else assets_root.parent / ".minecraft-sounds.json"
    report = {"spec": str(spec_path), "assets_root": str(assets_root), "namespace": namespace, "results": results}
    write_json(report_path, report)
    print(json.dumps({"report": str(report_path), **report}, indent=2))
    return 1 if any(result["status"] == "failed" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
