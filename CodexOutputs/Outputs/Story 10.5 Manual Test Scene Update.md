# Story 10.5: Integrate Journey Deck Reveals with the Action System

Date: 2026-08-08

Status: Ready to implement

Related: [[Story 10 Implementation Guide]], [[Story 10 Action Integration Review]]

## Goal

Route every gameplay journey-deck reveal through the action pipeline so a revealed card can trigger Story 10 effects.

The completed flow must be:

```text
JourneyDeck receives a reveal request
→ JourneyDeck chooses an empty slot
→ ActionQueue queues REVEAL_CARD
→ ActionProcessor calls JourneyDeck.revealTopCard(slot)
→ ActionProcessor emits actionResolved(action, card)
→ EffectProcessor activates the card and dispatches on_play
→ Goatman queues MODIFY_STATS
→ ActionProcessor increases Goatman's health from 3 to 5
```

`JourneyDeck.revealTopCard()` remains the low-level implementation. Input and gameplay setup must request that operation through `ActionQueue` rather than calling it directly.

## Why Story 10 Needs This

Story 10's effect code already reacts correctly to a resolved `REVEAL_CARD`. Its tests currently create that resolved event directly, however, while the journey deck bypasses the action system:

```text
_processRevealQueue()
→ revealToNextEmptySlot()
→ revealTopCard()
```

Because no action resolves in that path, `EffectProcessor` never receives an `on_play` event. This story joins the already-working deck and effect systems; it does not replace either one.

## Ownership After This Story

| Class | Responsibility |
|---|---|
| `JourneyDeck` | Handles deck input, chooses reveal slots, and coalesces rapid clicks. |
| `ActionQueue` | Orders actions and lets a caller await the result of one exact action. |
| `ActionProcessor` | Executes one action at a time and publishes its result. |
| `JourneyDeck.revealTopCard()` | Draws, animates, and places a card when called by `ActionProcessor`. |
| `EffectProcessor` | Reacts after resolution and dispatches `on_play`. |

## Change 1: Add a Shared Action-Completion Wait

Open:

`src/main/singletons/actions/action_queue.gd`

Add this method after `enqueueAction()`:

```gdscript
func waitForActionToResolve(expectedAction: Dictionary) -> Variant:
	while true:
		var resolution: Array = await GlobalSignalBus.actionResolved
		if resolution.size() < 2:
			continue

		var resolvedAction = resolution[0]
		if is_same(resolvedAction, expectedAction):
			return resolution[1]

	return null
```

`actionResolved` is global, so awaiting it once is unsafe: an unrelated action might finish first. This method keeps listening until the exact dictionary instance supplied by the caller resolves.

The final `return null` is unreachable in normal execution, but it satisfies GDScript's return-path validation.

Keep enqueueing separate from waiting. `enqueueAction()` can still report malformed actions through its existing Boolean return value.

## Change 2: Give JourneyDeck One Queued Reveal Helper

Open:

`src/main/decks/deck_types/journey_deck.gd`

Add this method below `revealTopCard()`:

```gdscript
func _requestRevealAtSlot(slot: CardSlot) -> Card:
	if slot == null or slot.isOccupied():
		return null

	var revealAction := ActionType.make(
		ActionType.REVEAL_CARD,
		self,
		slot,
	)

	if !ActionQueue.enqueueAction(revealAction):
		return null

	var result = await ActionQueue.waitForActionToResolve(revealAction)
	return result as Card
```

This is the request boundary. It creates and waits for an action but does not draw or place a card itself.

Do not change `revealTopCard()` to enqueue another action. `ActionProcessor` already calls that method while resolving `REVEAL_CARD`; enqueueing inside it would recurse indefinitely.

## Change 3: Route Board Filling Through Actions

Replace `fillEmptySlots()` with:

```gdscript
func fillEmptySlots(grid: SlotGrid) -> void:
	if grid == null:
		push_error("JourneyDeck: Cannot fill slots without a SlotGrid.")
		return

	for slot in grid.getEmptySlots():
		if isEmpty():
			return

		var revealedCard := await _requestRevealAtSlot(slot)
		if revealedCard == null:
			return
```

Board filling is gameplay, so its reveals must also publish `actionResolved` and trigger `on_play`. Waiting after each request preserves slot order and stops cleanly if a reveal fails.

## Change 4: Route the Next-Slot Helper Through Actions

Replace `revealToNextEmptySlot()` with:

```gdscript
func revealToNextEmptySlot() -> Card:
	if slotGrid == null:
		push_error("JourneyDeck: SlotGrid has not been assigned.")
		return null

	var emptySlots := slotGrid.getEmptySlots()
	if emptySlots.is_empty():
		return null

	return await _requestRevealAtSlot(emptySlots[0])
```

`_processRevealQueue()` can now remain structurally unchanged:

