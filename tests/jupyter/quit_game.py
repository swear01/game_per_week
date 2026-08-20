from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path


GAME_PROCESS_MARKER = "/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/"
QUIT_SOURCE = Path(__file__).with_name("quit_game.swift")
QUIT_BINARY = Path(__file__).with_name("artifacts") / "vakuu-quit-game"


def game_pids() -> list[int]:
    output = subprocess.check_output(
        ["ps", "-axo", "pid=,comm="], text=True, timeout=10
    )
    pids = []
    for line in output.splitlines():
        pid_text, _, command = line.strip().partition(" ")
        if pid_text.isdigit() and GAME_PROCESS_MARKER in command:
            pids.append(int(pid_text))
    return pids


def compile_quit_helper() -> Path:
    QUIT_BINARY.parent.mkdir(parents=True, exist_ok=True)
    if not QUIT_BINARY.exists() or QUIT_BINARY.stat().st_mtime < QUIT_SOURCE.stat().st_mtime:
        subprocess.run(
            ["swiftc", str(QUIT_SOURCE), "-o", str(QUIT_BINARY)],
            check=True,
            timeout=120,
        )
    return QUIT_BINARY


def wait_for_game_exit(pids: list[int], timeout: int = 30) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        active = set(game_pids()).intersection(pids)
        if not active:
            return True
        time.sleep(0.5)
    return not set(game_pids()).intersection(pids)


def request_graceful_quit(pids: list[int]) -> None:
    active = [pid for pid in pids if pid in game_pids()]
    if not active:
        return

    helper = compile_quit_helper()
    last_error: Exception | None = None
    for _ in range(2):
        try:
            subprocess.run(
                [helper, *(str(pid) for pid in active)], check=True, timeout=30
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            last_error = error
            time.sleep(1)
            active = [pid for pid in active if pid in game_pids()]
            if not active:
                return
            continue

        if wait_for_game_exit(active):
            return
        active = [pid for pid in active if pid in game_pids()]
        if not active:
            return

    detail = f"; last helper error: {last_error}" if last_error else ""
    raise RuntimeError(
        f"Slay the Spire 2 did not exit gracefully after two termination attempts; refusing forced termination{detail}"
    )


def main() -> int:
    pids = game_pids()
    if not pids:
        return 0
    request_graceful_quit(pids)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"graceful game shutdown failed: {error}", file=sys.stderr)
        raise
