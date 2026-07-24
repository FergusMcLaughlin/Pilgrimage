# Story 7 Implementation Guide: Add Action Queue

Date: 2026-07-14

## Current Status

**Complete and runtime verified on 2026-07-16 with Godot 4.7.**

The queue is registered as the `ActionQueue` autoload, validates through `ActionType.isValid()`, preserves FIFO order, supports peek/pop/clear/size queries, and emits its three events through `GlobalSignalBus` wrappers in the project's existing style. A temporary runtime test verified valid and invalid enqueue behavior, FIFO order, peek without removal, clearing, and all three signals; the temporary test was deleted afterward.

Before Story 8: keep the existing singular `ActionType` name and extra action constants. Add `DESTROY_CARD = "destroy_card"` before implementing the destruction handler. The invalid-action test currently produces a handled `push_error()` from Story 6 followed by the queue warning; this is expected with the present validator, though changing that validator message to `push_warning()` remains optional cleanup.

## Outcome

Story 7 adds one shared first-in, first-out waiting line for gameplay actions. Story 6 defines what an action looks like; Story 7 stores valid actions in a predictable order; Story 8 will decide what those actions actually do.

This is needed because effects, combat, movement, and deck refills will eventually create actions while other work is already happening. A queue gives them one stable timeline instead of allowing nested script calls to change game state unpredictably.

## Where It Fits

```text
Gameplay systems
      ↓ create actions
ActionType (Story 6)
      ↓ validate
ActionQueue (Story 7)
      ↓ provide the next action
ActionProcessor (Story 8)
      ↓ mutate game state
Board, cards, decks, and stats
```

The queue sits between action creation and action processing. It knows whether an action has the shared Story 6 shape and when it entered the queue. It does not know how to move a card, deal damage, trigger an effect, or end the game.

## Prerequisite

Story 6's current `ActionType` implementation already provides the shared action shape, constructor, and validator needed by this queue. Its additional action constants do not affect Story 7. The queue only depends on `ActionType.isValid()` and therefore does not need the action vocabulary to be reduced or the class renamed.

Add `DESTROY_CARD` before Story 8 implements action processing, because later combat and effect stories use that exact action name. It does not block building or testing this queue.

## Scope

Create:

```text
src/singletons/actions/action_queue.gd
```

Update:

```text
src/singletons/global_signal_bus.gd
```

Register it in `project.godot` as the `ActionQueue` autoload.

The queue must:

- accept only dictionaries that pass `ActionType.isValid()`;
- preserve first-in, first-out order;
- allow callers to inspect the next action without removing it;
- remove and return the next action;
- report its size and whether it contains actions;
- clear pending actions between runs; and
- emit signals when its state changes.

Do not add action processing, board mutation, animation waiting, effect hooks, or action-specific payload validation in this story.

## Public Contract

| Member | Purpose |
| --- | --- |
| `enqueueAction(action)` | Validate and append one action. Return whether it was accepted. |
| `popNextAction()` | Remove and return the oldest action, or `{}` when empty. |
| `peekNextAction()` | Return the oldest action without removing it, or `{}` when empty. |
| `queueHasActions()` | Report whether an action is waiting. |
| `clearQueue()` | Remove every queued action. |
| `getActionQueueSize()` | Return the number of waiting actions. |
| `GlobalSignalBus.actionEnqueued` | Signal that a valid action was appended. |
| `GlobalSignalBus.actionPopped` | Signal that an action was removed. |
| `GlobalSignalBus.queueCleared` | Signal that the queue was cleared. |

Returning `{}` for an empty pop or peek fits the action contract: an empty dictionary is not valid and can be checked safely.

## Implementation

Add `src/singletons/actions/action_queue.gd`:

```gdscript
extends Node

var _queue: Array[Dictionary] = []

func enqueueAction(action: Dictionary) -> bool:
	if !ActionType.isValid(action):
		push_warning("ActionQueue: Rejected invalid action.")
		return false

	_queue.append(action)
	GlobalSignalBus.emitActionEnqueued(action)
	return true

func popNextAction() -> Dictionary:
	if _queue.is_empty():
		return {}

	var action := _queue.pop_front()
	GlobalSignalBus.emitActionPopped(action)
	return action

func peekNextAction() -> Dictionary:
	if _queue.is_empty():
		return {}
	return _queue.front()

func queueHasActions() -> bool:
	return !_queue.is_empty()

func clearQueue() -> void:
	_queue.clear()
	GlobalSignalBus.emitQueueCleared()

func getActionQueueSize() -> int:
	return _queue.size()
```

