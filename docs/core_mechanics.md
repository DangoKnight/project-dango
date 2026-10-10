# Characters, classes, and combat

Definitions are editable Godot `.tres` resources under `resources/rpg/`. Select them in the FileSystem dock to edit them in the Inspector. Runtime `CharacterState` instances hold permanent stats, level, class, HP, and MP separately, so two instances of the same character do not share vital values or mutate their definitions.

## Definitions

- **CharacterDefinition:** stable ID, name, title, description, starting class, base stats, per-level growth, innate resistances, unique abilities, allowed weapon types, optional starting weapon, portrait presentation settings, combat traits, and combat texture.
- **CharacterClass:** its own base-stat contribution, growth, resistances, ability unlocks at specified levels, and allowed weapon types.
- **RPGStats:** max HP, max MP, strength, defense, Mental Acuity, Mental Resilience, and speed. All start at zero in a new resource; HP has a runtime minimum of one.
- **AbilityDefinition:** stable ID, name, description, Damage/Heal/Status effect, targeting rule, MP cost, damage/healing parameters, and a status definition for Status abilities. The existing Damage and Heal enum values remain unchanged.
- **DamageType:** stable ID and display name. Types are resources, so adding a new type requires no combat-code changes.
- **DamageResistance:** a damage-type resource and resistance fraction. `0.25` reduces damage by 25%; `-0.25` increases it by 25%.
- **AbilityUnlock:** an ability resource and the level at which a class grants it.
- **StatusEffectDefinition:** stable ID, name, description, turn duration, and percentage stat modifiers, including negative percentages for debuffs.
- **WeaponType:** stable ID and display name, independent of damage types.
- **WeaponDefinition:** stable ID, name, and weapon type, used for equipment validation.

Keep definition IDs unique within each category. Damage types match by ID, and available abilities are deduplicated by ID with the character's unique ability taking precedence.

## Growth and classes

At creation, permanent base stats combine the character's base stats with its **starting** class's base stats. Each earned level independently rolls every primary stat around the combined character, current class, and equipped gear growth:

```text
permanent_stat = initial_character_base + initial_class_base
                 + sum(character_growth + class_growth + equipped_growth_modifiers + random_variation)
current_stat = floor(permanent_stat + active_status_modifiers + artifact_modifiers)
```

Each roll uses uniform variation of ±0.5 for Usami, Takane, and Kurako, or ±1.0 for Koumi. Growth remains fractional internally; effective stats round down. Rolls are made separately for every intermediate level, including higher starting levels. A sufficiently low base growth can roll negative. `get_growth()` returns the base growth before variation; gear may add `stat_growth_modifiers`, currently unset on shipped items. Growth values, natural variation, and growth ranges are hidden from every player-facing screen. `set_class()` preserves all permanent stats and current HP/MP; the new class's base stats never replace the original contribution. Subsequent `set_level()` calls add the new class's growth only for new levels. Switching back or removing a class does not erase earlier gains. Levels advance from 1 to 99; lower/repeated level requests are ignored so growth cannot be removed or earned twice. A starting level above one seeds its earlier gains using the starting class.

Class abilities still use the character's level and the current class. Changing class updates these abilities and class resistances, preserves unique/medallion abilities, and unequips incompatible weapons. There are no separate class levels or permanent cross-class ability unlocks yet.

Leveling does not refill HP/MP. Call `restore()` explicitly to replenish a character. Temporary statuses and artifacts remain separate from permanent growth and disappear normally when removed. New Game creates fully replenished level-one characters.

All four playable characters start as **Explorer**. Explorer adds +10 HP, +10 MP, and +2 to every other primary stat at creation. Each level contributes +5 HP, +3 MP, and +1 to Strength, Defense, Mental Acuity, Mental Resilience, and Speed. Their character-specific growth also contributes, so units remain distinct.

## Status abilities

Set an ability's **Effect** to **Status** and assign a **Status Effect** resource. It needs no damage type. The same known-ability, living-target, and MP checks apply as for other abilities. On success it applies the status, spends MP, and returns `amount: 0` plus `status_id`.

