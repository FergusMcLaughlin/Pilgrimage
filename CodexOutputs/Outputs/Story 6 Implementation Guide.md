# Story 6 Implementation Guide: Add Action Types

Date: 2026-07-13

## Outcome

Story 6 introduces one shared action contract for gameplay requests. An action describes **what should happen**; it does not perform the change. Story 7 will queue these dictionaries and Story 8 will process them.

After this story:

- every planned gameplay action has a named constant;
- every action has the same `type`, `source`, `target`, and `data` fields;
- malformed or unknown actions can be rejected before they enter the future queue; and
- callers do not need to know how an action will eventually be resolved.

## Scope

Create:

```text
src/actions/action_types.gd
```

Include these action types:

| Constant | String value | Intended request |
| --- | --- | --- |
| `REVEAL_CARD` | `reveal_card` | Reveal or create a card in a target slot. |
| `MOVE_CARD` | `move_card` | Move a card to a target slot. |
| `MODIFY_STATS` | `modify_stats` | Apply stat changes carried in `data`. |
| `DESTROY_CARD` | `destroy_card` | Remove a target card from play. |
| `DEAL_DAMAGE` | `deal_damage` | Deal an amount of damage to a target. |
| `DRAW_CARD` | `draw_card` | Draw from a source deck. |
| `GAME_OVER` | `game_over` | Request the end-of-run flow. |

`GAME_OVER` appears in the engineering backlog even though it is absent from the shorter implementation-stories summary. Include it now so later processors and effects share the same vocabulary.

Do not add an action queue, processor, board mutation, animation, effect hooks, or new autoload in this story.

## Action Contract

Every action is a `Dictionary` with four required keys:

```gdscript
{
	"type": String,
	"source": Variant,
	"target": Variant,
	"data": Dictionary,
}
```

- `type` identifies the request and must be one of the constants above.
- `source` is the object or data that initiated/provides the action. It may be `null`.
- `target` is the object or data the action is aimed at. It may be `null`.
- `data` contains action-specific parameters and is always a dictionary.

The base validator should validate this shared envelope only. It should not reject a `MOVE_CARD` because its source or target is `null`; action-specific requirements belong in the future processor. This keeps Story 6 independent of board, deck, and card classes and makes the contract useful in isolated tests.

## Implementation

Add `src/actions/action_types.gd` with the following implementation:

```gdscript
class_name ActionTypes
extends RefCounted

const REVEAL_CARD := "reveal_card"
const MOVE_CARD := "move_card"
const MODIFY_STATS := "modify_stats"
const DESTROY_CARD := "destroy_card"
const DEAL_DAMAGE := "deal_damage"
const DRAW_CARD := "draw_card"
const GAME_OVER := "game_over"

const VALID_TYPES: Array[String] = [
	REVEAL_CARD,
	MOVE_CARD,
	MODIFY_STATS,
	DESTROY_CARD,
	DEAL_DAMAGE,
	DRAW_CARD,
	GAME_OVER,
]

static func make(
	actionType: String,
	source = null,
	target = null,
	data: Dictionary = {},
) -> Dictionary:
	return {
		"type": actionType,
		"source": source,
		"target": target,
		"data": data.duplicate(),
	}

static func isValid(action: Dictionary) -> bool:
	if action.is_empty():
		push_warning("ActionTypes: Action cannot be empty.")
		return false

	for requiredKey in [&"type", &"source", &"target", &"data"]:
		if !action.has(requiredKey):
			push_warning("ActionTypes: Action is missing required key '%s'." % requiredKey)
			return false

	if !(action["type"] is String):
		push_warning("ActionTypes: Action type must be a String.")
		return false

	if action["type"] not in VALID_TYPES:
		push_warning("ActionTypes: Unknown action type '%s'." % action["type"])
		return false

	if !(action["data"] is Dictionary):
		push_warning("ActionTypes: Action data must be a Dictionary.")
		return false

	return true
```

The public methods use the repository's existing camelCase convention (`initialiseDeck`, `placeCard`, `getSlotAt`) rather than introducing snake_case in one isolated file. The `actionType` parameter also avoids using the broad name `type` in method code.

`data.duplicate()` gives the action its own top-level payload dictionary. A caller can safely reuse or clear the original dictionary without immediately changing the queued action. A deep copy is unnecessary at this boundary; action payloads may intentionally contain references to cards, slots, or decks.

`ActionTypes` extends `RefCounted` because it is a utility class and never needs to enter the scene tree. `class_name` makes it available project-wide without an autoload.

## Usage Examples

Callers must use constants, not raw action-name strings:

```gdscript
var moveAction := ActionTypes.make(
	ActionTypes.MOVE_CARD,
	playerCard,
	destinationSlot,
)
```

Action-specific values belong under `data`:

```gdscript
var damageAction := ActionTypes.make(
	ActionTypes.DEAL_DAMAGE,
	attacker,
	defender,
	{"amount": 3},
)
```

```gdscript
var statAction := ActionTypes.make(
	ActionTypes.MODIFY_STATS,
	effectSource,
	targetCard,
	{
		"stat": "health",
		"amount": -2,
	},
)
```

These payload names are examples, not additional Story 6 contracts. Story 8 should document and validate the required `data` fields when it implements each handler.

## Verification

Godot should import the script without parse errors. Then verify the contract with a temporary test script, the debugger, or assertions in the existing blank test scene:

```gdscript
func _ready() -> void:
	var action := ActionTypes.make(ActionTypes.MOVE_CARD)

	assert(ActionTypes.isValid(action))
	assert(action["type"] == ActionTypes.MOVE_CARD)
	assert(action.has("source"))
	assert(action.has("target"))
	assert(action["data"].is_empty())

	assert(!ActionTypes.isValid({}))
	assert(!ActionTypes.isValid({
		"type": "unknown_action",
		"source": null,
		"target": null,
		"data": {},
	}))
	assert(!ActionTypes.isValid({
		"type": ActionTypes.DRAW_CARD,
		"source": null,
		"target": null,
		"data": 2,
	}))
```

Warnings are expected for the three invalid cases. Remove temporary test code after verification; Story 6 does not require changes to a game scene.

Also run:

```text
git diff --check
```

## Definition of Done

- `src/actions/action_types.gd` exists and declares `class_name ActionTypes`.
- All seven planned action names live in that file as constants.
- `make()` always returns the shared four-key action shape.
- `isValid()` accepts an action created with a known type.
- `isValid()` rejects empty, incomplete, mistyped, and unknown actions without crashing.
- Usage examples rely on `ActionTypes` constants rather than raw strings.
- The file contains no action execution or game-state mutation.
- No autoload or scene change is introduced.
- Godot reports no parser errors and `git diff --check` passes.

## Handoff to Story 7

Story 7's `ActionQueue.enqueueAction()` should call `ActionTypes.isValid(action)` before appending. The queue should store the accepted dictionary unchanged, preserve FIFO order, and remain unaware of the action-specific payload rules that Story 8 will own.
