from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from quit_game import game_pids, request_graceful_quit
from validate_vakuu_run import validate_log


REPO_ROOT = Path(__file__).resolve().parents[2]
ROOT = REPO_ROOT / "sls_vakuu"
GAME_APP = Path.home() / "Library/Application Support/Steam/steamapps/common/Slay the Spire 2/SlayTheSpire2.app"
MOD_ROOT = GAME_APP / "Contents/MacOS/mods"
LOG_PATH = Path.home() / "Library/Application Support/SlayTheSpire2/logs/godot.log"
SAVE_ROOT = Path.home() / "Library/Application Support/SlayTheSpire2/steam"
WINDOW_ID_SOURCE = REPO_ROOT / "tests/jupyter/window_id.swift"
WINDOW_ID_BINARY = REPO_ROOT / "tests/jupyter/artifacts/vakuu-window-id"


@dataclass
class TestSession:
    settings_path: Path
    backup_dir: Path
    pids: list[int]
    screenshots_dir: Path
    artifacts_dir: Path


def run(command: list[str]) -> None:
    print("$", " ".join(command))
    env = os.environ.copy()
    env["PATH"] = f"{Path.home() / '.dotnet'}:{env.get('PATH', '')}"
    subprocess.run(command, cwd=ROOT, check=True, env=env)


def settings_path() -> Path:
    paths = sorted(SAVE_ROOT.glob("*/settings.save"))
    if len(paths) != 1:
        raise RuntimeError(f"expected exactly one settings.save, found {len(paths)}: {paths}")
    return paths[0]


def build() -> None:
    run(["dotnet", "build", "-c", "Release", "src/VakuuPlayer/VakuuPlayer.csproj"])
    run(["dotnet", "build", "-c", "Release", str(REPO_ROOT / "tests/jupyter/VakuuHarness/VakuuHarness.csproj")])


def prepare() -> TestSession:
    existing = game_pids()
    if existing:
        raise RuntimeError(f"Slay the Spire 2 is already running: {existing}")
    if not GAME_APP.exists():
        raise FileNotFoundError(GAME_APP)

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = Path("/private/tmp") / f"vakuu-jupyter-test-{stamp}"
    artifacts_dir = REPO_ROOT / "tests/jupyter/artifacts"
    screenshots_dir = ROOT / "assets/screenshots"
    backup_dir.mkdir(parents=True)
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    screenshots_dir.mkdir(parents=True, exist_ok=True)

    settings = settings_path()
    shutil.copy2(settings, backup_dir / "settings.save")
    progress = settings.parent / "saves/progress.save"
    if progress.exists():
        shutil.copy2(progress, backup_dir / "progress.save")
    if LOG_PATH.exists():
        shutil.copy2(LOG_PATH, backup_dir / "godot.log")
        LOG_PATH.write_text("", encoding="utf-8")

    return TestSession(settings, backup_dir, [], screenshots_dir, artifacts_dir)


def deploy_and_enable(session: TestSession) -> None:
    local_mod = MOD_ROOT / "VakuuPlayer"
    harness_mod = MOD_ROOT / "VakuuHarness"
    local_mod.mkdir(parents=True, exist_ok=True)
    harness_mod.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "src/VakuuPlayer/bin/Release/net9.0/VakuuPlayer.dll", local_mod / "VakuuPlayer.dll")
    shutil.copy2(ROOT / "deploy/VakuuPlayer/content/VakuuPlayer.json", local_mod / "VakuuPlayer.json")
    shutil.copy2(REPO_ROOT / "tests/jupyter/VakuuHarness/bin/Release/net9.0/VakuuHarness.dll", harness_mod / "VakuuHarness.dll")
    shutil.copy2(REPO_ROOT / "tests/jupyter/VakuuHarness/VakuuHarness.json", harness_mod / "VakuuHarness.json")

    data = json.loads(session.settings_path.read_text(encoding="utf-8"))
    mod_list = data["mod_settings"]["mod_list"]
    wanted = {("VakuuPlayer", "mods_directory"), ("VakuuHarness", "mods_directory")}
    seen = set()
    for entry in mod_list:
        key = (entry.get("id"), entry.get("source"))
        if key in wanted:
            entry["is_enabled"] = True
            seen.add(key)
    for mod_id, source in sorted(wanted - seen):
        mod_list.append({"id": mod_id, "is_enabled": True, "source": source})
    session.settings_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def launch(session: TestSession) -> None:
    run(["open", "steam://rungameid/2868840"])
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        pids = game_pids()
        if pids:
            session.pids = pids
            subprocess.run(["open", "-a", str(GAME_APP)], check=True)
            time.sleep(2)
            return
        time.sleep(2)
    raise TimeoutError("game process did not start within 90 seconds")


