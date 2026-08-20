from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from quit_game import QUIT_SOURCE, compile_quit_helper, game_pids, request_graceful_quit


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
        )

        self.assertEqual(game_pids(), [200])

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
