# Translation tables

The game uses Godot's CSV translation importer and `TranslationServer`. English is the source and fallback language. No other languages are shipped yet.

| Table | Contents |
| --- | --- |
| `localization/ui.csv` | Menus, battle commands and logs, stat labels, journal, services, and formatted messages |
| `localization/content.csv` | Character names, titles and descriptions, abilities, classes, equipment, enemies, labyrinths and landmarks |
| `localization/dialogue.csv` | Conversation lines, notifications and speaker name overrides |

Each table starts with `keys,en`. The `keys` column contains stable identifiers, such as `ui.attack`, `content.characters.usami.name`, and `dialogue.station_departure.32.notification_text`. The `en` column contains the English wording. Scene text, resource presentation fields, labyrinth JSON names, and code refer to these identifiers. Gameplay IDs, service routing names, node names, flags, and resource paths remain separate.

## Editing and adding languages

1. Open a CSV in a spreadsheet editor using UTF-8 and comma delimiters. Edit the **en cell** to change English wording; keep its key unchanged. Multiline cells must remain quoted. Changing wording does not require edits to scripts or resources.
2. To add a language, append its Godot locale code as a column, for example `es` or `ja`, and fill in translations. Keep placeholders such as `%s`, `%d`, `%.1f`, and `%%`, including their types, count, and order. Preserve BBCode tags and meaningful line breaks.
3. Open the project in Godot to import the tables. Godot generates files such as `ui.es.translation` beside the CSVs; these generated files are ignored by Git.
4. Check **Project → Project Settings → Localization → Translations** and register the new generated files for all three tables. The English files are already registered in `project.godot`.
5. Preview a locale with `godot --path . --language es`, or set `TranslationServer.set_locale("es")` before opening a screen. There is no player-facing language selector yet. Reopen formatted screens and dialogue after changing locale; active conversation lines are not rebuilt automatically.

For a new message, choose a unique key in the owning table's namespace. Add the row manually, or run:

```bash
python tools/update_translations.py --add ui.example_prompt --english 'Ready to continue?'
```

The command leaves existing English and translated cells intact, and leaves new language cells empty. Existing keys cannot be overwritten with `--add`. The checker never generates keys from English wording, changes existing text, or removes unused rows. Retained messages from older dialogue are available for reuse; delete them manually when no longer needed. Dialogue keys remain stable even if you move a line or rename its subresource.

## Using keys in scenes, resources, and code

Scene `Label`, `Button`, and other translated Control properties use Godot's automatic translation. Set their Text property to a key. For character fields, dialogue Text, Notification Text, and speaker overrides, assign the key in Godot and edit its wording in the CSV. Leave optional fields empty when they should be hidden.

For resource text or strings assembled in code, use:

```gdscript
label.text = L10n.text(character.definition.display_name)
round_counter.text = L10n.text("ui.battle.round_counter") % round_number
```

`L10n.text()` translates a key. Format the translated template **before** inserting names or numbers. Translate each resource name or description used in a template as well. Use whole sentences with placeholders rather than assembling translated sentence fragments. Do not translate gameplay IDs or use translated labels to route actions. Unregistered custom text passes through unchanged, but it has no translation entry; shipped player-facing text should use registered keys.

Validate tables and references after editing:

```bash
python tools/update_translations.py --check
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/translations.gd
python -m unittest discover -s tests -p 'test_translation_tables.py'
```

The checker detects invalid or duplicate keys, missing English text, missing referenced keys, malformed rows, and incompatible format placeholders in nonempty translated cells. Running it without arguments also validates without modifying files.

Images with baked-in text are not translated by these tables. Fonts for additional writing systems may need to be added when those languages are introduced.

Godot reference: [Localization using spreadsheets](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_spreadsheets.html).
