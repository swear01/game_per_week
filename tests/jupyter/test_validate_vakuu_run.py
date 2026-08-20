from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from validate_vakuu_run import validate_log


class VakuuRunValidationTests(unittest.TestCase):
    def write_log(self, final: str) -> Path:
        lines = [
            "[VakuuHarness] attached",
            "[VakuuHarness] confirming first 3 snapshot cards",
            "[VakuuHarness] starting Vakuu relics=10",
            "BLOOD_SOAKED_ROSE FIDDLE PRESERVED_FOG SERE_TALON DISTINGUISHED_CAPE CHOICES_PARADOX MUSIC_BOX LORDS_PARASOL JEWELED_MASK VAKUU_CONTRACT",
            "[VakuuHarness] first combat room entered",
            "[VakuuHarness] auto-phase turn=1",
            "[VakuuHarness] auto-played card=STRIKE turn=1",
            "[VakuuHarness] ending first player turn to test next turn",
            "[VakuuHarness] player control returned; end-turn issued",
            "[VakuuHarness] auto-phase turn=2",
            "[VakuuHarness] auto-played card=DEFEND turn=2",
            f"[VakuuHarness] FINAL {final}",
        ]
        handle = tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", delete=False)
        handle.write("\n".join(lines))
        handle.close()
        return Path(handle.name)

    def test_accepts_valid_final_assertions(self):
        path = self.write_log("firstCombatAutoPlayCount=2 distinctAutoPlayTurns=1,2 thirdActVakuuPresent=True")
        self.assertEqual(validate_log(path)["auto_play_count"], 2)
        path.unlink()

    def test_rejects_missing_act_three_result(self):
        path = self.write_log("firstCombatAutoPlayCount=2 distinctAutoPlayTurns=1,2")
        with self.assertRaises(AssertionError):
            validate_log(path)
        path.unlink()


if __name__ == "__main__":
    unittest.main()
