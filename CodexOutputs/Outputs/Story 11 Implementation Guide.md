# Story 11: Implement the First Three Stateful Effects

Date: 2026-08-09

Status: Ready for staged implementation

Related: [[Story 10 Implementation Guide]] · [[Story 11 Pre-Chore - Graveyard and Death Contract]] · [[Old Effect System Comparison]] · [[Original PDF Progress Audit]]

## Goal

Implement three effects that test different parts of the runtime system:

1. `SolitaryBeast` recalculates stats from the current board.
2. `WaxingFerocity` accumulates attack after nonlethal attacks and resets when any card is removed.
3. `TasteOfVictory` grants temporary health after a successful kill, tracks damage absorbed by that health, and expires after four turns.

The latter two replace the original PDF's simpler HealOnKill and BuffAttackOnKill effects.

## Why This Is Better Coverage

| Effect | System pressure |
|---|---|
| SolitaryBeast | Board queries, recalculation, delta application, loop prevention |
| WaxingFerocity | Stateful accumulation, combat outcome events, global reset condition |
| TasteOfVictory | Kill attribution, temporary stat pool, damage accounting, turn duration |

These effects expose more useful architectural weaknesses before the game loop is built.

## Readiness and Staging

The Graveyard pre-chore is ready and tested. It provides removal context, attacker identity, final-event timing, and cleanup.

Combat and turns do not exist yet. Story 11 should therefore be implemented in two stages:

### Stage A — now

- add all three effect scripts and data;
- add a general gameplay-event entry point to `EffectProcessor`;
- implement and test each effect's internal state transitions with synthetic combat/turn events;
- use existing `MODIFY_STATS` actions as the temporary damage/stat boundary;
- keep effects unattached to production cards except SolitaryBeast on Goatman.

### Stage B — Stories 12–14

- GameController emits real turn events;
- combat emits real attack-result events;
- `DEAL_DAMAGE` replaces temporary negative `MODIFY_STATS` damage events;
- the same effect scripts are connected to those real events;
- manual combat testing replaces synthetic event calls.

Synthetic events are test scaffolding, not a second combat implementation.

## Shared Gameplay Event Boundary

Current effects receive action-resolution events, but attacks and turns are not themselves implemented actions. Add one public entry point to `src/main/singletons/effects/effect_processor.gd`:

```gdscript
func dispatchGameplayEvent(event: Dictionary) -> void:
	if event.is_empty() or !event.has("type"):
		push_warning("EffectProcessor: rejected malformed gameplay event.")
		return
	_dispatchEvent(event.duplicate())
```

For Stage A, tests call this method. Later, only the owning gameplay systems call it:

- CombatResolver dispatches `attack_resolved`.
- GameController dispatches `turn_ended`.

Do not let cards dispatch authoritative combat outcomes about themselves.

### Placeholder event shapes

```gdscript
EffectProcessor.dispatchGameplayEvent({
	"type": "attack_resolved",
	"attacker": attacker,
	"defender": defender,
	"damage": 2,
	"was_kill": false,
})
```

```gdscript
EffectProcessor.dispatchGameplayEvent({
	"type": "turn_ended",
	"card": cardWhoseTurnEnded,
})
```

Story 14 may add fields, but it must preserve these meanings.

## Effect 1: Solitary Beast

### Rule

Goatman receives a configurable health and attack bonus for every Woods card (`M_0006`) currently on the board.

Recalculate when activated and after these actions resolve:

```gdscript
const BOARD_ACTIONS: Array[String] = [
	ActionType.REVEAL_CARD,
	ActionType.MOVE_CARD,
	ActionType.REMOVE_CARD,
	ActionType.DELETE_CARD,
	ActionType.REVIVE_CARD,
]
```

Apply only the difference between desired and previously applied bonus. Never react to its own `MODIFY_STATS` actions.

### Data

Add to `data/effect_dictionary.json`:

```json
"solitary_beast": {
  "id": "solitary_beast",
  "name": "Solitary Beast",
  "trigger": "action_resolved",
  "operation": "recalculate_stats",
  "target": "self",
  "script_path": "res://src/main/effects/handlers/solitary_beast.gd",
  "parameters": {
    "matching_card_id": "M_0006",
    "health_per_match": 1,
    "attack_per_match": 1
  }
}
```

