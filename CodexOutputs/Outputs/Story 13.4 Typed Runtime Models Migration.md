# Story 13.4 — Replace Runtime Dictionaries with Typed Models

## Goal

Replace dictionaries representing stable runtime objects with typed `RefCounted` models. Keep dictionaries for raw JSON, serialization, genuine lookup maps, and test-fixture bundles.

Do not maintain parallel dictionary and typed APIs. The completed story must have one working typed path.

## Current position

Already complete:

- `CardData` is in `src/main/cards/models/`.
- `EffectData` is in `src/main/effects/models/`.
- Combat models are in `src/main/combat/models/`.
- Board-refill models are in `src/main/board/board_refill/models/`.
- `GraveyardEntry` is in `src/main/graveyard/models/`.
- `GameAction` exists in `src/main/actions/models/`.
- The queue, processor, and signals are partly typed as `GameAction`.

The current branch is incomplete and cannot compile cleanly: payload classes do not exist, `ActionType.make()` uses an undefined variable, and callers still pass dictionaries.

Use `models`, not `objects`, for data-only classes. Resources such as `CardData` and `EffectData` are models too. Do not move behavioural classes merely because they extend `RefCounted`.

## 1. Finish the generic action envelope

In `ActionType` at line 30 in `src/main/singletons/actions/action_object.gd`, change:

```gdscript
static func make(actionType: String, source = null, target = null, data: Dictionary = {}) -> GameAction:
	return GameAction.create(actionType, source, target, payload)
```

to:

```gdscript
static func make(
	actionType: String,
	source: Variant = null,
	target: Variant = null,
	payload: ActionPayload = null,
) -> GameAction:
	return GameAction.create(actionType, source, target, payload)
```

In `GameAction` at line 9 in `src/main/actions/models/game_action.gd`, retain four typed constructor arguments and the `GameAction` return type. Change line 10 from `var action = GameAction.new()` to `var action := GameAction.new()`.

In `GameAction` at line 17, keep `isValid()` as the action-type validator:

```gdscript
func isValid() -> bool:
	return type in ActionType.VALID_TYPES
```

In `ActionQueue` at line 6 in `src/main/singletons/actions/action_queue.gd`, change:

```gdscript
if !action.isValid():
```

to:

```gdscript
if action == null or !action.isValid():
```

This is required because typed arguments can still be `null`.

In `ActionQueue` at line 14, add `if expectedAction == null: return null` before starting the wait loop.

In `ActionQueue` at line 20, change `var resolvedAction = resolution[0]` to `var resolvedAction := resolution[0] as GameAction`.

In `ActionQueue` at line 30, change `var action = _queue.pop_front()` to `var action := _queue.pop_front()`.

In `ActionProcessor` at line 17 in `src/main/singletons/actions/action_processor.gd`, change the popped action declaration to `var action := ActionQueue.popNextAction()`.

In `ActionProcessor` at line 136, change the bare `return` to `return null` because `_handleRemoveCard()` returns `GraveyardEntry`.

In `GlobalSignalBus` at line 60 in `src/main/singletons/global_signal_bus.gd`, retain the typed signal and change it to `signal actionResolved(action: GameAction, result: Variant)`.

## ==2. Create the action payload models==

Create `src/main/actions/models/payloads/action_payload.gd` containing `class_name ActionPayload`, extending `RefCounted`, with `var cause: String = "effect"`.

Create `DealDamagePayload` in `src/main/actions/models/payloads/deal_damage_payload.gd`. It extends `ActionPayload`, contains `amount: int` and `cycleNumber: int`, and has `create(amount, cause = "effect", cycleNumber = 0)`.

Create `ModifyStatsPayload` in `src/main/actions/models/payloads/modify_stats_payload.gd`. It extends `ActionPayload`, contains `stat: String` and `amount: int`, and has `create(stat, amount, cause = "effect")`.

Create `RemoveCardPayload` in `src/main/actions/models/payloads/remove_card_payload.gd`. It extends `ActionPayload`, contains `sourceInstanceId: int = 0`, and has `create(cause = "effect", sourceInstanceId = 0)`.

