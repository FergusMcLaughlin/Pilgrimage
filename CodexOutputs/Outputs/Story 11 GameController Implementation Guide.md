# Story 11: Add GameController and the Player Action Cycle

Date: 2026-08-09

Status: Ready to implement

Related: [[Amended Implementation Story Order]] · [[Story 14 Pre-Chore - Graveyard and Death Contract]] · [[Future Story - Combat Integration Effect Reassessment]]

## Goal

Create the authoritative owner of one run and one player-driven action cycle.

This is not a traditional alternating-turn game. Other board cards do not take turns. The repeating structure is:

```text
PLAYER_READY
→ player chooses a move/attack
→ movement or combat resolves
→ AFTER_MOVE phase
→ queued effects, refill, and optional board maintenance resolve
→ playerCycleCompleted
→ PLAYER_READY
```

`AFTER_MOVE` is always a real boundary, even when it has no work and completes immediately. This gives effects and maintenance one deterministic place to finish before input returns.

## Ownership

Use a scene-owned `GameController`, not an autoload. It owns the board, grid, deck, player identity, state, cycle count, and input lock for one game scene.

`Graveyard` and `BoardHistory` remain run-scoped autoload services. GameController resets them when a new run starts.

## States

Create `src/main/game/game_controller.gd`:

```gdscript
extends Node
class_name GameController

enum GameState {
	SETUP,
	PLAYER_READY,
	RESOLVING_MOVE,
	COMBAT,
	AFTER_MOVE,
	GAME_OVER,
}

@export var boardController: BoardController
@export var slotGrid: SlotGrid
@export var journeyDeck: JourneyDeck
@export var playerCardId := "C_0000"

var state := GameState.SETUP
var playerCard: Card
var playerCycleNumber := 0
var _createCard := CreateCard.new()
```

Only GameController changes run state.

## Signals

Add to `GlobalSignalBus` with matching wrappers:

```gdscript
signal gameStateChanged(previousState, newState)
signal playerCycleStarted(player, cycleNumber)
signal afterMoveStarted(player, cycleNumber)
signal playerCycleCompleted(player, cycleNumber)
```

There are deliberately no generic `turnStarted` or enemy-turn signals.

`playerCycleCompleted` is the duration boundary later consumed by TasteOfVictory. An invalid click or rejected move does not complete a cycle.

## State Transition Helper

```gdscript
func setState(newState: GameState) -> void:
	if state == newState:
		return
	var previousState := state
	state = newState
	GlobalSignalBus.emitGameStateChanged(previousState, state)
```

## Start a Run

```gdscript
func startRun(shuffleDeck: bool = true) -> bool:
	setState(GameState.SETUP)
	InputManager.lockInput()

	if !_hasRequiredReferences():
		return _failSetup("missing board, grid, or journey deck")

	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	playerCycleNumber = 0

	journeyDeck.boardController = boardController
	journeyDeck.slotGrid = slotGrid
	journeyDeck.initialiseJourneyDeck(shuffleDeck)

	playerCard = _createCard.createCard(playerCardId)
	if playerCard == null:
		return _failSetup("could not create player")

	var centerSlot := slotGrid.getCenterSlot()
	if centerSlot == null or !boardController.placeCard(playerCard, centerSlot):
		playerCard.queue_free()
		playerCard = null
		return _failSetup("could not place player in center")

	await journeyDeck.fillEmptySlots(slotGrid)
	_enterPlayerReady()
	return true
```

Helpers:

```gdscript
func _hasRequiredReferences() -> bool:
	return boardController != null and slotGrid != null and journeyDeck != null


func _failSetup(message: String) -> bool:
	push_error("GameController: " + message)
	setState(GameState.SETUP)
	InputManager.lockInput()
	return false
```

The player occupies center before board filling, so JourneyDeck fills only the eight surrounding slots through queued `REVEAL_CARD` actions.

## Player Action Cycle API

### Ready boundary

```gdscript
func _enterPlayerReady() -> void:
	playerCycleNumber += 1
	setState(GameState.PLAYER_READY)
	InputManager.unlockInput()
	GlobalSignalBus.emitPlayerCycleStarted(
		playerCard,
		playerCycleNumber,
	)
```

### Begin a valid player action

