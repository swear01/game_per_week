from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ReviewContractTests(unittest.TestCase):
    def test_preserved_fog_prefix_converts_unexpected_errors_to_faulted_task(self):
        source = (ROOT / "sls_vakuu/src/VakuuPlayer/Patches/PreservedFogObtainPatch.cs").read_text()

        self.assertIn("catch (Exception e)", source)
        self.assertIn("__result = Task.FromException(e);", source)

    def test_localization_validates_exact_inserted_keys(self):
        source = (ROOT / "sls_vakuu/src/VakuuPlayer/Patches/LocOverridesPatch.cs").read_text()

        self.assertIn("table.IsLocalKey(key)", source)


if __name__ == "__main__":
    unittest.main()
