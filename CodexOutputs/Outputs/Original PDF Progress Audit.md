# Original Implementation PDF Progress Audit

Date: 2026-08-08

Source of truth: `docs/Pilgrimage_2_Implementation_Stories.pdf`

## Position

The PDF contains 18 stories.

- **7 complete:** Stories 1–5, 7, and 9.
- **4 partial:** Stories 6, 8, 10, and 18.
- **7 not started:** Stories 11–17.
- **11 stories remain** when partial stories are included.

The foundation is substantially built. The project has card/slot ownership, board helpers, a board controller, ID-backed decks, queued reveals, typed effect data, an action processor, and one working scripted effect. The missing half is the playable game loop: complete action semantics, richer effect timing, game setup, movement, combat, game over, the real game scene, and UI.

## Story audit

| Story | Status | Evidence and remaining work |
|---:|---|---|
| 1. Stabilize Card Placement | Complete | `InputManager`, `CardSlot`, and `CardStateMachine` own drag, acceptance, placement, and state changes. Automated placement coverage is still light. |
| 2. Clean Board Grid API | Complete | Coordinate, empty/occupied, center, and cardinal-neighbour queries exist in `SlotGrid`. |
| 3. Add Board Controller | Complete | Placement, movement, clearing, removal, and board-change emission are centralized in `BoardController`. |
| 4. Add Deck Model | Complete | `DeckCardBag` provides the PDF's ID-backed model; drawing, shuffling, size, and empty behavior exist. The class name differs but the responsibility matches. |
| 5. Add Journey Deck | Complete | Reveal, refill, empty handling, animation, placement, and queued action integration exist. Story 10 integration tests now cover this path. |
| 6. Add Action Types | Partial | The shared action envelope and validation exist. The PDF's `DEAL_DAMAGE` and `DESTROY_CARD` contract is absent; `DELETE_CARD`/`REMOVE_CARD` partially replace destruction. Several declared actions are not implemented. |
| 7. Add Action Queue | Complete | FIFO queueing, validation, clearing, signals, and exact-action result waiting exist. No gameplay outcomes are decided here. |
| 8. Add Action Processor | Partial | Reveal, move, stat modification, removal, and deletion work and are tested. Damage is missing, destruction naming/semantics need consolidation, and most declared action types warn as unsupported. |
| 9. Add Effect Data Loading | Complete | Typed effect data, factory, JSON library, missing-ID validation, and tests exist. `EffectLibrary` replaces the PDF's proposed registry name. |
| 10. Add Effect Runtime | Partial | Runtime effect scripts are instantiated, activated on reveal, removed on leave/delete, and enqueue follow-up actions. The system exposes post-resolution and `on_play`, but not the PDF's explicit pre/post action hooks needed for kill/combat effects. |
| 11. Rebuild First Effects | Not started | The proof effect `gain_health_on_play` works, but none of the three specified effects—SolitaryBeast, HealOnKill, BuffAttackOnKill—exist. |
| 12. Add Game Controller Setup | Not started | No game controller, run state machine, player-center setup, or automatic gameplay-board initialization exists. |
| 13. Add Movement Rules | Not started | The processor can execute `MOVE_CARD`, but no player movement rules, adjacency input flow, or previous-slot refill exists. |
| 14. Add Combat Rules | Not started | No combat resolver, damage action, battle result, retaliation, or attacker/defender flow exists. |
| 15. Add Game Over Conditions | Not started | `GAME_OVER` is only a declared action name. There is no player-death handling, deck outcome, input lock transition, or reason signal/UI. |
| 16. Build Main Game Scene | Not started | `main.tscn` is empty and `project.godot` still launches the card test scene. There is no production scene composition. |
| 17. Add Minimal Game UI | Not started | Deck count visuals exist, but there is no production state, combat, or game-over UI. |
| 18. Keep Card Test Scene as a Lab | Partial | The lab exists and supports card/visual experiments, but it is currently the configured main scene and still contains noisy debug behavior. It becomes complete after Story 16 separates production gameplay. |

## Main work remaining

### 1. Finish the action contract

Complete Stories 6 and 8 before adding combat:

- Decide one destruction vocabulary: preferably one gameplay `DESTROY_CARD` action, with removal as a separate non-destructive transition only if the design needs it.
- Add `DEAL_DAMAGE` and its processor handler.
- Define required `source`, `target`, and result data for damage, destruction, and combat attribution.
- Either implement or remove currently advertised but unsupported action types until their stories begin.
- Add processor tests for damage, lethal damage policy, destruction, and action results.

### 2. Finish effect timing and rebuild the PDF effects

Complete Stories 10 and 11:

- Add explicit before/after action events, or document an equivalent event model that supports prevention, recalculation, and kill attribution.
- Ensure destroy events retain the attacker/source context needed by HealOnKill and BuffAttackOnKill.
- Implement SolitaryBeast, HealOnKill, and BuffAttackOnKill as separate effect scripts.
- Add lifecycle and end-to-end tests for board changes, kills, and listener cleanup.

### 3. Build the playable rules layer

Stories 12–15 form one dependency chain:

```text
Game setup/state
→ cardinal movement
→ combat and damage
→ death/refill
→ game-over decisions
```

Create a `GameController` that owns run state and rules while continuing to delegate mutations to actions and board operations to `BoardController`.

The empty-deck outcome must be decided before Story 15 can be completed.

### 4. Create the production scene and UI

Complete Stories 16–18 last:

- Compose `SlotGrid`, `BoardController`, `JourneyDeck`, and `GameController` in a real main scene.
- Switch `project.godot` away from the card lab only after setup is reliable.
- Add minimal state, deck, combat, and game-over feedback.
- Retain the card test scene under `src/tests`, then remove or gate noisy debug output.

## Recommended order

1. Finish Stories 6 and 8: damage/destruction action contract.
2. Finish Story 10: effect timing and action context.
3. Implement Story 11's three effects as proof of combat-ready effects.
4. Implement Stories 12 and 13: setup and movement.
5. Implement Stories 14 and 15: combat and game over.
6. Implement Stories 16–18: production scene, UI, and lab separation.

## Current verification

The current automated baseline is healthy:

- ActionProcessor: 10 tests pass.
- EffectProcessor: 10 tests pass.
- EffectLibrary: 8 tests pass.
- Story 10 integration: 4 tests pass.
- **Total: 32 tests pass.**

This confirms that the implemented foundation is stable; it does not yet validate the unbuilt gameplay loop.
