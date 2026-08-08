# Story 11 Pre-Chore: Build Graveyard and Board History

Date: 2026-08-08

Status: Ready to implement

Related: [[Story 10 Implementation Guide]] · [[Future Story - Removed Card System]] · [[Action Processor Delegation Principle]]

## Goal

Build the removal foundation required by Story 11's kill effects:

- `Graveyard` stores cards that left active play and may be revived.
- `BoardHistory` stores an ordered, append-only record of removals, revivals, and deletions.
- `REMOVE_CARD`, `DELETE_CARD`, and `REVIVE_CARD` have distinct meanings.
- A slain card receives its final effect event before its runtime effects are removed.
- Removal records identify who caused the removal and why.

This supports effects such as “gain attack for every Giant slain this run” and “summon a previously slain card.”

## Final Model

```text
Active board
    │ REMOVE_CARD
    ▼
Graveyard.entries              BoardHistory.events
(currently recoverable)        (everything that happened)
    │                                  ▲
    │ REVIVE_CARD                      │ append only
    └──────────────► Active board      │
    │                                  │
    │ DELETE_CARD                      │
    └──────────────► gone from play ───┘
```

The graveyard changes as cards enter, revive, or are deleted. Board history never removes old events.

## Storage Decision

Do not store only `Array[String]` and do not keep dead `Card` nodes alive.

An ID-only array cannot distinguish two copies of `M_0002`, identify which copy was killed by which attacker, or revive one exact entry. Instead use:

```gdscript
var entries: Array[GraveyardEntry] = []
```

Each entry still contains a card ID. `Graveyard.getCardIds()` can provide a simple ID list when that is all a caller needs.

## Ownership

### `Graveyard` singleton

- owns current removed-card entries;
- adds removed cards;
- finds and deletes exact entries;
- reconstructs and revives exact entries;
- exposes safe queries;
- resets between runs and tests.

### `BoardHistory` singleton

- assigns chronological sequence numbers;
- appends removal, revival, and deletion events;
- exposes safe filtering and counts;
- never edits or removes recorded events;
- resets between runs and tests.

The name allows later movement and combat events to use the same run history. This pre-chore records lifecycle events only.

### Existing systems

- `ActionProcessor` validates and routes lifecycle actions to `Graveyard`.
- `EffectProcessor` dispatches the resolved event before unregistering the leaving card.
- `BoardController` remains the owner of clearing occupied slots.
- `CreateCard` remains the owner of constructing cards.

## Action Contract

| Action | Meaning | Result |
|---|---|---|
| `REMOVE_CARD` | Move an active card into the graveyard. Normal death uses this. | New `GraveyardEntry` or `null` |
| `DELETE_CARD` | Permanently erase an active card or graveyard entry. | `true` or `false` |
| `REVIVE_CARD` | Recreate one exact graveyard entry in an empty slot. | Recreated `Card` or `null` |

Deletion removes a card from the current graveyard but never erases older history. “Giants slain this run” therefore remains correct after revival or deletion.

## Step 1: Add Logical Card Identity

Open `src/main/cards/card.gd` and add:

```gdscript
var instanceId: int = 0
```

At the start of `_ready()` assign a new identity only when one was not restored:

```gdscript
if instanceId == 0:
	instanceId = get_instance_id()
```

Open `src/main/cards/card_loaders/create_card.gd` and extend the factory signature:

```gdscript
func createCard(cardId: String, existingInstanceId: int = 0) -> Card:
	var createCardData: CardData = CardLibrary.getCardData(cardId)
	if createCardData == null:
		push_error("Failed to create unknown card %s." % cardId)
		return null

	var cardInstance: Card = cardScene.instantiate()
	cardInstance.setCardData(createCardData)
	if existingInstanceId != 0:
		cardInstance.instanceId = existingInstanceId
	return cardInstance
```

Existing callers remain valid. Revival supplies the saved identity to the optional second argument.

Godot's object ID only seeds the first identity. A revived replacement node explicitly receives the saved ID, so its logical identity survives reconstruction.

