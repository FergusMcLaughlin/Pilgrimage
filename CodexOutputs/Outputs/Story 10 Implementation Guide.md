# Story 10: Add Gameplay Events and the Effect System

Status: Planned

Related: [[Story 9 Effect Data Draft]] · [[Scalable Effect System Explained Simply]] · [[Action Processor Delegation Principle]]

## Goal

Prove the effect-data pipeline works end to end with one small effect:

> When a card with `heal_self_on_play` is revealed onto the board, enqueue a `MODIFY_STATS` action that heals that card by the configured amount.

Story 10 introduces effect execution. It does not introduce general targeting, conditions, chained effects, durations, or statuses.

## Why This Design

Use one `EffectSystem` autoload instead of creating a separate runtime object for every effect at this stage.

- `EffectLibrary` owns loaded definitions.
- `ActionProcessor` owns resolving actions.
- `GlobalSignalBus` publishes the completed action and its result.
- `EffectSystem` interprets supported effect data and enqueues new actions.
- `Card` remains unaware of effect execution.

Effects must request gameplay changes through `ActionQueue`. They must not modify card health or board state directly.

## Required Flow

```text
REVEAL_CARD is queued
    ↓
ActionProcessor awaits JourneyDeck.revealTopCard()
    ↓
The revealed Card is returned as the action result
    ↓
GlobalSignalBus emits actionResolved(action, result)
    ↓
EffectSystem sees an on_play event for the revealed Card
    ↓
EffectSystem loads each effect ID from EffectLibrary
    ↓
heal_self_on_play enqueues MODIFY_STATS
    ↓
ActionProcessor applies the heal through Card.modifyStat()
```

## Files

Create:

```text
src/effects/effect_system.gd
tests/effect_system_test.gd
tests/effect_system_test.tscn
```

Update:

```text
src/singletons/global_signal_bus.gd
src/singletons/actions/action_processor.gd
project.godot
```

The existing `EffectData`, `EffectLibrary`, card data, and JSON shape should not need redesigning.

## Implementation Checklist

### 1. Publish Completed Action Results

- [ ] Add `signal actionResolved(action, result)` to `GlobalSignalBus`.
- [ ] Add an `emitActionResolved(action, result)` wrapper.
- [ ] Emit the signal only after an action handler has finished.
- [ ] For asynchronous reveal, emit only after the reveal tween and placement finish.
- [ ] Do not use `actionPopped` as an effect trigger; it fires before resolution.

### 2. Return the Revealed Card

- [ ] Make the `REVEAL_CARD` resolution path retain the value returned by `JourneyDeck.revealTopCard()`.
- [ ] Publish that card as the resolved action result.
- [ ] Publish `null` when reveal validation or placement fails.
- [ ] Other current handlers may publish `null` until a later story needs their results.
- [ ] Keep `ActionProcessor.isProcessingAction` true until the handler and result publication are complete.

Suggested processor flow:

```gdscript
func _processNextAction() -> void:
	isProcessingAction = true

	var action := ActionQueue.popNextAction()
	if !action.is_empty():
		var result = await _resolveAction(action)
		GlobalSignalBus.emitActionResolved(action, result)

	isProcessingAction = false
```

### 3. Add the `EffectSystem` Autoload

- [ ] Create `src/effects/effect_system.gd` extending `Node`.
- [ ] Register it once as `EffectSystem` in `project.godot`.
- [ ] Connect to `GlobalSignalBus.actionResolved` in `_ready()`.
- [ ] Ignore actions that do not currently create a supported gameplay event.
- [ ] Treat a successful `REVEAL_CARD` result as `on_play` for Story 10.
- [ ] Ignore a failed reveal whose result is `null`.

Suggested boundary:

```gdscript
func _onActionResolved(action: Dictionary, result) -> void:
	if action.get("type") != ActionType.REVEAL_CARD:
		return
	if !(result is Card):
		return

	_processCardTrigger(result, "on_play")
```

### 4. Resolve Every Effect ID on the Card

- [ ] Return safely if the card or its `CardData` is missing.
- [ ] Loop over the complete `card.data.effects` array.
- [ ] Fetch each definition through `EffectLibrary.getEffectData(effectId)`.
- [ ] Skip a missing definition without stopping later effects.
- [ ] Ignore definitions whose trigger does not match the current event.
- [ ] Do not register permanent listeners or store card references in Story 10.

### 5. Implement Only `heal → self`

- [ ] Route definitions with `operation == "heal"` to a small heal handler.
- [ ] Support `target == "self"` only in this story.
- [ ] Read `amount` from `effectData.parameters`.
- [ ] Require `amount` to be a positive integer in the heal handler.
- [ ] Warn and return for a malformed amount or unsupported target.
- [ ] Enqueue `ActionType.MODIFY_STATS`; do not change `card.health` directly.

Suggested action:

```gdscript
var healAction := ActionType.make(
	ActionType.MODIFY_STATS,
	card,
	card,
	{"stat": "health", "amount": amount},
)
ActionQueue.enqueueAction(healAction)
```

The operation handler validates `amount` because it understands what healing requires. `EffectDataFactory` remains free of gameplay-specific rules.

### 6. Handle Unsupported Data Safely

- [ ] An unsupported trigger does nothing.
- [ ] An unsupported operation warns and does nothing.
- [ ] An unsupported target warns and does nothing.
- [ ] A malformed heal amount warns and does nothing.
- [ ] One bad effect does not prevent later effects on the same card.
- [ ] No invalid effect leaves `ActionProcessor` busy or corrupts `ActionQueue`.

## Permanent Tests

Create a top-level `tests/effect_system_test.tscn` suite covering the public runtime flow.

- [ ] A successful reveal publishes `actionResolved` after placement.
- [ ] The reveal result is the placed `Card`.
- [ ] `heal_self_on_play` enqueues a `MODIFY_STATS` action.
- [ ] The queued heal resolves and increases the revealed card's health by 2.
- [ ] The heal is not applied before reveal completes.
- [ ] A card without effects produces no follow-up action.
- [ ] A failed reveal does not fire an effect.
- [ ] A malformed heal amount warns and queues nothing.
- [ ] An unsupported operation warns and queues nothing.
- [ ] One unsupported effect does not block a later supported effect.
- [ ] Existing ActionProcessor tests still pass.
- [ ] Existing EffectLibrary tests still pass.

The suite must use bounded frame waits and exit non-zero when its expected pass count is not reached.

## Keep Out of Story 10

- action source or action target selection;
- selected enemies, allies, or board-wide targeting;
- conditions or health thresholds;
- pre-action effects;
- kill, damage, combat, or game-over triggers;
- chained effect steps or previous-result references;
- recursion/depth systems;
- durations and persistent statuses;
- per-card effect listener objects; and
- general-purpose scripting inside JSON.

## Definition of Done

- [ ] Resolved actions publish their result after completion.
- [ ] A successful reveal produces one `on_play` event for the revealed card.
- [ ] Every effect ID on that card is inspected.
- [ ] `heal_self_on_play` heals through `ActionQueue` and `ActionProcessor`.
- [ ] Effect execution never directly mutates card stats.
- [ ] Unsupported or malformed effect data warns and fails safely.
- [ ] Story 10 tests pass headlessly.
- [ ] Story 9 and Story 8 regression suites still pass.
- [ ] The configured main scene passes a smoke test.
- [ ] `git diff --check` passes.

## Handoff to Story 11

Story 11 can expand targeting and conditions using real card requirements. It should build on the resolved-action event and the small explicit operation routing established here rather than replacing it with a general scripting language.
