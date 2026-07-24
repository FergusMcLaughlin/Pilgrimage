# Story 9 Draft: Load Valid Effect Data

Date: 2026-07-19

Related: [[Story 8.5 Action Processor Completion]] · [[Old Effect System Comparison]] · [[Scalable Effect System Explained Simply]]

## Outcome

Story 9 gives effect IDs a small, validated runtime definition. Cards continue storing reusable IDs such as `heal_self_on_play`; the game can resolve each ID through one effect catalogue and reject malformed or missing definitions safely.

This story does **not** execute effects. Story 10 will add gameplay events and the `EffectSystem` that turns a matching definition into queued actions.

## Simple Explanation

At present a card can say:

```json
"effects": ["solitary_beast"]
```

but the current game only keeps that text. It does not load the matching entry from `effect_dictionary.json` or know what the entry means.

Story 9 connects the label to validated data:

```text
Card contains effect ID
    ↓
Effect catalogue finds that ID
    ↓
EffectData validates trigger, operation, target, and amount
    ↓
The valid definition is available for later use
```

That is preparation, not execution. Nothing should heal merely because its data was loaded.

## Prerequisite

[[Story 8.5 Action Processor Completion]] is complete and runtime verified. The effect layer must be built on working basic actions rather than compensating for missing processor handlers.

## First Vertical Slice

Use one deliberately simple definition: **when this card is played, heal itself by 2**.

Suggested catalogue entry:

```json
"heal_self_on_play": {
	"id": "heal_self_on_play",
	"name": "Heal Self on Play",
	"trigger": "on_play",
	"operation": "heal",
	"target": "self",
	"amount": 2
}
```

This proves the data shape without attempting `solitary_beast`. That effect needs board-state counting and safe recalculation, so it belongs after the basic trigger and targeting path works.

## Smallest Effect Shape

| Field | Type | Purpose |
| --- | --- | --- |
| `id` | `String` | Stable catalogue key used by cards and logs |
| `name` | `String` | Human-readable name |
| `trigger` | `String` | Story 9 supports `on_play` only |
| `operation` | `String` | Story 9 supports `heal` only |
| `target` | `String` | Story 9 supports `self` only |
| `amount` | `int` | Positive healing amount |

Do not carry old fields such as `timing` and `frequency` forward until a runtime story defines and enforces their meaning.

## Files

Create:

```text
src/effects/effect_data.gd
src/effects/effect_data_factory.gd
src/effects/effect_library.gd
```

Update:

```text
data/effect_dictionary.json
src/cards/card_loaders/card_data.gd
src/cards/card_loaders/card_data_factory.gd
project.godot
```

`EffectLibrary` may be an autoload like `CardLibrary`, registered exactly once. It loads the catalogue, builds validated `EffectData` resources, and provides queries such as `hasEffectData(id)` and `getEffectData(id)`.

## Card Data Decision

Keep effect IDs in `CardData` as the source reference:

```gdscript
@export var effects: Array[String] = []
```

Do not replace IDs with effect-specific scripts. IDs let several cards share one definition and preserve the useful data-driven part of the old system.

Add a resolved list only when a real caller needs it. Otherwise validate every card's IDs after both catalogues load and leave lookup to the later `EffectSystem`.

Support every ID in a card's `effects` array. Do not repeat the old system's mistake of using only the first entry.

## Validation Rules

Warn and skip an effect when:

- its catalogue entry is not a dictionary;
- its ID or name is empty;
- its trigger is not `on_play`;
- its operation is not `heal`;
- its target is not `self`;
- its amount is missing, not an integer, or not positive; or
- a card refers to an ID absent from the catalogue.

One bad effect must not stop valid effects or card data from loading.

## Keep Out of Story 9

- `EffectSystem` or `EffectMediator`
- subscribing to board or card signals
- firing `on_play`
- creating or enqueueing a `HEAL` action
- changing card health
- processor before/after hooks
- effect registration based on board zones
- conditions, target searches, sequences, frequency, or timing rules
- `solitary_beast` execution

Loading data and reacting to gameplay are separate responsibilities and should be tested separately.

## Verification

- Load `heal_self_on_play` and verify every field.
- Verify two effect IDs on one card are both preserved and checked.
- Verify an unknown card effect ID warns without breaking card loading.
- Verify malformed trigger, operation, target, and amount values are skipped safely.
- Verify catalogue reload clears old cached definitions.
- Verify loading effect data does not enqueue an action or change a card.
- Run `git diff --check`.

## Definition of Done

- [ ] A minimal `EffectData` model exists.
- [ ] The effect catalogue loads and validates definitions by ID.
- [ ] `heal_self_on_play` is available as valid runtime data.
- [ ] Cards retain all effect IDs, not only the first.
- [ ] Unknown and malformed definitions warn without stopping loading.
- [ ] No effect executes and no action is queued in this story.
- [ ] Runtime loading tests pass and temporary test code is removed.

## Handoff to Story 10

Story 10 adds a small `EffectSystem`, defines the `on_play` event precisely, finds active effects interested in it, and translates `heal_self_on_play` into a queued `HEAL` action. It must also decide when a card becomes active and inactive so cards in a deck cannot react, fixing a key problem from the old system.
