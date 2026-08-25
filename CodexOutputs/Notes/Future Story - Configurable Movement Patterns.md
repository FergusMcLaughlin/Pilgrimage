# Future Story: Configurable Movement Patterns

Date noted: 2026-08-16

Status: Deferred — do not expand Story 12

Related: [[Story 12 Cardinal Movement Implementation Guide]] · [[Amended Implementation Story Order]] · [[Story 14 Effects Implementation Guide]]

## Idea

Different player cards, items, or effects may eventually change how the player can move.

Possible examples include:

- the standard player moving one cardinal step;
- a knight-themed player moving in the L-shaped pattern used by a chess knight;
- items adding diagonal or extended movement;
- effects temporarily adding or removing valid destinations;
- terrain or card effects restricting movement.

## Current Decision

This is outside Story 12.

Story 12 will implement the currently intended default rule only:

```text
one slot up, down, left, or right
```

Do not add movement-pattern fields to `CardData`, a general movement-rule service, item modifiers, knight movement, or effect-driven target modification during Story 12.

The immediate goal is to make basic board-card/slot selection and valid/invalid cardinal evaluation work reliably without expanding the content system.

## Future Architectural Direction

When a real alternative player, item, or effect requires different movement, introduce a movement-rule boundary between input and target calculation:

```text
PlayerMovementController receives selection
→ movement-rule owner calculates valid targets for the current player
→ item/effect modifiers adjust those targets if required
→ controller accepts or rejects the selection
```

At that point, consider:

- a `movement_pattern` field in player-card data;
- a `MovementRules` or `MovementResolver` helper;
- reusable grid offset queries;
- additive and restrictive item/effect modifiers;
- precedence when several modifiers apply;
- UI highlighting for non-cardinal destinations;
- serialization of permanent movement upgrades.

## Boundaries

The future movement-rule system should calculate valid targets only. It should not:

- move cards directly;
- change GameController state;
- calculate combat;
- perform board replacement;
- unlock input.

Those responsibilities remain with the movement controller, action system, combat pipeline, and GameController.

## Definition of Ready

Revisit this note only when at least one concrete player card, item, or effect has a defined non-cardinal movement rule and is scheduled for implementation.

Before implementation, define:

- the exact movement pattern;
- whether it replaces or supplements cardinal movement;
- whether occupied and empty targets behave identically;
- how multiple movement modifiers combine;
- how valid destinations are presented to the player.