Create `MoveCardPayload` in `src/main/actions/models/payloads/move_card_payload.gd`. It extends `ActionPayload` and has `create(cause = "effect")`.

Create `RevealCardPayload` in `src/main/actions/models/payloads/reveal_card_payload.gd`. It extends `ActionPayload` and has `create(cause = "effect")`.

Delete and revive currently use only their envelope fields. Do not create unused subclasses. Pass `null` unless their cause becomes real behaviour.

## 3. Convert every production action creator

In `CombatResolver` at lines 52–61 in `src/main/combat/combat_resolver.gd`, change the defender damage dictionary to `DealDamagePayload.create(context.attackerDamage, "combat", context.cycleNumber)`.

In `CombatResolver` at lines 62–71, change the retaliation dictionary to `DealDamagePayload.create(context.retaliationDamage, "combat_retaliation", context.cycleNumber)` and rename `retalitation` to `retaliation`.

In `CombatResolver` at lines 73–78, change `ActionType.isValid(defenderHit)` and `ActionType.isValid(retalitation)` to `defenderHit.isValid()` and `retaliation.isValid()`.

In `CombatResolver` at lines 82 and 89, rename the remaining `retalitation` references to `retaliation`.

In `CombatResolver` at lines 106–114, change the defender removal dictionary to `RemoveCardPayload.create("combat", context.attackerInstanceId)`.

In `CombatResolver` at lines 126–134, change the player removal dictionary to `RemoveCardPayload.create("combat_retaliation", context.defenderInstanceId)`.

In `CombatResolver` at lines 151–156, change the movement dictionary to `MoveCardPayload.create("combat_advance")`.

In `BoardRefillController` at line 24 in `src/main/board/board_refill/board_refill_controller.gd`, change `{"cause": refillRequest.cause}` to `RevealCardPayload.create(refillRequest.cause)`.

In `JourneyDeck` at lines 68–72 in `src/main/decks/deck_types/journey_deck.gd`, add `RevealCardPayload.create("manual_reveal")` as the fourth argument. The processor rejects a reveal without it.

In `GainHealthOnPlay` at lines 20–25 in `src/main/effects/handlers/gain_health_on_play.gd`, change the dictionary to `ModifyStatsPayload.create("health", parameters.amount, data.id)`.

In `card_test_scene` at lines 262–267 in `src/tests/card_test_scene.gd`, change `{"cause": "manual_test"}` to `RemoveCardPayload.create("manual_test")`.

In `card_test_scene` at lines 278–283 and 299–304, remove the dictionary fourth arguments because delete and revive do not consume them.

## 4. Complete the processor contract

In `ActionProcessor` at lines 45–144, retain every typed payload cast and null check. Wrong payload types must fail without mutation.

In `ActionProcessor` at line 111, keep negative damage invalid and zero damage valid.

In `ActionProcessor` at lines 146–162, change active deletion so `boardController == null` or `!boardController.removeCard(target)` returns `false`. Only record history and call `queue_free()` after successful removal.

In `ActionProcessor` at lines 156–160, replace the dictionary history call with `BoardHistory.recordEvent(CardDeletedHistoryEvent.fromActiveCard(target))`.

In `ActionProcessor` at lines 167–170, change the declarations to `var entry := action.source as GraveyardEntry` and `var slot := action.target as CardSlot`, then check for null.

## 5. Replace effect event dictionaries

Create `GameplayEvent` in `src/main/effects/models/events/gameplay_event.gd`. It extends `RefCounted` and contains `type: String`.

Create `ActionResolvedEvent` in `src/main/effects/models/events/action_resolved_event.gd`. It extends `GameplayEvent`, contains `action: GameAction` and `result: Variant`, and its `create()` sets `type = "action_resolved"`.

Create `CardPlayedEvent` in `src/main/effects/models/events/card_played_event.gd`. It extends `GameplayEvent`, contains `card: Card`, and its `create()` sets `type = "on_play"`.