## Step 2: Add `GraveyardEntry`

Create `src/main/graveyard/graveyard_entry.gd`:

```gdscript
class_name GraveyardEntry
extends RefCounted

var entryId: int
var instanceId: int
var cardId: String
var removedSequence: int
var sourceInstanceId: int
var cause: String
var statSnapshot: Dictionary = {}


func toDictionary() -> Dictionary:
	return {
		"entry_id": entryId,
		"instance_id": instanceId,
		"card_id": cardId,
		"removed_sequence": removedSequence,
		"source_instance_id": sourceInstanceId,
		"cause": cause,
		"stat_snapshot": statSnapshot.duplicate(true),
	}
```

`instanceId` follows one logical card across revival. `entryId` identifies one particular visit to the graveyard.

## Step 3: Add `BoardHistory`

Create `src/main/singletons/history/board_history.gd`:

```gdscript
extends Node

var events: Array[Dictionary] = []
var _nextSequence := 1


func recordEvent(eventType: String, details: Dictionary = {}) -> Dictionary:
	var event := details.duplicate(true)
	event["sequence"] = _nextSequence
	event["event"] = eventType
	_nextSequence += 1
	events.append(event)
	return event.duplicate(true)


func getEvents(eventType: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if eventType.is_empty() or event.get("event") == eventType:
			result.append(event.duplicate(true))
	return result


func countRemovedCards(cardId: String = "") -> int:
	var count := 0
	for event in events:
		if event.get("event") != "removed":
			continue
		if !cardId.is_empty() and event.get("card_id") != cardId:
			continue
		count += 1
	return count


func reset() -> void:
	events.clear()
	_nextSequence = 1
```

Return deep copies so callers cannot rewrite history. Do not add Giant-specific functions; traits belong in `CardData`, and effects can filter general history queries later.

## Step 4: Add the `Graveyard` Singleton

Create `src/main/singletons/graveyard/graveyard.gd`:

```gdscript
extends Node

var entries: Array[GraveyardEntry] = []
var _nextEntryId := 1
var _createCard := CreateCard.new()


func buryCard(
	card: Card,
	source,
	cause: String,
	boardController: BoardController,
) -> GraveyardEntry:
	if card == null or card.data == null:
		return null
	if boardController == null or !boardController.removeCard(card):
		return null

	var entry := GraveyardEntry.new()
	entry.entryId = _nextEntryId
	entry.instanceId = card.instanceId
	entry.cardId = card.data.id
	entry.sourceInstanceId = source.instanceId if source is Card else 0
	entry.cause = cause
	entry.statSnapshot = {"health": card.health, "attack": card.attack}
	_nextEntryId += 1

	var event := BoardHistory.recordEvent("removed", entry.toDictionary())
	entry.removedSequence = event["sequence"]
	entries.append(entry)

	# Deferred freeing keeps the node valid during actionResolved.
	card.queue_free()
	return entry


func getEntries() -> Array[GraveyardEntry]:
	return entries.duplicate()


func getCardIds() -> Array[String]:
	var cardIds: Array[String] = []
	for entry in entries:
		cardIds.append(entry.cardId)
	return cardIds


func getEntry(entryId: int) -> GraveyardEntry:
	for entry in entries:
		if entry.entryId == entryId:
			return entry
	return null


func deleteEntry(entryId: int, source = null) -> bool:
	var entry := getEntry(entryId)
	if entry == null:
		return false

	entries.erase(entry)
	BoardHistory.recordEvent("deleted", {
		"entry_id": entry.entryId,
		"instance_id": entry.instanceId,
		"card_id": entry.cardId,
		"source_instance_id": source.instanceId if source is Card else 0,
		"from": "graveyard",
	})
	return true


func reviveCard(
	entryId: int,
	slot: CardSlot,
	boardController: BoardController,
) -> Card:
	var entry := getEntry(entryId)
	if entry == null or slot == null or slot.isOccupied():
		return null

	var card := _createCard.createCard(entry.cardId, entry.instanceId)
	if card == null:
		return null
	if !boardController.placeCard(card, slot):
		card.queue_free()
		return null

	entries.erase(entry)
	BoardHistory.recordEvent("revived", {
		"entry_id": entry.entryId,
		"instance_id": entry.instanceId,
		"card_id": entry.cardId,
	})
	return card


func reset() -> void:
	entries.clear()
	_nextEntryId = 1
```

