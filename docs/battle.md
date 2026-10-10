# Turn-based 2D combat

Run the project with **F5**, choose **New Game → Enter the Labyrinth**, and press **B** to start the map's sample encounter. You can also open `scenes/battle/combat.tscn` and use **F6** to preview combat with a separate example party.

Entering combat from the map fades to black over 0.35 seconds, switches to the battlefield, then fades the black overlay away over **two seconds**. The portrait, round counter, commands, party cards, and log stay hidden during the reveal, and input is blocked until it finishes. The background and enemies remain visible beneath the fade. Adjust **Battle Fade In Duration** and **Battle Reveal Duration** on the main scene root in the Inspector. The former character description panel has been removed.
Press **Tab** during combat to open a fullscreen information panel. A single button at the right switches sides: **Hostiles** when viewing friendlies, and **Friendlies** when viewing hostiles. Select a unit to see its level, class, title, HP/MP, current primary stats, abilities, weapons, gear, active statuses, and damage resistances. All enemy information is available immediately, including defeated units. Each side remembers its selected unit. **Tab**, **Esc**, or **Return to battle** closes the panel without changing planned actions or the current target selection. Queued actions pause while it is open. The shortcut is unavailable during the battle intro.


## Round flow

1. Choose an action for each living party member, in party order. The left action card offers **Attack**, **Defend**, **Special**, the equipped consumable (or a disabled **Consumable** placeholder), **Observe**, and **Run**. When a previous character has chosen an action, **Return to <character name>** appears immediately above Run and reopens that character’s choice. Special slides a scrollable submenu out to the right of the action card, leaving the action menu open. It lists all available character, class, and medallion abilities with SP costs; unaffordable abilities are disabled. Right-click, Esc, clicking outside the submenu, or selecting an ability slides it back behind the action card. Dismissal leaves planned actions unchanged. The active character's portrait fills the right 60% of the screen over the enemies and behind the game UI.
2. Choose **Attack**, an available learned/unique ability, or **Wait**. Unaffordable abilities are disabled. Attack always costs zero MP.
3. For attacks and abilities, select a valid enemy or party member. The portrait hides and the action menu slides off the left edge during targeting so the battlefield is visible. Targeting displays no instructional prompt; **Right-click** or **Esc** cancels targeting. When selecting an ability from Special, the drawer finishes collapsing before the main menu slides away. Target buttons become active after the drawer has collapsed. Selecting a target slides the menu back in for the next character. Click a party card to choose an ally. **Esc** returns to the action list and restores the portrait.
4. After every living character has an action, review the queue. **Edit previous choice** lets you change earlier choices. HP, MP, and status durations do not change during planning.
5. Select **Execute round**. Enemies commit their choices, then all queued actions execute one at a time. Input is locked during resolution, and the battle log reports the results.
6. Surviving sides begin a new planning round. Combat ends as soon as either side has no living members.

**Defend** halves incoming attack/ability and consumable damage for the entire committed round, including attacks before the defender’s turn. It costs no SP, expires at the next round, and does not reduce poison. **Run** is planned like other actions and guarantees retreat when that character can act; defeat or paralysis can prevent it. Retreat preserves HP/SP, clears battle statuses, and returns to the map without a victory.

**Observe** toggles independently for the active character without committing an action. While checked, it halves effective stats except HP and SP and grants 50% more round and enemy defeat XP to that character. Current HP/SP and their maxima stay unchanged when toggling. Observe persists across rounds and resets at battle end. Existing knockout and retreat XP penalties still apply.

Actions resolve by descending speed, sampled when execution begins. Equal speeds use party order followed by encounter enemy order. Speed changes during resolution affect the next round's initiative. Defeated and paralyzed actors cannot act; paralysis expires by counting skipped action opportunities. An enemy-targeting action whose target was defeated retargets another living enemy; defeated ally/self targets cause the action to fail without spending MP.

Enemy AI uses its first affordable, enemy-targeting damage ability, or a basic attack if none is available. Current aggro weights can redirect its target at execution; neutral weights preserve its ordinary spread. Basic Attack uses the editable `resources/rpg/abilities/basic_attack.tres` parameters: blunt damage, strength scaling, defense mitigation, and no MP cost. It does not derive damage from equipped weapons yet.

Abilities have an editable **Targeting** property: Enemy, Ally, Self, Any, Party, or Enemies. Group abilities apply to every living member of the chosen side and spend MP once. Mend targets one ally and Fortify targets self; damage abilities and Enfeeble target enemies. Target selection uses living characters only; there is no resurrection action.

Four compact party cards at the bottom display each character's name on the top row, with a green HP bar on the left and a blue SP (mana) bar on the right below it. Both bars show current and maximum values. Unoccupied cards remain visible as disabled **Empty** slots with empty bars; they are excluded from targeting and turn planning. New Game starts Usami, Takane, Kurako, and Koumi, filling all four cards with their matching character portraits. SP is the combat UI label for the existing MP pool (`current_mp`, `max_mp`, and ability `mana_cost`); it is not a separate resource. Bars refresh after resolved actions, including poison, damage, healing, and ability-point costs. Zero maximum SP displays `0 / 0` with an empty bar.

