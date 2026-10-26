# Turn-based 2D combat

Run the project with **F5**, choose **New Game → Enter the Labyrinth**, and walk outside the Safe Zone to encounter monsters after the labyrinth’s configured number of walking steps. You can also open `scenes/battle/combat.tscn` and use **F6** to preview combat with a separate example party.

Entering combat from the map fades to black over 0.35 seconds, switches to the battlefield, then fades the black overlay away over **two seconds**. The portrait, round counter, commands, party cards, and log stay hidden during the reveal, and input is blocked until it finishes. The background and enemies remain visible beneath the fade. Adjust **Battle Fade In Duration** and **Battle Reveal Duration** on the main scene root in the Inspector. The former character description panel has been removed.
Press **Tab** during combat to open a fullscreen information panel. A single button at the right switches sides: **Hostiles** when viewing friendlies, and **Friendlies** when viewing hostiles. Friendly units show their level, class, title, HP/MP, primary stats, abilities, weapons, gear, active statuses, and damage resistances. Hostiles show only learned compendium resistances and observed abilities, including for defeated monsters. Enemy HP/SP values, levels, and stats are always hidden. Each side remembers its selected unit. **Tab**, **Esc**, or **Return to battle** closes the panel without changing planned actions or the current target selection. Queued actions pause while it is open. The shortcut is unavailable during the battle intro.


## Round flow

1. Choose an action for each living party member, in party order. The left side offers a narrow, vertically centered group of rounded buttons on a transparent surrounding menu: **Attack**, **Defend**, **Abilities**, the equipped consumable (or a disabled **Consumable** placeholder), **Observe**, and **Run**. **Return to <character name>** sits immediately above Run and reopens that character’s choice. For the first character, it reads **Return to previous character** and is disabled. Abilities slides a transparent scrollable list out to the right, aligned with the Abilities button and leaving the action menu open. The action prompt is omitted. It lists all available character, class, and medallion abilities with SP costs; unaffordable abilities are disabled. Right-click, Esc, clicking outside the submenu, or selecting an ability slides it back behind the action buttons. Dismissal leaves planned actions unchanged. The active character's portrait fills the right 60% of the screen over the enemies and behind the game UI.
2. Choose **Attack**, an available learned/unique ability, or **Wait**. Unaffordable abilities are disabled. Attack always costs zero MP.
3. For attacks and abilities, select a valid enemy or party member. The portrait hides and the action menu slides off the left edge during targeting so the battlefield is visible. Targeting displays no instructional prompt; **Right-click** or **Esc** cancels targeting. When selecting an ability from Special, the drawer finishes collapsing before the main menu slides away. Target buttons become active after the drawer has collapsed. Selecting a target slides the menu back in for the next character. Click a party card to choose an ally. **Esc** returns to the action list and restores the portrait.
4. After every living character has an action, review the queue. **Edit previous choice** lets you change earlier choices. HP, MP, and status durations do not change during planning.
5. Select **Execute round**. Enemies commit their choices, then all queued actions execute one at a time. Input is locked during resolution, and the battle log reports the results.
6. Surviving sides begin a new planning round. Combat ends as soon as either side has no living members.

**Defend** halves incoming attack/ability and consumable damage for the entire committed round, including attacks before the defender’s turn. It costs no SP, expires at the next round, and does not reduce poison. **Run** is planned like other actions and rolls separately for each character when they can act; defeat or paralysis can prevent the attempt. Chance is `clamp(0.60 × runner Speed / max(1, fastest living opponent Speed) + 0.15 × that runner’s previous failures, 0.20, 1.00)`. Each failure consumes that character’s action and leaves the other queued actions intact. Failure bonuses last for the encounter and belong to the individual runner; any successful attempt retreats the whole party. Retreat preserves HP/SP, clears battle statuses, and returns to the map without a victory.

**Observe** toggles independently for the active character without committing an action. While checked, it halves Strength, Defense, Mental Acuity, Mental Resilience, and Speed and grants 50% more round and enemy defeat XP to that character. HP/SP, their maxima, and hidden combat traits stay unchanged when toggling. Observe persists across rounds and resets at battle end. Existing knockout and retreat XP penalties still apply.

Actions resolve by descending speed, sampled when execution begins. Equal speeds use party order followed by encounter enemy order. Speed changes during resolution affect the next round's initiative. Defeated and paralyzed actors cannot act; paralysis expires by counting skipped action opportunities. An enemy-targeting action whose target was defeated retargets another living enemy; defeated ally/self targets cause the action to fail without spending MP.

