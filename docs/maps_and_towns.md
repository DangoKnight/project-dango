# Maps and towns

Walkable areas are `Map` instances (`Node3D`), and towns are `Town` instances (`Control`). Both have reusable base scenes and concrete inherited scenes that you can edit in Godot.

| Base scene | Script type | Current inherited scene |
| --- | --- | --- |
| `scenes/base/map.tscn` | `Map` | `scenes/world/office_labyrinth.tscn` (generated) |
| `scenes/base/town.tscn` | `Town` | `scenes/ui/town.tscn` |

## Make a map

1. Right-click `scenes/base/map.tscn` in the FileSystem dock and select **New Inherited Scene**.
2. Save the scene under `scenes/world/`.
3. Set the root node's **Map Id** and **Display Name** in the Inspector.
4. Add geometry, collision shapes, lighting, and an environment. The base supplies the player and a `SpawnPoint` marker, but no walkable geometry.
5. Position and rotate `SpawnPoint` to define where the player starts and faces.
6. Assign this scene to a town's **Exploration Map** property.

Assign the Map root's **Encounter** resource to configure its battle. Procedural labyrinths trigger the [2D combat scene](battle.md) through their encounter rate; victory returns to the existing map instance and player position. The B shortcut is disabled.

`Map` owns the player reference and spawn behavior. Its `set_active()` method enables/disables movement and captures/releases the mouse. `reset_player()` restores the spawn transform, clears velocity, and resets camera pitch. The game controller activates a map when entering/resuming exploration and deactivates it when showing menus. Run the whole project with **F5** to use this navigation and pause flow.

## Make a town

1. Create an inherited scene from `scenes/base/town.tscn` and save it under `scenes/ui/`.
2. Set **Town Id**, **Display Name**, and **Background Texture** on the root node.
3. Assign a `Map` scene to **Exploration Map**. Explore is disabled if no destination is assigned.
4. Assign textures in **Location Backgrounds** using the keys `Barracks`, `Tinkerer`, and `Barterer` for the current services.
5. Assign **Location NPCs** with the same service keys. This mapping belongs to each safe zone; Station 45-B uses York for Barracks, Sydney for Tinkerer, and Cairo for Barterer. Shared backgrounds remain in `textures/Backgrounds/SafeZones/`, while NPC artwork lives under `textures/NPCs/<SafeZone>/<Service>/`.
6. Edit the inherited UI layout and button labels as needed. Existing button node names identify their actions.

Opening a service slides the hub actions out to the right and shows its NPC on the right while the module card enters from the left. **Return to Hub** in each module restores the hub actions and dismisses the NPC. Escape also returns to the hub, except that Manage Party first returns to Barracks. The base scene's `ModuleNPC` anchors define portrait placement; **Location NPCs** is configured on the inherited town root. An unassigned NPC hides the portrait.

The current base provides the prototype's standard service buttons. New service actions require a corresponding route in the controller. Towns emit `exploration_requested(map_scene)` for Explore and the shared `action_requested(action)` signal for menu/service actions.

## Navigation

The main scene's **Starting Town** property selects the town for New Game. The controller opens a town through `show_town(town_scene)` and a map through `explore(map_scene)`. Both accept any scene inheriting from their respective base, so changing the room or town does not require changing hard-coded scene constants.

The controller retains the current town scene while exploring or showing options, character details, and services. Walking into a Safe Zone endpoint restores that town. New Game resets to Starting Town. The party remains owned by the game controller, so changing maps and towns preserves character state.

