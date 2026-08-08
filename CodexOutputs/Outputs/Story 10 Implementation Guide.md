# Story 10: Scriptable Card Effects

Status: In progress

Related: [[Story 9 Effect Data Draft]]

## Goal

Finish the effect framework and make the first effect work:

> When Goatman is revealed, it gains 2 health through `ActionQueue`.

Each effect behaviour gets its own script. Adding a future effect must not require adding branches to `EffectProcessor`.

## How the System Works

`EffectProcessor` listens to gameplay once. When a card enters play, it loads the scripts named by that card's effect data and creates an effect instance for that card.

The processor sends gameplay events to active effect instances. Each effect script decides whether it cares and may queue an action. Effect scripts never change cards or the board directly.

```text
Action finishes
    ↓
EffectProcessor creates or removes effect instances
    ↓
EffectProcessor sends an event to active effects
    ↓
An interested effect queues an action
    ↓
ActionProcessor changes the game
```

Adding a normal effect later should mean:

1. Add one effect script.
2. Add one effect definition to JSON.
3. Put that effect ID on a card.
4. Add a test.

Do not edit `EffectProcessor` for each new effect.

## Already Complete

- [x] `GlobalSignalBus.actionResolved(action, result)` exists.
- [x] `ActionProcessor` returns the revealed card.
- [x] `ActionProcessor` emits the resolved action and result.
- [x] `EffectProcessor` is registered as an autoload.
- [x] `EffectProcessor` connects to `actionResolved`.

## Files for Story 10

Create:

```text
src/effects/card_effect.gd
src/effects/effect_context.gd
src/effects/handlers/gain_health_on_play.gd
tests/effect_processor_test.gd
tests/effect_processor_test.tscn
```

Update:

```text
data/effect_dictionary.json
src/effects/effect_data.gd
src/effects/effect_data_factory.gd
src/singletons/effects/effect_processor.gd
src/singletons/actions/action_processor.gd
tests/action_processor_test.gd
```

## Step 1: Add the Script Path to EffectData

Add this field to `effect_data.gd`:

```gdscript
@export var scriptPath: String
```

Copy it in `effect_data_factory.gd`:

```gdscript
data.scriptPath = dictionary.get("script_path", "")
```

Update Story 9's factory test to include and assert the new field.

## Step 2: Point the First Effect at Its Script

Update `heal_self_on_play` in `effect_dictionary.json`:

```json
{
	"heal_self_on_play": {
		"id": "heal_self_on_play",
		"name": "Gain Health on Play",
		"trigger": "on_play",
		"operation": "gain_health",
		"target": "self",
		"script_path": "res://src/effects/handlers/gain_health_on_play.gd",
		"parameters": {
			"amount": 2
		}
	}
}
```

Health may go above base health in this story. This is a health gain, not capped healing.

Update `_testProductionEffectLoads` in `effect_library_test.gd` to expect:

```gdscript
assert(effect.name == "Gain Health on Play")
assert(effect.operation == "gain_health")
assert(
	effect.scriptPath
	== "res://src/effects/handlers/gain_health_on_play.gd"
)
```

## Step 3: Create the Base Effect Contract

Create `src/effects/card_effect.gd`:

```gdscript
class_name CardEffect
extends RefCounted

var hostCard: Card
var data: EffectData
var context: EffectContext


func setup(
	card: Card,
	effectData: EffectData,
	effectContext: EffectContext,
) -> void:
	hostCard = card
	data = effectData
	context = effectContext


func onActivated() -> void:
	pass


func onEvent(_event: Dictionary) -> void:
	pass


func onDeactivated() -> void:
	pass
```

An effect script extends this class. It may remember its own counters or applied bonuses.

It does not connect to `GlobalSignalBus` itself. `EffectProcessor` owns the shared connection and lifecycle.

## Step 4: Create EffectContext

Create `src/effects/effect_context.gd`:

```gdscript
class_name EffectContext
extends RefCounted

var processor: Node


func _init(effectProcessor: Node) -> void:
	processor = effectProcessor


func queueAction(action: Dictionary) -> bool:
	return ActionQueue.enqueueAction(action)


func getBoardController() -> BoardController:
	return processor.get_tree().get_first_node_in_group(
		"boardController"
	) as BoardController
```

The context is the safe doorway back into the game. Add stable helper methods here later when effects need shared board queries.

## Step 5: Replace EffectProcessor

Replace `src/singletons/effects/effect_processor.gd` with:

```gdscript
extends Node

var activeEffectsByCard: Dictionary = {}
var effectContext: EffectContext


func _ready() -> void:
	effectContext = EffectContext.new(self)
	GlobalSignalBus.actionResolved.connect(_onActionResolved)


func _onActionResolved(action: Dictionary, result: Variant) -> void:
	var actionType = action.get("type")
	if actionType in [ActionType.REMOVE_CARD, ActionType.DELETE_CARD]:
		var removedCard = action.get("target")
		if removedCard is Card:
			_deactivateCardEffects(removedCard)

	_dispatchEvent({
		"type": "action_resolved",
		"action": action,
		"result": result,
	})

	match actionType:
		ActionType.REVEAL_CARD:
			if result is Card:
				_activateCardEffects(result)
				_dispatchEvent({
					"type": "on_play",
					"card": result,
				})


func _activateCardEffects(card: Card) -> void:
	if card == null || card.data == null:
		return

	_deactivateCardEffects(card)
	var cardEffects: Array[CardEffect] = []

	for effectId in card.data.effects:
		if !EffectLibrary.hasEffectData(effectId):
			continue

		var effectData := EffectLibrary.getEffectData(effectId)
		var effect := _createEffect(card, effectData)
		if effect == null:
			continue

		cardEffects.append(effect)
		effect.onActivated()

	if !cardEffects.is_empty():
		activeEffectsByCard[card] = cardEffects


func _createEffect(card: Card, effectData: EffectData) -> CardEffect:
	if effectData.scriptPath.is_empty():
		push_warning(
			"EffectProcessor: effect %s has no script path."
			% effectData.id
		)
		return null

	var effectScript = load(effectData.scriptPath)
	if effectScript == null:
		push_warning(
			"EffectProcessor: could not load %s."
			% effectData.scriptPath
		)
		return null

	var effect = effectScript.new()
	if !(effect is CardEffect):
		push_warning(
			"EffectProcessor: effect %s must extend CardEffect."
			% effectData.id
		)
		return null

	effect.setup(card, effectData, effectContext)
	return effect


func _dispatchEvent(event: Dictionary) -> void:
	for card in activeEffectsByCard.keys():
		if !is_instance_valid(card):
			activeEffectsByCard.erase(card)
			continue

		var cardEffects: Array = activeEffectsByCard[card]
		for effect in cardEffects:
			effect.onEvent(event)


func _deactivateCardEffects(card: Card) -> void:
	if !activeEffectsByCard.has(card):
		return

	var cardEffects: Array = activeEffectsByCard[card]
	for effect in cardEffects:
		effect.onDeactivated()

	activeEffectsByCard.erase(card)


func clearEffects() -> void:
	for card in activeEffectsByCard.keys():
		if is_instance_valid(card):
			_deactivateCardEffects(card)

	activeEffectsByCard.clear()
```

`clearEffects()` exists mainly so tests and future scene changes can reset the autoload safely.

## Step 6: Create the First Effect Script

Create `src/effects/handlers/gain_health_on_play.gd`:

```gdscript
extends CardEffect


func onEvent(event: Dictionary) -> void:
	if event.get("type") != data.trigger:
		return

	if event.get("card") != hostCard:
		return

	if data.target != "self":
		push_warning("GainHealthOnPlay: target must be self.")
		return

	var amount = data.parameters.get("amount")
	if !(amount is int) || amount <= 0:
		push_warning("GainHealthOnPlay: amount must be positive.")
		return

	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		{"stat": "health", "amount": amount},
	))
```

This file owns all knowledge of the effect. `EffectProcessor` does not know what `gain_health` means.

## Step 7: Tidy ActionProcessor

Use a space after the comma:

```gdscript
GlobalSignalBus.emitActionResolved(action, result)
```

Fix the indentation in the invalid reveal-source block:

```gdscript
if !(source is JourneyDeck):
	push_warning("ActionProcessor: REVEAL_CARD source must be a JourneyDeck.")
	return
```

Returning `null` for actions without a useful result is correct.

## Step 8: Test the Resolved Reveal

Extend `_testRevealBlocksUntilAnimationFinishes` in `action_processor_test.gd`.

Before enqueueing the reveal:

```gdscript
var resolvedCards: Array[Card] = []
var recordResolved := func(action: Dictionary, result: Variant) -> void:
	if action.get("type") == ActionType.REVEAL_CARD:
		resolvedCards.append(result as Card)

GlobalSignalBus.actionResolved.connect(recordResolved)
```

