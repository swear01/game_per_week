#!/usr/bin/env python3
"""Build a Minecraft Java resource pack folder and optional zip from a spec."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Any


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def resource_pack_config(spec: dict[str, Any]) -> dict[str, Any]:
    return spec.get("resource_pack") if isinstance(spec.get("resource_pack"), dict) else {}


def namespace(spec: dict[str, Any], override: str | None) -> str:
    rp = resource_pack_config(spec)
    return str(override or rp.get("namespace") or spec.get("namespace") or spec.get("mod_id") or "minecraft")


def target_path(entry: dict[str, Any], default_namespace: str) -> tuple[str, str]:
    raw = str(entry.get("target_id") or entry.get("vanilla_reference") or entry.get("id"))
    if ":" in raw:
        ns, path = raw.split(":", 1)
        return ns, path
    return default_namespace, raw


def resolve_pack_format(root: Path, version: str | None, explicit: int | None) -> int:
    if explicit:
        return explicit
    if not version:
        raise SystemExit("Missing minecraft_version; pass --pack-format or set spec.minecraft_version.")
    builder = root / "skills" / "minecraft-vanilla-harness" / "scripts" / "build_vanilla_index.py"
    subprocess.run(["python3", str(builder), "--version", version], check=True)
    cache = Path.home() / ".cache" / "minecraft-vanilla-harness" / version / "client.jar"
    with zipfile.ZipFile(cache) as jar:
        version_json = json.loads(jar.read("version.json").decode("utf-8"))
    pack_version = version_json.get("pack_version", {})
    value = pack_version.get("resource_major")
    if not isinstance(value, int):
        value = pack_version.get("resource")
    if not isinstance(value, int):
        raise SystemExit("Could not resolve resource pack format from version.json; pass --pack-format.")
    return value


def emit_pack_mcmeta(output: Path, spec: dict[str, Any], pack_format: int, description: str | None) -> None:
    desc = description or resource_pack_config(spec).get("description") or spec.get("display_name") or "Minecraft Resource Pack"
    write_json(
        output / "pack.mcmeta",
        {"pack": {"pack_format": pack_format, "supported_formats": [pack_format, pack_format], "description": str(desc)}},
    )


def emit_models_and_lang(output: Path, spec: dict[str, Any], default_namespace: str) -> None:
    lang_updates: dict[str, str] = {}
    for item in spec.get("items", []) or []:
        ns, item_id = target_path(item, default_namespace)
        model_id = item_id
        parent = "minecraft:item/handheld" if item.get("type") == "tool" else "minecraft:item/generated"
        write_json(
            output / "assets" / ns / "models" / "item" / f"{model_id}.json",
            {"parent": parent, "textures": {"layer0": f"{ns}:item/{model_id}"}},
        )
        if item.get("display_name"):
            lang_updates[f"item.{ns}.{model_id}"] = str(item["display_name"])
        (output / "assets" / ns / "textures" / "item").mkdir(parents=True, exist_ok=True)

    for block in spec.get("blocks", []) or []:
        ns, block_id = target_path(block, default_namespace)
        write_json(
            output / "assets" / ns / "blockstates" / f"{block_id}.json",
            {"variants": {"": {"model": f"{ns}:block/{block_id}"}}},
        )
        write_json(
            output / "assets" / ns / "models" / "block" / f"{block_id}.json",
            {"parent": "minecraft:block/cube_all", "textures": {"all": f"{ns}:block/{block_id}"}},
        )
        write_json(output / "assets" / ns / "models" / "item" / f"{block_id}.json", {"parent": f"{ns}:block/{block_id}"})
        if block.get("display_name"):
            lang_updates[f"block.{ns}.{block_id}"] = str(block["display_name"])
        (output / "assets" / ns / "textures" / "block").mkdir(parents=True, exist_ok=True)

    by_ns: dict[str, dict[str, str]] = {}
    for key, value in lang_updates.items():
        ns = key.split(".", 2)[1]
        by_ns.setdefault(ns, {})[key] = value
    for ns, updates in by_ns.items():
        path = output / "assets" / ns / "lang" / "en_us.json"
        existing = load_json(path) if path.exists() else {}
        existing.update(updates)
        write_json(path, dict(sorted(existing.items())))

    for lang_id, updates in (spec.get("lang") or {}).items():
        if not isinstance(updates, dict):
            continue
        path = output / "assets" / default_namespace / "lang" / f"{lang_id}.json"
        existing = load_json(path) if path.exists() else {}
        existing.update({str(key): str(value) for key, value in updates.items()})
        write_json(path, dict(sorted(existing.items())))


def resolve_vanilla_texture(root: Path, mc_version: str, namespace: str, texture_rel: str) -> Path | None:
    script = root / "skills" / "minecraft-texture-replicate" / "scripts" / "resolve_vanilla_texture.py"
    r = subprocess.run(
        [
            "python3",
            str(script),
            "--version",
            mc_version,
            "--namespace",
            namespace,
            "--texture-rel",
            texture_rel,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if r.returncode != 0:
        return None
    lines = [ln.strip() for ln in r.stdout.strip().splitlines() if ln.strip()]
    if not lines:
        return None
    p = Path(lines[-1])
    return p if p.is_file() else None


def infer_texture_override_kind(target: str, explicit: str | None) -> str:
    if explicit in ("item", "block", "entity"):
        return str(explicit)
    if target.startswith("item/"):
        return "item"
    if target.startswith("entity/"):
        return "entity"
    return "block"


def generate_textures(
    root: Path,
    output: Path,
    spec: dict[str, Any],
    default_namespace: str,
    size: int,
    skip_existing: bool,
    spec_path: Path,
) -> list[dict[str, Any]]:
    if not os.environ.get("REPLICATE_API_TOKEN"):
        raise SystemExit("REPLICATE_API_TOKEN is required for texture generation. Use --skip-textures to skip.")
    script = root / "skills" / "minecraft-texture-replicate" / "scripts" / "generate_texture.mjs"
    results: list[dict[str, Any]] = []
    for kind, collection in [("item", "items"), ("block", "blocks")]:
        for entry in spec.get(collection, []) or []:
            ns, entry_id = target_path(entry, default_namespace)
            out_dir = output / "assets" / ns / "textures" / kind
            png = out_dir / f"{entry_id}.png"
            if skip_existing and png.exists():
                results.append({"type": kind, "id": f"{ns}:{entry_id}", "status": "skipped_existing", "png": str(png)})
                continue
            prompt = str(entry.get("texture_prompt") or entry.get("display_name") or entry_id)
            cmd = [
                "node",
                str(script),
                "--type",
                kind,
                "--subject",
                entry_id,
                "--prompt",
                prompt,
                "--size",
                str(size),
                "--output-dir",
                str(out_dir),
                "--name",
                entry_id,
            ]
            if kind == "item" and entry.get("transparent_texture", True):
                cmd.append("--transparent-bg")
            code = subprocess.run(cmd, check=False).returncode
            results.append({"type": kind, "id": f"{ns}:{entry_id}", "status": "ok" if code == 0 else "failed", "exit_code": code, "png": str(png)})
    for entry in spec.get("texture_overrides", []) or []:
        raw = str(entry.get("target") or entry.get("target_path") or "")
        if not raw:
            results.append({"type": "texture_override", "status": "failed", "error": "missing target"})
            continue
        ns = str(entry.get("namespace") or default_namespace)
        target = raw.removeprefix("assets/").removeprefix(f"{ns}/")
        target = target.removeprefix("textures/")
        if target.endswith(".png"):
            target = target[:-4]
        kind = infer_texture_override_kind(target, entry.get("type"))
        rel = Path(target)
        name = rel.name
        out_dir = output / "assets" / ns / "textures" / rel.parent
        png = out_dir / f"{name}.png"
        if skip_existing and png.exists():
            results.append({"type": "texture_override", "id": f"{ns}:textures/{target}", "status": "skipped_existing", "png": str(png)})
            continue
        prompt = str(entry.get("texture_prompt") or entry.get("prompt") or entry.get("display_name") or name)
        cmd = [
            "node",
            str(script),
            "--type",
            kind,
            "--subject",
            name,
            "--prompt",
            prompt,
            "--size",
            str(int(entry.get("texture_size") or size)),
            "--output-dir",
            str(out_dir),
            "--name",
            name,
        ]
        if kind == "item" and entry.get("transparent_texture", True):
            cmd.append("--transparent-bg")
        if kind == "entity":
            cmd.append("--no-tile")

        ref: Path | None = None
        ref_spec = entry.get("reference_image")
        if ref_spec:
            ref = (spec_path.parent / str(ref_spec)).expanduser().resolve()
            if not ref.is_file():
                results.append(
                    {
                        "type": "texture_override",
                        "id": f"{ns}:textures/{target}",
                        "status": "failed",
                        "error": f"reference_image not found: {ref}",
                    }
                )
                continue
        elif kind == "entity" and ns == "minecraft":
            mc_ver = str(spec.get("minecraft_version") or "").strip()
            if mc_ver:
                ref = resolve_vanilla_texture(root, mc_ver, ns, target)
        if ref is not None and ref.is_file():
            cmd.extend(["--reference-image", str(ref)])
        if entry.get("img2img_strength") is not None:
            cmd.extend(["--img2img-strength", str(entry["img2img_strength"])])
        if entry.get("entity_layout_blend") is not None:
            cmd.extend(["--entity-layout-blend", str(entry["entity_layout_blend"])])
        if entry.get("bypass_prompt_expansion"):
            cmd.append("--bypass-prompt-expansion")
        if entry.get("seed") is not None:
            cmd.extend(["--seed", str(int(entry["seed"]))])
        code = subprocess.run(cmd, check=False).returncode
        results.append({"type": "texture_override", "id": f"{ns}:textures/{target}", "status": "ok" if code == 0 else "failed", "exit_code": code, "png": str(png)})
    return results


def generate_pack_icon(root: Path, output: Path, spec: dict[str, Any], spec_dir: Path, skip_existing: bool) -> dict[str, Any]:
    rp = resource_pack_config(spec)
    icon_target = output / "pack.png"
    if skip_existing and icon_target.exists():
        return {"status": "skipped_existing", "path": str(icon_target)}

    local_icon = rp.get("icon")
    if local_icon:
        src = Path(str(local_icon)).expanduser()
        if not src.is_absolute():
            src = (spec_dir / src).resolve()
        if not src.exists():
            return {"status": "failed", "error": f"icon source not found: {src}"}
        shutil.copyfile(src, icon_target)
        return {"status": "ok", "source": str(src), "path": str(icon_target), "mode": "copy"}

    if not os.environ.get("REPLICATE_API_TOKEN"):
        raise SystemExit("REPLICATE_API_TOKEN is required for pack icon generation. Use --skip-pack-icon to skip or set resource_pack.icon to a local PNG path.")

    icon_size = int(rp.get("icon_size") or 128)
    display_name = str(rp.get("description") or spec.get("display_name") or "Minecraft resource pack")
    icon_prompt = str(rp.get("icon_prompt") or f"Minecraft resource pack icon, square pixel art emblem representing {display_name}, bold readable silhouette, plain solid background, no text, no UI, no border")

    script = root / "skills" / "minecraft-texture-replicate" / "scripts" / "generate_texture.mjs"
    cmd = [
        "node",
        str(script),
        "--type",
        "item",
        "--subject",
        display_name,
        "--prompt",
        icon_prompt,
        "--size",
        str(icon_size),
        "--output-dir",
        str(output),
        "--name",
        "pack",
        "--preview-scale",
        "0",
    ]
    icon_style = rp.get("icon_style")
    if icon_style:
        cmd.extend(["--style", str(icon_style)])
    if rp.get("icon_bypass_prompt_expansion"):
        cmd.append("--bypass-prompt-expansion")
    code = subprocess.run(cmd, check=False).returncode
    return {
        "status": "ok" if code == 0 and icon_target.exists() else "failed",
        "exit_code": code,
        "path": str(icon_target),
        "mode": "replicate",
        "size": icon_size,
        "prompt": icon_prompt,
    }


def generate_sounds(root: Path, output: Path, spec_path: Path, default_namespace: str, skip_existing: bool) -> dict[str, Any] | None:
    spec = load_json(spec_path)
    if not spec.get("sounds"):
        return None
    if not os.environ.get("ELEVENLABS_API_KEY"):
        raise SystemExit("ELEVENLABS_API_KEY is required for sound generation. Use --skip-sounds to skip.")
    script = root / "skills" / "minecraft-sound-effects" / "scripts" / "generate_sounds_from_spec.py"
    report = output / ".minecraft-sounds.json"
    cmd = [
        "python3",
        str(script),
        "--spec",
        str(spec_path),
        "--assets-root",
        str(output / "assets"),
        "--namespace",
        default_namespace,
        "--report",
        str(report),
    ]
    if skip_existing:
        cmd.append("--skip-existing")
    code = subprocess.run(cmd, check=False).returncode
    return {"report": str(report), "exit_code": code, "status": "ok" if code == 0 else "failed"}


def zip_pack(output: Path, zip_path: Path | None = None) -> Path:
    target = zip_path or output.with_suffix(".zip")
    if target.exists():
        target.unlink()
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(output.rglob("*")):
            if path.is_file():
                if path.name.startswith(".minecraft-"):
                    continue
                if path.name == "preview.png":
                    continue
                relative = path.relative_to(output)
                parts = relative.parts
                if len(parts) == 1 and (path.name == "pack.json" or path.name.endswith(".preview.png") or path.name.endswith(".raw.png")):
                    continue
                if "textures" in parts and (path.suffix == ".json" or path.name.endswith(".preview.png") or path.name.endswith(".raw.png")):
                    continue
                archive.write(path, relative)
    return target


def validate_pack(output: Path) -> list[str]:
    errors: list[str] = []
    if not (output / "pack.mcmeta").exists():
        errors.append("Missing pack.mcmeta")
    if not (output / "assets").exists():
        errors.append("Missing assets directory")
    return errors


def copy_pack_artifacts(output_dir: Path, zip_path: Path | None, dest_parent: Path) -> dict[str, str]:
    """Copy unpacked pack folder and optional zip into dest_parent (e.g. .../minecraft/resourcepacks)."""
    dest_parent.mkdir(parents=True, exist_ok=True)
    written: dict[str, str] = {}
    target_folder = dest_parent / output_dir.name
    if target_folder.exists():
        shutil.rmtree(target_folder)
    shutil.copytree(output_dir, target_folder)
    written["folder"] = str(target_folder.resolve())
    if zip_path is not None:
        zp = Path(zip_path)
        if zp.is_file():
            zdest = dest_parent / zp.name
            shutil.copy2(zp, zdest)
            written["zip"] = str(zdest.resolve())
    return written


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--namespace")
    parser.add_argument("--description")
    parser.add_argument("--pack-format", type=int)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-textures", action="store_true")
    parser.add_argument("--skip-sounds", action="store_true")
    parser.add_argument("--skip-pack-icon", action="store_true")
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--zip", action="store_true")
    parser.add_argument("--zip-path")
    parser.add_argument(
        "--copy-to",
        help="After a successful build, copy the pack folder (and zip if --zip) into this directory "
        "(e.g. Prism instance .../minecraft/resourcepacks or repo path resources/resourcepacks).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repo_root()
    spec_path = Path(args.spec).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    spec = load_json(spec_path)
    ns = namespace(spec, args.namespace)
    if args.skip_textures and spec.get("texture_overrides"):
        raise SystemExit(
            "This spec declares texture_overrides. Passing --skip-textures builds a pack without those textures "
            "(often only pack.mcmeta remains under assets). Omit --skip-textures when rebuilding this spec."
        )
    if output.exists():
        if args.skip_existing:
            pass
        elif not args.force:
            raise SystemExit(f"Output exists: {output}. Use --force.")
        else:
            shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)
    write_json(output / ".minecraft-resource-pack-spec.json", spec)
    pack_format = resolve_pack_format(root, str(spec.get("minecraft_version") or ""), args.pack_format)
    emit_pack_mcmeta(output, spec, pack_format, args.description)
    emit_models_and_lang(output, spec, ns)

    texture_results: list[dict[str, Any]] = []
    if not args.skip_textures:
        texture_results = generate_textures(root, output, spec, ns, int(spec.get("texture_size", 32)), args.skip_existing, spec_path)
    sound_result = None
    if not args.skip_sounds:
        sound_result = generate_sounds(root, output, spec_path, ns, args.skip_existing)
    pack_icon_result: dict[str, Any] | None = None
    if not args.skip_pack_icon:
        pack_icon_result = generate_pack_icon(root, output, spec, spec_path.parent, args.skip_existing)
    errors = validate_pack(output)
    zip_result = str(zip_pack(output, Path(args.zip_path).expanduser().resolve() if args.zip_path else None)) if args.zip else None
    copy_map: dict[str, str] | None = None
    copy_dest = (os.environ.get("RESOURCE_PACK_COPY_TO") or "").strip() or (args.copy_to or "").strip()
    report = {
        "spec": str(spec_path),
        "output": str(output),
        "namespace": ns,
        "pack_format": pack_format,
        "textures_skipped": bool(args.skip_textures),
        "texture_results": texture_results,
        "sounds_skipped": bool(args.skip_sounds),
        "sound_result": sound_result,
        "pack_icon_skipped": bool(args.skip_pack_icon),
        "pack_icon_result": pack_icon_result,
        "zip": zip_result,
        "copy_to": None,
        "errors": errors,
        "passed": not errors
            and not any(result.get("status") == "failed" for result in texture_results)
            and not (sound_result and sound_result.get("status") == "failed")
            and not (pack_icon_result and pack_icon_result.get("status") == "failed"),
    }
    if report["passed"] and copy_dest:
        copy_parent = Path(copy_dest).expanduser()
        if not copy_parent.is_absolute():
            copy_parent = (root / copy_parent).resolve()
        else:
            copy_parent = copy_parent.resolve()
        try:
            zip_path_obj = Path(zip_result) if zip_result else None
            copy_map = copy_pack_artifacts(output, zip_path_obj, copy_parent)
            report["copy_to"] = copy_map
        except OSError as e:
            report["passed"] = False
            report["errors"] = list(errors) + [f"copy-to failed: {e}"]
    write_json(output / ".minecraft-resource-pack-report.json", report)
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
