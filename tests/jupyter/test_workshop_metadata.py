from __future__ import annotations

import json
import unittest
from pathlib import Path


WORKSHOP = Path(__file__).parents[2] / "sls_vakuu/deploy/VakuuPlayer/workshop.json"


class WorkshopMetadataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(WORKSHOP.read_text(encoding="utf-8"))
        cls.localizations = cls.data["localizations"]

    def test_top_level_fallback_is_english_only(self):
        self.assertEqual(self.data["description"], self.localizations["english"]["description"])
        self.assertIn("Features", self.data["description"])
        self.assertNotIn("特色", self.data["description"])
        self.assertNotIn("連結", self.data["description"])

    def test_each_language_contains_only_its_own_copy(self):
        english = self.localizations["english"]["description"]
        simplified = self.localizations["schinese"]["description"]
        traditional = self.localizations["tchinese"]["description"]

        for description in (english, simplified, traditional):
            self.assertNotIn("[url=", description)
            self.assertNotIn("https://", description)

        self.assertIn("Features", english)
        self.assertNotIn("特色", english)
        self.assertNotIn("链接", english)
        self.assertIn("特色", simplified)
        self.assertNotIn("链接", simplified)
        self.assertNotIn("Features", simplified)
        self.assertNotIn("連結", simplified)
        self.assertIn("特色", traditional)
        self.assertNotIn("連結", traditional)
        self.assertNotIn("Features", traditional)
        self.assertNotIn("链接", traditional)

    def test_workshop_remains_public(self):
        self.assertEqual(self.data["visibility"], "public")


if __name__ == "__main__":
    unittest.main()
