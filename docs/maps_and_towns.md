# Maps and towns

Walkable areas are `Map` instances (`Node3D`), and towns are `Town` instances (`Control`). Both have reusable base scenes and concrete inherited scenes that you can edit in Godot.

| Base scene | Script type | Current inherited scene |
| --- | --- | --- |
| `scenes/base/map.tscn` | `Map` | `scenes/world/exploration_room.tscn` |
| `scenes/base/town.tscn` | `Town` | `scenes/ui/town.tscn` |

## Make a map

1. Right-click `scenes/base/map.tscn` in the FileSystem dock and select **New Inherited Scene**.
2. Save the scene under `scenes/world/`.
3. Set the root node's **Map Id** and **Display Name** in the Inspector.
4. Add geometry, collision shapes, lighting, and an environment. The base supplies the player and a `SpawnPoint` marker, but no walkable geometry.
5. Position and rotate `SpawnPoint` to define where the player starts and faces.
6. Assign this scene to a town's **Exploration Map** property.

Assign the Map root's **Encounter** resource to configure its battle. Press **B** while exploring to enter the [2D combat scene](battle.md); victory returns to the existing map instance and player position.

`Map` owns the player reference and spawn behavior. Its `set_active()` method enables/disables movement and captures/releases the mouse. `reset_player()` restores the spawn transform, clears velocity, and resets camera pitch. The game controller activates a map when entering/resuming exploration and deactivates it when showing menus. Run the whole project with **F5** to use this navigation and pause flow.

## Make a town

1. Create an inherited scene from `scenes/base/town.tscn` and save it under `scenes/ui/`.
2. Set **Town Id**, **Display Name**, and **Background Texture** on the root node.
3. Assign a `Map` scene to **Exploration Map**. Explore is disabled if no destination is assigned.
4. Assign textures in **Location Backgrounds** using the keys `Barracks`, `Tinkerer`, and `Chemist` for the current services.
5. Edit the inherited UI layout and button labels as needed. Existing button node names identify their actions.

The current base provides the prototype's standard service buttons. New service actions require a corresponding route in the controller. Towns emit `exploration_requested(map_scene)` for Explore and the shared `action_requested(action)` signal for menu/service actions.

## Navigation

The main scene's **Starting Town** property selects the town for New Game. The controller opens a town through `show_town(town_scene)` and a map through `explore(map_scene)`. Both accept any scene inheriting from their respective base, so changing the room or town does not require changing hard-coded scene constants.

The controller retains the current town scene while exploring or showing options, character details, and services. Return to Safe Zone restores that town. New Game resets to Starting Town. The party remains owned by the game controller, so changing maps and towns preserves character state.

Maps are newly instantiated on entry, with the player reset to their spawn. Returning to town recreates its UI. Persistent world changes and travel portals are not part of this prototype yet. Avoid assigning a town scene to Exploration Map; that property expects a `Map` scene.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/maps.gd
godot --headless --path . --script res://tests/smoke.gd
```

The Map/Town tests create a second map and town, checking destination selection, custom spawning, activation, return navigation, location backgrounds, and party preservation.

The Safe Zone displays only Barracks, Tinkerer, Chemist, and Enter the Labyrinth. Tab toggles the Characters screen; Escape opens the town menu with Options and Main Menu. Returning from Options preserves this menu’s town context, so Return/Escape goes back to the same town. Service placeholder backgrounds use matching labelled grey SVG textures.