Do not create combat/refill/cycle event models until an effect actually consumes those boundaries.

In `EffectProcessor` at line 10 in `src/main/singletons/effects/effect_processor.gd`, change `action: Dictionary` to `action: GameAction` and guard against null.

In `EffectProcessor` at lines 11–12, change `action.get("type")` and `action.get("target")` to `action.type` and `action.target`.

In `EffectProcessor` at lines 14–18, change the dictionary to `ActionResolvedEvent.create(action, result)`.

In `EffectProcessor` at line 22, change the dictionary to `CardPlayedEvent.create(result)`.

In `EffectProcessor` at line 68, change `event: Dictionary` to `event: GameplayEvent`.

In `CardEffect` at line 16 in `src/main/effects/handlers/card_effect.gd`, change `Dictionary` to `GameplayEvent`.

In `GainHealthOnPlay` at line 3, change `Dictionary` to `GameplayEvent` and cast it to `CardPlayedEvent`.

In `GainHealthOnPlay` at lines 4–8, change `event.get("type")` and `event.get("card")` to `event.type` and `cardPlayedEvent.card` after checking that the cast succeeded.

In `EffectContext` at line 9 in `src/main/effects/effect_context.gd`, change `action: Dictionary` to `action: GameAction`.

In `tests/fixtures/removal_recorder_effect.gd` at lines 16–28, accept `GameplayEvent`, cast to `ActionResolvedEvent`, read its `GameAction`, cast its payload to `RemoveCardPayload`, and use typed fields instead of `.get()`.

## 6. Replace effect parameter dictionaries

Create `EffectParameters` in `src/main/effects/models/parameters/effect_parameters.gd` extending `RefCounted`.

Create `GainHealthParameters` in `src/main/effects/models/parameters/gain_health_parameters.gd`. It extends `EffectParameters`, contains `amount: int`, and has a `fromDictionary()` factory. Accept an integer or an integral float, but return `null` for missing, non-numeric, non-integral, zero, or negative amounts.

In `EffectData` at line 10 in `src/main/effects/models/effect_data.gd`, change `@export var parameters: Dictionary = {}` to `var parameters: EffectParameters`. Do not export a `RefCounted` value from the Resource.

In `EffectDataFactory` at line 12 in `src/main/effects/effect_data_factory.gd`, change the dictionary copy to `_parseParameters(data.operation, dictionary.get("parameters", {}))`.

In `EffectDataFactory` after line 14, add `_parseParameters(operation: String, rawParameters: Variant) -> EffectParameters`. Reject non-dictionaries; return `GainHealthParameters.fromDictionary(rawParameters)` for `"gain_health"`; return null for unknown operations.

In `GainHealthOnPlay` at lines 13–18, replace `.get("amount")` and conversion logic with `var parameters := data.parameters as GainHealthParameters`; warn and return if the cast is null.

## 7. Replace the graveyard snapshot

Create `CardStatSnapshot` in `src/main/graveyard/models/card_stat_snapshot.gd`. It extends `RefCounted`, contains typed integer `health`, `temporaryHealth`, and `attack` fields, and provides `fromCard()`, `copy()`, and `toDictionary()`.

In `GraveyardEntry` at line 10 in `src/main/graveyard/models/graveyard_entry.gd`, change `var statSnapshot: Dictionary = {}` to `var statSnapshot: CardStatSnapshot`.

In `GraveyardEntry` at line 20, change `statSnapshot.duplicate(true)` to `statSnapshot.toDictionary() if statSnapshot != null else {}`.

In `Graveyard` at line 19 in `src/main/singletons/graveyard/graveyard.gd`, change the snapshot dictionary to `CardStatSnapshot.fromCard(card)`.

In `tests/graveyard_test.gd` at line 77, change `entry.statSnapshot.get("health")` to `entry.statSnapshot.health`.

## 8. Replace board-history dictionaries