def capture(session: TestSession, name: str) -> Path:
    path = session.screenshots_dir / name
    if not WINDOW_ID_BINARY.exists() or WINDOW_ID_BINARY.stat().st_mtime < WINDOW_ID_SOURCE.stat().st_mtime:
        run(["swiftc", str(WINDOW_ID_SOURCE), "-o", str(WINDOW_ID_BINARY)])

    path.unlink(missing_ok=True)
    for attempt in range(5):
        window_id = subprocess.check_output([str(WINDOW_ID_BINARY)], text=True).strip()
        if not window_id.isdigit():
            raise RuntimeError("Slay the Spire 2 window is not visible")
        try:
            run(["/usr/sbin/screencapture", "-x", "-l", window_id, str(path)])
        except subprocess.CalledProcessError:
            if attempt < 4:
                time.sleep(2)
                continue
            raise
        if not path.exists() or path.stat().st_size == 0:
            raise RuntimeError(f"screenshot was not created: {path}")
        return path

    raise RuntimeError(f"screenshot was not created: {path}")


def wait_for_marker(session: TestSession, marker: str, screenshot_name: str | None = None, timeout: int = 600) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        text = LOG_PATH.read_text(encoding="utf-8", errors="replace") if LOG_PATH.exists() else ""
        failure_marker = "[VakuuHarness] failed:"
        if failure_marker in text:
            tail = text[-4000:]
            raise RuntimeError(f"harness reported failure while waiting for {marker!r}\n{tail}")
        if marker in text:
            if screenshot_name is not None:
                capture(session, screenshot_name)
            return
        time.sleep(2)
    tail = text[-4000:] if "text" in locals() else ""
    raise TimeoutError(f"timed out waiting for {marker!r}\n{tail}")


def finish(session: TestSession) -> dict[str, object]:
    wait_for_marker(session, "[VakuuHarness] FINAL ", "05-final.png")
    shutil.copy2(LOG_PATH, session.artifacts_dir / "godot.log")
    return validate_log(session.artifacts_dir / "godot.log")


def cleanup(session: TestSession) -> None:
    request_graceful_quit(session.pids)

    harness_mod = MOD_ROOT / "VakuuHarness"
    if harness_mod.exists():
        shutil.rmtree(harness_mod)
    shutil.copy2(session.backup_dir / "settings.save", session.settings_path)
    progress_backup = session.backup_dir / "progress.save"
    if progress_backup.exists():
        shutil.copy2(progress_backup, session.settings_path.parent / "saves/progress.save")
    log_backup = session.backup_dir / "godot.log"
    if log_backup.exists():
        shutil.copy2(log_backup, LOG_PATH)


def run_test() -> dict[str, object]:
    session = prepare()
    try:
        build()
        deploy_and_enable(session)
        launch(session)
        wait_for_marker(session, "[VakuuHarness] starting Vakuu relics=10", "01-relics.png")
        wait_for_marker(session, "[VakuuHarness] confirming first 3 snapshot cards", "02-preserved-fog.png")
        wait_for_marker(session, "[VakuuHarness] first combat room entered", "03-first-combat.png")
        wait_for_marker(session, "[VakuuHarness] auto-phase turn=1", "04-auto-turn-1.png")
        return finish(session)
    finally:
        if LOG_PATH.exists():
            shutil.copy2(LOG_PATH, session.artifacts_dir / "godot-raw.log")
        cleanup(session)
