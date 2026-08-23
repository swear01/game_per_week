import unittest
from pathlib import Path


class VakuuStartingRelicTests(unittest.TestCase):
    def test_mod_does_not_patch_character_starting_relics(self):
        source_root = Path(__file__).parents[2] / "sls_vakuu/src/VakuuPlayer"
        offenders = [
            path.relative_to(source_root)
            for path in source_root.rglob("*.cs")
            if "HarmonyPatch" in path.read_text() and "StartingRelics" in path.read_text()
        ]

        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
