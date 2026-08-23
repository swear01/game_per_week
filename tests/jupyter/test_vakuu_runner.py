from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from vakuu_test import (
    LIVE_STEPS,
    backup_account_state,
    collect_harness_screenshots,
    configure_test_mods,
    restore_account_state,
)


class VakuuRunnerTests(unittest.TestCase):
    def test_live_steps_capture_the_release_story_in_order(self):
        self.assertEqual(
            LIVE_STEPS,
            (
                ("[VakuuHarness] Vakuu event ready; relics=1", "01-native-starting-relic.png"),
                ("[VakuuHarness] Preserved Fog selection visible", "02-preserved-fog.png"),
                ("[VakuuHarness] Accept complete; relics=11", "03-native-plus-vakuu-relics.png"),
                ("[VakuuHarness] first combat room entered", None),
                ("[VakuuHarness] auto-played card=", "04-auto-play.png"),
            ),
        )

    def test_harness_guards_run_start_reentrancy(self):
        source = (Path(__file__).with_name("VakuuHarness") / "Harness.cs").read_text(encoding="utf-8")

        self.assertIn("Interlocked.Exchange(ref _runStartRequested, 1)", source)
        self.assertIn("tree.Root.GetTexture().GetImage()", source)
        self.assertIn("SavePng", source)

    def test_collects_native_viewport_screenshots_from_log(self):
        with tempfile.TemporaryDirectory(prefix="vakuu-screenshots-") as directory:
            root = Path(directory)
            source = root / "source"
            destination = root / "destination"
            source.mkdir()
            lines = []
            for index, (_, name) in enumerate(LIVE_STEPS):
                if name is None:
                    continue
                image = source / name
                image.write_bytes(f"png-{index}".encode())
                lines.append(f"[VakuuHarness] screenshot saved name={name} path={image}")
            log = root / "godot.log"
            log.write_text("\n".join(lines), encoding="utf-8")

            collect_harness_screenshots(log, destination)

            for index, (_, name) in enumerate(LIVE_STEPS):
                if name is not None:
                    self.assertEqual((destination / name).read_bytes(), f"png-{index}".encode())

    def test_enables_only_local_vakuu_and_harness(self):
        data = {
            "mod_settings": {
                "mod_list": [
                    {"id": "OtherMod", "is_enabled": True, "source": "steam_workshop"},
                    {"id": "VakuuPlayer", "is_enabled": True, "source": "steam_workshop"},
                    {"id": "VakuuPlayer", "is_enabled": False, "source": "mods_directory"},
                    {"id": "VakuuHarness", "is_enabled": False, "source": "mods_directory"},
                ]
            }
        }

        configure_test_mods(data)

        enabled = {
            (entry["id"], entry["source"])
            for entry in data["mod_settings"]["mod_list"]
            if entry["is_enabled"]
        }
        self.assertEqual(
            enabled,
            {("VakuuPlayer", "mods_directory"), ("VakuuHarness", "mods_directory")},
        )

    def test_restores_account_state_and_removes_test_created_files(self):
        with tempfile.TemporaryDirectory(prefix="vakuu-runner-") as directory:
            root = Path(directory)
            account = root / "account"
            backup = root / "backup"
            saves = account / "profile1/saves"
            saves.mkdir(parents=True)
            (account / "settings.save").write_text("original settings", encoding="utf-8")
            (saves / "progress.save").write_text("original progress", encoding="utf-8")

            backup_account_state(account, backup)
            (account / "settings.save").write_text("test settings", encoding="utf-8")
            (saves / "progress.save").unlink()
            (saves / "current_run.save").write_text("test run", encoding="utf-8")
            modded_saves = account / "modded/profile1/saves"
            modded_saves.mkdir(parents=True)
            (modded_saves / "current_run.save").write_text("test modded run", encoding="utf-8")

            restore_account_state(account, backup)

            self.assertEqual((account / "settings.save").read_text(encoding="utf-8"), "original settings")
            self.assertEqual((saves / "progress.save").read_text(encoding="utf-8"), "original progress")
            self.assertFalse((saves / "current_run.save").exists())
            self.assertFalse((account / "modded/profile1").exists())

    def test_handles_deck_selection_before_waiting_for_event_choice(self):
        source = (Path(__file__).with_name("VakuuHarness") / "Harness.cs").read_text(encoding="utf-8")

        self.assertLess(
            source.index("var selection = FindNode<NDeckCardSelectScreen>(root);"),
            source.index("if (_optionTask != null)"),
        )


if __name__ == "__main__":
    unittest.main()