Enemy AI uses its first affordable, enemy-targeting damage ability, or a basic attack if none is available. Targets are randomly selected at execution in proportion to maximum HP, modified by aggro bonuses from gear and statuses. Current HP does not reduce targeting weight; downed units are excluded. Basic Attack uses the editable `resources/rpg/abilities/basic_attack.tres` parameters: blunt damage, strength scaling, defense mitigation, and no MP cost. It does not derive damage from equipped weapons yet.

Abilities have an editable **Targeting** property: Enemy, Ally, Self, Any, Party, Enemies, or Enemy Row. Party/Enemies abilities apply to every living member of the chosen side and spend MP once. Enemy Row abilities affect living enemies in the selected slot’s row: slots 1–3 form the upper row and slots 4–6 the lower row. Empty or defeated slots never shift the other units between rows. Kurako’s **I am scary!** affects one enemy row; her stabs remain single-target. Hovering a target highlights all living recipients, including group consumables and party healing. Mend targets one ally and Fortify targets self; damage abilities and Enfeeble target enemies. Target selection uses living characters only; there is no resurrection action.

Four compact party cards at the bottom display each character's name on the top row, with a green HP bar on the left and a blue SP (mana) bar on the right below it. Both bars show current and maximum values. Unoccupied cards remain visible as disabled **Empty** slots with empty bars; they are excluded from targeting and turn planning. New Game starts Usami, Takane, and Kurako, leaving the fourth card empty. Koumi is reserved for later recruitment and is not available in reserve at the start. SP is the combat UI label for the existing MP pool (`current_mp`, `max_mp`, and ability `mana_cost`); it is not a separate resource. Bars refresh after resolved actions, including poison, damage, healing, and ability-point costs. Zero maximum SP displays `0 / 0` with an empty bar.

The affected character's status durations advance after its resolved turn, including Wait and turns skipped by paralysis. Poison deals its per-turn damage at this point, before duration expiration. Applying a status to oneself counts that turn toward the duration. Remaining statuses are cleared on both sides when the battle ends. HP and MP persist. Victory automatically restores the existing map, player position, movement, and mouse capture. A full party wipe returns to the last visited Safe Zone, fully heals the roster, resets the global exploration multiplier, and destroys all consumables in the stash and on active/reserve characters. Non-consumable gear and permanent progress remain intact. Combat XP is banked until sleeping at Barracks. Level-up cards appear over the black sleep screen before returning to Barracks; in-battle revival actions and save files remain future work.

## Scene and resource setup

| Path | Purpose |
| --- | --- |
| `scenes/battle/combat.tscn` | Editable 2D battlefield, anchored enemy spots, portrait overlay, party targets, commands, and log |
| `scenes/battle/enemy_slot.tscn` | Reusable enemy image/name/HP target button |
| `scenes/battle/party_card.tscn` | Reusable character name, HP/SP bars, and ally target button |
| `scripts/battle/battle_session.gd` | Planning, targeting, initiative, round execution, and outcome rules |
| `scripts/battle/combat_screen.gd` | Presentation and command input |
| `scripts/battle/battle_action.gd` | A queued action's actor, target, and ability |
| `scripts/battle/encounter.gd` | Enemy definitions and encounter level |
| `resources/rpg/encounters/training.tres` | Sample Rat/Ethereal Orb encounter |
| `resources/rpg/enemies/` | Enemy character definitions using the same stat, ability, and resistance system as party characters |

Hand-authored Maps use their root's **Encounter** resource. Procedural labyrinths choose a complete `BattleEncounter` resource from their definition's **Encounters** list; JSON uses an `encounters` array of resource paths. Each preset defines its own ordered enemy lineup and enemy level. The scene contains six staggered enemy positions spread across the battlefield, including behind the action panel. Set the anchors of `EnemySpots/Spot1` through `Spot6` in the 2D editor to change their position and size. Enemy definitions fill spots in encounter order; unused slots hide. Slots have transparent button styles in every state, enlarged aspect-preserving sprites, and a compact green health bar above the image. Health bars use a normalized fraction and show no numbers. Hovering a valid target pulses its sprite toward white using a shader; the effect clears when targeting ends. Death fades the slot to transparent over 1.4 seconds without darkening RGB. Adjust Death Fade Duration on the EnemySlot scene. Enemy names, numeric HP, and hover text are omitted from the battlefield; details remain available through Battle Information. An encounter accepts one to six enemies, including multiple independent instances of the same definition.

`Party/Character1` through `Character4` are saved instances of `party_card.tscn`, arranged into equal-width slots by the HBoxContainer. Parties contain one to four actual character states. Add definitions to the main scene's **Starting Characters** list to populate additional cards; capacity does not create extra characters automatically. Encounters or parties exceeding the scene capacity are rejected before combat starts.

## Resizing and layout

