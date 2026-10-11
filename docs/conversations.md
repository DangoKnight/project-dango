# Conversation events

Conversations are reusable Godot resources. They overlay the current scene, show at most two portraits (left and right), and pause the scene tree. Movement, encounters, scene tweens, and battle action delays resume where they stopped. The previous mouse capture and keyboard focus are restored afterward. Requests made during navigation, battle fades, or rest notices wait for that transition to finish.

## Fabricating an event in Godot

1. In the FileSystem dock, create a new **ConversationEvent** resource under `resources/conversations/` and save it as a `.tres` file.
2. Expand **Lines**, set its size, and create a **ConversationLine** resource for each entry.
3. Assign **Left Character** and/or **Right Character** from `resources/rpg/characters/`. Leaving a side empty hides it. Each line defines both slots, so retain the character assignments on subsequent lines if they should stay visible.
4. Select **Speaker** (Narrator, Left, or Right) and enter **Text**. Speaking portraits remain bright; the other portrait dims. **Speaker Name**, the side-specific names, and portrait overrides support narration, expressions, and NPCs without a roster resource. Portraits fit their slots without using battle-specific offsets.
5. Set **Characters Per Second** on the event; zero displays text immediately. Set a unique **ID** and enable **Once Per Game** if the event must only finish once per new game.

`resources/conversations/station_check_in.tres` is the opening conversation with Usami and Takane at Station 45-B. New Game reveals the Safe Zone with a fade from black, then starts the conversation once the fade finishes. Safe Zone action buttons are disabled before the town is presented and remain disabled until the conversation finishes. Returning to town does not replay the opening; starting another New Game does.

Select the root of `scenes/main.tscn` and change **Opening Conversation** to replace the event, or **New Game Reveal Duration** to adjust the fade. An empty or invalid event skips the opening. Automated gameplay fixtures can call `new_game(false)` to initialize a party without the opening or its fade.

## Portrait entrances and slots

**Slot 1 is the left side; Slot 2 is the right side.** Assign the character to **Left Character** or **Right Character** on the dialogue line to choose their destination. Each slot has an entrance group with **Entrance**, **Entrance Duration**, **Entrance Delay**, and **Repeat Entrance**. Choose Instant, From Left, From Right, From Top, From Bottom, or Fade. Direction is independent of the destination slot.

For Usami to slide in from the right into slot 2, assign Usami to **Right Character**, then set **Slot 2 (Right) Entrance → Right Entrance** to **From Right**. The opening event already demonstrates this, with Takane sliding into slot 1 from the left.

Entrances normally play when a character first appears or replaces another character in that slot. Keeping the same character in the same slot on the next line preserves their position and any animation still running. Enable **Repeat Entrance** to replay an entrance deliberately. Assigning a portrait override for the same character changes their expression without replaying their entrance. Slides use proportional anchors, so they adapt to window resizing. Dialogue typing starts alongside the portrait transitions.

Each line also has **Slot 1 (Left) Exit** and **Slot 2 (Right) Exit** groups. These settings apply to the **previous occupant** when the new line replaces or clears that slot. Choose Instant, To Left, To Right, To Top, To Bottom, or Fade, and set **Exit Duration**. With an animated exit, the outgoing character leaves first; only then does the new character appear and perform their configured entrance (including its delay). A slot always displays at most one character.

For example, on the line where Takane replaces Usami in slot 2, assign Takane to **Right Character**, set **Right Exit** to **To Right**, and **Right Entrance** to **From Right**. Usami slides out to the right, then Takane slides in. The opening now uses this pattern for its character replacements. To create a separate departure step, add a line with an empty slot and configure its exit; the next line can introduce a new occupant. Leaving the exit at Instant retains immediate replacement/hiding. Rapidly advancing lines cancels superseded transitions safely.

To preview an event, open `scenes/ui/conversation_preview.tscn`, select its root, assign **Event**, and press **F6** to run that scene. The preview initially uses the example event. Close the preview window after the conversation ends.

Click, Enter, or Space reveals the rest of a line, then advances on the next press. The last line closes the event. Escape and Tab do not open other menus during a conversation. Long dialogue can scroll inside the text area. The layout uses anchors and supports window resizing.

## Triggering in town, exploration, or battle

Instance `scenes/ui/conversation_trigger.tscn` under the desired Town, Map, or combat scene. Assign its **Event**. Enable **On Scene Entry** for an automatic conversation when that scene loads. **Once Per Instance** prevents repeat requests from the same node; **Once Per Game** on the event prevents repeats across scene reloads. Neither option saves completion to disk.

For a location trigger, connect an `Area3D.body_entered` signal to the trigger's `trigger` method and configure the area's collision mask to detect the player. Leave **On Scene Entry** disabled. The trigger accepts an optional signal payload; custom conditions should be checked in the caller.

Any gameplay script can also request a conversation directly:

```gdscript
const CHECK_IN = preload("res://resources/conversations/station_check_in.tres")

func talk() -> void:
    Conversations.play(CHECK_IN)
```

For a battle condition, connect to the configured `CombatScreen.session` signals, then call `Conversations.play(event)` when the condition is met. For example, a round-based event can check `session.round_number` and `session.phase` in `session.changed`; use **Once Per Game** or a local guard to avoid repeated requests. `session.enemy_defeated` can trigger a species-specific conversation. An already resolving action completes its synchronous calculation before the scene pauses; subsequent actions wait until the conversation ends.

`Conversations.play()` returns whether a request was accepted. Accepted requests queue in order; the scene stays paused between queued conversations. `Conversations.started(event)` and `Conversations.finished(event)` identify which event is being displayed or has completed. Check the event ID when reacting to these shared signals. `Conversations.is_active()` reports whether an overlay is open. `Conversations.reset()` clears pending events and completion history; starting a new game already calls it.

### Ending with both characters leaving

Append one final **ConversationLine** to the event's **Lines** array. Clear both character slots and any portrait overrides, leave **Text** empty, set **Left Exit** to **To Left** and **Right Exit** to **To Right**, and enable **Auto Advance**. Adjust each exit duration as desired. The dialogue card hides for this step, both characters leave together, and the conversation closes only after both animations finish, without another click. Choose different exit directions if needed. The opening conversation includes this final departure step.

**Auto Advance** also supports intermediate animation steps: it waits for both slots' transitions and any text typing to finish before proceeding. Manual advance is ignored during an automatic step so departure animations finish fully. For text the player should read at their own pace, leave Auto Advance disabled.

Set **Minimum Duration** to hold a step for a specified number of seconds from its start, including its portrait animations. Neither manual nor automatic advancement can shorten that time; longer animations still finish before automatic advancement. Opening step **10** uses **Auto Advance** and a **Minimum Duration** of **1.0**: its portraits slide out, the empty scene holds for the remainder of that second, then Koumi's next line begins.

During the opening, the Safe Zone action card stays hidden through the scene fade and the entire conversation. It slides in from the right after the conversation and final departures finish.

The overlay scene is `scenes/ui/conversation.tscn`. Edit its portrait anchors, dialogue panel, font sizes, or colors to change presentation for every event. These resources do not modify party membership or character stats.