Story 12 calls this only after validating a real move target:

```gdscript
func beginPlayerAction() -> bool:
	if state != GameState.PLAYER_READY:
		return false
	InputManager.lockInput()
	setState(GameState.RESOLVING_MOVE)
	return true
```

Story 13 may transition from `RESOLVING_MOVE` to `COMBAT` when the valid target is occupied.

### After-move boundary

Movement or combat calls:

```gdscript
func beginAfterMovePhase() -> bool:
	if state not in [GameState.RESOLVING_MOVE, GameState.COMBAT]:
		return false
	setState(GameState.AFTER_MOVE)
	GlobalSignalBus.emitAfterMoveStarted(
		playerCard,
		playerCycleNumber,
	)
	return true
```

The `AFTER_MOVE` phase may perform:

- effects created by the completed action;
- refill of the slot left behind;
- optional board reshuffle;
- other future maintenance.

It must wait for `ActionQueue` and `ActionProcessor` to become idle before completing.

### Complete the cycle

```gdscript
func completePlayerCycle() -> bool:
	if state != GameState.AFTER_MOVE:
		return false
	if ActionQueue.queueHasActions() or ActionProcessor.isProcessingAction:
		return false

	GlobalSignalBus.emitPlayerCycleCompleted(
		playerCard,
		playerCycleNumber,
	)
	_enterPlayerReady()
	return true
```

The phase exists even if there is nothing to do: enter `AFTER_MOVE`, observe an idle action system, emit completion, and return to ready.

## Input Policy

| State | Input |
|---|---|
| `SETUP` | Locked |
| `PLAYER_READY` | Unlocked |
| `RESOLVING_MOVE` | Locked |
| `COMBAT` | Locked |
| `AFTER_MOVE` | Locked |
| `GAME_OVER` | Locked |

No other card receives an input turn.

## Test Scene

Create:

```text
src/tests/gameplay_test_scene.gd
src/tests/gameplay_test_scene.tscn
```

Instance `SlotGrid`, `BoardController`, `JourneyDeck`, and the scene-owned GameController. Story 16 later composes the production scene.

## Automated Tests

Create `tests/game_controller_test.gd/.tscn` covering:

1. Missing references fail with input locked.
2. A run resets Graveyard and BoardHistory.
3. Player is created and placed in center.
4. Remaining slots fill through queued reveals.
5. Setup waits for all actions and enters `PLAYER_READY`.
6. Input unlocks only in `PLAYER_READY`.
7. The first cycle is numbered 1.
8. Invalid/rejected input does not start or complete a cycle.
9. A valid action locks input and enters `RESOLVING_MOVE`.
10. Combat can be entered only from the resolving state.
11. `AFTER_MOVE` can follow movement or combat.
12. The after-move signal fires even when no maintenance is required.
13. A cycle cannot complete while actions are queued/busy.
14. Completion emits once and returns to `PLAYER_READY` with the next cycle number.
15. Other cards never receive cycle events.

## Files

| File | Change |
|---|---|
| `src/main/game/game_controller.gd` | Add run and player-cycle owner. |
| `src/main/singletons/global_signal_bus.gd` | Add state/cycle signals and wrappers. |
| `src/tests/gameplay_test_scene.gd/.tscn` | Add temporary manual fixture. |
| `tests/game_controller_test.gd/.tscn` | Add setup and cycle coverage. |

No movement or combat calculation belongs in this story.

## Definition of Done

- [ ] GameController owns one run and one player action cycle.
- [ ] No enemy or board-card turn system is introduced.
- [ ] Player starts in center and surrounding slots fill through actions.
- [ ] Setup locks input and successful setup enters `PLAYER_READY`.
- [ ] Valid actions move through resolution and `AFTER_MOVE`.
- [ ] `AFTER_MOVE` exists even when it completes immediately.
- [ ] Effects and maintenance settle before cycle completion.
- [ ] Only completed valid player actions advance the cycle counter.
- [ ] Input unlocks only in `PLAYER_READY`.
- [ ] New and existing tests pass.
- [ ] `git diff --check` passes.

## Story 12 Ready When

Movement may begin when there is one authoritative player, a validated begin-action boundary, and a deterministic after-move phase that cannot return input while actions are unresolved.