Add `solitary_beast` to Goatman's effects beside `heal_self_on_play`.

### Required context helper

Add to `src/main/effects/effect_context.gd`:

```gdscript
func getOccupiedCards() -> Array[Card]:
	var cards: Array[Card] = []
	var boardController := getBoardController()
	if boardController == null or boardController.grid == null:
		return cards

	for slot in boardController.grid.getOccupiedSlots():
		if slot.currentCard != null:
			cards.append(slot.currentCard)
	return cards
```

### State

`solitary_beast.gd` stores:

```gdscript
var _appliedHealthBonus := 0
var _appliedAttackBonus := 0
```

On recalculation:

```gdscript
var desiredHealthBonus := matchingCount * healthPerMatch
var desiredAttackBonus := matchingCount * attackPerMatch
var healthDelta := desiredHealthBonus - _appliedHealthBonus
var attackDelta := desiredAttackBonus - _appliedAttackBonus
```

Update the stored desired bonuses, then enqueue non-zero deltas through `MODIFY_STATS`.

If Goatman itself is being removed or deleted, do not queue new stat changes for the dying node.

## Effect 2: Waxing Ferocity

### Rule

After this card completes an attack that does not remove its target, it gains +1 attack.

Each subsequent nonlethal attack adds another +1:

```text
starting attack
→ nonlethal attack: +1
→ nonlethal attack: +2 total
→ nonlethal attack: +3 total
```

When any card is successfully removed from the board, the entire accumulated bonus resets to zero. A lethal attack therefore resets the bonus through its resulting `REMOVE_CARD` action.

The bonus is visible between attacks because it is applied to the card's normal attack value through `MODIFY_STATS`.

### Name

Use `Waxing Ferocity`. “Waxing” communicates increasing strength; “Ferocity” is clearer than Martial Cadence for a bonus that grows until a death occurs.

### Data

```json
"waxing_ferocity": {
  "id": "waxing_ferocity",
  "name": "Waxing Ferocity",
  "trigger": "attack_resolved",
  "operation": "accumulate_attack",
  "target": "self",
  "script_path": "res://src/main/effects/handlers/waxing_ferocity.gd",
  "parameters": {
    "amount_per_nonlethal_attack": 1
  }
}
```

Keep it unattached to production card data until the intended owner is chosen.

### State and event handling

Create `src/main/effects/handlers/waxing_ferocity.gd`:

```gdscript
extends CardEffect

var _accumulatedBonus := 0


func onEvent(event: Dictionary) -> void:
	if event.get("type") == "attack_resolved":
		_onAttackResolved(event)
		return

	if event.get("type") != "action_resolved":
		return
	var action: Dictionary = event.get("action", {})
	if action.get("type") != ActionType.REMOVE_CARD:
		return
	if event.get("result") is GraveyardEntry:
		_resetBonus()


func _onAttackResolved(event: Dictionary) -> void:
	if event.get("attacker") != hostCard:
		return
	if event.get("was_kill", false):
		return

	var amount: int = data.parameters.get(
		"amount_per_nonlethal_attack",
		1,
	)
	if amount <= 0:
		return

	_accumulatedBonus += amount
	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		{"stat": "attack", "amount": amount},
	))


func _resetBonus() -> void:
	if _accumulatedBonus == 0:
		return
	if is_instance_valid(hostCard):
		context.queueAction(ActionType.make(
			ActionType.MODIFY_STATS,
			hostCard,
			hostCard,
			{"stat": "attack", "amount": -_accumulatedBonus},
		))
	_accumulatedBonus = 0
```

### Edge cases

- Another card's nonlethal attack does nothing.
- A malformed event does nothing.
- A failed `REMOVE_CARD` with a null result does not reset the bonus.
- Removing any card resets the bonus, not only the attacked defender.
- If the host itself is removed, do not enqueue a reset against the dying node; simply clear internal state during deactivation.
- `onDeactivated()` sets `_accumulatedBonus = 0` without queuing an action.

## Effect 3: Taste of Victory