Create `BoardHistoryEvent`, `CardRemovedHistoryEvent`, `CardDeletedHistoryEvent`, and `CardRevivedHistoryEvent` under `src/main/board/history/models/`.

`BoardHistoryEvent` extends `RefCounted` and contains `sequence: int`, `type: String`, and `cardId: String`. It declares `copy() -> BoardHistoryEvent` and `toDictionary() -> Dictionary`.

`CardRemovedHistoryEvent` adds `entryId`, `instanceId`, `sourceInstanceId`, `cause`, `statSnapshot: CardStatSnapshot`, and `removedSequence`. Its constructor copies a `GraveyardEntry`.

`CardDeletedHistoryEvent` adds `entryId`, `instanceId`, `sourceInstanceId`, and `from`. Give it constructors for a graveyard entry and an active card.

`CardRevivedHistoryEvent` adds `entryId` and `instanceId` and copies a graveyard entry.

Every subtype must implement `copy()` so returned models cannot mutate stored history. Every subtype must implement `toDictionary()` for debug and serialization boundaries.

In `BoardHistory` at line 2 in `src/main/singletons/board_history.gd`, change `Array[Dictionary]` to `Array[BoardHistoryEvent]`.

In `BoardHistory` at lines 5–11, change `recordEvent(eventType, details)` to `recordEvent(event: BoardHistoryEvent) -> BoardHistoryEvent`. Reject null, assign the next sequence, store `event.copy()`, and return another copy.

In `BoardHistory` at lines 13–18, change the return type to `Array[BoardHistoryEvent]`, filter with `event.type`, and append `event.copy()`.

In `BoardHistory` at lines 23–26, change `.get("event")` to `.type` and `.get("card_id")` to `.cardId`.

In `Graveyard` at lines 25–30, construct and record a `CardRemovedHistoryEvent`, then set `entry.removedSequence` from the recorded event sequence. Do not pass `entry.toDictionary()` into runtime history.

In `Graveyard` at lines 56–62, change the dictionary to `CardDeletedHistoryEvent.fromGraveyardEntry(entry, source)`.

In the deleted-event constructor corresponding to `Graveyard` line 60, check `is_instance_valid(source) and source is Card` before accessing `source.instanceId`.

In `Graveyard` at lines 79–83, change the dictionary to `CardRevivedHistoryEvent.fromGraveyardEntry(entry)`.

In `EffectContext` at line 18, change `Array[Dictionary]` to `Array[BoardHistoryEvent]`.

In `card_test_scene` at lines 102–118, change dictionary queries to `event.cardId`, `event.sequence`, and `event.type`. Use subtype fields for `cause` and `from`, or call `toDictionary()` only inside this debug display.

## 9. Move the remaining existing models

In `CardState` currently at `src/main/cards/card_states/card_states.gd`, move the `.gd` and `.gd.uid` files to `src/main/cards/models/card_state.gd` and `.gd.uid`. Search scenes, resources, and scripts for the old path before removing it.

In `DeckCardBag` currently at `src/main/decks/deck_card_bag.gd`, move the `.gd` and `.gd.uid` files to `src/main/decks/models/deck_card_bag.gd` and `.gd.uid`.

Do not move `CardStateMachine`, `EffectContext`, `CardEffect`, `CreateCard`, factories, loaders, controllers, or processors. They are behavioural classes.

## 10. Update every affected test

In `tests/action_processor_test.gd` at lines 70, 91, 108, 141, 144, 159, 175, 189, and 237, replace dictionary or missing payload arguments with the payload required by that action.

In `tests/action_processor_test.gd` at line 136, change the callback argument to `GameAction`; at lines 137–138 use `action.type` and `(action.payload as ModifyStatsPayload).amount`.

In `tests/action_processor_test.gd` at line 231, change the callback argument to `GameAction`; at line 232 use `action.type`.

In `tests/damage_action_test.gd` at lines 70–76, 87, and 118, replace damage dictionaries with `DealDamagePayload`. Include an explicit wrong-subtype case using `MoveCardPayload`.

