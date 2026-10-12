#!/usr/bin/env python3
"""Refresh Godot CSV tables without overwriting translations or deleting old keys."""
import argparse
import csv
import io
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
STRING = r'"(?:[^"\\]|\\.)*"'
FIELDS = r'display_name|description|title|text|notification_text|speaker_name|left_name|right_name|tooltip_text'


def decode(value):
    return json.loads(value, strict=False)


def collect():
    groups = {"dialogue": set(), "content": set(), "ui": set()}
    for folder, extension in [("scenes", "*.tscn"), ("resources", "*.tres")]:
        for path in sorted((ROOT / folder).rglob(extension)):
            if folder == "scenes" and path.stem in {"portrait_preview", "conversation_preview"}:
                continue
            group = "ui" if folder == "scenes" else "dialogue" if "conversations" in path.parts else "content"
            source = path.read_text(encoding="utf-8")
            for match in re.finditer(rf'^(?:{FIELDS})\s*=\s*({STRING})', source, re.MULTILINE):
                groups[group].add(decode(match[1]))
            for match in re.finditer(r'enemy_names\s*=.*?\(\{(.*?)\}\)', source, re.DOTALL):
                groups["content"].update(decode(m[1]) for m in re.finditer(rf':\s*({STRING})', match[1]))
    def visit(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key in {"display_name", "description"} and isinstance(child, str):
                    groups["content"].add(child)
                else:
                    visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
    for path in sorted((ROOT / "resources/labyrinths").glob("*.json")):
        visit(json.loads(path.read_text(encoding="utf-8")))
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        if path.stem == "portrait_preview":
            continue
        source = path.read_text(encoding="utf-8")
        patterns = [
            rf'(?:L10n\.text|\btr|TranslationServer\.translate)\(\s*({STRING})',
            rf'\.(?:text|tooltip_text)\s*=\s*({STRING})',
            rf'_command\(\s*({STRING})',
            rf'_(?:label|button)\([^,\n]+,\s*({STRING})',
            rf'_index_button\([^,\n]+,\s*{STRING}\s*,\s*({STRING})',
        ]
        for pattern in patterns:
            groups["ui"].update(decode(m[1]) for m in re.finditer(pattern, source))
        if path.stem == "damage_resistance":
            groups["ui"].update(decode(m[1]) for m in re.finditer(rf'return\s+({STRING})', source))
    # These runtime branches contain source labels rather than direct translation calls.
    groups["ui"].update({"Normal", "Your offer", "Requested goods", "Return", "Resume", "Safe Zone"})
    seen = set()
    for keys in groups.values():
        keys.difference_update(key for key in list(keys) if not key.strip())
        keys.difference_update(seen)
        seen.update(keys)
    return groups


def render(path, keys):
    columns = ["keys", "en"]
    existing = {}
    if path.exists():
        with path.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            columns = reader.fieldnames
            if not columns or columns[:2] != ["keys", "en"]:
                raise ValueError(f"{path}: expected keys,en as first two columns")
            for row in reader:
                if row["keys"] in existing:
                    raise ValueError(f"{path}: duplicate key {row['keys']!r}")
                existing[row["keys"]] = row
    result = io.StringIO(newline="")
    writer = csv.DictWriter(result, columns, lineterminator="\n")
    writer.writeheader()
    for key in sorted(keys | existing.keys()):
        row = existing.get(key, {column: "" for column in columns})
        row["keys"] = key
        row["en"] = key
        writer.writerow(row)
    return result.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check that all extracted text is in the tables")
    args = parser.parse_args()
    changed = False
    for name, keys in collect().items():
        path = ROOT / "localization" / f"{name}.csv"
        output = render(path, keys)
        if not path.exists() or path.read_text(encoding="utf-8") != output:
            changed = True
            if args.check:
                print(f"Needs update: {path.relative_to(ROOT)}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(output, encoding="utf-8", newline="")
        print(f"{name}: {len(keys)} current messages")
    return int(args.check and changed)


if __name__ == "__main__":
    raise SystemExit(main())