After `_waitForProcessor(240)`:

```gdscript
GlobalSignalBus.actionResolved.disconnect(recordResolved)

assert(resolvedCards.size() == 1)
assert(resolvedCards[0] == slot.currentCard)
```

Keep the existing animation assertions. Together they prove resolution happens after placement.

## Step 9: Add the Effect Tests

Create `tests/effect_processor_test.gd`:

```gdscript
extends Node

var _createdCards: Array[Card] = []


func _ready() -> void:
	await _runTest(_testOnPlayHealthGain)
	await _runTest(_testOnlyPlayedCardReacts)
	await _runTest(_testCardWithoutEffectsDoesNothing)

	print("PASS: EffectProcessor tests")
	get_tree().quit(0)


func _runTest(testMethod: Callable) -> void:
	await _beforeEach()
	await testMethod.call()
	await _afterEach()


func _beforeEach() -> void:
	await _waitForProcessor()
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()


func _afterEach() -> void:
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()

	for card in _createdCards:
		if is_instance_valid(card):
			card.queue_free()

	_createdCards.clear()
	await get_tree().process_frame


func _testOnPlayHealthGain() -> void:
	var goatman := _createCard("M_0002")
	var startingHealth := goatman.health

	_emitPlayed(goatman)
	await _waitForProcessor()

	assert(goatman.health == startingHealth + 2)


func _testOnlyPlayedCardReacts() -> void:
	var firstGoatman := _createCard("M_0002")
	var secondGoatman := _createCard("M_0002")

	_emitPlayed(secondGoatman)
	await _waitForProcessor()
	var secondHealthAfterPlay := secondGoatman.health

	_emitPlayed(firstGoatman)
	await _waitForProcessor()

	assert(firstGoatman.health == firstGoatman.data.baseHealth + 2)
	assert(secondGoatman.health == secondHealthAfterPlay)


func _testCardWithoutEffectsDoesNothing() -> void:
	var knight := _createCard("M_0001")
	var startingHealth := knight.health

	_emitPlayed(knight)
	await _waitForProcessor()

	assert(knight.health == startingHealth)


func _emitPlayed(card: Card) -> void:
	GlobalSignalBus.emitActionResolved(
		ActionType.make(ActionType.REVEAL_CARD),
		card,
	)


func _createCard(cardId: String) -> Card:
	var card := CreateCard.new().createCard(cardId)
	assert(card != null)
	add_child(card)
	_createdCards.append(card)
	return card


func _waitForProcessor(maxFrames := 120) -> void:
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() && !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame

	assert(false, "ActionProcessor did not become idle.")
```

Create `tests/effect_processor_test.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/effect_processor_test.gd" id="1_test"]

[node name="EffectProcessorTest" type="Node"]
script = ExtResource("1_test")
```

## Step 10: Add Safety Tests

Add these after the basic tests work:

- An effect with an empty script path is skipped.
- A script that does not extend `CardEffect` is skipped.
- A non-positive health amount queues nothing.
- A non-reveal action does not activate a card.
- Removing a card removes its active effect instances.
- Re-activating the same card does not create duplicate effects.
- One broken effect script does not block a later valid effect on the card.

Use temporary effect definitions and restore `EffectLibrary.effectDataById` after each test.

## Step 11: Run Everything

```bash
godot --headless --path . tests/effect_processor_test.tscn
godot --headless --path . tests/effect_library_test.tscn
godot --headless --path . tests/action_processor_test.tscn
git diff --check
```

## Definition of Done

- [ ] Goatman gains exactly 2 health after reveal.
- [ ] The effect queues `MODIFY_STATS` instead of changing health directly.
- [ ] Only the revealed Goatman reacts.
- [ ] Cards without effects do nothing.
- [ ] Effect scripts are loaded from effect data.
- [ ] Removing a card deactivates its effect instances.
- [ ] Invalid scripts and data fail safely.
- [ ] New and existing tests pass.
- [ ] `git diff --check` passes.

## Future Effect Experience

A future effect such as “after ten cards are removed, move this card” gets its own script extending `CardEffect`. That script stores its removal count, watches `action_resolved` events, and queues `MOVE_CARD` when the count reaches ten.

The processor, signal bus, and action processor do not change unless the effect needs a genuinely new gameplay action that the game cannot already perform.

## Not Part of Story 10

Do not implement Solitary Beast, board-count helpers, maximum health, general targeting searches, chained effects, or statuses in this story.