In `tests/damage_action_test.gd` at line 125, change `_enqueueAndWait(action: Dictionary)` to `_enqueueAndWait(action: GameAction)`.

In `tests/graveyard_test.gd` at lines 61, 96, 97, 112, 113, 145, 167, and 185, supply `RemoveCardPayload` to remove actions.

In `tests/graveyard_test.gd` at line 189, change `_enqueueAndWait(action: Dictionary)` to `_enqueueAndWait(action: GameAction)`.

In `tests/effect_processor_test.gd` at line 65, change `Array[Dictionary]` to `Array[GameAction]`; at line 66 change the callback argument to `GameAction`.

In `tests/effect_processor_test.gd` at lines 138, 153, 171, and 214, supply the required typed payload.

In `tests/effect_library_test.gd` at lines 45 and 66, cast to `GainHealthParameters` and assert `.amount` instead of `.get("amount")`.

In `tests/story_10_integration_test.gd` at line 48, supply the required payload; at line 67 change the callback argument to `GameAction`; at line 68 use `action.type`.

In `tests/game_controller_test.gd` at line 81, replace the arbitrary dictionary history event with a `BoardHistoryEvent` fixture; at line 154 supply the action's typed payload.

In `tests/combat_resolver_test.gd` at line 224, change the action argument to `GameAction` and use its typed fields.

In `tests/board_refill_controller_test.gd` at line 203, change the action argument to `GameAction` and inspect its `RevealCardPayload`.

In `tests/board_history_test.gd` at lines 29, 30, 38, 51–54, 59–62, 68, and 70, construct concrete history events instead of passing names and dictionaries.

In `tests/board_history_test.gd` at line 72, change `.get("sequence")` to `.sequence`.

Add tests proving `enqueueAction(null)` is rejected, invalid action types are rejected, wrong payload subtypes do not mutate state, effect JSON creates the right parameter subtype, invalid effect parameters fail, history copies are defensive, and invalid/freed graveyard sources use the stable source ID.

## Dictionaries that remain intentionally

In JSON loaders and factories, keep raw dictionaries at the parsing boundary.

In `CardLibrary.cardDataById`, `EffectLibrary.effectDataById`, and `EffectProcessor.activeEffectsByCard`, keep dictionaries because they are lookup maps.

In coordinate-to-card collections and test fixture bundles, keep dictionaries because they are genuine maps or local bundles.

In `toDictionary()` methods, keep dictionaries because they are serialization/debug output.

## Verification

Run:

```bash
rg -n 'action: Dictionary|action\.get\(|event\.get\(|parameters\.get\(|statSnapshot\.get\(|recordEvent\("' src/main tests
rg -n 'ActionType\.make|\{"(amount|cause|stat|source_instance_id|cycle_number)"' src/main tests
rg -n 'card_states/card_states|decks/deck_card_bag|combat_objects' . --glob '!.godot/**'
```

The first search should find no runtime action, effect-event, parameter, snapshot, or history dictionary access. The second must show only typed payload arguments. The third must find no stale moved paths.

Run every existing test scene: action processor, damage, combat, refill, effect library, effect processor, graveyard, board history, game controller, player movement, and Story 10 integration.

Manually verify reveal/refill, movement, two-survivor combat, defender death and advance, mutual death, on-play healing, removal, deletion, revival, and the history debug panel.

## Definition of done

- The project parses without missing classes, scripts, or UIDs.
- `ActionType.make()` accepts `ActionPayload` and returns `GameAction`.
- The queue safely rejects null and invalid actions.
- Every producer supplies the payload required by its handler.
- Every action signal consumer accepts `GameAction`.
- Effects receive typed events and parameters.
- Graveyard snapshots and board-history records are typed models.
- Board history returns defensive copies.
- Existing data models live in feature-local `models` folders.
- Only boundary dictionaries and genuine maps remain.
- All automated and manual regressions pass.

## Outside this story

- The Story 13.5 board-shift/refill algorithm.
- New effect behaviour.
- Converting JSON source files to `.tres`.
- Replacing genuine lookup maps.
