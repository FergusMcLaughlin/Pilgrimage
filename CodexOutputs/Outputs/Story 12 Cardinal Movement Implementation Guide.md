# Story 12: Select Cardinal Combat Targets

Date: 2026-08-16

Status: Ready to implement

Related: [[Story 11 GameController Implementation Guide]] · [[Story 11 Add-ons Before Movement]] · [[Amended Implementation Story Order]] · [[Future Story - Configurable Movement Patterns]]

## Goal

Allow the player to click a card next to them and determine whether it is a valid combat target.

The rule for this story is simple:

```text
The target must contain a card
and
the target must be one slot up, down, left, or right from the player.
```

A valid target starts the player action and enters `COMBAT`. An invalid target does nothing.

The player does not move in Story 12. Combat, player movement after combat, board reorganisation, and replacement cards belong to Story 13.

## Existing Code Used By This Story

Story 12 builds on code that already exists:

- `CardInput` emits `GlobalSignalBus.cardPressed(card)`.
- `GameController.playerCard` identifies the player.
- `GameController.beginPlayerAction()` locks input and enters `RESOLVING_MOVE`.
- `GameController.beginCombat()` enters `COMBAT`.
- `BoardController.getSlotCardIsIn(card)` finds a card's slot.
- `SlotGrid.getCardinalNeighbours(slot)` returns the slots directly touching a slot.

Do not duplicate any of these responsibilities.

## Files

Create:

```text
src/main/controllers/player_movement_controller.gd
tests/player_movement_controller_test.gd
tests/player_movement_controller_test.tscn
```

Update:

```text
src/main/singletons/global_signal_bus.gd
src/tests/card_test_scene.gd
src/tests/card_test_scene.tscn
```

## Step 1: Add The Combat Request Signal

Add this signal to `GlobalSignalBus`:

```gdscript
signal playerCombatRequested(
	player,
	defender,
	playerSlot,
	targetSlot,
	cycleNumber,
)
```

Add the matching wrapper:

```gdscript
func emitPlayerCombatRequested(
	player: Card,
	defender: Card,
	playerSlot: CardSlot,
	targetSlot: CardSlot,
	cycleNumber: int,
) -> void:
	emit_signal(
		"playerCombatRequested",
		player,
		defender,
		playerSlot,
		targetSlot,
		cycleNumber,
	)
```

Story 12 emits this signal. Story 13 will listen to it and resolve combat.

## Step 2: Create PlayerMovementController

Create a scene-owned controller:

```gdscript
extends Node
class_name PlayerMovementController

@export var gameController: GameController
@export var boardController: BoardController
@export var slotGrid: SlotGrid


func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
```

This is not an autoload. One gameplay scene owns one movement controller.

The controller interprets player input. It does not move cards, calculate damage, or replace the board.

## Step 3: Validate Required References

```gdscript
func _hasRequiredReferences() -> bool:
	return (
		gameController != null
		and boardController != null
		and slotGrid != null
	)
```

If a reference is missing, reject the click without changing GameController state.

## Step 4: Find The Player And Target Slots

Use `BoardController` for both lookups:

```gdscript
func _getPlayerSlot() -> CardSlot:
	if gameController == null or gameController.playerCard == null:
		return null
	return boardController.getSlotCardIsIn(gameController.playerCard)


func _getTargetSlot(card: Card) -> CardSlot:
	if card == null or boardController == null:
		return null
	return boardController.getSlotCardIsIn(card)
```

Do not use `card.get_parent()` to find a slot. Card presentation and animation containers may change later.

## Step 5: Validate The Clicked Card

```gdscript
func isValidTarget(card: Card) -> bool:
	if !_hasRequiredReferences():
		return false
	if gameController.state != GameController.GameState.PLAYER_READY:
		return false
	if card == null or card == gameController.playerCard:
		return false

	var playerSlot := _getPlayerSlot()
	var targetSlot := _getTargetSlot(card)
	if playerSlot == null or targetSlot == null:
		return false
	if !targetSlot.isOccupied():
		return false

	return targetSlot in slotGrid.getCardinalNeighbours(playerSlot)
```

This rejects:

- the player card;
- cards outside the active board;
- diagonal cards;
- cards more than one slot away;
- clicks outside `PLAYER_READY`;
- missing references;
- empty slots, because there is no target card to click.

`SlotGrid.getCardinalNeighbours()` owns the coordinate rule. Do not calculate coordinate differences again in this controller.

## Step 6: Handle A Card Click