The affected character's status durations advance after its resolved turn, including Wait and turns skipped by paralysis. Poison deals its per-turn damage at this point, before duration expiration. Applying a status to oneself counts that turn toward the duration. Remaining statuses are cleared on both sides when the battle ends. HP and MP persist. Victory automatically restores the existing map, player position, movement, and mouse capture. Defeat returns to the originating town; start a New Game from the main menu to reset a defeated party. Combat XP is banked until sleeping at Barracks. Level-up cards appear over the black sleep screen before returning to Barracks; revival actions and save files remain future work.

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
| `resources/rpg/encounters/training.tres` | Sample Sentinel/Acolyte encounter |
| `resources/rpg/enemies/` | Enemy character definitions using the same stat, ability, and resistance system as party characters |

Set a Map root's **Encounter** resource to choose its battle. The scene contains six staggered enemy positions spread across the battlefield, including behind the action panel. Set the anchors of `EnemySpots/Spot1` through `Spot6` in the 2D editor to change their position and size. Enemy definitions fill spots in encounter order; unused slots hide. An encounter accepts one to six enemies, including multiple independent instances of the same definition.

`Party/Character1` through `Character4` are saved instances of `party_card.tscn`, arranged into equal-width slots by the HBoxContainer. Parties contain one to four actual character states. Add definitions to the main scene's **Starting Characters** list to populate additional cards; capacity does not create extra characters automatically. Encounters or parties exceeding the scene capacity are rejected before combat starts.

## Resizing and layout

All UI regions use anchors or containers, with no fixed pixel positions or positional offsets. In the Inspector, adjust **Layout → Anchors** for RoundCounter, EnemySpots, Party, ActionPanel, SpecialDrawer, BattleLog, PortraitOverlay, and each enemy spot. Values from 0 to 1 describe fractions of the parent rectangle. PortraitOverlay spans x=0.4–1.0 and the full screen height, and renders over the enemies and behind party cards and commands. Children managed by a Container use size flags and stretch ratios instead of anchors; theme margins and minimum button heights provide readable spacing.

The window is resizable, with a minimum of 800 × 450. `project.godot` retains a 1280 × 720 design size and `canvas_items` stretch with `expand`, so the UI scales at smaller window sizes and adapts to different aspect ratios. `scripts/window_settings.gd` sets the minimum for both normal play and F6 scene previews. Portrait and enemy images preserve their aspect ratio. Long action titles clip within their buttons and remain available as tooltips; overflowing action lists and the log can scroll.

Godot's embedded Game view has a separate size mode that defaults to **Fixed Size**, even when the project allows resizing. In the **Game** screen's top-right menu, choose **Stretch to Fit** to resize inside the editor, or uncheck **Embed Game on Next Play**, stop, and run again to use a normal window with draggable borders. The local project editor preference is configured for standalone play; an editor already open may need this toggle changed manually or a restart. Editor preferences in `.godot/` are local and are not tracked in Git. Removing `window/size/resizable=true` when saving `project.godot` is normal because true is Godot's default.

Assign **Portrait** textures on character definitions and **Combat Texture** textures on enemy definitions. Missing images use labelled grey placeholders. Each character definition has a **Portrait Presentation** section in the Inspector:

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
Capacity tests exercise a full party and all six enemies, including targeting the sixth enemy and requiring all four characters to plan before execution. Layout tests fill all ten slots and resize the window through small, standard, ultrawide, and portrait dimensions, checking that combat regions, enemy images/labels, menus, and the party screen stay within the viewport, enemy target regions do not overlap, and resizing preserves combat state. Add `-- --screenshots` to the graphical layout command to save previews under `/tmp/negi-layout-*.png`.

See [gear](gear.md) for artifact stat/resistance modifiers, medallion spell grants, and consumables with friendly or enemy targets.

The action menu slides in after the battle intro and at the start of each new round. Once every living character has chosen an action, it slides away and a confirmation card slides up into the center. The card asks **Proceed with this round?** without listing the selected actions. Choose **Execute round**, or **Return to <character name>** to revise the last choice. Execution slides the confirmation away. **Menu Slide Duration** on the Combat root controls these animations (default 0.25 seconds). Slides use normalized anchors so resizing and interrupted transitions preserve the layout.

Character portraits slide in and out from the right alongside action selection and targeting, retaining each character’s own artwork adjustments. The battle log appears at the top only while actions resolve. Its background is mostly transparent and it shows only the two most recent performed actions, one per line. Long lines clip instead of wrapping and remain available as a tooltip.

The top-right round counter shows only **Round N**, slides down when planning begins, and slides up out of view while actions resolve. Party HP/SP cards slide up from the bottom after the intro and remain visible through targeting, confirmation, and resolution.

At battle end there is no prompt. The log adds **Victory!**, **Defeat.**, or **Escaped!** and remains visible for one second. The party cards, log, and enemies then slide out, followed by a fade to black and back to navigation. Victory and retreat restore the existing map; defeat returns to town. **Battle Return Fade Duration** on the main root controls each half of the return fade (default 0.35 seconds). Input stays blocked through the return transition.

Battle Information slides down from above when opened and slides back up when closed. Its **Slide Duration** is editable on the BattleInformation node (default 0.25 seconds). Tab can reverse an in-progress slide. Battle actions and mouse input remain blocked through the closing animation.
