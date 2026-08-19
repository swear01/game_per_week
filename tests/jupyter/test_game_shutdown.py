from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from quit_game import request_graceful_quit


class GameShutdownTests(unittest.TestCase):
    @patch("quit_game.wait_for_game_exit", return_value=True)
    @patch("quit_game.compile_quit_helper", return_value=Path("/private/tmp/vakuu-quit-game"))
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
            [Path("/private/tmp/vakuu-quit-game"), "1234"],
            check=True,
        )
        wait_for_game_exit.assert_called_once_with([1234])
        game_pids.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
