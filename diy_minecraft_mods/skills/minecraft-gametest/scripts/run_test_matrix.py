#!/usr/bin/env python3
"""Run available Gradle test tasks for a Minecraft mod project and write a report."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def detect_loader(project: Path) -> str:
    gradle_text = []
    for path in sorted(project.glob("*.gradle*")):
        gradle_text.append(path.read_text(encoding="utf-8", errors="ignore"))
    props = project / "gradle.properties"
    if props.exists():
        gradle_text.append(props.read_text(encoding="utf-8", errors="ignore"))
    text = "\n".join(gradle_text).lower()
    if (project / "src/main/resources/fabric.mod.json").exists() or "fabric-loom" in text or "fabricloader" in text:
        return "fabric"
    if (project / "src/main/resources/META-INF/neoforge.mods.toml").exists() or "neoforge" in text or "moddevgradle" in text:
        return "neoforge"
    if "architectury" in text:
        return "architectury"
    return "unknown"


def gradle_command(project: Path) -> list[str] | None:
    wrapper = project / "gradlew"
    if wrapper.exists():
        wrapper.chmod(wrapper.stat().st_mode | 0o111)
        return [str(wrapper)]
    gradle = shutil.which("gradle")
    return [gradle] if gradle else None


def run(cmd: list[str], cwd: Path, timeout: int) -> dict[str, Any]:
    started = time.time()
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
            check=False,
        )
        output = result.stdout or ""
        return {
            "command": cmd,
            "exit_code": result.returncode,
            "duration_seconds": round(time.time() - started, 2),
            "timed_out": False,
            "output_tail": output[-8000:],
        }
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        return {
            "command": cmd,
            "exit_code": None,
            "duration_seconds": round(time.time() - started, 2),
            "timed_out": True,
            "output_tail": output[-8000:],
        }


def list_tasks(project: Path, gradle: list[str], timeout: int) -> tuple[set[str], dict[str, Any]]:
    result = run(gradle + ["tasks", "--all"], project, timeout)
    tasks: set[str] = set()
    for line in str(result.get("output_tail", "")).splitlines():
        if " - " not in line:
            continue
        name = line.split(" - ", 1)[0].strip()
        if name and " " not in name and not name.startswith(">"):
            tasks.add(name)
    return tasks, result


def default_tasks(loader: str, include_client: bool, skip_build: bool) -> list[str]:
    tasks: list[str] = []
    if not skip_build:
        tasks.extend(["test", "runData", "build"])
    if loader in {"fabric", "neoforge", "architectury", "unknown"}:
        tasks.append("runGameTestServer")
    if include_client and loader in {"fabric", "architectury", "unknown"}:
        tasks.append("runClientGameTest")
    return list(dict.fromkeys(tasks))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="Minecraft mod project root.")
    parser.add_argument("--task", action="append", default=[], help="Explicit Gradle task to run. Can be repeated.")
    parser.add_argument("--include-client", action="store_true", help="Include client GameTest tasks when present.")
    parser.add_argument("--skip-build", action="store_true", help="Skip test/runData/build defaults.")
    parser.add_argument("--continue-on-failure", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--report", help="Defaults to <project>/.minecraft-test-report.json")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project = Path(args.project).expanduser().resolve()
    if not project.exists():
        raise SystemExit(f"Project does not exist: {project}")

    loader = detect_loader(project)
    gradle = gradle_command(project)
    report_path = Path(args.report).expanduser().resolve() if args.report else project / ".minecraft-test-report.json"
    report: dict[str, Any] = {
        "project": str(project),
        "loader": loader,
        "available_tasks": [],
        "executed": [],
        "skipped": [],
        "manual_checks": [
            "Launch a client and verify creative tab visibility.",
            "Inspect generated textures/models in inventory and in world.",
            "Place and break each block in a real world.",
            "Start a dedicated server if client-only code changed.",
        ],
    }

    if not gradle:
        report["error"] = "No Gradle wrapper or gradle executable found."
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2

    available, task_list_result = list_tasks(project, gradle, args.timeout_seconds)
    report["task_list"] = task_list_result
    report["available_tasks"] = sorted(available)
    wanted = args.task or default_tasks(loader, args.include_client, args.skip_build)

    exit_code = 0
    for task in wanted:
        if task not in available:
            report["skipped"].append({"task": task, "reason": "Gradle task not available"})
            continue
        result = run(gradle + [task], project, args.timeout_seconds)
        result["task"] = task
        report["executed"].append(result)
        failed = result["timed_out"] or result["exit_code"] not in (0, None)
        if failed:
            exit_code = int(result["exit_code"] or 124)
            if not args.continue_on_failure:
                break

    report["passed"] = exit_code == 0
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
