import unittest
from pathlib import Path


class VakuuStartingRelicTests(unittest.TestCase):
    def test_mod_does_not_patch_character_starting_relics(self):
        source_root = Path(__file__).parents[2] / "sls_vakuu/src/VakuuPlayer"
        self.assertTrue(source_root.is_dir(), f"source root not found: {source_root}")
        offenders = []
        scanned = 0
        for path in source_root.rglob("*.cs"):
            if "bin" in path.parts or "obj" in path.parts:
                continue
            scanned += 1
            content = path.read_text(encoding="utf-8")
            if "HarmonyPatch" in content and "StartingRelics" in content:
                offenders.append(path.relative_to(source_root))

        self.assertGreater(scanned, 0, f"no .cs files scanned under {source_root}")
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
