# Story 8 Implementation Guide: Add Action Processor

Date: 2026-07-16

Related: [[Story 7 Implementation Guide]] · [[Action Processor Delegation Principle]] · [[Action System Explained Simply]]

## Task

Create the `ActionProcessor` autoload that takes the next action from `ActionQueue`, routes it to the correct owner, waits for that action to finish, and then moves on to the next queued action.

The processor controls **when** an action resolves. Existing specialist classes control **how** it resolves.

## Before Starting

- Story 7 is complete and runtime verified.
- Keep the existing `ActionType` class name, camelCase methods, and expanded action vocabulary.
- Add `const DESTROY_CARD = "destroy_card"` to `ActionType` and include it in `VALID_TYPES`.
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
| `DEAL_DAMAGE` | attacking `Card` or request source | target `Card` | `{"amount": int}` | a public method on `Card` |
| `DESTROY_CARD` | destroyer/request source or `null` | target `Card` | `{}` | `BoardController` plus card lifecycle |

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
		ActionType.DEAL_DAMAGE:
			_handleDealDamage(action)
		ActionType.DESTROY_CARD:
			_handleDestroyCard(action)
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

### Stats and damage

Do not make the processor responsible for refreshing card visuals. Add focused public methods to `Card`, such as `modifyStat(statName, amount) -> bool` and `takeDamage(amount) -> bool`. Those methods should own the mutation, prevent invalid stat names or negative damage, clamp values where appropriate, and call `_refreshCard()` internally.

For this story, support `health` and `attack` in `MODIFY_STATS`. Treat `amount` as a delta. `DEAL_DAMAGE` subtracts a non-negative amount from health. Do not automatically destroy a zero-health card unless a separate `DESTROY_CARD` action is queued; keeping those actions separate will matter to later effects.

### Destruction

Destruction must locate and clear the card's current slot before calling `queue_free()`. Prefer adding a focused public `removeCard(card) -> bool` operation to `BoardController` and calling it from the processor rather than duplicating slot-search and clearing logic in the handler.

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
- `DEAL_DAMAGE` reduces health but does not implicitly free the target;
- `DESTROY_CARD` clears the occupied slot before freeing the card;
- malformed action-specific data warns and the processor becomes idle again;
- a currently unsupported valid type warns and does not stop later actions; and
- the temporary test code is removed after the run.

Also run:

```text
git diff --check
```

## Definition Of Done

- [ ] `DESTROY_CARD` exists in `ActionType.VALID_TYPES`.
- [ ] `ActionProcessor` is registered exactly once as an autoload.
- [ ] It consumes actions from the existing `ActionQueue` in FIFO order.
- [ ] It cannot re-enter while an action is resolving.
- [ ] Reveal, move, stat modification, damage, and destruction are routed by `ActionType` constants.
- [ ] Asynchronous reveal work is awaited.
- [ ] Board operations delegate to `BoardController`.
- [ ] Stat changes and visual refresh delegate to `Card`.
- [ ] Destruction clears the slot before freeing the card.
- [ ] Malformed payloads and unsupported types warn without wedging the queue.
- [ ] No effect system or unrelated gameplay rules are added.
- [ ] Runtime verification passes, temporary test code is deleted, and `git diff --check` passes.

## Handoff To Story 9

Once this processor is stable, Story 9 can add effect data without changing the queue contract. Later effect mediation should wrap resolution with pre/post hooks while preserving this processor's single-action, non-reentrant flow.
