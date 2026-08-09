# Story 14: Implement the First Three Stateful Effects

Date: 2026-08-09

Status: Blocked by Stories 11–13

Related: [[Amended Implementation Story Order]] · [[Story 14 Pre-Chore - Graveyard and Death Contract]] · [[Future Story - Combat Integration Effect Reassessment]]

## Goal

Implement three effects against real game, player-cycle, attack, damage, and removal events:

1. `SolitaryBeast` recalculates stats from the current board.
2. `WaxingFerocity` gains +1 attack after each nonlethal attack and resets when any card is removed.
3. `TasteOfVictory` grants a non-stacking three-point temporary-health pool for four completed player action cycles after a successful kill.

Do not implement synthetic combat or cycle behavior in this story. Stories 11–13 must provide the authoritative events first.

## Required Contracts from Earlier Stories

Story 11 provides:

- authoritative `playerCycleStarted` and `playerCycleCompleted` events;
- numbered player action cycles and the `AFTER_MOVE` boundary;
- player identity and game state.

Story 12 provides:

- action-based movement;
- previous-slot refill;
- occupied adjacent targets routed to combat.

Story 13 provides:

- `DEAL_DAMAGE`;
- authoritative attack results;
- actual damage dealt;
- lethal removal through `REMOVE_CARD` with `cause=combat`;
- attacker and defender attribution;
- one documented combat ordering.

The completed pre-chore already provides GraveyardEntry results, BoardHistory, and final effect dispatch before deactivation.

## Required Event Shapes

Story 14 consumes, rather than invents, these Story 11–13 events.

Attack result:

```gdscript
{
	"type": "attack_resolved",
	"attacker": attacker,
	"defender": defender,
	"damage_dealt": 2,
	"was_kill": false,
	"removal_entry": null,
}
```

Damage result:

```gdscript
{
	"type": "damage_resolved",
	"source": attacker,
	"target": defender,
	"damage_requested": 5,
	"damage_dealt": 5,
	"remaining_health": 2,
}
```

Player-cycle completion:

```gdscript
{
	"type": "player_cycle_completed",
	"player": playerCard,
	"cycle_number": 4,
}
```

`EffectProcessor` remains the single dispatcher to active effect instances. CombatResolver and GameController publish the authoritative source events.

## Effect 1: Solitary Beast

### Rule

Goatman gains configurable health and attack for every Woods card (`M_0006`) currently on the board.

Recalculate on activation and after successful:

- reveal;
- movement;
- removal;
- deletion;
- revival;
- combat refill.

Store the previously applied bonus and enqueue only the delta. Never react to its own `MODIFY_STATS` actions.

### Data

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

Attach `solitary_beast` to Goatman alongside `heal_self_on_play`.

### Implementation state

```gdscript
var _appliedHealthBonus := 0
var _appliedAttackBonus := 0
```

Calculate:

```gdscript
var desiredHealthBonus := matchingCount * healthPerMatch
var desiredAttackBonus := matchingCount * attackPerMatch
var healthDelta := desiredHealthBonus - _appliedHealthBonus
var attackDelta := desiredAttackBonus - _appliedAttackBonus
```

Then enqueue non-zero `MODIFY_STATS` actions. Skip recalculation when the host itself is leaving play.

Add a generic `EffectContext.getOccupiedCards()` helper rather than scanning scene children inside the effect.

## Effect 2: Waxing Ferocity

### Rule

After the host completes an attack that does not kill its defender, it gains +1 attack.

Each further nonlethal attack adds another +1. When any card is successfully removed, the whole accumulated bonus resets.

```text
base attack
→ first nonlethal attack: +1
→ second nonlethal attack: +2 total
→ third nonlethal attack: +3 total
→ any successful removal: base attack
```

A lethal attack does not add another point before reset.

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

Keep it unattached to production card data until its owner is chosen.

### Implementation state

```gdscript
var _accumulatedBonus := 0
```

On `attack_resolved`:

- require `attacker == hostCard`;
- require `was_kill == false`;
- increment stored bonus by the configured amount;
- enqueue that increment through `MODIFY_STATS`.

On a resolved `REMOVE_CARD` with a valid `GraveyardEntry` result:

- if the host is still active, enqueue `-_accumulatedBonus` attack;
- set accumulated bonus to zero.

If the host itself leaves, clear internal state during deactivation without targeting the dying node.

## Effect 3: Taste of Victory

### Rule

When the host successfully kills another card in combat, it gains a three-point temporary-health pool lasting through the next four completed player action cycles.

