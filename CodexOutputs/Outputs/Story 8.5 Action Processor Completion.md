# Story 8.5: Finish and Test the Action Processor

Date: 2026-07-19

Related: [[Story 8 Implementation Guide]] · [[Action Processor Delegation Principle]] · [[Story 9 Effect Data Draft]]

## Purpose

Finish the basic action processor and protect its public queue-to-handler flow with a small permanent Godot test suite. Effect loading and execution remain later stories.

## Chosen Action Semantics

Story 8.5 uses the project's existing action vocabulary:

| Action | Meaning | Delegate | Await? |
| --- | --- | --- | --- |
| `REVEAL_CARD` | Reveal the top journey card into a slot | `JourneyDeck.revealTopCard()` | Yes |
| `MOVE_CARD` | Move a card between board slots | `BoardController.moveCard()` | No |
| `MODIFY_STATS` | Apply a signed delta to health or attack | `Card.modifyStat()` | No |
| `REMOVE_CARD` | Remove a card from active play without deleting it | `BoardController.removeCard()` | No |
| `DELETE_CARD` | Completely delete a card node | card lifecycle, after clearing a board reference | No |

`MODIFY_STATS` deliberately covers both healing and damage:

- a positive health amount heals;
- a negative health amount deals damage;
- health and attack clamp at zero;
- reaching zero health does not automatically remove or delete the card.

`REMOVE_CARD` and `DELETE_CARD` are different operations. Removing clears the card's occupied slot but leaves the card node alive for later use. Deleting calls `queue_free()`; if the card is still on the active board, its slot is cleared first so the board does not retain a stale reference. A card already outside active play can still be deleted.

## Payload Contract

| Action | Required payload |
| --- | --- |
| Reveal | source: `JourneyDeck`; target: `CardSlot` |
| Move | source: `Card`; target: destination `CardSlot` |
| Modify stats | target: `Card`; data: `stat` String and signed integer `amount` |
| Remove | target: `Card` currently on the active board |
| Delete | target: `Card` |

Every invalid payload should warn and return safely. An invalid or unsupported action must not leave `ActionProcessor.isProcessingAction` stuck on `true` or prevent the next queued action from resolving.

## Delegation Rules

The processor validates the request, selects the owner, and coordinates lifecycle work. It does not duplicate specialist behavior.

- `Card.modifyStat()` owns supported stat names, clamping, and visual refresh.
- `BoardController.moveCard()` owns slot-to-slot movement.
- `BoardController.removeCard()` owns locating and clearing a card's occupied slot and emitting the board-state change.
- `JourneyDeck.revealTopCard()` owns drawing, animation, and placement.
- `ActionProcessor` owns the final `queue_free()` for `DELETE_CARD`.

Only reveal is awaited at handler level because it currently contains asynchronous animation. Move, stat modification, removal, and deletion are immediate.

## Board Controller Lookup

`ActionProcessor` is an autoload while the active `BoardController` belongs to the loaded board scene. The controller registers itself in the `boardController` group, and the processor looks it up when a board operation is requested.

```gdscript
func _getBoardController() -> BoardController:
	return get_tree().get_first_node_in_group("boardController") as BoardController
```

`REMOVE_CARD` requires an active controller. `DELETE_CARD` does not require one, but uses it when available to clear an occupied slot before deletion.

## Test Suite

The reusable starting files are currently:

```text
tests/action_processor_test_template.gd
tests/action_processor_test_template.tscn
```

Turn them into the permanent `action_processor_test.gd` and `.tscn` suite. Test through `ActionQueue` rather than calling private handlers so the tests cover the real queue → processor → delegate flow.

Required tests:

- positive health modification heals through the queue;
- negative health modification damages and clamps at zero without removing or freeing the card;
- two immediate actions resolve FIFO;
- malformed data warns and does not wedge the processor;
- an unsupported valid action does not block the next action;
- move clears the old slot and fills the destination;
- remove clears the occupied slot without freeing the card;
- delete clears an occupied slot and frees the card;
- delete also frees a card that is already outside active play;
- reveal keeps `isProcessingAction` true until its tween finishes.

Use a bounded frame wait for asynchronous processing and reset the autoload queue between tests. A test runner must not print or count a failed assertion as a pass.

## Definition of Done

- [ ] All five handlers exist and validate their payloads.
- [ ] Only reveal is awaited at handler level.
- [ ] Positive and negative stat deltas work and clamp at zero.
- [ ] Remove and delete have distinct, tested lifecycle behavior.
- [ ] Invalid and unsupported actions do not wedge the queue.
- [ ] The permanent test scene runs headlessly without assertion or script errors.
- [ ] No effect or combat system is added.
- [ ] `git diff --check` passes.

## Handoff

After these checks pass, Story 8 is complete and Story 9 may add validated effect data without changing this action contract.