All UI regions use anchors or containers, with no fixed pixel positions or positional offsets. In the Inspector, adjust **Layout → Anchors** for RoundCounter, EnemySpots, Party, ActionPanel, SpecialDrawer, BattleLog, PortraitOverlay, and each enemy spot. Values from 0 to 1 describe fractions of the parent rectangle. PortraitOverlay spans x=0.4–1.0 and the full screen height, and renders over the enemies and behind party cards and commands. Children managed by a Container use size flags and stretch ratios instead of anchors; theme margins and minimum button heights provide readable spacing.

The window is resizable, with a minimum of 800 × 450. `project.godot` retains a 1280 × 720 design size and `canvas_items` stretch with `expand`, so the UI scales at smaller window sizes and adapts to different aspect ratios. `scripts/window_settings.gd` sets the minimum for both normal play and F6 scene previews. Portrait and enemy images preserve their aspect ratio. Long action titles clip within their buttons and remain available as tooltips; overflowing action lists and the log can scroll.

Godot's embedded Game view has a separate size mode that defaults to **Fixed Size**, even when the project allows resizing. In the **Game** screen's top-right menu, choose **Stretch to Fit** to resize inside the editor, or uncheck **Embed Game on Next Play**, stop, and run again to use a normal window with draggable borders. The local project editor preference is configured for standalone play; an editor already open may need this toggle changed manually or a restart. Editor preferences in `.godot/` are local and are not tracked in Git. Removing `window/size/resizable=true` when saving `project.godot` is normal because true is Godot's default.

Assign **Portrait** textures on character definitions and **Combat Texture** textures on enemy definitions. Missing images use an anonymous expedition portrait or the rat sprite. Rats and floating ethereal orbs have distinct square transparent artwork against a fluorescent office hall backdrop. Each character definition has a **Portrait Presentation** section in the Inspector:

- **Portrait Offset** moves only that character's artwork. X is horizontal, Y is vertical; positive values move right/down. Values are fractions of the portrait area: `0.1` moves 10% of its width/height, so placement adapts to window resizing.
- **Portrait Scale** uniformly scales the artwork around its center: `1` is normal, `0.8` is smaller, `1.2` is larger.
- **Portrait Stretch Mode** can inherit the scene's setting (**Scene Default**), show the whole image while preserving aspect ratio (**Fit**), or fill the rectangle with cropping (**Fill**).