```gdscript
func _processRevealQueue() -> void:
	isProcessingRevealQueue = true

	while pendingRevealRequests > 0:
		pendingRevealRequests -= 1

		if isEmpty():
			break

		var revealedCard := await revealToNextEmptySlot()
		if revealedCard == null:
			break

	pendingRevealRequests = 0
	isProcessingRevealQueue = false
```

The call now requests an action rather than directly revealing. Keeping this loop matters: each pending click chooses its empty slot only after the previous action has completed, so rapid clicks cannot all select the same slot.

## Change 5: Update the Manual Test Scene Script

Open:

`src/tests/card_test_scene.gd`

Disable the visual stat cycle by default:

```gdscript
@export var debug_stat_cycle := false
```

Otherwise the timer can overwrite Goatman's effect result.

Use the Goatman configured with `heal_self_on_play`:

```gdscript
func _onAddGoatmanPressed() -> void:
	_addCardById("M_0002")
```

The button still creates a loose visual-test card; it does not reveal that card or trigger `on_play`.

Connect action feedback in `_ready()`:

```gdscript
func _ready() -> void:
	GlobalSignalBus.actionResolved.connect(_onActionResolved)
	# Keep the existing setup below this line.
```

Add:

```gdscript
func _onActionResolved(action: Dictionary, _result: Variant) -> void:
	if action.get("type") != ActionType.MODIFY_STATS:
		return

	var card := action.get("target") as Card
	if card != null:
		print("Effect resolved: %s now has %s health" % [
			card.data.name,
			card.health,
		])
```

This output is manual-test feedback only. Gameplay must not depend on it.

## Change 6: Clarify the Loose Goatman Button

Open:

`src/tests/card_test_scene.tscn`

Change:

```text
text = "Add Goatman"
```

to:

```text
text = "Add Goatman (No Reveal)"
```

This distinguishes loose card creation from clicking the journey deck, which performs a gameplay reveal.

## Change 7: Add an End-to-End Integration Test

Create:

```text
tests/story_10_integration_test.gd
tests/story_10_integration_test.tscn
```

The test must instantiate a real `JourneyDeck`, `SlotGrid`, and `BoardController`. Do not synthesize `actionResolved` in this suite.

Cover these cases:

1. Put `M_0002` at the top of an unshuffled journey deck, request a reveal, and assert that the placed Goatman's health becomes 5 after the queue becomes idle.
2. Record `actionResolved` and assert that `REVEAL_CARD` resolves before the effect's `MODIFY_STATS` action.
3. Queue multiple deck requests rapidly and assert that each successful reveal occupies a different slot.
4. Call `fillEmptySlots()` with Goatman first and assert that its `on_play` effect also resolves.

Use the existing fixture patterns in `tests/action_processor_test.gd` for board construction and processor-idle waiting.

This suite closes the gap left by Story 10's unit tests: it proves the real producer, queue, processor, and effect consumer work together.

## Files Changed

Implementation scope: **6 code/test files**.

| File | Change |
|---|---|
| `src/main/singletons/actions/action_queue.gd` | Add filtered action-result waiting. |
| `src/main/decks/deck_types/journey_deck.gd` | Route click and board-fill reveals through actions. |
| `src/tests/card_test_scene.gd` | Make the manual effect result observable and stable. |
| `src/tests/card_test_scene.tscn` | Clarify the loose-card button. |
| `tests/story_10_integration_test.gd` | Add full-pipeline regression coverage. |
| `tests/story_10_integration_test.tscn` | Host the new headless test. |

No functional changes are required in `ActionProcessor`, `EffectProcessor`, `GlobalSignalBus`, `ActionType`, `Card`, or `BoardController`.

## Verification

Run:

```bash
godot --headless --path . tests/action_processor_test.tscn
godot --headless --path . tests/effect_processor_test.tscn
godot --headless --path . tests/effect_library_test.tscn
godot --headless --path . tests/story_10_integration_test.tscn
git diff --check
```

Then run `src/tests/card_test_scene.tscn` manually:

1. Click the journey deck until Goatman is revealed.
2. Confirm the card is placed only after its reveal animation.
3. Confirm Goatman's health changes from 3 to 5.
4. Confirm the Output panel reports the resolved health change.
5. Click rapidly and confirm revealed cards occupy different slots.
6. Confirm the loose Goatman button does not trigger `on_play`.

## Definition of Done

- [ ] Deck clicks enqueue `REVEAL_CARD`.
- [ ] Board filling also enqueues `REVEAL_CARD`.
- [ ] `ActionProcessor` is the only gameplay caller of `revealTopCard()`.
- [ ] JourneyDeck waits for its exact reveal action before handling the next pending click.
- [ ] Revealed Goatman gains exactly 2 health through queued `MODIFY_STATS`.
- [ ] Loose card creation is clearly marked as not triggering `on_play`.
- [ ] The real end-to-end path is covered without synthesizing `actionResolved`.
- [ ] Existing and new automated tests pass.
- [ ] The manual test passes.
- [ ] `git diff --check` passes.