### Rule

After this card successfully kills another card in combat, it gains a three-point temporary-health pool lasting through its next four completed turns.

Temporary health absorbs damage before ordinary health:

```text
base health 4 + temporary health 3
take 1 damage → base 4 + temporary 2
buff expires → base remains 4

base health 4 + temporary health 3
take 3 damage → base 4 + temporary 0
buff expires → no further change

base health 4 + temporary health 3
take 5 damage → base health becomes 2
buff expires → no further change
```

The last result is 2, not 3: seven total health minus five damage equals two. If a result of 3 is intended, a different damage rule must be defined before Story 14.

### Refresh rule

The buff does not stack.

A new kill while it is active:

- restores the temporary pool to 3;
- adds only the missing temporary points;
- resets duration to four turns.

Example: if one temporary point remains, another kill adds two, returning the pool to three.

### Data

```json
"taste_of_victory": {
  "id": "taste_of_victory",
  "name": "Taste of Victory",
  "trigger": "action_resolved",
  "operation": "temporary_health_after_kill",
  "target": "self",
  "script_path": "res://src/main/effects/handlers/taste_of_victory.gd",
  "parameters": {
    "temporary_health": 3,
    "duration_turns": 4
  }
}
```

Keep it unattached to production card data until the intended owner is chosen.

### Stage A damage convention

Until `DEAL_DAMAGE` exists, damage tests use:

```gdscript
ActionType.make(
	ActionType.MODIFY_STATS,
	attacker,
	target,
	{
		"stat": "health",
		"amount": -damage,
		"kind": "damage"
	},
)
```

The `kind` field prevents ordinary stat penalties from being mistaken for damage.

### State

Create `src/main/effects/handlers/taste_of_victory.gd` with:

```gdscript
var _remainingTemporaryHealth := 0
var _turnsRemaining := 0
```

Handle three event types.

#### Successful combat kill

Watch resolved `REMOVE_CARD` actions where:

```gdscript
action.get("source") == hostCard
action.get("data", {}).get("cause") == "combat"
event.get("result") is GraveyardEntry
```

Refresh the pool:

```gdscript
var maximum: int = data.parameters.get("temporary_health", 3)
var amountToAdd := maximum - _remainingTemporaryHealth
_remainingTemporaryHealth = maximum
_turnsRemaining = data.parameters.get("duration_turns", 4)

if amountToAdd > 0:
	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		{
			"stat": "health",
			"amount": amountToAdd,
			"kind": "temporary_health_gain",
		},
	))
```

#### Damage resolution

Watch resolved negative health `MODIFY_STATS` actions targeting the host with `kind=damage`:

```gdscript
var damage := -int(action.get("data", {}).get("amount", 0))
var absorbed := mini(damage, _remainingTemporaryHealth)
_remainingTemporaryHealth -= absorbed
```

The existing stat action already reduced total displayed health. This state update records how much of that reduction came from the temporary pool.

#### Turn expiry

On `turn_ended` for the host:

```gdscript
_turnsRemaining -= 1
if _turnsRemaining > 0:
	return

var amountToRemove := _remainingTemporaryHealth
_remainingTemporaryHealth = 0
_turnsRemaining = 0
if amountToRemove > 0:
	context.queueAction(ActionType.make(
		ActionType.MODIFY_STATS,
		hostCard,
		hostCard,
		{
			"stat": "health",
			"amount": -amountToRemove,
			"kind": "temporary_health_expired",
		},
	))
```

Only decrement duration while the buff is active. Turns belonging to other cards do not count.

### Stage B migration

When `DEAL_DAMAGE` is implemented, it should return actual damage allocation:

```gdscript
{
	"damage_requested": 5,
	"temporary_health_lost": 3,
	"base_health_lost": 2,
}
```

TasteOfVictory should then consume that result rather than infer absorption from negative `MODIFY_STATS`. The effect's kill, refresh, duration, and expiry logic remains unchanged.

## Tests

Create `tests/story_11_effects_test.gd/.tscn`.

### SolitaryBeast