Open `resources/rpg/characters/usami.tres`, `takane.tres`, `kurako.tres`, or `koumi.tres` to adjust each separately. For example, set Offset Y to `0.1` to move the character down, or Scale to `0.85` to shrink it. For live adjustment, open `scenes/ui/portrait_preview.tscn` in Godot and switch to the **2D** workspace. Select the **PortraitPreview** root, expand **Preview Character** in the Inspector, and edit its **Portrait Presentation** fields. The artwork updates immediately without running the game. Drag another character `.tres` from the FileSystem dock onto **Preview Character** to switch. Save the character resource after editing. The preview instances the actual combat scene and shares its placement logic. You can also press **F6** in the combat scene to test the result in play; choose Wait to advance to the next character. Test window resizing too. Individual transforms apply inside the scene's existing portrait layout; **PortraitOverlay** stays anchored to the right 60%, preserving its position beneath the game UI. Defaults preserve the existing scene appearance. Supplied character artwork replaces the grey portrait fallback. Change the combat scene's **Action Delay** to adjust the pause between action messages.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/portrait_preview.gd
godot --headless --path . --script res://tests/battle.gd
godot --headless --path . --script res://tests/layout.gd
godot --path . --script res://tests/battle.gd
godot --path . --script res://tests/layout.gd
```

Tests cover planning without side effects, target rules, undo/cancel, initiative and ties, retargeting, defeated actors, status timing, fixed enemy positions, portrait transitions, victory/defeat, and return to the existing map. The graphical run also checks mouse recapture after victory.
Capacity tests exercise a full party and all six enemies, including targeting the sixth enemy and requiring all four characters to plan before execution. Layout tests fill all ten slots and resize the window through small, standard, ultrawide, and portrait dimensions, checking that combat regions, enemy images/labels, menus, and the party screen stay within the viewport, enemy target regions do not overlap, and resizing preserves combat state. Add `-- --screenshots` to the graphical layout command to save previews under `/tmp/dango-layout-*.png`.

See [gear](gear.md) for artifact stat/resistance modifiers, medallion spell grants, and consumables with friendly or enemy targets.

The action menu slides in after the battle intro and at the start of each new round. Once every living character has chosen an action, it slides away and a confirmation card slides up into the center. The card asks **Proceed with this round?** without listing the selected actions. Choose **Execute round**, or **Return to <character name>** to revise the last choice. Execution slides the confirmation away. **Menu Slide Duration** on the Combat root controls these animations (default 0.25 seconds). Slides use normalized anchors so resizing and interrupted transitions preserve the layout.

Character portraits slide in and out from the right alongside action selection and targeting, retaining each character’s own artwork adjustments. The battle log appears at the top only while actions resolve. Its background is mostly transparent and it shows only the two most recent performed actions, one per line. Long lines clip instead of wrapping and remain available as a tooltip.

The top-right round counter shows only **Round N**, slides down when planning begins, and slides up out of view while actions resolve. Party HP/SP cards slide up from the bottom after the intro and remain visible through targeting, confirmation, and resolution.

At battle end there is no prompt. The log adds **Victory!**, **Defeat.**, or **Escaped!** and remains visible for one second. Once every defeated monster has finished fading away (even if this takes longer than the one-second hold), the party cards, log, and enemies slide out, followed by a fade to black and back to navigation. Victory and retreat restore the existing map; a full party wipe restores the last visited Safe Zone with a fully healed roster and the consumable-loss penalty. **Battle Return Fade Duration** on the main root controls each half of the return fade (default 0.35 seconds). Input stays blocked through the return transition.

Battle Information slides down from above when opened and slides back up when closed. Its **Slide Duration** is editable on the BattleInformation node (default 0.25 seconds). Tab can reverse an in-progress slide. Battle actions and mouse input remain blocked through the closing animation.

Undiscovered resistances are listed by damage type with `???` (for example, **Pierce: ???**) in both the compendium and Hostiles panel. Discovering an affinity replaces only that row with its qualitative label. Unobserved abilities show `???`; enemy numerical stats and HP/SP maxima remain hidden.

Living enemy sprites slide out through the top of the screen on battle exit, including retreat. Party bars continue to leave through the bottom.

## Battle animations

Attacks now play pre-made frame animations on each affected target. Slash, pierce,
blunt, fire, frost, lightning, poison, and arcane have separate presets. Healing,
positive statuses, negative statuses, defending, and consumable effects also have
presentation. Missed or failed effects do not show a successful impact. Group
abilities animate all actual recipients, including the selected enemy row.

The unique skills Jolly cheer, Caring friend, Lock-on, Ride the gale, Graceful
assault, Painful stab, Immobilizing stab, I am scary!, Bonk, and Cover have their
own presets, using different clips, tints, sizes, or combinations of imported
clips. No animation artwork is generated at runtime.

To configure a skill, open its ability `.tres` in Godot and choose **Battle
Animation**. Explicit presets override the damage type. **Auto** prioritizes healing and status effects, then falls back to the damage type. Custom
presets are defined in `scripts/battle/battle_effects.gd`; the imported, non-looping
`SpriteFrames` clips can be inspected in `resources/battle/effects.tres`. The
Combat root's **Attack Animation Duration** controls playback time (default 0.7
seconds; zero disables effects). **Action Delay** remains the pause after each
completed animation.

Enemies receive effects over their sprite. Friendly effects are centered directly over
their compact party card, scaled to the card and drawn above its name and bars. Positions follow the target when the window resizes.
Effects pause with conversation events and battle information. The next action
waits for the current effects, and planning controls stay hidden through the last
animation in the round. Victory waits for the final animation, then shows its log
and follows the existing disappearance/return transition.

Artwork comes from **BDragon1727's 1050 RPG Effects 64x64 — free bundle**.
The complete free bundle contains 252 original sheets with nine color rows each,
plus animated catalog previews, preserved under `textures/battle_fx/bdragon`.
Current battle presets load only the sheets they need. The other sheets are
available for future abilities; each sheet uses 64 × 64 frames from left to right,
with one color variant per row. Original PNGs are unchanged. Effects use nearest
filtering to preserve their pixel art and play once over **Attack Animation Duration**.

`textures/battle_fx/sources.json` records sheet IDs, checksums, color rows and
preset mappings. Regenerate `resources/battle/effects.tres` after changing a
mapping with `python tools/import_bdragon_effects.py`, and keep the preset's
size in `BattleEffects.PROFILES` consistent with the mapping. Special ability
presets retain priority over damage-type effects.

This pack uses BDragon's custom license, not CC0. Noncommercial use is free;
commercial use requires a contribution. Standalone asset redistribution is
prohibited. See `textures/battle_fx/CREDITS.txt` and the publisher's page:
https://bdragon1727.itch.io/1050-rpg-effects-64x64.

Press **Q** in battle to toggle an unobstructed view of the background and enemies, including their health bars and effects. Commands, friendly portraits/cards, round counter, log, confirmation, and battle information are hidden. Press Q again to restore the current UI state. Hidden controls cannot receive input; an ongoing action sequence continues. Confirmation uses a compact rounded panel and the same rounded buttons as the action menu.
