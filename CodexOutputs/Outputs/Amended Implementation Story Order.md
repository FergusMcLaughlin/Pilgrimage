# Amended Implementation Story Order

Date: 2026-08-09

Status: Active build order

Related: [[Original PDF Progress Audit]] · [[Story 11 GameController Implementation Guide]] · [[Story 14 Effects Implementation Guide]]

## Why the Order Changed

The original PDF placed the first effects before GameController, movement, and combat. That made sense when Story 11 contained three simple action reactions.

The revised effects are deliberately more demanding:

- SolitaryBeast depends on authoritative board state.
- WaxingFerocity depends on completed attack outcomes.
- TasteOfVictory depends on attributed kills, temporary-health damage allocation, and real player-cycle expiry.

Implementing those effects first would require synthetic combat and player-cycle events that would be replaced immediately. The remaining stories are therefore reordered around their real dependencies.

## Amended Numbering

Stories 1–10 remain unchanged and complete according to the project's revised implementation guides. Story 10.5 remains the completed deck/action integration chore.

| New number | Story | Original PDF number | Dependency |
|---:|---|---:|---|
| 11 | GameController and run setup | 12 | Existing board, deck, actions, Graveyard |
| 12 | Cardinal movement and refill | 13 | Story 11 |
| 13 | Combat, damage, kills, and combat events | 14 | Stories 11–12 |
| 14 | Stateful effects: SolitaryBeast, WaxingFerocity, TasteOfVictory | Revised 11 | Stories 11–13 |
| 15 | Game-over conditions | 15 | Stories 11 and 13 |
| 16 | Production game scene | 16 | Stories 11–15 |
| 17 | Minimal gameplay UI | 17 | Story 16 |
| 18 | Final card-lab separation and cleanup | 18 | Story 16 |

The completed Graveyard and BoardHistory work is now documented as [[Story 14 Pre-Chore - Graveyard and Death Contract]]. It remains implemented before Story 11 because it was completed early and is already useful for testing lifecycle actions.

## Active Dependency Chain

```text
Story 11 — GameController and player action cycle
    ↓
Story 12 — movement and occupied-target intent
    ↓
Story 13 — combat, DEAL_DAMAGE, removal and results
    ↓
Story 14 — real stateful effects
    ↓
Story 15 — game-over decisions
    ↓
Story 16 — production scene
    ↓
Story 17 — gameplay UI
```

Story 18 completes once the production scene no longer depends on the card laboratory.

## Story Boundaries

### Story 11

Own run setup, player identity, game states, input locking, run resets, and the authoritative player action cycle. Other cards do not take turns. Do not implement movement or combat rules.

### Story 12

Own cardinal target validation, empty-slot movement, and previous-slot refill. An occupied valid target requests combat but does not calculate it.

### Story 13

Own attack resolution, `DEAL_DAMAGE`, temporary/base-health allocation, lethal removal, kill attribution, retaliation, and authoritative combat result events.

### Story 14

Consume the real Story 11–13 events. Do not retain synthetic attack, damage, or player-cycle behavior in production code.

### Story 15

Own run termination, player death, empty-deck outcome, and permanent input lock after game over.

## Remaining Count

There are eight renumbered stories remaining including the next story:

```text
Stories 11–18
```

After GameController is complete, seven remain. After combat and effects are complete, four remain: game over, production scene, UI, and lab cleanup.

## Source-of-Truth Rule

Use this amended order for scheduling. Continue using the original PDF for each story's design intent, but use the renumbered Obsidian implementation guides for current dependencies and implementation details.
