# Future Story: Revival Presentation and Placement

Date noted: 2026-08-08

Related: [[Story 11 Pre-Chore - Graveyard and Death Contract]] · [[Future Story - Removed Card System]]

## Current Position

The functional revival path works:

```text
Select GraveyardEntry
→ queue REVIVE_CARD
→ reconstruct the card through CreateCard
→ preserve its logical instance identity
→ place it in an empty CardSlot
→ remove the entry from Graveyard
→ append a revived BoardHistory event
```

The manual test button currently revives the first Graveyard entry into the first empty slot. This is intentionally a deterministic test helper, not the final player-facing design.

## Deferred Design

The game does not yet define how revival should look or how its destination should be chosen.

A future story must decide:

- whether a revived card uses the journey-deck reveal animation, a distinct resurrection animation, or no reveal animation;
- whether the player chooses a destination slot;
- whether an effect chooses the slot automatically;
- whether revival is allowed only into particular slot types or positions;
- what happens when no valid slot exists;
- whether the action waits for animation before resolving;
- whether revival triggers `on_play`, `on_revive`, both, or neither;
- whether restored cards use base stats, their death snapshot, or effect-defined stats;
- whether the card returns face-up, face-down, or in another state;
- what feedback appears in the Graveyard UI and on the board.

## Architectural Boundary

Keep the existing graveyard mutation and identity behavior. The future story should add presentation and target-selection around it rather than moving those responsibilities into `Graveyard`.

Recommended ownership:

| Responsibility | Owner |
|---|---|
| Available cards to revive | `Graveyard` |
| Valid destination rules | Game/effect rule owner |
| Player destination selection | Gameplay input/controller |
| Card construction and identity restoration | `CreateCard` and `Graveyard` |
| Animation | Dedicated card/board visuals |
| Action ordering and completion | `ActionQueue` and `ActionProcessor` |
| Revival triggers | `EffectProcessor` |

`Graveyard.reviveCard()` should not permanently own player input or final animation rules.

## Story Boundary

Do not block the Story 11 pre-chore on these unanswered presentation questions. The current base-stat, first-valid-slot behavior is sufficient for automated and manual lifecycle testing.

Revisit this note when the first real revival effect or Graveyard UI is designed. That effect will provide the concrete requirements needed to choose destination, animation, restored state, and triggers.

## Definition of Ready

This future story is ready when at least one real card effect requires revival and its intended player experience is known.
