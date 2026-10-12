# Texture organization

| Folder | Contents |
| --- | --- |
| `Characters/<Name>/` | Active character portraits, grouped by character |
| `NPCs/Enemies/` | Monster sprites shared by enemy resources |
| `NPCs/Station_45B/<Service>/` | Station 45-B NPC artwork, grouped by service |
| `Backgrounds/SafeZones/` | Shared safe zone and service room backgrounds |
| `Backgrounds/Menus/` | Main menu and options backgrounds |
| `Backgrounds/Battle/` | Combat backgrounds |
| `Environments/Labyrinth/` | Repeating wall, ground and ceiling textures |
| `UI/` | Shared UI artwork, including the fallback portrait |
| `battle_fx/` | Imported battle effect packs, credits and frame mappings |

Reuse `Backgrounds/SafeZones/` across safe zones. NPCs vary by safe zone: add
new station folders under `NPCs/`, following `NPCs/Station_45B/<Service>/`.
Keep active portraits grouped by character, and keep backgrounds separate
from NPC sprites. Add distinct labyrinth environments as sibling folders.
Art prompts in `docs/art_prompts.json` use the current asset paths.

Move or rename imported assets through Godot's FileSystem dock so resource
references update with them. Keep each `.import` sidecar with its image to
preserve its UID and import settings. `textures.old/` at the project root holds
archived art and editor backups; it is excluded from imports and version control.

Unused full-body character artwork is archived in
`textures.old/2026-10-11-unused-full-body-art/`, with original import settings and
a checksum manifest. The complete BDragon pack remains available for authoring new
battle effects, including sheets not yet assigned to abilities.
