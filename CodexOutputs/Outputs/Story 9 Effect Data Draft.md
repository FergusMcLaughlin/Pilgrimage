# Story 9: Load Effect Data

Status: Complete — runtime verified.

Related: [[Story 8.5 Action Processor Completion]] · [[Scalable Effect System Explained Simply]]

## Outcome

Load effect definitions from `data/effect_dictionary.json` into `EffectData` resources and make them available through one `EffectLibrary` autoload.

Cards retain effect IDs as data. Story 9 does not execute effects, subscribe to gameplay events, change card state, or enqueue actions.

## Current Data Shape

Keep the current fixed fields for this first vertical slice:

```gdscript
class_name EffectData
extends Resource

@export var id: String
@export var name: String
@export var trigger: String
@export var operation: String
@export var target: String
@export var parameters: Dictionary = {}
```

The first production definition is:

```json
"heal_self_on_play": {
	"id": "heal_self_on_play",
	"name": "Heal Self on Play",
	"trigger": "on_play",
	"operation": "heal",
	"target": "self",
	"parameters": {
		"amount": 2
	}
}
```

## Validation Decision

Story 9 does not enforce a universal effect shape beyond the current conversion fields, and it does not hardcode every legal trigger, operation, target, or parameter combination.

Effects may grow into different shapes. Gameplay-specific validation belongs to the future handler that understands the operation.

The catalogue performs only the safety check needed at this stage:

- the top-level JSON must be a dictionary; and
- each catalogue entry must be a dictionary before it is passed to `EffectDataFactory`.

A non-dictionary entry warns, is skipped, and does not stop valid definitions loading.

## Card Data Boundary

Cards keep all referenced effect IDs:

```gdscript
@export var effects: Array[String] = []
```

`CardDataFactory` preserves the complete array. It does not resolve effects or execute gameplay.

After both catalogues load, `EffectLibrary` should check every ID on every card. Unknown references should warn without rejecting or changing the card.

## Implemented Files

- `src/effects/effect_data.gd`
- `src/effects/effect_data_factory.gd`
- `src/effects/effect_json_loader.gd`
- `src/effects/effect_library.gd`
- `data/effect_dictionary.json`
- `tests/effect_library_test.gd`
- `tests/effect_library_test.tscn`
- `project.godot` autoload registration

## Current Automated Coverage

- [x] `heal_self_on_play` loads with every expected field.
- [x] `EffectDataFactory` copies the current fixed fields.
- [x] A non-dictionary catalogue entry warns and is skipped.
- [x] Reloading clears stale cached definitions.
- [x] Loading effect data does not enqueue an action.
- [x] A card retains two effect IDs and both can be checked through `EffectLibrary`.
- [x] Unknown references warn with their card and effect IDs.
- [x] An unknown reference does not stop later IDs or cards being checked.
- [x] Reference validation preserves `CardData.effects` and queues no actions.

## Work Remaining

No implementation or automated verification work remains in Story 9.

## Keep Out of Story 9

- universal trigger, operation, target, or parameter validation;
- `EffectSystem` or `EffectMediator`;
- firing `on_play`;
- creating or enqueueing a heal action;
- changing card health;
- processor pre/post hooks;
- effect registration based on board zones; and
- conditions, targeting searches, timing, frequency, or sequences.

## Definition of Done

- [x] A minimal `EffectData` model exists.
- [x] The effect catalogue loads definitions by ID.
- [x] `heal_self_on_play` is available as runtime data.
- [x] Non-dictionary entries warn and do not stop catalogue loading.
- [x] Cards retain all effect IDs, not only the first.
- [x] Unknown card effect references warn without breaking card loading.
- [x] No effect executes and no action is queued.
- [x] All Story 9 runtime tests pass, including reference-validation tests.

## Handoff to Story 10

Story 10 will decide how triggers, operations, targets, and operation-specific parameters are interpreted. It will translate valid runtime effects into queued actions without changing Story 9's catalogue responsibility.
