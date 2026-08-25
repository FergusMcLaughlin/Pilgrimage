# Story 11 Add-ons Before Movement

Date: 2026-08-16

Status: To do before Story 12

Related: [[Story 11 GameController Implementation Guide]] · [[Story 12 Cardinal Movement Implementation Guide]] · [[Amended Implementation Story Order]]

## Purpose

Story 11's GameController and player-cycle behavior are complete. These small setup and presentation requirements must be made explicit and verified before movement input is added.

This is a completion add-on, not a new numbered story.

## Add-on 1: Explicit Player Face-Up Setup

After the player is placed in the centre slot, explicitly guarantee that the player is face-up.

Do not rely on the card scene's current default visibility. Setup should produce the same result if card defaults change later.

`CardVisuals` now exposes a public orientation query. GameController uses it to avoid flipping an already face-up card:

```gdscript
# CardVisuals
func isFaceUp() -> bool:
	return face.visible and !back.visible


# GameController
func _activatePlayerCard(card: Card) -> void:
	if card != null and !card.visuals.isFaceUp():
		await card.flipCard()
```

`startRun()` awaits `_activatePlayerCard()` so `PLAYER_READY` cannot begin during the flip animation. GameController does not directly manipulate face/back visibility.

## Add-on 2: Initial Journey Card Orientation

Document and verify the intended orientation of the eight cards revealed during initial setup.

Current expectation:

- Journey cards animate from the deck;
- each revealed card finishes face-up and readable;
- effects activate once after placement;
- the player remains face-up in the centre.

If the intended rule is face-down encounters, change this expectation before Story 12 rather than hiding it inside movement code.

## Add-on 3: Automatic Run Start in the Lab

The card test scene must call the real `GameController.startRun()` path automatically when launched.

This is now implemented. Retain a regression check so future scene edits cannot return to manual-only setup.

## Add-on 4: Setup Completion Contract

Before `PLAYER_READY`:

- the player exists;
- the player occupies the centre slot;
- the player is face-up;
- the eight surrounding slots are populated when the deck has enough cards;
- reveal animations have completed;
- reveal-triggered effects have settled;
- `ActionQueue` is empty;
- `ActionProcessor` is idle;
- input remains locked.

Only then may GameController enter `PLAYER_READY` and unlock input.

## Add-on 5: Tests

Extend `tests/game_controller_test.gd` to verify:

1. The player is face-up after setup.
2. Initial Journey cards have the intended orientation.
3. The centre player is never overwritten by board filling.
4. Setup does not emit `PLAYER_READY` before flips, reveals, and effects settle.
5. The lab scene invokes the real start-run path automatically.

Retain all existing 46 GameController checks.

## Files

| File | Change |
|---|---|
| `src/main/controllers/game_controller.gd` | Explicitly guarantee player orientation during setup. |
| `src/main/cards/card_visuals.gd` | Expose the `isFaceUp()` orientation query. |
| `src/tests/card_test_scene.gd` | Retain automatic `startRun()` invocation. |
| `tests/game_controller_test.gd/.tscn` | Add setup-orientation and readiness coverage. |

## Definition of Done

- [x] Player placement is explicitly face-up, not dependent on scene defaults.
- [x] Initial Journey card orientation is documented and tested.
- [x] The lab starts a real run automatically.
- [x] Setup waits for all placement, flip, reveal, action, and effect work.
- [x] The player remains in the centre throughout initial filling.
- [x] New and existing tests pass.
- [x] `git diff --check` passes.

## Story 12 Gate

Do not begin movement implementation until this checklist is complete. Story 12 should be able to assume one visible, authoritative player in the centre of a fully settled initial board.