Maps are newly instantiated on entry. Hand-authored maps reset to their spawn. Procedural maps generate a fresh layout, encounters, and reward nodes on every entry, and spawn at the most recently visited Safe Zone. Returning to town recreates its UI. Disk saves and travel between different labyrinth maps are not implemented. Avoid assigning a town scene to Exploration Map; that property expects a `Map` scene.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/smoke.gd
```

The Map/Town tests create a second map and town, checking destination selection, custom spawning, activation, return navigation, location backgrounds, and party preservation.

The Safe Zone displays only Barracks, Tinkerer, Barterer, and Enter the Labyrinth. Tab toggles the Characters screen; Escape opens the town menu with Options and Main Menu. Returning from Options preserves this menu’s town context, so Return/Escape goes back to the same town. Service backgrounds use distinct illustrated modern interiors: a bunk room, repair workshop, and chemical workroom. The Safe Zone uses a furnished office refuge.

## Procedural labyrinths

The default Explore destination is `scenes/world/office_labyrinth.tscn`, a `LabyrinthMap` inheriting from `Map`. It generates textured floor, ceiling, walls, and collision from a connected grid. The original square room is still available: assign it to the town's Exploration Map to use it instead.

Edit **`resources/labyrinths/office.json`** with any text editor and reenter the labyrinth to apply changes. The file initializes a `LabyrinthDefinition` Godot `Resource`. You can also create a `LabyrinthDefinition` resource in Godot, save it as `.tres`, and assign the map root's **Definition** property. An assigned resource takes precedence over **Definition Json**. Duplicate the inherited map scene and give it another JSON path or resource to create another labyrinth.

| Setting | Meaning |
| --- | --- |
| `id`, `display_name` | Map identity and title |
| `size` | `[width, depth]`, each between 2 and 64 cells (`grid_size` is accepted as a legacy JSON alias) |
| `cell_size` | Width and depth of each cell in world units; resource default 8, Office configuration 4, minimum 4. Wall height is independent. |
| `wall_height` | World units from floor to ceiling; default 4, minimum 3 |
| `generation_seed` | `0` generates a fresh layout on every entry; a nonzero integer reproduces a layout for design/testing |
| `spawn_landmark` | ID of the landmark used for first entry |
| `landmarks` | Fixed coordinates, IDs, names, kinds, and optional town scene paths |
| `reward_node_min`, `reward_node_max` | Inclusive minimum and maximum number of items/caches per visit; default 4–8. Each cache contains one randomly selected gear item. Legacy `reward_node_count` sets both bounds to one exact value. |
| `possible_rewards` | Resource paths to valid consumable `GearDefinition` resources only; artifacts and medallions are rejected. Each cache randomly chooses one, with repeats allowed |
| `encounters` | Resource paths to predefined `BattleEncounter` resources; one complete preset is selected with equal probability per battle |
| `encounters_enabled` | Whether walking triggers encounters (default true) |
| `encounter_steps_min`, `encounter_steps_max` | Inclusive range of walking steps between encounters (default 8–14); minimum must be positive |

Coordinates are zero-based `[x, z]`: `[0, 0]` is the first cell center, and `[x, z]` maps to `(x × cell_size, 0, z × cell_size)` in 3D. The maze is randomized around these fixed coordinates. Changing `cell_size` scales the horizontal distance between landmarks without changing their grid coordinates or wall height. The walking route varies with the layout.

Each landmark is a `LabyrinthLandmark` resource. Use `kind: "safe_zone"` for an interactive refuge, or another kind for future notable places. IDs and coordinates must be unique and inside the grid. Example:

```json
{"id": "entry_refuge", "display_name": "Station 45-B", "kind": "safe_zone", "coordinate": [1, 1]}
```

Each Safe Zone occupies a dead-end cell enclosed by three full-height textured walls, a floor, and a ceiling, with exactly one open side connecting to the labyrinth. Its terminal wall is fully black. Both side walls, the floor, and the ceiling fade smoothly from the lit entrance into full darkness at the back, using a shared spatial gradient. Walking into that doorway automatically fades to black and transfers the player to town; no interaction button is needed. Reentering fades through black again and places the player outside the trigger, facing down the sole passage. **Navigation Fade Duration** on the main scene controls each half of these transitions (default 0.45 seconds). They currently share the current town's services; an optional `town_scene_path` can select a separate inherited Town scene. Keep that town's Exploration Map assigned to the same labyrinth scene to return to the same area. Scene paths are strings, allowing Town → Map → landmark references without circular resource loading.

Supply caches show **Collect [E]** when their room is dim or fully lit. Item and ordinary landmark labels stay hidden while their room’s ceiling light is off, and update when exploration changes its lighting state. Safe Zone name signs follow the same visibility rule using the approach room’s light, because the endpoint fixture remains off; the initial refuge is Station 45-B. Collecting one adds its chosen consumable to the shared inventory and removes that cache. Leaving the labyrinth discards its layout and remaining caches. Reentering regenerates passages, rewards, and encounters while preserving fixed landmark coordinates and the last visited refuge. Collected gear remains in the party inventory. Pausing and returning from combat keep the current map instance. A full party wipe returns to the last visited refuge with the roster fully healed, destroys carried and stash consumables, and resets the global exploration multiplier. **New Game** resets the last visited refuge. No random generator states are serialized, and no disk save system is introduced.

`LabyrinthLayout.generate(definition)` returns the logical map independently of rendering: `passages` maps cell coordinates to connected neighbors, `rewards` maps endpoint coordinates to chosen gear resources, `landmark(id)` retrieves fixed landmark metadata, and `world_position(cell)` converts coordinates. A randomized growing-tree algorithm connects the non-Safe-Zone cells, then attaches each Safe Zone through one passage, producing a spanning tree: the whole grid is connected, and there is exactly one route between any pair of cells. Rewards are sampled without replacing endpoints and never overlap landmarks. The generator samples an item count between the configured bounds once per entry, then retries at most 64 times to meet that endpoint count; impossible requests (including fixed Safe Zones that would disconnect the remaining grid) return an error instead of reducing the count or looping indefinitely. Reduce the reward bounds, enlarge the grid, or move landmarks if generation fails.

The 3D renderer builds walls from passage boundaries and is separate from generation. It can later add varied room shapes, props, doors, and visual offsets while preserving grid connectivity and fixed landmark coordinates. The initial renderer uses square rooms and matching cyan concrete wall panels, grey-blue floor slabs, and pale concrete ceiling panels.

Automatic encounters choose an integer walking distance uniformly from `encounter_steps_min` through `encounter_steps_max`, inclusive, on entry and after each battle. One step equals `cell_size` units of actual horizontal movement outside Safe Zone cells; partial steps accumulate. The Office configuration uses **4–8 steps**, guaranteeing a minimum gap and an encounter by the chosen count. Standing still, blocked movement, teleporting, and paused navigation do not advance the countdown. Safe Zone cells suspend it; pause/resume preserves it. Each battle selects one complete preset from `encounters`, preserving its enemy count, order, repeated enemies, and level. Set `encounters_enabled` to false to disable automatic battles. Random generator states and countdowns are never saved. Weighted reward tables and bespoke services at separate refuges remain future features.

To design encounters, create `BattleEncounter` resources in Godot (script `scripts/battle/encounter.gd`) and add their `res://` paths to the JSON `encounters` array, or assign them directly to **Encounters** on a `LabyrinthDefinition`. Each preset defines its own display name, ordered **Enemies** list (1–6 entries), and **Enemy Level** (1–99). Repeating an enemy resource creates multiple separate enemies of that species. The Office list includes `rat_pair.tres`, `orb_pair.tres`, and `office_patrol.tres`; no enemies are randomly added or replaced within these lineups. The list must contain at least one valid preset. Runtime battle containers are copied from presets so configured lineups remain unchanged.

