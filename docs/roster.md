# Playable roster

Usami, Takane, Kurako, and Koumi all start in the **Explorer** class. Their existing `_V03` portrait assignments and individual offset/scale adjustments are preserved. Character resources live in `resources/rpg/characters/`; skills and statuses are editable `.tres` files in their respective RPG resource directories.

| Character | Title | Unique skills |
| --- | --- | --- |
| Usami | The friendly rabbit | Jolly cheer; Caring friend |
| Takane | The hunting hawk | Lock-on; Ride the gale; Graceful assault |
| Kurako | The prankster jellyfish | Painful stab; Immobilizing stab; I am scary! |
| Koumi | Enigmatic hare | Bonk; Cover |

These values are starting balance choices for the requested minor/moderate/massive effects. Attack buffs/debuffs modify **Strength**. Buffs/debuffs last three affected action opportunities unless listed otherwise. Self-application counts the casting turn, matching the existing status timing rules.

| Skill | Target | MP / SP | Effect |
| --- | --- | --- | --- |
| Jolly cheer | One ally | 4 | +4 Strength and +4 Defense for 3 turns |
| Caring friend | Living party | 5 | Each ally heals 8 + 0.3 × caster Mental Acuity HP, rounded and capped at maximum HP |
| Lock-on | Self | 5 | +65 percentage points critical rate and +1.0 critical damage multiplier for 3 turns; default 5% / 150% becomes 70% / 250% |
| Ride the gale | Self | 3 | +4 Speed for 3 turns; affects subsequent round initiative |
| Graceful assault | One enemy | 4 | Pierce damage: power 8 + Strength, minus Defense and adjusted for Pierce resistance; cannot miss |
| Painful stab | One enemy | 4 | Weak poison: 3 Poison damage before resistance at the end of each affected turn, for exactly 5 ticks |
| Immobilizing stab | One enemy | 5 | Paralysis blocks the next 2 action opportunities, including an already queued action |
| I am scary! | Entire living enemy party | 6 | -3 Strength and -3 Mental Acuity for 3 turns |
| Bonk | One enemy | 3 | Moderate bash attack using the existing Blunt damage type: power 12 + 1.2 × Strength, minus Defense and adjusted for resistance |
| Cover | Self | 4 | +4 Defense and +2 aggro weight for 3 turns; increases the probability of receiving enemy attacks |

Poison and paralysis are status applications with no additional immediate stab damage. Status applications and healing do not roll accuracy or criticals. Damage abilities, including Bonk and Graceful assault, can critically hit. Graceful assault bypasses accuracy and evasion, but still respects Defense and Pierce resistance.

Group actions confirm through any living member of the group and spend MP once. Dead members are excluded. Identical status IDs refresh rather than stack. Poison and paralysis clear with other statuses when battle ends. Consumables are also unusable while paralyzed.

Explorer adds balanced primary stats and growth as described in [core mechanics](core_mechanics.md). Permanent stats retain the initial class base and every earned level's growth. Class changes affect only growth on later levels; they do not reroll or replace earned stats. Class abilities, resistances, and weapon restrictions still follow the current class.

## Character descriptions

- **Usami** encourages and cares for her companions, becoming quicker on her feet when everyone is safe and healthy.
- **Takane** combines swift, precise attacks with fierce protectiveness toward Usami, fighting harder when her sister is hurt or downed.
- **Kurako** is a playful opportunist whose thinking sharpens around outmatched or afflicted opponents.
- **Koumi** is difficult to read emotionally but deliberate in action, protecting companions and showing her strongest composure at the start of a fight.

Only these four characters remain in the playable character resources. Automated stat/class tests use unnamed-role fixtures under `tests/fixtures/`.

## Hidden combat passives

These automatic effects are editable under `resources/rpg/passives/` and assigned through each character’s **Hidden Abilities**. They do not appear in Special, ability lists, or active statuses.

| Character | Hidden ability | Condition and effect |
| --- | --- | --- |
| Usami | Happy friends | All party members, including Usami, must be strictly above 70% of their current maximum HP. Speed ×1.2. Downed members prevent activation. |
| Takane | Overprotective sister | Usami strictly below 50% HP: direct damage ×1.2. Usami downed: ×1.5 instead. No bonus if Usami is absent. |
| Kurako | Easy target | Any living enemy is below Kurako’s level, has a negative stat modifier, poison, paralysis, or an explicitly negative status: Mental Acuity ×1.2. Multiple qualifying enemies do not stack it. |
| Koumi | Collected | Rounds 1–4: Strength, Defense, Mental Acuity, Mental Resilience, and Speed ×1.1; maximum HP/SP are unchanged. Expires before round 5 planning and resets each battle. |

Stat multipliers apply after permanent stats, equipment, and flat status modifiers, then round down. HP/MP capacity increases do not heal or restore points; expiration clamps excess points to the normal caps. Damage multipliers affect attacks, damage abilities, and damaging consumables after resistance; poison ticks retain their fixed status damage. Conditions update at each stat/damage calculation. Initiative still snapshots speed at round execution. All bonuses disappear at battle end and never change permanent growth. Status resources can set **Is Negative** for harmful effects without existing damage, paralysis, or stat penalties.
