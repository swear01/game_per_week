from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from quit_game import (
    GAME_EXECUTABLE_SUFFIX,
    QUIT_SOURCE,
    compile_quit_helper,
    game_pids,
    request_graceful_quit,
)


class GameShutdownTests(unittest.TestCase):
    def test_compiles_quit_helper_with_timeout(self):
        with tempfile.TemporaryDirectory(prefix="vakuu-test-quit-") as directory:
            binary = Path(directory) / "vakuu-quit-helper"
            with patch("quit_game.QUIT_BINARY", binary), patch("quit_game.subprocess.run") as run:
                compile_quit_helper()

            run.assert_called_once_with(
                ["swiftc", str(QUIT_SOURCE), "-o", str(binary)],
                check=True,
                timeout=120,
            )

    @patch("quit_game.subprocess.check_output")
    def test_only_matches_the_game_executable(self, check_output):
        check_output.return_value = (
            "100 /bin/sh -c echo '/Slay the Spire 2'\n"
            "200 /Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/Slay the Spire 2\n"
            "201 /Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/helper\n"
        )

        self.assertEqual(game_pids(), [200])

    def test_swift_and_python_use_the_same_executable_suffix(self):
        source = QUIT_SOURCE.read_text(encoding="utf-8")

        self.assertIn(f'let gameExecutableSuffix = "{GAME_EXECUTABLE_SUFFIX}"', source)

    @unittest.skipUnless(sys.platform == "darwin", "macOS AppKit helper test")
    def test_compiled_helper_rejects_invalid_and_non_game_processes(self):
        if shutil.which("swiftc") is None:
            self.skipTest("swiftc is required to compile the AppKit helper")
        helper = compile_quit_helper()
        process_table = subprocess.check_output(["ps", "-axo", "pid=,comm="], text=True)
        non_game_app_pid = next(
            (
                line.strip().split(maxsplit=1)[0]
                for line in process_table.splitlines()
                if ".app/Contents/MacOS/" in line
            ),
            None,
        )
        if non_game_app_pid is None:
            self.skipTest("no running macOS application was available for identity rejection")

        cases = [
            (["not-a-pid"], "invalid process id"),
            (["0"], "process not found"),
            ([non_game_app_pid], ("not a Slay the Spire 2 process", "process not found")),
        ]

        for arguments, messages in cases:
            with self.subTest(arguments=arguments):
                result = subprocess.run(
                    [helper, *arguments], capture_output=True, text=True, check=False, timeout=30
                )
                self.assertEqual(result.returncode, 1)
                expected_messages = (messages,) if isinstance(messages, str) else messages
                self.assertTrue(any(message in result.stderr for message in expected_messages))

    @patch("quit_game.wait_for_game_exit", return_value=True)
    @patch("quit_game.compile_quit_helper", return_value=Path("tests/jupyter/artifacts/vakuu-quit-game"))
    @patch("quit_game.game_pids", return_value=[1234])
    @patch("quit_game.subprocess.run")
    def test_requests_normal_application_termination(
        self,
        run,
        game_pids,
        compile_quit_helper,
        wait_for_game_exit,
    ):
        request_graceful_quit([1234])

        compile_quit_helper.assert_called_once_with()
        run.assert_called_once_with(
            [Path("tests/jupyter/artifacts/vakuu-quit-game"), "1234"],
            check=True,
            timeout=30,
        )
        wait_for_game_exit.assert_called_once_with([1234])
        game_pids.assert_called_once_with()

    @patch("quit_game.compile_quit_helper", return_value=Path("tests/jupyter/artifacts/vakuu-quit-game"))
    @patch("quit_game.game_pids", side_effect=[[1234], []])
    @patch("quit_game.subprocess.run", side_effect=subprocess.CalledProcessError(1, "helper"))
    def test_treats_process_exit_during_helper_failure_as_success(
        self,
        run,
        game_pids,
        compile_quit_helper,
    ):
        request_graceful_quit([1234])

        run.assert_called_once()
        self.assertEqual(game_pids.call_count, 2)


if __name__ == "__main__":
    unittest.main()