Validate with:

```sh
godot --headless --path . --script res://tests/labyrinth.gd
```

This checks connectivity and reward endpoints across 30 seeds, fixed landmarks, seeded reproducibility, invalid configuration handling, collision matching the logical graph, reward collection, Safe Zone enclosure and travel, regeneration on reentry, inventory preservation, and New Game reset.

The definition stores labyrinth dimensions in its exported **Size** property, under **Labyrinth Size** in Godot. `world_size` reports the derived physical width/depth (`size × cell_size`); for example, `[6, 9]` cells at 4 units per cell occupy 24 × 36 world units. Set `cell_size` in the JSON configuration (or **Cell Size** on a `LabyrinthDefinition` resource) to adjust corridor width and cell depth. The Office configuration uses 4 instead of 8 for cells that are half as wide and deep; `wall_height` remains independent.

## Exploration lighting

Each cell contains an instanced fluorescent ceiling fixture (`scenes/world/labyrinth_ceiling_light.tscn`). Walked cells and discovered ordinary landmarks have full light. Each known Safe Zone’s approach cell (its sole connected neighbor) is revealed and fully lit when the labyrinth initializes. The entry Safe Zone is known immediately. Unknown Safe Zones grant no automatic light or map reveal; discovering one reveals and lights its approach at that moment. Ordinary walking still lights visited rooms. The Safe Zone endpoint itself keeps its ceiling light off, even when walked, preserving its dark entrance. Their immediately connected neighbors have dim light; adjacency follows open passages, and dim cells do not spread lighting further. All other fixtures are off. Walking into a cell updates its light and neighboring lights immediately. Lighting does not reveal map floors or count as discovering a landmark.