Temporary health is represented in total displayed health but tracked separately by the effect:

```text
base 4 + temporary 3
take 1 → total 6, temporary remaining 2
expiry removes 2 → base remains 4

base 4 + temporary 3
take 3 → total 4, temporary remaining 0
expiry changes nothing

base 4 + temporary 3
take 5 → total/base health becomes 2
expiry changes nothing
```

Seven total health minus five damage equals two. If a result of three is desired, the damage rule must be changed explicitly rather than hidden in this effect.

### Refresh behavior

The pool does not stack. Another kill:

- restores the pool to three;
- adds only missing temporary points;
- restarts the four-cycle duration.

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
    "duration_cycles": 4
  }
}
```

Keep it unattached to production card data until its owner is chosen.

### Implementation state

```gdscript
var _remainingTemporaryHealth := 0
var _cyclesRemaining := 0
```

Grant/refresh only when a resolved removal has:

```gdscript
action.get("source") == hostCard
action.get("data", {}).get("cause") == "combat"
event.get("result") is GraveyardEntry
```

Enqueue only the difference between three and the current temporary pool.

On `damage_resolved` targeting the host:

```gdscript
var absorbed := mini(
	int(event.get("damage_dealt", 0)),
	_remainingTemporaryHealth,
)
_remainingTemporaryHealth -= absorbed
```

On authoritative `playerCycleCompleted`, decrement duration. When the fourth completed player cycle ends, enqueue a negative health `MODIFY_STATS` equal only to the remaining temporary pool, then clear state.

There are no other-card turns. Invalid actions and optional maintenance that occurs without a completed player move do not advance the duration. Deactivation clears state without queuing expiry against a leaving node.

## Tests

Create `tests/story_14_effects_test.gd/.tscn`.

### Solitary Beast

1. No Woods gives no bonus.
2. One Woods gives exactly one configured increment.
3. Unrelated actions cannot stack it.
4. A second Woods adds one further increment.
5. Removing Woods subtracts one increment.
6. Complete combat removal/refill settles on the correct final value.

### Waxing Ferocity

1. Repeated real nonlethal attacks grow linearly.
2. Other attackers do nothing.
3. Failed attacks and failed removals do nothing.
4. A real lethal attack finishes with the bonus reset.
5. An unrelated successful removal also resets it.
6. Host removal leaves no queued dying-node modification.

### Taste of Victory

1. Only a real attributed combat kill grants the pool.
2. One, three, and five damage match the examples above.
3. Expiry removes only unspent temporary health.
4. Exactly four completed player action cycles expire the pool.
5. Invalid/rejected actions do not count.
6. Another kill refreshes rather than stacks.
7. Removal/deactivation leaves no retained duration or listener.

Unit-test effect-local edge cases, but the acceptance tests must use the real Story 11–13 player-cycle and combat pipeline.

## Files

| File | Change |
|---|---|
| `data/effect_dictionary.json` | Add all three definitions. |
| `data/card_dictionary.json` | Attach SolitaryBeast to Goatman. |
| `src/main/effects/effect_context.gd` | Add occupied-card query. |
| `src/main/effects/handlers/solitary_beast.gd` | Add board recalculation. |
| `src/main/effects/handlers/waxing_ferocity.gd` | Add attack accumulation/reset. |
| `src/main/effects/handlers/taste_of_victory.gd` | Add temporary-health lifecycle. |
| `tests/effect_library_test.gd` | Validate definitions. |
| `tests/story_14_effects_test.gd/.tscn` | Add real integration coverage. |

No placeholder combat or player-cycle producer belongs in these files.

## Definition of Done

- [ ] All effects consume authoritative Story 11–13 events.
- [ ] No synthetic production combat/player-cycle path remains.
- [ ] SolitaryBeast recalculates by delta.
- [ ] WaxingFerocity grows only after host nonlethal attacks.
- [ ] Any successful removal resets WaxingFerocity.
- [ ] TasteOfVictory requires an attributed combat kill.
- [ ] Temporary health absorbs real damage before expiry.
- [ ] Refresh never exceeds three temporary points.
- [ ] Four completed player action cycles expire the pool.
- [ ] Effects use queued actions for stat mutations.
- [ ] Removal cleans up all effect state/listeners.
- [ ] Unit and real-pipeline integration tests pass.
- [ ] `git diff --check` passes.

## Story 15 Ready When

Game-over work may begin when real combat, kills, and post-combat effects settle completely before the controller checks player death or end-of-run conditions.
