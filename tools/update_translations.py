#!/usr/bin/env python3
"""Validate stable translation keys, or add a new English message without rewriting tables."""
import argparse
import csv
import io
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TABLES = ("ui", "content", "dialogue")
KEY = re.compile(r"^(ui|content|dialogue)\.[a-z0-9_]+(?:\.[a-z0-9_]+)*$")
REFERENCE = re.compile(r'["\']((?:ui|content|dialogue)\.[^"\'\n]+)["\']')
PLACEHOLDER = re.compile(r'%(?:\d+\$)?[-+0 #]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[sdifFeEgGxXoc]')


def read_tables():
    tables = {}
    for name in TABLES:
        path = ROOT / "localization" / f"{name}.csv"
        with path.open(encoding="utf-8", newline="") as stream:
            reader = csv.DictReader(stream)
            columns = reader.fieldnames
            if not columns or columns[:2] != ["keys", "en"] or len(set(columns)) != len(columns):
                raise ValueError(f"{path}: expected unique columns starting with keys,en")
            tables[name] = (columns, list(reader))
    return tables


def validate(tables):
    messages = {}
    errors = []
    for name, (columns, rows) in tables.items():
        for row in rows:
            key = row.get("keys", "")
            if not KEY.fullmatch(key) or not key.startswith(name + "."):
                errors.append(f"{name}.csv: invalid key {key!r}")
            if key in messages:
                errors.append(f"Duplicate translation key: {key}")
            if None in row or any(row.get(column) is None for column in columns):
                errors.append(f"{key}: malformed CSV row")
            english = row.get("en") or ""
            if not english.strip():
                errors.append(f"{key}: English text must not be empty")
            messages[key] = english
            for locale in columns[2:]:
                translated = row.get(locale) or ""
                if translated and PLACEHOLDER.findall(translated.replace('%%', '')) != PLACEHOLDER.findall(english.replace('%%', '')):
                    errors.append(f"{key}: {locale} placeholders differ from English")
        print(f"{name}: {len(rows)} messages")
    for directory in ("scripts", "scenes", "resources"):
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix not in {".gd", ".tscn", ".tres", ".json"}:
                continue
            for key in REFERENCE.findall(path.read_text(encoding="utf-8")):
                if not KEY.fullmatch(key):
                    errors.append(f"{path.relative_to(ROOT)}: invalid translation key {key}")
                elif key not in messages:
                    errors.append(f"{path.relative_to(ROOT)}: missing translation {key}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate without modifying files (also the default)")
    parser.add_argument("--add", metavar="KEY", help="Add a stable key, e.g. ui.new_game")
    parser.add_argument("--english", help="English text for --add; other language columns stay empty")
    args = parser.parse_args()
    if args.add and (args.check or args.english is None or not KEY.fullmatch(args.add)):
        parser.error("--add requires a valid namespaced key and --english, without --check")
    if args.english is not None and not args.add:
        parser.error("--english requires --add")
    try:
        tables = read_tables()
        if args.add:
            name = args.add.split(".")[0]
            columns, rows = tables[name]
            if any(row["keys"] == args.add for _, all_rows in tables.values() for row in all_rows):
                raise ValueError(f"Key already exists: {args.add}; edit its English cell in the CSV")
            rows.append({**{column: "" for column in columns}, "keys": args.add, "en": args.english})
        errors = validate(tables)
        if errors:
            for error in errors:
                print(error)
            return 1
        if args.add:
            output = io.StringIO(newline="")
            writer = csv.DictWriter(output, columns, lineterminator="\n")
            writer.writeheader()
            writer.writerows(sorted(rows, key=lambda row: row["keys"]))
            (ROOT / "localization" / f"{name}.csv").write_text(output.getvalue(), encoding="utf-8", newline="")
        return 0
    except (ValueError, OSError) as error:
        print(error)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