Statuses use `stat_percent_modifiers`: `{&"defense": 0.25}` increases defense by 25%, while `{&"mental_resilience": -0.2}` reduces Mental Resilience by 20%. Different active statuses add their percentages, with a minimum total multiplier of zero. Apply this multiplier to permanent stats plus artifact bonuses, then apply hidden passives and round down once. Critical rate, accuracy, evasion, and critical damage use additive percentage points instead: a modifier of `0.25` adds 25 percentage points, including from a zero base rate. Rate results clamp to 0–100%; critical damage retains its minimum multiplier of 1. Aggro uses relative percentages. Reapplying the same status refreshes its duration without stacking. Keys must be one of `RPGStats.ALL_NAMES` (primary and combat traits). Use `mental_acuity` and `mental_resilience` for Mental Acuity and Mental Resilience; UI labels use `RPGStats.display_name()`. Stats retain their existing minima; HP/MP are clamped whenever statuses are added, removed, or expire.

Different status IDs coexist and their stat modifiers add. Reapplying the same ID replaces its definition and refreshes its duration without stacking the modifier. `advance_status_turn()` runs at the end of the affected character's resolved turn in combat; a duration of three lasts for three such calls. Statuses do not use wall-clock timers. Use `remove_status(id)` to dispel an effect and `get_active_statuses()` to inspect definitions and remaining durations. Each instance owns its durations separately. Remaining statuses clear when combat ends.

Vanguard learns **Fortify** at level 2, applying **Fortified** (+25% defense for three turns). Arcanist learns **Enfeeble** at level 3, applying **Frailty** (-20% Mental Resilience for three turns). Statuses also support `turn_damage` with a damage type and `prevents_action`. Poison ticks at the end of the affected living unit's action opportunity, respects damage resistance, and can defeat the unit. Paralysis prevents actions; its duration still decreases on skipped opportunities.

## Weapons and restrictions

Edit **Allowed Weapon Types** on both character and class resources. An empty list means unrestricted for that source. If both lists are populated, a type must appear in **both** lists. Matching uses the weapon type's ID. A character without a class uses only their character list.

Use `can_equip_weapon_type(type)` or `can_equip_weapon(weapon)` to check eligibility, and `equip_weapon(weapon)` to equip. Rejected equipment leaves the existing weapon unchanged. Passing `null` unequips. `get_allowed_weapon_types()` returns the effective intersection; when that returns an empty array, `has_weapon_restrictions()` distinguishes unrestricted access from no allowed types. Changing class automatically unequips any weapon that is no longer allowed. A starting weapon is equipped only when it satisfies both restrictions.

Initial types are sword, axe, spear, hammer, dagger, staff, wand, and bow. Explorer has no class weapon restrictions, so each starting character uses their own allowed types. For example, a character permitting sword/axe/spear who changes to Vanguard (sword/axe/hammer) can use only sword/axe. Training Sword, Apprentice Staff, and Training Dagger remain available as example resources.

Weapon definitions currently provide identity and type for eligibility. Weapon stat bonuses, weapon attacks, inventory ownership, and equipment-selection UI are not implemented. Weapon types do not implicitly assign damage types to abilities.

## Damage and healing

```text
raw_damage = max(0, power + attacker_stat × scaling - target_defense)
resistance = clamp(character_resistance + class_resistance, -1, 1)
damage = round(raw_damage × (1 - resistance))
healing = round(power + caster_stat × scaling)
```

All matching resistance entries add together. Missing resistance is zero. At `1`, a character is immune; at `-1`, it takes double damage. Abilities can use defense, Mental Resilience, or bypass defense. Healing ignores defense and resistances. Damage has no minimum-one rule.

Player-facing character, hostile, and equipment information hides exact resistance values. `DamageResistance.display_label()` shows **Weak** for negative resistance above -0.5, **Very weak** at -0.5 or below, **Resistant** for positive resistance below 0.5, **Very resistant** from 0.5 to below 1, and **Immune** at 1. Neutral types are omitted; a unit with no affinities shows **None**. Character labels use the combined effective resistance; equipment labels describe the item's contribution. These labels do not change damage calculations.

`RPGCombat.calculate_amount()` previews an amount without changing either character. `RPGCombat.use_ability()` verifies that the user and target are alive, that the exact ability resource is known, and that the user has enough MP. Validation failures spend no MP. A successful cast spends its MP even if its damage attack misses; results include `missed` and `critical` flags. Healing/status effects are not accuracy or critical rolls. Damage and healing obey HP bounds and emit state-change signals. The returned amount is actual HP lost or gained, so overkill and overhealing are excluded. Successful immune hits or healing a full-health target still spend MP.

```gdscript
var usami := CharacterState.new(load("res://resources/rpg/characters/usami.tres"))
var koumi := CharacterState.new(load("res://resources/rpg/characters/koumi.tres"))
var cheer: AbilityDefinition = load("res://resources/rpg/abilities/jolly_cheer.tres")
var result := RPGCombat.use_ability(usami, koumi, cheer)
print(result) # Buffs Koumi's strength and defense and spends Usami's MP.
```

