from __future__ import annotations

import json
import os
import re
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
LIVE_STEPS = (
    ("[VakuuHarness] Vakuu event ready; relics=1", "01-native-starting-relic.png"),
    ("[VakuuHarness] Preserved Fog selection visible", "02-preserved-fog.png"),
    ("[VakuuHarness] Accept complete; relics=11", "03-native-plus-vakuu-relics.png"),
    ("[VakuuHarness] first combat room entered", None),
    ("[VakuuHarness] auto-played card=", "04-auto-play.png"),
)
ACCOUNT_STATE_PATHS = (
    Path("settings.save"),
    Path("settings.save.backup"),
    Path("profile.save"),
    Path("profile.save.backup"),
    Path("profile1"),
    Path("modded/profile.save"),
    Path("modded/profile.save.backup"),
    Path("modded/profile1"),
)


@dataclass
class TestSession:
    settings_path: Path
    account_dir: Path
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


def backup_account_state(account_dir: Path, backup_dir: Path) -> None:
    backup_dir.mkdir(parents=True, exist_ok=True)
    for relative in ACCOUNT_STATE_PATHS:
        source = account_dir / relative
        target = backup_dir / relative
        if source.is_dir():
            shutil.copytree(source, target)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def restore_account_state(account_dir: Path, backup_dir: Path) -> None:
    for relative in ACCOUNT_STATE_PATHS:
        source = backup_dir / relative
        target = account_dir / relative
        if target.is_dir():
            shutil.rmtree(target)
        elif target.exists():
            target.unlink()
        if source.is_dir():
            shutil.copytree(source, target)
        elif source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def configure_test_mods(data: dict[str, object]) -> None:
    mod_list = data["mod_settings"]["mod_list"]
    wanted = {("VakuuPlayer", "mods_directory"), ("VakuuHarness", "mods_directory")}
    seen = set()
    for entry in mod_list:
        key = (entry.get("id"), entry.get("source"))
        entry["is_enabled"] = key in wanted
        if key in wanted:
            seen.add(key)
    for mod_id, source in sorted(wanted - seen):
        mod_list.append({"id": mod_id, "is_enabled": True, "source": source})

    indexes = {entry.get("id"): index for index, entry in enumerate(mod_list)}
    vakuu_index = indexes.get("VakuuPlayer")
    harness_index = indexes.get("VakuuHarness")
    if vakuu_index is not None and harness_index is not None and vakuu_index > harness_index:
        mod_list[vakuu_index], mod_list[harness_index] = mod_list[harness_index], mod_list[vakuu_index]


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
    account_dir = settings.parent
    backup_account_state(account_dir, backup_dir / "account")
    if LOG_PATH.exists():
        shutil.copy2(LOG_PATH, backup_dir / "godot.log")
        LOG_PATH.write_text("", encoding="utf-8")

    return TestSession(settings, account_dir, backup_dir, [], screenshots_dir, artifacts_dir)


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
    configure_test_mods(data)
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


def collect_harness_screenshots(log_path: Path, destination: Path) -> None:
    matches = re.findall(
        r"^\[VakuuHarness\] screenshot saved name=(\S+) path=(.+)$",
        log_path.read_text(encoding="utf-8", errors="replace"),
        re.MULTILINE,
    )
    sources = {name: Path(path) for name, path in matches}
    expected = [name for _, name in LIVE_STEPS if name is not None]
    missing = [name for name in expected if name not in sources]
    if missing:
        raise RuntimeError(f"harness screenshots missing from log: {missing}")

    destination.mkdir(parents=True, exist_ok=True)
    for name in expected:
        source = sources[name]
        if not source.is_file() or source.stat().st_size == 0:
            raise RuntimeError(f"harness screenshot was not created: {source}")
        shutil.copy2(source, destination / name)


def wait_for_marker(
    session: TestSession,
    marker: str,
    timeout: int = 600,
) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        text = LOG_PATH.read_text(encoding="utf-8", errors="replace") if LOG_PATH.exists() else ""
        failure_marker = "[VakuuHarness] failed:"
        if failure_marker in text:
            tail = text[-4000:]
            raise RuntimeError(f"harness reported failure while waiting for {marker!r}\n{tail}")
        if marker in text:
            return
        time.sleep(2)
    tail = text[-4000:] if "text" in locals() else ""
    raise TimeoutError(f"timed out waiting for {marker!r}\n{tail}")


def finish(session: TestSession) -> dict[str, object]:
    wait_for_marker(session, "[VakuuHarness] Neow dialogue visible")
    wait_for_marker(session, "[VakuuHarness] FINAL ")
    collect_harness_screenshots(LOG_PATH, session.screenshots_dir)
    shutil.copy2(LOG_PATH, session.artifacts_dir / "godot.log")
    return validate_log(session.artifacts_dir / "godot.log")


def cleanup(session: TestSession) -> None:
    request_graceful_quit(session.pids)

    harness_mod = MOD_ROOT / "VakuuHarness"
    if harness_mod.exists():
        shutil.rmtree(harness_mod)
    restore_account_state(session.account_dir, session.backup_dir / "account")
    log_backup = session.backup_dir / "godot.log"
    if log_backup.exists():
        shutil.copy2(log_backup, LOG_PATH)


def run_test() -> dict[str, object]:
    session = prepare()
    try:
        build()
        deploy_and_enable(session)
        launch(session)
        for marker, _ in LIVE_STEPS:
            wait_for_marker(session, marker)
        return finish(session)
    finally:
        if LOG_PATH.exists():
            shutil.copy2(LOG_PATH, session.artifacts_dir / "godot-raw.log")
        cleanup(session)
