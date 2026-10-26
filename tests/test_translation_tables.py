"""Translation maintenance must preserve message identity and authored language cells."""
import contextlib
import csv
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("translation_tables", Path(__file__).resolve().parents[1] / "tools/update_translations.py")
tables = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tables)


class TranslationTableTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "localization").mkdir()
        for category in tables.TABLES:
            self.write(category, [])
        self.patch = patch.object(tables, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def write(self, category, rows):
        with (self.root / "localization" / f"{category}.csv").open("w", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(["keys", "en", "es"])
            writer.writerows(rows)

    def run_tool(self, *args):
        with patch("sys.argv", ["update_translations.py", *args]), contextlib.redirect_stdout(io.StringIO()):
            return tables.main()

    def test_english_edits_and_other_languages_survive_maintenance(self):
        self.write("ui", [["ui.attack", "Strike!\nNow!", "¡Ataca!"]])
        path = self.root / "localization/ui.csv"
        original = path.read_bytes()
        self.assertEqual(self.run_tool("--check"), 0)
        self.assertEqual(path.read_bytes(), original)
        self.assertEqual(self.run_tool("--add", "ui.defend", "--english", "Brace!"), 0)
        messages = {row["keys"]: row for row in tables.read_tables()["ui"][1]}
        self.assertEqual(messages["ui.attack"]["en"], "Strike!\nNow!")
        self.assertEqual(messages["ui.attack"]["es"], "¡Ataca!")
        self.assertEqual(messages["ui.defend"]["es"], "")
        self.assertEqual(self.run_tool("--add", "ui.attack", "--english", "Overwrite"), 1)

    def test_invalid_keys_references_and_placeholders_are_rejected(self):
        self.write("ui", [["ui.attack", "Attack %s", "Atacar %d"], ["ui.attack", "Duplicate", ""]])
        self.assertEqual(self.run_tool("--check"), 1)
        self.write("ui", [["Attack", "Attack", ""]])
        self.assertEqual(self.run_tool("--check"), 1)
        self.write("ui", [])
        (self.root / "scripts").mkdir()
        (self.root / "scripts/test.gd").write_text('var prompt = L10n.text("ui.missing")\n')
        self.assertEqual(self.run_tool("--check"), 1)


if __name__ == "__main__":
    unittest.main()