The singleton owns the zone, not combat rules or revival target selection. Failed revival leaves the entry untouched.

## Step 5: Register and Reset the Singletons

Add to `project.godot` before `ActionProcessor` and `EffectProcessor`:

```ini
BoardHistory="*res://src/main/singletons/history/board_history.gd"
Graveyard="*res://src/main/singletons/graveyard/graveyard.gd"
```

These autoloads represent the current run, not permanent save data. Future `GameController.startRun()` and every relevant test setup must call:

```gdscript
BoardHistory.reset()
Graveyard.reset()
```

This is the main tradeoff of using singletons: reset ownership must be explicit.

## Step 6: Route Lifecycle Actions

Open `src/main/singletons/actions/action_processor.gd`.

Return lifecycle results from `_resolveAction()`:

```gdscript
ActionType.REMOVE_CARD:
	return _handleRemoveCard(action)
ActionType.DELETE_CARD:
	return _handleDeleteCard(action)
ActionType.REVIVE_CARD:
	return _handleReviveCard(action)
```

Replace removal with:

```gdscript
func _handleRemoveCard(action: Dictionary) -> GraveyardEntry:
	var target = action["target"]
	if !(target is Card):
		push_warning("ActionProcessor: REMOVE_CARD target must be a Card.")
		return null

	var boardController := _getBoardController()
	if boardController == null:
		return null

	return Graveyard.buryCard(
		target,
		action["source"],
		action["data"].get("cause", "effect"),
		boardController,
	)
```

Deletion accepts either a live card or one exact graveyard entry:

```gdscript
func _handleDeleteCard(action: Dictionary) -> bool:
	var target = action["target"]
	if target is GraveyardEntry:
		return Graveyard.deleteEntry(target.entryId, action["source"])

	if target is Card:
		var boardController := _getBoardController()
		if boardController != null:
			boardController.removeCard(target)
		BoardHistory.recordEvent("deleted", {
			"instance_id": target.instanceId,
			"card_id": target.data.id,
			"from": "active_play",
		})
		target.queue_free()
		return true

	push_warning("ActionProcessor: invalid DELETE_CARD target.")
	return false
```

Revival uses the graveyard entry as source and destination slot as target:

```gdscript
func _handleReviveCard(action: Dictionary) -> Card:
	var entry = action["source"]
	var slot = action["target"]
	if !(entry is GraveyardEntry) or !(slot is CardSlot):
		push_warning("ActionProcessor: invalid REVIVE_CARD action.")
		return null

	var boardController := _getBoardController()
	if boardController == null:
		return null
	return Graveyard.reviveCard(entry.entryId, slot, boardController)
```

## Step 7: Fix Effect Removal Timing

Open `src/main/singletons/effects/effect_processor.gd`.

The current implementation deactivates a removed card before dispatching its resolved event. Change `_onActionResolved()` to this order:

```gdscript
func _onActionResolved(action: Dictionary, result: Variant) -> void:
	var actionType = action.get("type")
	var leavingCard = action.get("target")

	_dispatchEvent({
		"type": "action_resolved",
		"action": action,
		"result": result,
	})

	if actionType == ActionType.REVEAL_CARD and result is Card:
		_activateCardEffects(result)
		_dispatchEvent({"type": "on_play", "card": result})

	if actionType in [ActionType.REMOVE_CARD, ActionType.DELETE_CARD]:
		if leavingCard is Card:
			_deactivateCardEffects(leavingCard)
```

The leaving card can now inspect the source, target, cause, and returned `GraveyardEntry`, queue one final effect action, and then be deactivated.

## Step 8: Expose Safe Effect Queries

Add to `src/main/effects/effect_context.gd`:

```gdscript
func getGraveyardEntries() -> Array[GraveyardEntry]:
	return Graveyard.getEntries()


func getBoardHistory(eventType: String = "") -> Array[Dictionary]:
	return BoardHistory.getEvents(eventType)
```

Effects query through `EffectContext`; they do not mutate singleton arrays.

Use the correct source for each rule:

- “currently slain” queries `Graveyard`;
- “slain this run” queries `BoardHistory` removal events;
- revival selects an exact `GraveyardEntry`;
- repeated deaths count history by `instance_id`.

## Step 9: Add Tests

Create `tests/graveyard_test.gd/.tscn` covering:

1. Removal clears the slot and adds one entry.
2. The old node is freed after resolution.
3. Entry identity, source, cause, and stat snapshot are correct.
4. Duplicate card IDs create distinct entries.
5. Revival preserves `instanceId` but removes the exact entry.
6. Failed revival leaves the entry unchanged.
7. Deleting one entry leaves other copies intact.
8. Active-card deletion bypasses the graveyard.
9. Reset clears entries and restarts numbering.

Create `tests/board_history_test.gd/.tscn` covering:

1. Sequence numbers increase monotonically.
2. Event filtering works.
3. Returned copies cannot mutate stored history.
4. Revival and deletion never erase removal history.
5. Reset clears history and restarts sequencing.

Update `tests/action_processor_test.gd` to assert lifecycle action results, graveyard contents, and history.

Update `tests/effect_processor_test.gd` to prove a removed card receives its own event once, sees the attacker/cause, and is then deactivated without a retained listener.

## File Scope

| File | Change |
|---|---|
| `src/main/cards/card.gd` | Add logical identity. |
| `src/main/cards/card_loaders/create_card.gd` | Restore identity during revival. |
| `src/main/graveyard/graveyard_entry.gd` | Add typed graveyard record. |
| `src/main/singletons/graveyard/graveyard.gd` | Add graveyard singleton. |
| `src/main/singletons/history/board_history.gd` | Add history singleton. |
| `src/main/singletons/actions/action_processor.gd` | Route lifecycle actions and return results. |
| `src/main/singletons/effects/effect_processor.gd` | Dispatch before deactivation. |
| `src/main/effects/effect_context.gd` | Add read-only queries. |
| `project.godot` | Register both autoloads. |
| Four new test files | Add graveyard and history suites. |
| Two existing test files | Extend action and effect lifecycle coverage. |

## Outside This Pre-Chore

- Full combat calculations.
- Story 11's three effects.
- Graveyard UI.
- Final revival target-selection UI.
- Saving history between runs.
- Giant Slayer itself.
- Card traits such as `giant`; add them to `CardData` with the effect that needs them.

## Verification

```bash
godot --headless --path . tests/graveyard_test.tscn
godot --headless --path . tests/board_history_test.tscn
godot --headless --path . tests/action_processor_test.tscn
godot --headless --path . tests/effect_processor_test.tscn
godot --headless --path . tests/effect_library_test.tscn
godot --headless --path . tests/story_10_integration_test.tscn
git diff --check
```

## Definition of Done

- [ ] `Graveyard` owns currently removed cards.
- [ ] `BoardHistory` owns chronological lifecycle events.
- [ ] Graveyard stores typed entries, not only IDs or hidden live nodes.
- [ ] `REMOVE_CARD` adds one entry and one history event.
- [ ] `DELETE_CARD` permanently removes active cards or exact entries.
- [ ] Deletion never rewrites history.
- [ ] `REVIVE_CARD` reconstructs one exact entry and preserves identity.
- [ ] Failed revival cannot lose an entry.
- [ ] Removal records source and cause.
- [ ] A removed card receives its last effect event before deactivation.
- [ ] Effects receive read-only access through `EffectContext`.
- [ ] Both singletons reset cleanly between runs and tests.
- [ ] All new and existing tests pass.
- [ ] `git diff --check` passes.

## Story 11 Ready When

Story 11 can begin when kill effects no longer need temporary answers for death storage, attacker attribution, event order, revival identity, history counting, or listener cleanup.
