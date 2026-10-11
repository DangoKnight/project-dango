# Translation tables

The game uses Godot's CSV translation importer and `TranslationServer`. English is the source and fallback language. No other languages are shipped yet.

| Table | Contents |
| --- | --- |
| `localization/ui.csv` | Menus, battle commands and logs, stat labels, journal, services, and formatted messages |
| `localization/content.csv` | Character names, titles and descriptions, abilities, classes, equipment, enemies, labyrinths and landmarks |
| `localization/dialogue.csv` | Conversation lines and speaker name overrides |

Each table starts with `keys,en`. The original English text is the lookup key and the English value. This keeps resources readable in Godot and gives untranslated entries a readable fallback. Names and descriptions are translated when displayed; resource IDs, service names used for routing, flags, and saved knowledge stay unchanged.

## Editing and adding languages

1. Open a CSV in a spreadsheet editor using UTF-8 and comma delimiters. Multiline cells must remain quoted. Do not edit the `keys` column to translate a message.
2. To add a language, append its Godot locale code as a column, for example `es` or `ja`, and fill in translations. Keep placeholders such as `%s`, `%d`, `%.1f`, and `%%`, including their types, count, and order. Preserve BBCode tags and meaningful line breaks.
3. Open the project in Godot to import the tables. Godot generates files such as `ui.es.translation` beside the CSVs; these generated files are ignored by Git.
4. Check **Project → Project Settings → Localization → Translations** and register the new generated files for all three tables. The English files are already registered in `project.godot`.
5. Preview a locale with `godot --path . --language es`, or set `TranslationServer.set_locale("es")` before opening a screen. There is no player-facing language selector yet. Existing formatted screens and dialogue should be reopened after changing locale; the setup does not rebuild an active conversation mid-line.

Changing source English requires changing the original scene/resource/script text and refreshing the tables. Keep translated columns for other languages intact. Old keys are retained by the updater so authored translations are not silently discarded; remove unused rows manually when appropriate.

## Adding text in code

Scene `Label`, `Button`, and other translated Control properties use Godot's automatic translation. For resource text or strings assembled in code, use:

```gdscript
label.text = L10n.text(character.definition.display_name)
round_counter.text = L10n.text("Round %d") % round_number
```

`L10n.text()` is a small static wrapper around `TranslationServer.translate()`, usable from both Nodes and static information builders. Translate the template **before** inserting names or numbers. Translate each resource name or description passed into the template as well. Use whole sentences with placeholders rather than assembling translated sentence fragments. Do not translate IDs or use translated labels to route actions.

After adding or editing text, run from the project folder:

```bash
python tools/update_translations.py
python tools/update_translations.py --check
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/translations.gd
```

The updater collects scene text, resource fields, labyrinth JSON names, literal `L10n.text()`/`tr()` calls, and the existing UI helper calls. It preserves extra language columns and their values. For a new system that builds source strings indirectly, add explicit literal translation calls or extend the extraction rules in `tools/update_translations.py`.

Images with baked-in text are not translated by these tables. Fonts for additional writing systems may need to be added when those languages are introduced.

Godot reference: [Localization using spreadsheets](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html).
