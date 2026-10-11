# Project Dango

A Godot 4.7 game prototype. Import `project.godot` in the Godot Project Manager, open the project, and press **F5** to play. `scenes/main.tscn` is the configured main scene.

- **New Game** fades into the Safe Zone, then plays the opening conversation with animated portrait entrances and departures. The Safe Zone action card stays hidden until the conversation's final departure finishes, then slides in from the right.
- The Safe Zone navigation card slides in from the right and stays visible while modules are open. Module cards slide in from the left and slide out when closed. Barracks and Manage Party slide out before their replacement appears. Click Barracks again to close it, or another town module to switch directly. Barracks offers **Sleep** to fade to black, apply stored combat experience, restore roster HP/SP, and fade back into Barracks, **Manage Party** to replace the Barracks menu with a party card, and a disabled **Save** option. Select a name to inspect its portrait and stats. Drag names between four party slots and the reserve column, or between party slots to swap their order. Dropping a reserve onto an occupied slot exchanges the characters. Keep one to four active members; battle planning and party cards follow that order. Barterer exchanges artifacts and consumables using hidden values, with artifact stock refreshed after a configurable number of labyrinth steps following a conversation. Consumables are unlimited. Tinkerer commissions award weapons and medallions for relevant monster kills; first-time designs require double the base counts. Click a service button again to close its card.
- **Explore** generates a fresh, fully connected first-person labyrinth on every entry. Safe Zone cells have three solid walls and one open side. Fixed Safe Zones and landmarks retain their coordinates; 4–8 supply caches are randomly placed at dead ends (configurable minimum and maximum). Press **E** near a cache to collect its gear. Walk into a black doorway at a Safe Zone endpoint to enter it. Entering the labyrinth and crossing a Safe Zone doorway fade through black. Edit `resources/labyrinths/office.json` to configure the map without the Godot interface. See [procedural labyrinths](docs/maps_and_towns.md#procedural-labyrinths).
- Every labyrinth cell has a ceiling light: full brightness for walked cells, discovered ordinary landmarks, and each known Safe Zone’s approach room; dim for their neighbors through open passages; and off elsewhere. Safe Zone endpoints keep their ceiling lights off. Known Safe Zone approach rooms are revealed on the map at initialization; unknown refuges grant no automatic reveal or light. Very faint ambient lighting keeps unexplored rooms much darker without making them fully black.
- Move with **WASD** or **arrow keys**, look with the **mouse**, and press **Esc** to pause. The pause menu is an open field journal, with Resume, Map, Monsters, Options, and Main Menu across both pages. Options highlight on hover; selecting one fades the current page contents before showing the chapter. Monsters lists names on the left and learned information on the right. Map places completion, discovered landmarks (including Safe Zones), and picked-up item count on the left, with the chart on the right. Completion and collected item counts reset each visit, and item totals are never shown. **Map** charts only walked cells, including their floors, walls, and discovered Safe Zone endpoints, plus your position and facing direction. Walked floors and walls reset when the labyrinth regenerates; discovered Safe Zones and landmarks remain marked until New Game.
- Options control master volume and fullscreen for the current session. No audio is included yet.
- **Tab** in town opens Characters (press Tab again to return); **Esc** opens a menu with Options and Main Menu. Characters shows the full roster's current stats, abilities, class unlocks, and resistances. New Game recruits Usami, Takane, and Kurako; Koumi is absent from both the active party and reserve roster until she joins later. Character portraits come from `textures/Characters/Alpha/`. All four start as Explorer, with permanent level-up growth, titles, and their own unique skills. Their portraits use the V03 artwork, stored without version suffixes.
- Status abilities apply timed buffs/debuffs, poison, and paralysis. Damage attacks support accuracy and critical hits; aggro influences enemy targeting. Weapon types are restricted by both character and class; the Characters screen shows effective allowed types and starting equipment.
- **Characters → Equipment** manages four shared gear slots: up to three Artifacts, one Medallion, and one Consumable. Consumables can heal, buff, damage, or debuff single targets or groups, and are destroyed when their uses run out.
- Combat banks experience each round, with enemy rewards quartered each subsequent round and a defeat bonus equal to the defeated enemy’s turn reward for that round. Downed characters lose their entire unspent bank; retreat forfeits this encounter’s XP for the party. Sleep multiplies banked XP by the party’s highest labyrinth completion since its last rest (60% completion grants 60% of stored XP), using 100 × current level per level-up. This global peak survives individual knockouts, retreat, and map regeneration, and resets after rest, a full party wipe, or New Game. A wipe returns the team fully healed to the last visited Safe Zone and destroys all stash and carried consumables, including reserves. Artifacts, medallions, levels, and applied EXP remain intact. Each earned level shows a portrait card with actual stat changes and newly learned abilities over the black screen; dismiss all cards to fade back into Barracks.
- Walking through the labyrinth triggers 2D encounters after a randomly chosen number of steps within its configured range (resource default: 8–14). One step is a grid cell’s distance walked outside Safe Zones. Each battle selects a predefined encounter from the labyrinth’s `encounters` list, preserving its enemy lineup and level. Choose the party's actions and targets, then select **Execute round**. Portraits display during action selection and hide while targeting.
- **Observe** is a per-character battle toggle: halve Strength, Defense, Mental Acuity, Mental Resilience, and Speed while active and earn 50% more round and defeat XP. It leaves the action choice open, persists across rounds, and resets when combat ends.
- The window is resizable (minimum 800 × 450). UI regions use proportional anchors and containers, including enemy spots and portrait overlays.
- Open `scenes/ui/portrait_preview.tscn` in Godot’s 2D editor to adjust each character’s portrait live: select the root, expand **Preview Character → Portrait Presentation**, and edit position, scale, or fit.
- Entering battle fades to black, then reveals the battlefield over two seconds with the UI hidden and input blocked.
- Press **Tab** in battle to inspect your party or the enemy party in a fullscreen panel. Hostiles show only learned compendium information; Tab or Esc returns to combat.
- The active combat portrait fills the right 60% behind the UI, with the action menu on the left. Party cards display HP/SP bars; SP is the combat label for the existing MP pool.
- Combat has six enemy spots in two rows and four fixed character slots. Unused enemy spots hide, and empty character slots are disabled.

Backgrounds use illustrated modern labyrinth interiors, with a warm Safe Zone refuge and distinct Barracks, Tinkerer, and Barterer rooms. Exploration uses repeating carpet, wallpaper, and acoustic ceiling textures. The first encounter features rats and floating ethereal orbs with square transparent sprites. Safe Zone signs show their names when their approach room is dim or lit; the initial refuge is **Station 45-B**. Enemy slots have transparent holders and show only a compact green health bar above each enlarged sprite. Valid targets pulse toward white on hover, and defeated enemies fade away. Living monsters slide upward when leaving battle, including during retreat. Generated art lives in `textures/`; prompts are recorded in `docs/art_prompts.json`. The four playable characters retain the supplied artwork.

## Editing the project

The scene trees, controls, meshes, lights, camera, and collision shapes are saved in ordinary Godot scenes and can be edited visually in the editor.

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn` | Entry scene, world container, and UI layer |
| `scenes/base/` | Reusable Map and Town base scenes |
| `scenes/battle/` | 2D battlefield and enemy target slots |
| `scenes/ui/` | Main menu, town, location placeholder, options, pause menu, and exploration HUD |
| `scenes/world/office_labyrinth.tscn` | Procedural labyrinth, using the base Map and player |
| `resources/labyrinths/office.json` | Grid size, fixed landmarks, reward count/pool, and enemy pool |
| `scenes/world/exploration_room.tscn` | Original hand-authored room, available as an alternative map |
| `scenes/player/player.tscn` | Reusable first-person player, camera, and capsule collision |
| `resources/materials/` | Ground, wall, and ceiling materials |
| `resources/themes/default.tres` | Shared UI font size, spacing, and panel style |
| `textures/` | Illustrated environments, room textures, enemy sprites, and character artwork |
| `scripts/main.gd` | Scene navigation and exploration lifecycle |
| `scripts/state/game_state.gd` | GameState autoload: party, inventory, services, discoveries, and story progress |
| `scripts/player.gd` | First-person movement and mouse look |
| `scripts/ui/` | Menu action signals and options controls |
| `scripts/rpg/` | Character state, growth, abilities, and damage rules |
| `scripts/world/` | Map spawning/activation and Town configuration/navigation |
| `scripts/battle/` | Turn planning, targeting, initiative, and combat presentation |
| `scripts/conversation/` | Conversation resources, modal overlay, director, and triggers |
| `resources/conversations/` | Editable visual novel conversation events |
| `scripts/window_settings.gd` | Minimum window size for normal play and scene previews |
| `resources/rpg/` | Editable character, class, ability, and damage-type definitions |

See [gear](docs/gear.md) for slot limits, the shared stash, medallion spells, and consumable effects/targets.
See [playable roster](docs/roster.md) for titles and unique skills.
See [core mechanics](docs/core_mechanics.md) for formulas, class behavior, resource authoring, and API examples.
See [GameState](docs/game_state.md) for shared run data, story flags, and reset behavior.
See [maps and towns](docs/maps_and_towns.md) to create additional areas using inherited scenes and assign exploration destinations in the Inspector.
See [turn-based combat](docs/battle.md) for battle controls, enemy placement, portrait setup, encounters, and round rules.
See [conversation events](docs/conversations.md) to author and preview dialogue with left/right portraits and trigger it in town, exploration, or combat.
See [translation tables](docs/localization.md) to maintain English text and add languages.

Change movement bindings under **Project → Project Settings → Input Map**. Select the Player node in its scene to adjust speed, mouse sensitivity, and gravity in the Inspector. Open UI scenes to edit button text and layout; button node names identify their navigation actions.

The town's three businesses share `scenes/ui/location.tscn`; navigation selects the appropriate title and background. `scenes/main.tscn` instances the initial menu so it is also visible in the editor. Other screens and the exploration room are instantiated from their saved scenes as needed.

## Validation

Run the navigation and physics smoke test after importing the project:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/rpg.gd
godot --headless --path . --script res://tests/game_state.gd
godot --headless --path . --script res://tests/roster_skills.gd
godot --headless --path . --script res://tests/equipment_status.gd
godot --headless --path . --script res://tests/gear.gd
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/portrait_preview.gd
godot --headless --path . --script res://tests/battle.gd
godot --headless --path . --script res://tests/conversations.gd
godot --headless --path . --script res://tests/layout.gd
godot --headless --path . --script res://tests/smoke.gd
```

To also verify mouse capture and mouse look, run the smoke test with a graphical display:

```sh
godot --path . --script res://tests/smoke.gd
```

Headless runs skip these mouse checks because the headless display cannot capture the OS cursor.

Open **Monsters** from the Escape book in the Safe Zone or while exploring. Encountered monsters are listed with their sprites. Landed attacks reveal only the damage type tested (including Normal and Immune); misses reveal nothing. Damaging consumables and poison abilities also reveal their damage types. Monsters reveal abilities when actually used, even if they miss. Knowledge carries across fights and clears on New Game. Enemy HP/SP values, levels, and stats never appear in the compendium or Hostiles panel.

The pause book uses code-drawn paper, binding, page shadows, and ink-style italic typography. The bundled Noto Serif font and license are in `resources/fonts/`; no new generated artwork is required. `page_fade_duration` on the PauseBook root controls chapter fades. Run `tests/pause_book.gd` to validate both-page layout, transitions, item statistics, controls, and resizing.