## Example content and UI

Usami, Takane, Kurako, and Koumi start as Explorers with character-specific abilities. Vanguard grants Slash at level 1, Fortify at level 2, and Cleave at level 3; Arcanist grants Ember at level 1, Mend at level 2, and Enfeeble at level 3. These classes remain available for class changes. Slash, pierce, blunt, fire, frost, lightning, poison, and arcane are the initial damage types.

Select **New Game**, then press **Tab** in the Safe Zone to inspect the party, current stats, available abilities and their effect types, future class unlocks, equipped weapon, effective allowed types, active statuses, and resistances. The starting-party definitions are exposed on the main scene's root node. The resistance types displayed by the Characters screen are exposed on its root node.

The rules foundation is connected to a [turn-based 2D combat scene](battle.md), with encounters, basic enemy AI, action planning, and target selection. Experience rewards and save files are not implemented yet.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/rpg.gd
godot --headless --path . --script res://tests/roster_skills.gd
godot --headless --path . --script res://tests/equipment_status.gd
godot --headless --path . --script res://tests/smoke.gd
```

The RPG tests cover growth, unlocks, class changes, instance isolation, damage scaling, resistance stacking, weaknesses, immunity, MP validation, healing, and defeated characters. The smoke test also checks party creation and the Characters screen.
Equipment/status tests cover character/class restriction intersections, starting weapons, class-change unequipping, status MP costs, refresh and expiration, debuffs affecting damage, and instance isolation.

See [gear](gear.md) for artifact stat/resistance modifiers, medallion spell grants, and consumables with friendly or enemy targets.

The starting party contains Usami, Takane, Kurako, and Koumi. Their separate character resources assign both `portrait` and `combat_texture` to the matching artwork in `textures/Characters/Alpha/`. All four use Explorer and their own unique skills and titles; portrait and combat textures use the supplied `_V03` images. Initial character stat/growth profiles remain editable. Generic stat/class fixtures live only under `tests/fixtures/`.

## Accuracy, critical hits, and aggro

Critical rate, critical damage, accuracy, evasion, and aggro are hidden from all player-facing information, including Characters, Manage Party, friendly/hostile battle details, equipment modifiers, and ability descriptions. Their effects still operate internally; battle outcomes can still report a miss or critical hit. The values below are developer reference only.

Character resources expose combat traits separately from growing primary stats: `critical_rate`, `critical_damage`, `accuracy`, `evasion`, and `aggro`. Statuses/artifacts can modify these through their modifier dictionaries. Rates use fractions (0.65 is 65 percentage points); critical damage is a multiplier (1.5 means 150% damage); aggro is a positive targeting weight. Use `get_combat_stat()` for these floating-point values. Rates clamp to [0, 1], critical damage has a minimum of 1, and aggro has a minimum of 0.01. The playable characters start with 5% critical rate, 150% critical damage, 95% accuracy, zero evasion, and aggro 1.

Damage hit chance is `clamp(ability.hit_chance * user.accuracy - target.evasion, 0, 1)`. **Guaranteed Hit** bypasses this check. A landed hit with **Can Crit** enabled rolls critical rate and multiplies damage by critical damage. `calculate_amount()` shows the normal-hit amount; it does not roll accuracy or criticals. Combat methods optionally accept a seeded RandomNumberGenerator for reproducible checks.

Enemy AI keeps its ordinary spread when all aggro weights are 1. If aggro differs, it chooses among living party members proportionally to their current weights at action execution, so Cover can influence attacks queued earlier. Cover is not a guaranteed redirect. Cover doubles its user’s aggro; with weights 1, 1, 1, 2, the protected unit has a 40% target probability. Speed ordering is sampled once when the round starts resolving; speed buffs affect the next round.

## Group targeting

`AbilityDefinition.Target.PARTY` and `.ENEMIES` target every living member of the corresponding faction. Click any valid group member to confirm the action. Execution collects the currently living group and spends MP once. `RPGCombat.use_ability_on_targets()` validates all recipients before spending MP; callers outside BattleSession must supply the appropriate faction/group. Single-target self abilities reject other units.

See [playable roster](roster.md) for the exact titles, unique skills, starting balance values, and authoring resources.

## Barracks and active party

**Safe Zone → Barracks** offers **Sleep**, **Manage Party**, and a disabled **Save** option. Manage Party hides the Barracks menu and opens a replacement card while Safe Zone navigation remains visible. The selected character’s portrait and current stats appear on the left; four party slots and a scrollable reserve column appear on the right. Selecting either an active or reserve name changes the inspection view. Back to Barracks or Escape closes the party card first; Clicking Barracks again in the Safe Zone navigation or pressing another Escape closes the module. The Barracks card has no Back to Safe Zone button. Selecting a different Safe Zone module replaces only the module content, preserving the navigation card. Barracks feedback mentions rest and restored HP/SP without exposing stored experience. Sleep fades the entire screen to black, applies stored experience and any resulting permanent level growth, restores HP/SP for every recruited character including downed and reserve members, and fades back into Barracks. Equipment and consumable uses remain unchanged. Navigation is blocked throughout sleep, including level-up notifications. **Sleep Fade Duration** on the main controller sets each half of the fade. Drag an active name to the reserve column to remove it from the lineup, a reserve to an empty party slot to add it, or between occupied party slots to swap order. Dropping a reserve onto an occupied party slot exchanges them, including when the party is full. Empty slots trail the compact active lineup. At least one active character must remain. Battle planning and card order follow the resulting lineup. Changes apply immediately and persist in memory across navigation and battles.

The main controller stores all recruited `CharacterState` instances in `roster`; `party` references only the active members in order. New Game creates a fresh roster from `starting_characters`, with the first four active and any additional recruits in reserve. Character information and Equipment include reserves. Barracks edits the active array while preserving state identities. Save/load is not yet implemented.

Safe Zone and service cards use `screen.gd`’s **Card Slide From** and **Card Slide Duration** Inspector settings. Safe Zone enters from the right and remains in place when selecting modules; Barracks, Tinkerer, Chemist, and the separate Manage Party card enter from the left. `Town.module_view` holds the current module as a child of the town view; the main controller retains `screen = "location"` while it is open. Cards slide out before being hidden or removed; switching between Barracks and Manage Party finishes the outgoing slide before the replacement slides in. The slide animates normalized anchors to preserve placement when the window resizes.

## Banked experience and resting

Enemies author **Base Experience Reward** on `CharacterDefinition`; sample Sentinel and Acolyte rewards are 20 and 30. One combat turn means one global battle round. When a round is committed to resolution, every living party member banks the sum of each currently living enemy's `base_experience_reward / 2^(round_number - 1)`. Planning, cancelling targets, and undoing actions grant nothing. Fractions accumulate without integer rounding. Defeating an enemy grants each living party member an additional `2^(round_number - 1)` XP, once per enemy. This bonus is independent of the enemy's base reward and works for direct attacks, consumables, group damage, and poison. Enemies already down when an encounter begins do not grant defeat bonuses. Unexecuted rounds grant nothing.

`CharacterState` keeps unspent XP in an encounter-keyed ledger. Setting HP to zero clears the character's entire unspent ledger, including rewards from earlier encounters; downed characters cannot bank new XP. Successful retreat removes only the current encounter's ledger entry for every participating party member, including all round and defeat rewards. Prior surviving encounter rewards remain. Applied progress and permanent levels are never lost on knockout or retreat. Reserves receive no combat rewards.

Sleep transfers the bank into applied `experience` and clears the bank exactly once, for the full roster including reserves. Advancing from level L to L+1 costs **100 × L** XP; retain fractional progress and overflow toward subsequent levels. Each earned level calls the existing permanent growth system using the class and equipment equipped at rest, with hidden natural variation unchanged. Levels cap at 99; applied surplus is discarded at the cap. Rest restores HP/SP after level-ups so the resulting maxima are filled. These values persist in memory; disk saves remain unimplemented and Save stays disabled.

Observe is a per-character battle toggle available during that character’s action selection. It does not consume an action. While active, effective primary and hidden combat stats are halved, excluding HP and SP. Their current values and maxima stay unchanged when toggling. The mode persists across rounds and resets at battle end. Both round rewards and enemy defeat bonuses receive a 1.5 multiplier for that character at the time the reward is banked. Previously banked XP is unchanged, and knockout/retreat penalties still apply.

When sleep grants levels, the screen remains fully black beneath a notification card. Each earned level has its own report, in roster and level order, with the character portrait, old/new level, actual primary stat values and differences, and names of newly learned abilities (or None). Hidden combat stats, growth rates, and natural variation remain concealed. Continue advances through reports; Return to Barracks dismisses the final report. Enter/Space activates the focused button, and Escape advances or dismisses. The return fade begins only after all reports are dismissed; sleep without a level-up fades back immediately after rest. The card is `scenes/ui/level_up_notice.tscn`.
