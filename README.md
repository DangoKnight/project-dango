# Project Negi

A Godot 4.7 game prototype. Import `project.godot` in the Godot Project Manager, open the project, and press **F5** to play. `scenes/main.tscn` is the configured main scene.

- **New Game** opens the Safe Zone, with Barracks, Tinkerer, Chemist, and Enter the Labyrinth buttons on the right.
- The Safe Zone navigation card slides in from the right and stays visible while modules are open. Module cards slide in from the left and slide out when closed. Barracks and Manage Party slide out before their replacement appears. Click Barracks again to close it, or another town module to switch directly. Barracks offers **Sleep** to fade to black, apply stored combat experience, restore roster HP/SP, and fade back into Barracks, **Manage Party** to replace the Barracks menu with a party card, and a disabled **Save** option. Select a name to inspect its portrait and stats. Drag names between four party slots and the reserve column, or between party slots to swap their order. Dropping a reserve onto an occupied slot exchanges the characters. Keep one to four active members; battle planning and party cards follow that order. Tinkerer and Chemist remain placeholders; click their town button again to close them.
- **Explore** opens an enclosed 40 × 40 unit first-person room.
- Move with **WASD** or **arrow keys**, look with the **mouse**, and press **Esc** to pause. The pause menu offers Resume, Options, Return to Safe Zone, and Main Menu.
- Options control master volume and fullscreen for the current session. No audio is included yet.
- **Tab** in town opens Characters (press Tab again to return); **Esc** opens a menu with Options and Main Menu. Characters shows the full roster's current stats, abilities, class unlocks, and resistances. New Game starts Usami, Takane, Kurako, and Koumi with their named portraits from `textures/Characters/Alpha/`. All four start as Explorer, with permanent level-up growth, titles, and their own unique skills. Their portraits use the V03 artwork, stored without version suffixes.
- Status abilities apply timed buffs/debuffs, poison, and paralysis. Damage attacks support accuracy and critical hits; aggro influences enemy targeting. Weapon types are restricted by both character and class; the Characters screen shows effective allowed types and starting equipment.
- **Characters → Equipment** manages four shared gear slots: up to three Artifacts, one Medallion, and one Consumable. Consumables can heal, buff, damage, or debuff single targets or groups, and are destroyed when their uses run out.
- Combat banks experience each round, with diminishing enemy rewards and a separate defeat bonus. Downed characters lose their entire unspent bank; retreat forfeits this encounter’s XP for the party. Sleep applies banked XP, using 100 × current level per level-up. Each earned level shows a portrait card with actual stat changes and newly learned abilities over the black screen; dismiss all cards to fade back into Barracks.
- Press **B** while exploring to enter the map's 2D encounter. Choose the party's actions and targets, then select **Execute round**. Portraits display during action selection and hide while targeting.
- **Observe** is a per-character battle toggle: halve effective stats except HP/SP while active and earn 50% more round and defeat XP. It leaves the action choice open, persists across rounds, and resets when combat ends.
- The window is resizable (minimum 800 × 450). UI regions use proportional anchors and containers, including enemy spots and portrait overlays.
- Open `scenes/ui/portrait_preview.tscn` in Godot’s 2D editor to adjust each character’s portrait live: select the root, expand **Preview Character → Portrait Presentation**, and edit position, scale, or fit.
- Entering battle fades to black, then reveals the battlefield over two seconds with the UI hidden and input blocked.
- Press **Tab** in battle to inspect your party or the enemy party in a fullscreen panel. All enemy details are currently available; Tab or Esc returns to combat.
- The active combat portrait fills the right 60% behind the UI, with the action menu on the left. Party cards display HP/SP bars; SP is the combat label for the existing MP pool.
- Combat has six enemy spots in two rows and four fixed character slots. Unused enemy spots hide, and empty character slots are disabled.

Background and room textures are grey PNG placeholders with centered labels in `textures/`. The four playable characters use the supplied character artwork.

## Editing the project

The scene trees, controls, meshes, lights, camera, and collision shapes are saved in ordinary Godot scenes and can be edited visually in the editor.

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn` | Entry scene, world container, and UI layer |
| `scenes/base/` | Reusable Map and Town base scenes |
| `scenes/battle/` | 2D battlefield and enemy target slots |
| `scenes/ui/` | Main menu, town, location placeholder, options, pause menu, and exploration HUD |
| `scenes/world/exploration_room.tscn` | Room geometry, lighting, collisions, and player instance |
| `scenes/player/player.tscn` | Reusable first-person player, camera, and capsule collision |
| `resources/materials/` | Ground, wall, and ceiling materials |
| `resources/themes/default.tres` | Shared UI font size, spacing, and panel style |
| `textures/` | Labeled grey placeholder images |
| `scripts/main.gd` | Scene navigation and exploration lifecycle |
| `scripts/player.gd` | First-person movement and mouse look |
| `scripts/ui/` | Menu action signals and options controls |
| `scripts/rpg/` | Character state, growth, abilities, and damage rules |
| `scripts/world/` | Map spawning/activation and Town configuration/navigation |
| `scripts/battle/` | Turn planning, targeting, initiative, and combat presentation |
| `scripts/window_settings.gd` | Minimum window size for normal play and scene previews |
| `resources/rpg/` | Editable character, class, ability, and damage-type definitions |

See [gear](docs/gear.md) for slot limits, the shared stash, medallion spells, and consumable effects/targets.
See [playable roster](docs/roster.md) for titles and unique skills.
See [core mechanics](docs/core_mechanics.md) for formulas, class behavior, resource authoring, and API examples.
See [maps and towns](docs/maps_and_towns.md) to create additional areas using inherited scenes and assign exploration destinations in the Inspector.
See [turn-based combat](docs/battle.md) for battle controls, enemy placement, portrait setup, encounters, and round rules.

Change movement bindings under **Project → Project Settings → Input Map**. Select the Player node in its scene to adjust speed, mouse sensitivity, and gravity in the Inspector. Open UI scenes to edit button text and layout; button node names identify their navigation actions.

The town's three businesses share `scenes/ui/location.tscn`; navigation selects the appropriate title and background. `scenes/main.tscn` instances the initial menu so it is also visible in the editor. Other screens and the exploration room are instantiated from their saved scenes as needed.

## Validation

Run the navigation and physics smoke test after importing the project:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/rpg.gd
godot --headless --path . --script res://tests/roster_skills.gd
godot --headless --path . --script res://tests/equipment_status.gd
godot --headless --path . --script res://tests/gear.gd
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/portrait_preview.gd
godot --headless --path . --script res://tests/battle.gd
godot --headless --path . --script res://tests/layout.gd
godot --headless --path . --script res://tests/smoke.gd
```

To also verify mouse capture and mouse look, run the smoke test with a graphical display:

```sh
godot --path . --script res://tests/smoke.gd
```

Headless runs skip these mouse checks because the headless display cannot capture the OS cursor.
