# Story 8 Implementation Guide: Add Action Processor

Date: 2026-07-16

Related: [[Story 7 Implementation Guide]] · [[Action Processor Delegation Principle]] · [[Action System Explained Simply]] · [[Story 8.5 Action Processor Completion]]

## Task

Create the `ActionProcessor` autoload that takes the next action from `ActionQueue`, routes it to the correct owner, waits for that action to finish, and then moves on to the next queued action.

The processor controls **when** an action resolves. Existing specialist classes control **how** it resolves.

## Before Starting

- Story 7 is complete and runtime verified.
- Keep the existing `ActionType` class name, camelCase methods, and expanded action vocabulary.
- Keep the existing `REMOVE_CARD` and `DELETE_CARD` action types in `VALID_TYPES`.
- Add `BoardController` to a `boardController` group in `_ready()` so the autoload can find the active scene's controller without holding an exported scene reference.
- Do not add effect pre/post hooks yet. `EffectMediator` does not exist and belongs to a later story.

## Files

Create:

```text
src/singletons/actions/action_processor.gd
```

Update as needed:

```text
project.godot
src/singletons/actions/action_object.gd
src/board/board_controller/board_controller.gd
src/cards/card.gd
```

Register the new script exactly once as the `ActionProcessor` autoload.

## Processing Flow

```text
ActionQueue has an action
        ↓
ActionProcessor checks that it is not busy
        ↓
popNextAction()
        ↓
route by ActionType constant
        ↓
delegate to JourneyDeck, BoardController, or Card
        ↓
wait for asynchronous work
        ↓
mark processor idle
```

Only one action may be resolving at a time. This matters because `REVEAL_CARD` currently awaits its movement animation.

## Action Payloads For This Story

| Action | Source | Target | Data | Delegate |
| --- | --- | --- | --- | --- |
| `REVEAL_CARD` | `JourneyDeck` | `CardSlot` | `{}` | `JourneyDeck.revealTopCard()` |
| `MOVE_CARD` | `Card` | destination `CardSlot` | `{}` | `BoardController.moveCard()` |
| `MODIFY_STATS` | effect/request source or `null` | `Card` | `{"stat": String, "amount": int}` | a public method on `Card` |
| `REMOVE_CARD` | effect/request source or `null` | target `Card` | `{}` | `BoardController.removeCard()` |
| `DELETE_CARD` | effect/request source or `null` | target `Card` | `{}` | card lifecycle, after clearing any board reference |

These payload rules belong to Story 8. A malformed action-specific payload should warn and do nothing; it must not leave the processor busy.

The other valid constants can remain in `ActionType`. Until their handlers are deliberately implemented, the processor should warn that they are unsupported and continue with the next action.

## Processor Shape

Use the project's camelCase naming:

```gdscript
extends Node

var isProcessingAction := false

func _process(_delta: float) -> void:
	if isProcessingAction or !ActionQueue.queueHasActions():
		return

	_processNextAction()

func _processNextAction() -> void:
	isProcessingAction = true
	var action := ActionQueue.popNextAction()

	if !action.is_empty():
		await _resolveAction(action)

	isProcessingAction = false

func _resolveAction(action: Dictionary) -> void:
	match action["type"]:
		ActionType.REVEAL_CARD:
			await _handleRevealCard(action)
		ActionType.MOVE_CARD:
			_handleMoveCard(action)
		ActionType.MODIFY_STATS:
			_handleModifyStats(action)
		ActionType.REMOVE_CARD:
			_handleRemoveCard(action)
		ActionType.DELETE_CARD:
			_handleDeleteCard(action)
		_:
			push_warning("ActionProcessor: Unsupported action type: %s" % action["type"])
```

Do not put a `while` loop in `_process()`. One active coroutine plus `isProcessingAction` is enough to prevent re-entry while an awaited handler is running.

## Delegation Requirements

### Board controller access

Add the active controller to a group:

```gdscript
func _ready() -> void:
	add_to_group("boardController")
```

The processor can use a small helper:

```gdscript
func _getBoardController() -> BoardController:
	return get_tree().get_first_node_in_group("boardController") as BoardController
```

If no controller exists in the active scene, board-related handlers should warn and return safely.

### Stat changes, healing, and damage

Do not make the processor responsible for refreshing card visuals. `Card.modifyStat(statName, amount) -> bool` owns the mutation, rejects unsupported stat names, clamps values where appropriate, and calls `_refreshCard()` internally.

For this story, support `health` and `attack` in `MODIFY_STATS` and treat `amount` as a signed delta. A positive health amount heals and a negative health amount deals damage. Reaching zero health does not implicitly remove or delete the card.

### Removal and deletion

`REMOVE_CARD` means removing a card from active play without deleting the card node. It delegates to `BoardController.removeCard(card)`, which clears the occupied slot and board reference.

`DELETE_CARD` means completely deleting the card node. If the card is still on the active board, the processor first asks `BoardController` to clear that reference, then calls `queue_free()`. Deletion also works for a card that is already outside active play.

### Reveal

`REVEAL_CARD` should validate that its source is a `JourneyDeck` and its target is a `CardSlot`, then await `source.revealTopCard(target)`. The processor remains busy until the reveal animation and placement finish.

## Keep Out Of Story 8

- Effect mediation or pre/post effect hooks
- Combat turn rules
- Automatic action chaining beyond explicitly required actions
- New animation systems
- Implementations for every extra `ActionType`
- Direct duplication of board, deck, slot, or card rules inside the processor
- New processor signals unless a concrete caller needs them

## Runtime Test

Create a temporary test script or scene that verifies:

- two queued synchronous actions resolve in FIFO order;
- `isProcessingAction` prevents a second action from starting during an awaited reveal;
- `MOVE_CARD` delegates to `BoardController` and clears the starting slot;
- `MODIFY_STATS` changes the requested stat and refreshes its display;
- a negative health modification deals damage and clamps health at zero without removing the card;
- `REMOVE_CARD` clears the occupied slot without freeing the card;
- `DELETE_CARD` clears any occupied slot before freeing the card;
- malformed action-specific data warns and the processor becomes idle again;
- a currently unsupported valid type warns and does not stop later actions; and
- the temporary test code is removed after the run.

Also run:

```text
git diff --check
```

## Definition Of Done

- [ ] `REMOVE_CARD` and `DELETE_CARD` exist in `ActionType.VALID_TYPES`.
- [ ] `ActionProcessor` is registered exactly once as an autoload.
- [ ] It consumes actions from the existing `ActionQueue` in FIFO order.
- [ ] It cannot re-enter while an action is resolving.
- [ ] Reveal, move, stat modification, removal, and deletion are routed by `ActionType` constants.
- [ ] Asynchronous reveal work is awaited.
- [ ] Board operations delegate to `BoardController`.
- [ ] Stat changes and visual refresh delegate to `Card`.
- [ ] Removal clears the slot without freeing the card, and deletion frees the card completely.
- [ ] Malformed payloads and unsupported types warn without wedging the queue.
- [ ] No effect system or unrelated gameplay rules are added.
- [ ] Runtime verification passes, temporary test code is deleted, and `git diff --check` passes.

## Handoff To Story 9

Once this processor is stable, Story 9 can add effect data without changing the queue contract. Later effect mediation should wrap resolution with pre/post hooks while preserving this processor's single-action, non-reentrant flow.