1. No Woods means no bonus.
2. One Woods applies exactly one configured increment.
3. Unrelated board events do not stack the bonus.
4. A second Woods adds one further increment.
5. Removing a Woods subtracts one increment.
6. Removing the host queues no dying-node modification.

### WaxingFerocity

1. First nonlethal host attack adds +1.
2. Three nonlethal host attacks produce +3 total, not +6.
3. Another attacker's event does nothing.
4. A failed removal does not reset the bonus.
5. Any successful removal resets the whole accumulated bonus.
6. A lethal attack does not add before its removal reset.
7. Deactivation clears internal state without targeting a freed host.

### TasteOfVictory

1. A combat kill by the host grants +3 temporary health.
2. A non-combat removal grants nothing.
3. Another card's kill grants nothing.
4. One damage consumes one temporary point; expiry removes the remaining two.
5. Three damage consumes the pool; expiry changes nothing.
6. Five damage leaves base health at two from a starting base of four.
7. Exactly four host turns expire the buff; other turns do not count.
8. A second kill refreshes depleted temporary health to three and resets duration.
9. Repeated kills never stack beyond three temporary health.
10. Deactivation clears duration and pool state.

Tests may dispatch `attack_resolved` and `turn_ended` directly through `EffectProcessor.dispatchGameplayEvent()`. Removal and stat changes must still use real queued actions.

## File Scope

| File | Change |
|---|---|
| `data/effect_dictionary.json` | Add all three definitions. |
| `data/card_dictionary.json` | Attach SolitaryBeast to Goatman only. |
| `src/main/effects/effect_context.gd` | Add occupied-card query. |
| `src/main/singletons/effects/effect_processor.gd` | Add validated gameplay-event dispatch. |
| `src/main/effects/handlers/solitary_beast.gd` | New recalculation effect. |
| `src/main/effects/handlers/waxing_ferocity.gd` | New attack-accumulation effect. |
| `src/main/effects/handlers/taste_of_victory.gd` | New temporary-health effect. |
| `tests/effect_library_test.gd` | Validate production definitions. |
| `tests/story_11_effects_test.gd/.tscn` | Add stateful effect coverage. |

No changes should be required in `ActionProcessor`, `Graveyard`, `BoardHistory`, or `GlobalSignalBus` during Stage A.

## Outside Stage A

- Combat calculation.
- `DEAL_DAMAGE`.
- Real attack input.
- Real turn progression.
- Temporary-health UI treatment.
- Production card assignments for WaxingFerocity and TasteOfVictory.

Record temporary-health UI as part of Story 17 unless combat testing needs a small debug label earlier.

## Verification

```bash
godot --headless --path . tests/story_11_effects_test.tscn
godot --headless --path . tests/graveyard_test.tscn
godot --headless --path . tests/board_history_test.tscn
godot --headless --path . tests/action_processor_test.tscn
godot --headless --path . tests/effect_processor_test.tscn
godot --headless --path . tests/effect_library_test.tscn
godot --headless --path . tests/story_10_integration_test.tscn
git diff --check
```

## Definition of Done for Stage A

- [ ] All three scripts load through effect data.
- [ ] SolitaryBeast recalculates by delta without stacking accidentally.
- [ ] WaxingFerocity accumulates only from its host's nonlethal attacks.
- [ ] A successful card removal resets WaxingFerocity.
- [ ] TasteOfVictory requires a successful combat kill by its host.
- [ ] TasteOfVictory never exceeds a three-point pool.
- [ ] Damage consumption and four-turn expiry match the stated examples.
- [ ] Effects enqueue actions rather than directly editing card stats.
- [ ] Synthetic events enter through one documented boundary.
- [ ] Stage B integration points are explicit.
- [ ] New and existing tests pass.
- [ ] `git diff --check` passes.

## Remaining PDF Work

After Stage A, the seven numbered stories after Story 11 remain:

1. Story 12 — GameController and turn state.
2. Story 13 — cardinal movement and refill.
3. Story 14 — combat, real attack events, `DEAL_DAMAGE`, and Stage B effect integration.
4. Story 15 — game-over conditions.
5. Story 16 — production game scene.
6. Story 17 — minimal game and temporary-health UI.
7. Story 18 — final card-lab separation and cleanup.
