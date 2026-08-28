# Amended Implementation Story Order

Date: 2026-08-16

Status: Active build order

Related: [[Original PDF Progress Audit]] · [[Story 11 GameController Implementation Guide]] · [[Story 11 Add-ons Before Movement]] · [[Story 12 Cardinal Movement Implementation Guide]] · [[Story 13 Combat and Board Refill Implementation Guide]] · [[Post Story 13 Spike - Typed Gameplay Contracts]] · [[Story 13.4 Typed Runtime Models Migration]] · [[Story 13.5 Board Shift and Edge Refill Helper]] · [[Story 14 Effects Implementation Guide]]

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
| ~~11~~ | ~~GameController and run setup~~ — **Complete** | 12 | Existing board, deck, actions, Graveyard |
| ~~12~~ | ~~Player selection and occupied cardinal targets~~ — **Complete** | 13 | Story 11 add-on gate |
| ~~13~~ | ~~Combat, damage, kills, movement, and a separate board-refill flow~~ — **Complete** | 14 | Stories 11–12 |
| 13.4 | Replace POJO-like runtime Dictionaries with typed models and organize model folders | New architecture story | Story 13 and typed-contract spike |
| 13.5 | Board-shift planning, vacancy propagation, and correct edge refill | New refinement | Story 13.4 |
| 14 | Stateful effects: SolitaryBeast, WaxingFerocity, TasteOfVictory | Revised 11 | Stories 11–13.5 |
| 15 | Game-over conditions | 15 | Stories 11 and 13 |
| 16 | Production game scene | 16 | Stories 11–15 |
| 17 | Minimal gameplay UI | 17 | Story 16 |
| 18 | Final card-lab separation and cleanup | 18 | Story 16 |

The completed Graveyard and BoardHistory work is now documented as [[Story 14 Pre-Chore - Graveyard and Death Contract]]. It remains implemented before Story 11 because it was completed early and is already useful for testing lifecycle actions.

## Active Dependency Chain

```text
Story 11 add-ons — explicit setup orientation and readiness
    ↓
Story 12 — selection and occupied cardinal-target intent
    ↓
Story 13 — combat, DEAL_DAMAGE, removal and results
    ↓
Post-Story 13 spike — audit typed gameplay contracts
    ↓
Story 13.4 — typed runtime models and model folders
    ↓
Story 13.5 — board-shift planning and edge refill
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

Before Story 12, complete [[Story 11 Add-ons Before Movement]]: explicitly place the player face-up, document initial Journey-card orientation, and verify setup is fully settled before input unlocks.

### Story 12

Own card/slot selection, occupied-card cardinal validation, invalid feedback, and combat intent. Empty targets are invalid. Do not move, shift, or replace board cards in this story.

### Story 13

Own attack resolution, `DEAL_DAMAGE`, temporary/base-health allocation, lethal removal, player movement after combat, kill attribution, retaliation, and authoritative combat result events. Also add the separate board-refill flow needed after the player vacates a slot; replacement-card data does not belong to `CombatResult`.

### Story 13.4

Replace stable runtime Dictionary contracts with typed RefCounted models. Migrate actions, action payloads, effect events, effect parameters, Graveyard stat snapshots, and BoardHistory records. Organize data-only contracts into feature-local `models/` folders while leaving behavioral RefCounted helpers in their proper feature folders.

### Story 13.5

Replace Story 13's temporary direct-slot refill with a side-effect-free board-shift planner. Existing cards close the player's vacancy along a deterministic path, the vacancy propagates to the correct outer edge, and BoardRefillController executes the plan before revealing exactly one new Journey card.

### Story 14

Consume the real Story 11–13.5 events and the final settled-board boundary. Do not retain synthetic attack, damage, refill, or player-cycle behavior in production code.

Before implementing the final Story 14 event contracts, complete [[Post Story 13 Spike - Typed Gameplay Contracts]], [[Story 13.4 Typed Runtime Models Migration]], and [[Story 13.5 Board Shift and Edge Refill Helper]].

### Story 15

Own run termination, player death, empty-deck outcome, and permanent input lock after game over.

## Remaining Count

There are seven stories remaining including the two inserted refinements:

```text
Stories 13.4, 13.5, and 14–18
```

Stories 11–13 are complete. After the model migration, refill refinement, and effects are complete, four remain: game over, production scene, UI, and lab cleanup.

## Source-of-Truth Rule

Use this amended order for scheduling. Continue using the original PDF for each story's design intent, but use the renumbered Obsidian implementation guides for current dependencies and implementation details.