```gdscript
func _onCardPressed(card: Card) -> void:
	if !isValidTarget(card):
		return

	_requestCombat(card)
```

Invalid clicks do nothing. They do not lock input, change state, emit combat, or advance the player cycle.

## Step 7: Request Combat

```gdscript
func _requestCombat(defender: Card) -> bool:
	var player := gameController.playerCard
	var playerSlot := _getPlayerSlot()
	var targetSlot := _getTargetSlot(defender)

	if playerSlot == null or targetSlot == null:
		return false
	if !gameController.beginPlayerAction():
		return false
	if !gameController.beginCombat():
		return false

	GlobalSignalBus.emitPlayerCombatRequested(
		player,
		defender,
		playerSlot,
		targetSlot,
		gameController.playerCycleNumber,
	)
	return true
```

The two GameController transitions happen synchronously:

```text
PLAYER_READY
→ RESOLVING_MOVE
→ COMBAT
```

Input is locked by `beginPlayerAction()`. Further clicks are rejected because GameController is no longer in `PLAYER_READY`.

## Story 12 Stops Here

After `playerCombatRequested` is emitted:

- the player remains in their original slot;
- the defender remains in the target slot;
- neither card takes damage;
- neither card is removed;
- no card is revealed;
- the board is not reorganised;
- the player cycle is not completed.

Story 13 takes ownership from this point.

## Test Scene Wiring

Add `PlayerMovementController` to the card test scene and assign its references:

```gdscript
@onready var playerMovementController: PlayerMovementController = (
	$PlayerMovementController
)


func _ready() -> void:
	playerMovementController.gameController = gameController
	playerMovementController.boardController = boardController
	playerMovementController.slotGrid = slotGrid

	await gameController.startRun(false)
```

Add a small label showing the last result:

```gdscript
func _onPlayerCombatRequested(
	_player: Card,
	defender: Card,
	_playerSlot: CardSlot,
	targetSlot: CardSlot,
	_cycleNumber: int,
) -> void:
	movementStatus.text = "Valid target: %s at %s" % [
		defender.data.name,
		targetSlot.coordinates,
	]
```

The test scene may show invalid-click feedback locally. A new global rejection signal is not required for Story 12.

## Automated Tests

Create `tests/player_movement_controller_test.gd/.tscn` covering:

1. Missing references reject the click.
2. A click outside `PLAYER_READY` is rejected.
3. Clicking the player is rejected.
4. Clicking a loose card outside the board is rejected.
5. Each occupied cardinal neighbour is valid.
6. Diagonal occupied cards are invalid.
7. Occupied cards more than one slot away are invalid.
8. An empty cardinal slot cannot produce a combat request.
9. Invalid clicks do not change GameController state.
10. Invalid clicks do not lock input or advance the cycle.
11. A valid click enters `COMBAT` and locks input.
12. A valid click emits exactly one combat request.
13. The request contains the correct player and defender.
14. The request contains the correct source and target slots.
15. The request contains the current player-cycle number.
16. Neither card moves or changes stats in Story 12.
17. Further clicks during `COMBAT` emit no additional request.
18. Existing GameController tests continue to pass.

## Keep Out Of Story 12

- Empty-slot player movement
- `MOVE_CARD` actions
- Combat calculations
- Damage and retaliation
- Card death or Graveyard changes
- Player movement after combat
- Board shifting or reorganisation
- Journey Deck replacement cards
- Game-over checks
- Alternative movement patterns
- Item or effect movement modifiers

Alternative movement is recorded separately in [[Future Story - Configurable Movement Patterns]].

## Definition Of Done

- [ ] `playerCombatRequested` and its wrapper exist.
- [ ] `PlayerMovementController` is scene-owned.
- [ ] Board-card clicks enter one validation path.
- [ ] Only occupied cardinal neighbours are valid.
- [ ] Player, loose-card, diagonal, distant, empty, and out-of-state targets are rejected.
- [ ] Invalid clicks do not change state, input, board contents, or cycle number.
- [ ] A valid click moves GameController from `PLAYER_READY` to `COMBAT`.
- [ ] A valid click emits one correctly attributed combat request.
- [ ] Story 12 does not move or modify either card.
- [ ] Manual test-scene feedback works.
- [ ] New and existing tests pass.
- [ ] `git diff --check` passes.

## Handoff To Story 13

Story 13 receives one combat request containing the player, defender, both slots, and cycle number. At handoff, GameController is in `COMBAT`, input is locked, and the board has not changed.
