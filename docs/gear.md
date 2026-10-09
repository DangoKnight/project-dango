# Gear

Open **Town → Characters → Equipment** to select a character and equip items from the shared stash. Unequip an item before transferring it to another character. New Game supplies three sample artifacts, a spell medallion, Rally Flask, Healing Draught, and Frailty Bomb. The party starts with these items in the stash.

Each character has **four shared gear slots** with these additional limits:

| Type | Maximum | Effect |
| --- | --- | --- |
| Artifact | 3 | Flat stat modifiers and additive damage resistances |
| Medallion | 1 | Grants its configured spells while equipped |
| Consumable | 1 | Executes configured effects for a finite number of uses |

Medallions and consumables can be carried together. For example, two artifacts + one medallion + one consumable fills all four slots. The existing weapon slot is separate.

Artifacts support positive and negative modifiers using `RPGStats.NAMES`. Resistance amounts use fractions: `0.2` means +20%; negative values mean weakness. Resistances combine with character and class values and clamp to [-100%, +100%]. Removing maximum-HP/MP bonuses clamps current pools; equipping them does not refill pools.

Medallion spells appear in the normal battle action list and use their ordinary MP costs and target rules. The combat UI calls MP **SP**. Removing a medallion removes its spell grants; spells learned through character/class sources remain available.

Consumables appear as battle actions with their remaining use count. Choose the action, select a valid target, then execute the round. Cancellation, undo, failed actions, defeated users, and defeated single targets spend no uses. A group action spends one use for the entire group. The last use destroys the item and removes it from its carrier and stash. Unequipping or transferring an item preserves its remaining uses.

## Authoring resources

Create a `GearDefinition` resource in `resources/rpg/gear/`, assign a unique ID, name, description, and kind. Definitions are shared; `GearInstance` holds each copy's carrier and remaining uses.

- **Artifacts:** set `stat_modifiers` and `resistances`.
- **Medallions:** assign `spells` to existing `AbilityDefinition` resources.
- **Consumables:** set `max_uses`, `consumable_target`, and an ordered array of `ConsumableEffect` resources.

Consumable targets are **single ally**, **party**, **self**, **single enemy**, or **all enemies**. Only living targets qualify. For group actions, click any valid member to confirm the group; execution applies to all living members of that faction.

Effects can heal HP, restore MP, apply a status, or deal damage. Each effect has its own amount/status/damage type. Damage uses a fixed amount, optional defense or Mental Resilience reduction, and the target's damage resistance. There is no character scaling or MP cost for consumables. Positive status modifiers buff targets; negative modifiers debuff them. Effects execute in resource order. Statuses use existing turn durations, refresh by ID rather than stacking, and clear when combat ends.

Examples: Rally Flask heals the party and raises strength; Healing Draught heals one ally; Frailty Bomb damages and reduces one enemy's Mental Resilience.

The Main node's `starting_gear` array seeds the shared stash on New Game. `CharacterDefinition.starting_gear` optionally equips gear directly, subject to the same limits. Gear stays in memory for the current game; save/load and loot/shop systems are not implemented yet.

```gdscript
var inventory := GearInventory.new()
var item := inventory.add(load("res://resources/rpg/gear/frailty_bomb.tres"))
character.equip_gear(item)
battle.choose_consumable(item)
battle.select_target(enemy)
# The queued action spends a use only during round resolution.
```

`BattleSession` enforces target factions. The lower-level `RPGConsumables.use_item(user, item, targets)` validates equipped gear, living targets, target counts, and unique recipients; callers outside battle must supply the correct faction/group.