Visited-cell lighting resets with each regenerated map. Previously discovered ordinary landmarks stay lit at their fixed coordinates, even before they are walked during the new visit. Known Safe Zone approach cells are rediscovered using the new layout’s entrance direction on every generation. New Game clears that knowledge. Pause and combat preserve lighting in the current map.

The Office scene uses a low nonzero color ambient light (`WorldEnvironment → Environment → Ambient Light → Energy`, initially 0.015) and no directional light, keeping unlit rooms much darker while retaining a trace of visibility. The black Safe Zone back walls and doorway gradients remain unchanged. Adjust **Lit Light Energy** and **Dim Light Energy** on the labyrinth root under **Ceiling Lighting** to tune fixture brightness (initially 1.8 and 0.3). Fixtures cast shadows to block light at walls. Distant sources use [Godot's light distance fading](https://docs.godotengine.org/en/stable/classes/class_light3d.html#class-light3d-property-distance-fade-enabled) to limit rendering cost; fixture glow still reflects its exploration state.

Verify lighting states, discovery persistence, actual walking, and ambient settings with `godot --headless --path . --script res://tests/labyrinth_lighting.gd`. Visual brightness should also be checked in a rendered game window.

## Pause book and exploration map

Press **Esc** to open the two-page field journal. The contents list has options on both pages, with ink-style hover/focus highlights. Choosing a chapter fades out all current page content, replaces it, and fades in the new spread while the book stays open. Input is blocked through the transition. **Back** or **Esc** returns to the contents; Resume closes the journal and restores navigation. Main Menu fades the current contents before leaving. Safe Zones are reached through their doorways in the labyrinth; the book has no return shortcut.

**Monsters** replaces the previous Compendium menu label. It lists encountered species on the left, with the selected monster's portrait, learned affinities, and observed abilities on the right. Undiscovered affinities remain `???`, and numeric enemy stats remain hidden. The notes scroll independently of the species list.

**Map** shows stats on the left and the chart on the right:

- **Map completion** is the percentage of cells revealed in this visit, including the initially revealed known Safe Zone approaches. It resets when the labyrinth regenerates.
- **Discovered landmarks** counts known landmarks in this labyrinth, including Safe Zones. Known names appear beside their markers on the map and persist across visits. The stats page shows only the count, and the map has no explanatory legend.
- **Picked up items** shows only items collected in this visit. It never exposes the number of spawned or remaining items. Each new layout chooses an inclusive random count from `reward_node_min` through `reward_node_max`, currently 4–8.

Known Safe Zone approach cells show their floors and walls from initialization. Other cells are revealed by walking. Revealing an approach does not unlock its Safe Zone landmark marker; the endpoint must still be discovered.

The chart uses grey floor shading and dark ink for walls, green squares for Safe Zones, purple diamonds for other landmarks, and a rust-coloured arrow for position/facing direction. Unvisited floors, their walls, and undiscovered landmarks stay hidden. Discovered landmark markers remain visible across regenerations without revealing their new surrounding floor or walls.

`LabyrinthMap.walked_cells` records revealed cells: known Safe Zone approaches at initialization, and occupied grid cells on entry and while movement is enabled, including the final position before pausing. Pausing and returning from battle preserve the same chart. Reentering from town creates a fresh labyrinth and resets walked cells and the picked-up item count, then reveals the new approaches of known Safe Zones. The controller shares discovered landmark IDs across instances of each labyrinth scene, and markers use the current definition's fixed coordinates. New Game clears landmark knowledge. Knowledge is kept in memory; disk saves are not implemented. Map is hidden in the town menu and disabled for hand-authored maps without a labyrinth grid.

**Options** keeps its notes on the left and sound/display controls on the right. Volume and fullscreen behave as before; opening Options from the main menu continues to use the standalone screen.

The scene is `scenes/ui/pause_menu.tscn`, with `scripts/ui/pause_book.gd` managing chapters and `book_background.gd` drawing paper, the binding, shadows, and ruled lines. `resources/themes/book.tres` uses bundled Noto Serif Medium Italic for a written journal style; its Apache 2.0 license is included under `resources/fonts/`. **Page Fade Duration** on the PauseBook root defaults to 0.18 seconds per half of the chapter transition. Both pages and the map fit the available window area; long notes and map statistics scroll within their page.

Validate with:

```sh
godot --headless --path . --script res://tests/pause_book.gd
godot --headless --path . --script res://tests/labyrinth_chart.gd
godot --headless --path . --script res://tests/labyrinth.gd
```


## Barterer and Tinkerer

Each Town exposes **Barterer** and **Tinkerer** sections in its Inspector. Configure **Barter Artifacts**, **Barter Artifact Min/Max**, **Barter Consumables**, **Barter Restock Steps**, and **Fabrication Ideas** on each Safe Zone's town scene. The default artifact stock is 2–4 copies randomly selected from the configured artifact pool, plus unlimited offers for every configured consumable. The refresh step limit defaults to 25. Keep the artifact pool nonempty and its minimum at least one. Duplicate copies are separate goods. Give landmarks their own `town_scene_path` to author different service settings. Safe Zones retain independent runtime stock and commission history even when sharing a town scene.

Barterer displays selectable lists for **Your offer** and **Requested goods**. Offers may include equipped artifacts or consumables; successful trades automatically unequip the offered items. Medallions and weapons are excluded. Each definition has a developer-only **Hidden Value**. A trade is accepted when the offered sum is at least twice the requested sum. Partial consumables retain their remaining uses and use the definition's full hidden value. No values, ratios, or pricing explanations are displayed; feedback is only **Acceptable** or **Not acceptable**. Rejected trades change nothing. Accepted goods leave the player inventory. Requested artifacts leave stock; requested consumables create independent full-use copies without depleting their offer. Duplicate submissions are rejected.

Opening Barterer starts that Safe Zone’s artifact refresh timer if it is not already running. No purchase is required. A step is one cell-width of actual walking, including revisited passages; encounters need not be enabled. Reopening Barterer or trading during a running cycle does not reset its countdown. At the zone’s configured **Barter Restock Steps** limit, artifacts reroll from its pool and amount range, and the timer stops. Further walking does nothing until the first conversation after that refresh starts another cycle. Consumables remain available in unlimited quantities; each purchase creates a fresh full-use copy. Counters persist across menus, battles, and labyrinth regeneration; reopening the card never immediately refreshes stock. Walking advances every visited Barterer's pending countdown. New Game resets all service state. Like the rest of the current game state, service progress is held in memory rather than disk saves.

**FabricationRecipe** resources define exactly one weapon or medallion, `required_kills` (enemy species IDs mapped to base counts), and optional `enemy_names` for UI labels. Add recipes to a Town's **Fabrication Ideas** list. Sample recipes in `resources/rpg/recipes/` use the existing rats and ethereal orbs. New species can be used without named material drops: for example, `{&"slug": 5, &"snail": 7}` requires five slug and seven snail defeats for a known design, or ten and fourteen for an unmade idea.

Accept a commission before gathering kills. The requirements are fixed at acceptance. First-time commissions from that Tinkerer require twice every base count; collecting the first completed weapon or medallion teaches that Tinkerer the design, and later commissions require base counts. Kills before acceptance and unrelated species do not count. Every matching defeat advances all accepted commissions that need that species, including commissions at other visited Safe Zones. Direct damage, consumables, and poison share the same once-per-enemy defeat event. Retreat or party wipes do not erase completed kill progress. A commission delivers exactly one item when **Collect weapon** or **Collect medallion** is selected; it cannot be claimed again without accepting and finishing another commission.

Crafted weapons enter the shared weapon inventory. Tinkerer only exposes designs and commissions; it does not display the stash or provide equipment controls. Weapons retain their existing definition behavior: type and eligibility are implemented, while weapon-specific damage/stat bonuses remain future work.

Fabricated medallions enter the shared gear stash as independent instances. Equip them through **Characters → Equipment**; the existing one-medallion and four-total-gear limits apply, and granted spells still require their usual SP. The sample Spell Medallion commission requires a base of two rats and three ethereal orbs, doubled for the first fabrication. Weapon and medallion designs keep separate histories even if their item IDs match.

New games keep **Go to Labyrinth** disabled, including after the opening conversation.
Opening Barracks, Tinkerer, and Barterer after their introductions unlocks it automatically.
Module visits are recorded per Safe Zone in GameState flags. The first departure
plays `station_departure.tres` before the labyrinth entry fade.
The flag survives screen changes and resets on New Game. Service panels extend to
the left half of the viewport; bottom-aligned NPCs occupy the right half.

Barterer lists toggle individual goods with a click; Shift-click still selects ranges.
The Safe Zone heading sits above its action buttons, with the action group lower in the scene.
