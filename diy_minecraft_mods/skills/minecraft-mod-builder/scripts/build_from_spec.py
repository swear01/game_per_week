#!/usr/bin/env python3
"""Build a Minecraft mod project from spec by coordinating local Minecraft skills."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


def run(cmd: list[str], cwd: Path | None = None, required: bool = True) -> int:
    print("+ " + " ".join(cmd))
    result = subprocess.run(cmd, cwd=cwd, check=False)
    if required and result.returncode != 0:
        raise SystemExit(result.returncode)
    return result.returncode


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


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def validate_spec(root: Path, spec_path: Path) -> None:
    validator = root / "skills" / "minecraft-mod-spec" / "scripts" / "validate_spec.py"
    run(["python3", str(validator), str(spec_path)])


def check_vanilla(root: Path, spec_path: Path, warnings_only: bool) -> Path:
    script = root / "skills" / "minecraft-vanilla-harness" / "scripts" / "check_spec_against_vanilla.py"
    report_path = spec_path.parent / ".minecraft-vanilla-check.json"
    cmd = ["python3", str(script), "--spec", str(spec_path), "--report", str(report_path)]
    if warnings_only:
        cmd.append("--warnings-only")
    run(cmd, cwd=root)
    return report_path


def scaffold(root: Path, spec_path: Path, output: Path, template_url: str | None, force: bool) -> None:
    script = root / "skills" / "minecraft-mod-scaffold" / "scripts" / "scaffold_from_spec.py"
    cmd = ["python3", str(script), "--spec", str(spec_path), "--output", str(output)]
    if template_url:
        cmd += ["--template-url", template_url]
    if force:
        cmd.append("--force")
    run(cmd, cwd=root)


def ensure_project_spec(project: Path, spec_path: Path) -> None:
    project.mkdir(parents=True, exist_ok=True)
    target = project / ".minecraft-mod-spec.json"
    if target.resolve() != spec_path:
        target.write_text(spec_path.read_text(encoding="utf-8"), encoding="utf-8")


def copy_vanilla_report(project: Path, report_path: Path | None) -> Path | None:
    if not report_path or not report_path.exists():
        return None
    target = project / ".minecraft-vanilla-check.json"
    if target.resolve() != report_path.resolve():
        target.write_text(report_path.read_text(encoding="utf-8"), encoding="utf-8")
    return target


def generate_textures(root: Path, spec_path: Path, project: Path, skip_existing: bool) -> None:
    script = root / "skills" / "minecraft-texture-replicate" / "scripts" / "generate_from_spec.mjs"
    cmd = ["node", str(script), "--spec", str(spec_path), "--project", str(project)]
    if skip_existing:
        cmd.append("--skip-existing")
    run(cmd, cwd=root)


def generate_sounds(root: Path, spec_path: Path, project: Path, spec: dict[str, Any], skip_existing: bool) -> bool:
    if not spec.get("sounds"):
        return False
    script = root / "skills" / "minecraft-sound-effects" / "scripts" / "generate_sounds_from_spec.py"
    cmd = [
        "python3",
        str(script),
        "--spec",
        str(spec_path),
        "--assets-root",
        str(project / "src" / "main" / "resources" / "assets"),
        "--namespace",
        str(spec["mod_id"]),
        "--report",
        str(project / ".minecraft-sounds.json"),
    ]
    if skip_existing:
        cmd.append("--skip-existing")
    run(cmd, cwd=root)
    return True


def has_custom_models(spec: dict[str, Any]) -> bool:
    default_kinds = {"", "default", "generated", "handheld", "cube_all"}
    for collection in ["items", "blocks"]:
        for entry in spec.get(collection, []) or []:
            model = entry.get("model")
            if isinstance(model, dict) and str(model.get("kind", "")).lower() not in default_kinds:
                return True
    return False


def generate_models(root: Path, spec_path: Path, project: Path) -> None:
    script = root / "skills" / "minecraft-modeling" / "scripts" / "model_from_spec.py"
    run(["python3", str(script), "--spec", str(spec_path), "--project", str(project)], cwd=root)


def gradle(project: Path, tasks: list[str]) -> list[dict[str, Any]]:
    wrapper = project / "gradlew"
    if wrapper.exists():
        wrapper.chmod(wrapper.stat().st_mode | 0o111)
        gradle_cmd = [str(wrapper)]
    elif shutil.which("gradle"):
        gradle_cmd = ["gradle"]
    else:
        print("No Gradle wrapper or gradle executable found; skipping Gradle tasks.", file=sys.stderr)
        return []

    results: list[dict[str, Any]] = []
    for task in tasks:
        code = run(gradle_cmd + [task], cwd=project, required=False)
        results.append({"task": task, "exit_code": code})
        if code != 0:
            break
    return results


def collect_jars(project: Path) -> list[str]:
    return [str(path) for path in sorted(project.rglob("build/libs/*.jar")) if "-sources" not in path.name and "-javadoc" not in path.name]


def write_handoff(project: Path, spec: dict[str, Any], summary: dict[str, Any]) -> None:
    mod_id = spec["mod_id"]
    lines = [
        "# Minecraft Modding Handoff",
        "",
        f"- Project: `{project}`",
        f"- Mod id: `{mod_id}`",
        f"- Loader: `{spec.get('loader')}`",
        f"- Minecraft version: `{spec.get('minecraft_version')}`",
        f"- Spec: `{project / '.minecraft-mod-spec.json'}`",
        f"- Vanilla check report: `{summary.get('vanilla_report')}`",
        f"- Scaffold metadata: `{project / '.minecraft-scaffold.json'}`",
        f"- Texture report: `{project / '.minecraft-textures.json'}`",
        f"- Sound report: `{project / '.minecraft-sounds.json'}`",
        f"- Model report: `{project / '.minecraft-models.json'}`",
        f"- Build report: `{project / '.minecraft-build-report.json'}`",
        f"- Test report: `{project / '.minecraft-test-report.json'}`",
        "",
        "## Required Modding Phase",
        "",
        "Use `minecraft-modding` to read this project, follow the template's loader patterns, and implement/verify:",
        "",
        "- item registrations",
        "- block registrations",
        "- matching block items",
        "- custom model integration when `.minecraft-models.json` reports handoff work",
        "- custom sound event registration/use when `.minecraft-sounds.json` exists",
        "- creative tab visibility",
        "- recipe/datagen wiring when requested by spec",
        "- client/server separation",
        "- Gradle build/run task failures",
        "- automated test matrix and GameTest checks via `minecraft-gametest`",
        "",
        "## Declared Items",
        "",
    ]
    for item in spec.get("items", []) or []:
        lines.append(f"- `{item['id']}`: {item.get('display_name', item['id'])}")
    lines += ["", "## Declared Blocks", ""]
    for block in spec.get("blocks", []) or []:
        lines.append(f"- `{block['id']}`: {block.get('display_name', block['id'])}")
    lines += ["", "## Last Build Summary", "", "```json", json.dumps(summary, indent=2), "```", ""]
    (project / ".minecraft-modding-handoff.md").write_text("\n".join(lines), encoding="utf-8")


def write_report(project: Path, summary: dict[str, Any]) -> None:
    (project / ".minecraft-build-report.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--template-url")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--skip-scaffold", action="store_true")
    parser.add_argument("--skip-textures", action="store_true")
    parser.add_argument("--skip-existing-textures", action="store_true")
    parser.add_argument("--skip-sounds", action="store_true")
    parser.add_argument("--skip-existing-sounds", action="store_true")
    parser.add_argument("--skip-modeling", action="store_true")
    parser.add_argument("--skip-vanilla-check", action="store_true")
    parser.add_argument("--vanilla-warnings-only", action="store_true", help="Write vanilla duplicate findings but do not fail the build.")
    parser.add_argument("--skip-gradle", action="store_true")
    parser.add_argument("--gradle-task", action="append", default=[], help="Gradle task to run. Defaults to runData then build.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = repo_root()
    spec_path = Path(args.spec).expanduser().resolve()
    project = Path(args.output).expanduser().resolve()
    spec = load_spec(spec_path)

    validate_spec(root, spec_path)
    vanilla_report = None
    if not args.skip_vanilla_check:
        vanilla_report = check_vanilla(root, spec_path, args.vanilla_warnings_only)
    if not args.skip_scaffold:
        scaffold(root, spec_path, project, args.template_url, args.force)
    else:
        ensure_project_spec(project, spec_path)
    project_vanilla_report = copy_vanilla_report(project, vanilla_report)
    if not args.skip_textures:
        generate_textures(root, spec_path, project, args.skip_existing_textures)
    sounds_generated = False
    if not args.skip_sounds:
        sounds_generated = generate_sounds(root, spec_path, project, spec, args.skip_existing_sounds)
    modeling_needed = has_custom_models(spec)
    if modeling_needed and not args.skip_modeling:
        generate_models(root, spec_path, project)
    gradle_results = []
    if not args.skip_gradle:
        gradle_results = gradle(project, args.gradle_task or ["runData", "build"])
    summary = {
        "project": str(project),
        "spec": str(project / ".minecraft-mod-spec.json"),
        "vanilla_check_skipped": bool(args.skip_vanilla_check),
        "vanilla_report": str(project_vanilla_report or vanilla_report) if vanilla_report else None,
        "textures_skipped": bool(args.skip_textures),
        "sounds_declared": bool(spec.get("sounds")),
        "sounds_skipped": bool(args.skip_sounds),
        "sounds_generated": sounds_generated,
        "sound_report": str(project / ".minecraft-sounds.json") if sounds_generated else None,
        "modeling_needed": modeling_needed,
        "modeling_skipped": bool(args.skip_modeling),
        "gradle_skipped": bool(args.skip_gradle),
        "gradle": gradle_results,
        "jars": collect_jars(project),
        "handoff": str(project / ".minecraft-modding-handoff.md"),
        "next_step": "Use minecraft-modding for the implementation phase: registry code, custom model integration, datagen wiring, compile fixes, and runtime checks.",
    }
    write_report(project, summary)
    write_handoff(project, spec, summary)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