The methods follow the repository's camelCase convention and Story 6 API. The private `_queue` is not exposed for callers to edit directly.

Append accepted actions unchanged. `ActionType.make()` owns construction of the action envelope and copying its top-level `data` dictionary. The queue should not rewrite actions because sources and targets may intentionally be object references.

## Global Signal Bus

Keep queue signals with the project's other gameplay signals. Add a queue section to `src/singletons/global_signal_bus.gd`:

```gdscript
# ==================================================
# ACTION QUEUE SIGNALS
# ==================================================

signal actionEnqueued(action)
signal actionPopped(action)
signal queueCleared()
```

Add matching wrappers:

```gdscript
# ==================================================
# ACTION QUEUE EMIT WRAPPERS
# ==================================================

func emitActionEnqueued(action) -> void:
	emit_signal("actionEnqueued", action)

func emitActionPopped(action) -> void:
	emit_signal("actionPopped", action)

func emitQueueCleared() -> void:
	emit_signal("queueCleared")
```

This matches the existing project convention: camelCase signal names, untyped signal parameters, and `GlobalSignalBus` wrapper methods using `emit_signal()`.

## Autoload Registration

In Godot, open `Project > Project Settings > Globals > Autoload`, select:

```text
res://src/singletons/actions/action_queue.gd
```

Register it as `ActionQueue`. Do not also instantiate the script in a scene, because that would create a second independent queue.

## Usage Example

```gdscript
var moveAction := ActionType.make(
	ActionType.MOVE_CARD,
	playerCard,
	destinationSlot,
)

if ActionQueue.enqueueAction(moveAction):
	print("Move request queued.")
```

Queueing the action must not move the card. Story 8's processor will later pop it and delegate the actual change.

## Verification

Use a temporary test script or the existing blank test scene after registering the autoload:

```gdscript
func _ready() -> void:
	ActionQueue.clearQueue()

	var firstAction := ActionType.make(ActionType.DRAW_CARD)
	var secondAction := ActionType.make(ActionType.MOVE_CARD)

	assert(ActionQueue.getActionQueueSize() == 0)
	assert(!ActionQueue.queueHasActions())
	assert(ActionQueue.enqueueAction(firstAction))
	assert(ActionQueue.enqueueAction(secondAction))
	assert(ActionQueue.getActionQueueSize() == 2)
	assert(ActionQueue.peekNextAction() == firstAction)
	assert(ActionQueue.getActionQueueSize() == 2)
	assert(ActionQueue.popNextAction() == firstAction)
	assert(ActionQueue.popNextAction() == secondAction)
	assert(ActionQueue.popNextAction().is_empty())
	assert(!ActionQueue.queueHasActions())

	assert(!ActionQueue.enqueueAction({}))
	assert(ActionQueue.getActionQueueSize() == 0)

	ActionQueue.enqueueAction(firstAction)
	ActionQueue.clearQueue()
	assert(ActionQueue.getActionQueueSize() == 0)
```

Warnings are expected for the invalid enqueue. Temporarily connect counters to `GlobalSignalBus.actionEnqueued`, `GlobalSignalBus.actionPopped`, and `GlobalSignalBus.queueCleared` if needed to verify the signals, then remove the test code.

Also run:

```text
git diff --check
```

## Definition of Done

- The queue validates against the existing `ActionType.isValid()` API.
- `src/singletons/actions/action_queue.gd` exists and extends `Node`.
- `ActionQueue` is registered exactly once as an autoload.
- Queue signals and their emit wrappers live in `GlobalSignalBus`, matching the project's existing signal style.
- Valid actions can be enqueued and invalid actions do not change queue size.
- Peek does not remove an action; pop returns actions in insertion order.
- Empty pop and peek calls return `{}` without crashing.
- Queue state, size, and clearing behave correctly.
- Enqueue, successful pop, and clear operations emit their matching signals.
- The queue contains no action execution or game-state mutation.
- New-run setup can clear old pending actions.
- Godot reports no parser or autoload errors and `git diff --check` passes.

## Handoff to Story 8

Story 8's `ActionProcessor` should check `ActionQueue.queueHasActions()` when it is idle, call `popNextAction()`, and route the action by its `ActionType` constant. The processor—not the queue—will own action-specific validation, game-state changes, and waiting for animation or effects. Add the planned `ActionType.DESTROY_CARD` constant before implementing Story 8's destruction route.
