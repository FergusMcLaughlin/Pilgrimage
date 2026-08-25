# Post-Story 13 Spike: Typed Gameplay Contracts

Date noted: 2026-08-16

Status: Planned spike after Story 13

Related: [[Story 13 Combat and Board Refill Implementation Guide]] · [[Story 14 Effects Implementation Guide]] · [[Amended Implementation Story Order]] · [[Future Story - Combat Integration Effect Reassessment]] · [[Story 14 Pre-Chore - Graveyard and Death Contract]]

## Purpose

After Story 13 is implemented and tested, review the remaining runtime dictionaries that cross gameplay-system boundaries.

Story 13 introduces typed `CombatContext`, `DamageResult`, and `CombatResult` objects because large combat dictionaries would otherwise create fragile string-key contracts. It also keeps replacement-card information in the separate `BoardRefillResult`. The same reasoning may apply elsewhere, particularly before Story 14 adds several stateful effects.

This is a short architecture spike, not permission to convert every dictionary in the project.

## Timing

```text
Story 13 complete
→ typed-gameplay-contract spike
→ Story 14 effects implementation
```

Do not begin the spike until Story 13's real combat pipeline and tests pass. Complete the decision before Story 14 commits to its final event APIs.

## Candidate 1: Typed Effect Events

Priority: High

Current runtime boundary:

```gdscript
func CardEffect.onEvent(event: Dictionary) -> void
```

`EffectProcessor` currently constructs events with keys such as:

```gdscript
{
	"type": "action_resolved",
	"action": action,
	"result": result,
}
```

As Story 14 introduces combat, damage, removal, board-change, and player-cycle reactions, this risks producing one loosely documented dictionary containing many optional keys.

Evaluate a typed event family:

```text
GameplayEvent
├── ActionResolvedEvent
├── CardPlayedEvent
├── CombatCompletedEvent
├── BoardChangedEvent
└── PlayerCycleCompletedEvent
```

Possible base contract:

```gdscript
class_name GameplayEvent
extends RefCounted

enum Type {
	ACTION_RESOLVED,
	CARD_PLAYED,
	COMBAT_COMPLETED,
	BOARD_CHANGED,
	PLAYER_CYCLE_COMPLETED,
}

var type: Type
```

Possible effect boundary:

```gdscript
func onEvent(event: GameplayEvent) -> void:
	pass
```

The spike must decide whether subclasses are clearer than one typed envelope with optional typed fields. Prefer subclasses if the single envelope would contain many unrelated nullable properties.

## Candidate 2: Typed Card Stat Snapshot

Priority: High

`GraveyardEntry` is typed, but its fixed stat record is currently:

```gdscript
var statSnapshot: Dictionary = {}
```

Evaluate:

```gdscript
class_name CardStatSnapshot
extends RefCounted

var health: int
var temporaryHealth: int
var attack: int
```

`GraveyardEntry` would then expose:

```gdscript
var statSnapshot: CardStatSnapshot
```

Keep a conversion method for BoardHistory, saves, debugging, or JSON:

```gdscript
func toDictionary() -> Dictionary:
	return {
		"health": health,
		"temporary_health": temporaryHealth,
		"attack": attack,
	}
```

The runtime contract can be typed without removing dictionary serialization.

## Candidate 3: Typed Game-Over Result

Priority: High when Story 15 begins

Story 15 should avoid introducing a free-form game-over reason dictionary. Evaluate and document a contract such as:

```gdscript
class_name GameOverResult
extends RefCounted

enum Reason {
	PLAYER_DEFEATED,
	JOURNEY_DECK_EXHAUSTED,
}

var reason: Reason
var cycleNumber: int
var finalCombat: CombatResult
```

Expected signal:

```gdscript
signal gameOver(result: GameOverResult)
```

The spike does not need to implement Story 15, but it should record this decision so Story 15 and Story 17 share one contract.

## Candidate 4: Typed Board-History Envelope

Priority: Medium

BoardHistory currently stores heterogeneous dictionaries. Evaluate a typed outer record while retaining flexible serialized details:

```gdscript
class_name BoardHistoryEvent
extends RefCounted

var sequence: int
var eventType: String
var details: Dictionary
```

This would make sequence and event-type access safe without forcing every historical event into the same detail schema.

Only implement this if it materially simplifies Story 14 queries or future save/debug output. It should not become a prerequisite merely for aesthetic consistency.

## Candidate 5: Typed Action Envelope

Priority: Optional; not currently recommended

The generic action dictionary was an intentional Stories 6–10 design:

```gdscript
{
	"type": actionType,
	"source": source,
	"target": target,
	"data": data,
}
```

A `GameAction` object is technically possible, but converting now would affect every action producer, ActionQueue, ActionProcessor, EffectProcessor, signal, and related test.

During the spike, assess it only against concrete evidence:

- recurring misspelled envelope keys;
- action identity problems;
- confusing validation failures;
- difficulty typing action results;
- repeated unsafe casts across consumers.

If those problems are absent, retain the current action dictionary. Typed action-specific results already deliver most of the benefit at far lower migration cost.

## Dictionaries That Should Remain

Do not convert dictionaries simply because a class could be created. These uses are intentionally flexible:

- parsed JSON input;
- `CardDataFactory` and `EffectDataFactory` input;
- card and effect library ID maps;
- effect definition `parameters` while schemas differ by effect;
- small action-specific `data` payloads;
- serialization methods such as `toDictionary()`;
- flexible `BoardHistoryEvent.details`, if the typed envelope is adopted;
- test-only fixture bundles where a local class adds no clarity.

## Decision Rule

Prefer a typed object when most of these are true:

1. The fields form one stable gameplay concept.
2. The value crosses system or signal boundaries.
3. Multiple consumers read the same fields.
4. Missing or misspelled fields would silently change gameplay.
5. The value needs methods, validation, stable identity, or explicit success/failure state.

Prefer a dictionary when the shape is intentionally dynamic, external/serialized, local to one small function, or part of the established generic action/configuration boundary.

## Spike Tasks

1. Finish Story 13 and confirm the typed combat objects work in real tests.
2. Inventory every production `Dictionary` parameter, return type, signal payload, and stored runtime record.
3. Classify each as domain contract, generic transport, configuration, serialization, map, or local helper.
4. Prototype typed effect events against GainHealthOnPlay and one planned Story 14 combat effect.
5. Prototype `CardStatSnapshot` conversion to and from dictionary form.
6. Document the planned `GameOverResult` contract for Story 15.
7. Decide whether a typed BoardHistory envelope provides enough benefit.
8. Explicitly accept or reject a `GameAction` migration based on evidence.
9. Update Story 14 and Story 15 guides with the chosen contracts.
10. Add focused migration tests before removing any old dictionary event path.

## Expected Outcome

Produce a short decision record containing:

- accepted typed contracts;
- rejected conversions and reasons;
- exact files affected;
- compatibility/migration sequence;
- tests required;
- confirmation that no dual dictionary/object production path remains afterward.

## Definition Of Done

- [ ] Story 13 and its tests are complete first.
- [ ] Production dictionary boundaries have been classified.
- [ ] Typed effect events have been prototyped and accepted or rejected.
- [ ] `CardStatSnapshot` has been accepted or rejected.
- [ ] Story 15 has a documented typed game-over contract.
- [ ] BoardHistory typing has an explicit decision.
- [ ] Generic actions remain dictionaries unless concrete evidence justifies migration.
- [ ] Configuration and serialization dictionaries remain intentionally documented.
- [ ] Story 14 documentation matches the final event decision.
- [ ] No unnecessary conversion work has entered the spike.
- [ ] `git diff --check` passes.
