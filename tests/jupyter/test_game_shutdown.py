from __future__ import annotations

import subprocess
import unittest
from pathlib import Path
from unittest.mock import patch

from quit_game import request_graceful_quit


class GameShutdownTests(unittest.TestCase):
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
