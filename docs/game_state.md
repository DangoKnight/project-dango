# GameState

`GameState` is an autoload registered in `project.godot`. Its implementation is `scripts/state/game_state.gd` (`RunState`). It owns the current run independently of scene instances. `scripts/main.gd` handles navigation, input, fades, and screen creation, and exposes the same singleton through its `state` property.

| Data | GameState property |
| --- | --- |
| Active party, in order | `party` |
| All recruited characters, including reserves | `roster` |
| Shared gear and unequipped weapons | `gear_inventory`, `weapon_inventory` |
| Learned monster information | `compendium` |
| Barterer stock/timers and Tinkerer commissions/history per refuge | `safe_zone_services` |
| Current Safe Zone identity and scene destinations | `active_safe_zone_key`, `current_town_scene`, `current_map_scene` |
| Wipe recovery destination | `last_safe_zone_scene` |
| Last doorway used in each labyrinth | `labyrinth_entries` |
| Persistent landmark discovery per labyrinth | `labyrinth_discoveries` |
| Peak exploration multiplier since rest or wipe | `highest_labyrinth_completion` |
| Completed conversation IDs | `completed_conversations` |
| Custom story/event values | `flags` |

The starting active party contains Usami, Takane, and Kurako; Koumi is not recruited at New Game and is reserved for a later recruitment event. **Starting Party Size** on the main scene root controls how many starting characters are active (default three, maximum four).

Party and roster entries refer to the same `CharacterState` objects. Character levels, permanent stats, current HP/SP, equipment, and stored experience continue to live in those objects. Screens and battles receive references from GameState; they do not create separate copies of player progress.

Use the singleton directly in gameplay scripts:

```gdscript
var leader: CharacterState = GameState.party[0]
GameState.gear_inventory.add(preload("res://resources/rpg/gear/healing_draught.tres"))

GameState.set_flag(&"met_tinkerer", true)
if GameState.get_flag(&"met_tinkerer", false):
    print("The party has met the Tinkerer.")
```

`flag_changed(key, value)` is emitted by `set_flag()`. A missing flag returns the supplied default, or `null` if none is supplied. `run_started` is emitted after new characters and inventory have been initialized. `has_started` distinguishes an initialized run from the initial empty state.

Call the scene controller's `new_game()` to start normal gameplay, including the Safe Zone fade and opening conversation. It cancels existing conversations and delegates data initialization to `GameState.start_new_game(starting_town, starting_characters, starting_gear, starting_party_size)`. New Game resets party progress, inventory, service state, exploration, discoveries, monster knowledge, completed conversations, and story flags. `new_game(false)` skips the opening and fade for test fixtures. `GameState.reset()` clears data to an inactive state; it does not navigate screens or cancel UI coroutines.

`services_for(town)` returns or creates services for the active Safe Zone key. `adopt_initial_safe_zone()` preserves the initial refuge's services when its doorway ID becomes known. Walking and kills advance all visited services through `advance_service_step()` and `record_service_kill()`. `discoveries_for(map_path)` returns a shared landmark discovery dictionary. `record_exploration_completion()` retains the largest completion reached. `recover_from_party_wipe()` clears that multiplier, destroys carried and stashed consumables, and heals the entire roster; the controller then returns to `last_safe_zone_scene`.

Conversation presentation and its pending queue stay in `Conversations`; its completion-history property refers to GameState's dictionary. World nodes, generated layouts, visited cells for the current map, battle queues, tweens, mouse capture, and menu state remain owned by their scenes/controllers.

This is session memory, not a disk save system. It survives scene changes and recreation of the main controller, but not quitting the application. No random-generator state is serialized.

Validate with `godot --headless --path . --script res://tests/game_state.gd`.
