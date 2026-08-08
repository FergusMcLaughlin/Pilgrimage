ren# Story 10 Action Integration Review

Date: 2026-08-08

## Finding

Story 10's action and effect systems are compatible and their current unit tests pass. The integration is incomplete at the deck boundary.

`JourneyDeck` still uses its older private click queue to call `revealTopCard()` directly. Story 10.5 correctly moves that request through `ActionQueue`, but it does not define how the deck waits for its own action to finish. Its proposed edit is therefore incomplete rather than architecturally different.

The required ownership is:

```text
JourneyDeck chooses and requests a reveal
→ ActionQueue orders it
→ ActionProcessor calls JourneyDeck.revealTopCard()
→ actionResolved publishes the placed card
→ EffectProcessor activates on_play effects
→ effects enqueue further actions
```

## Current gaps

1. `ActionQueue` has no reusable way to wait for one specific action's result.
2. Deck clicks bypass `ActionQueue` through `revealToNextEmptySlot()`.
3. `fillEmptySlots()` also bypasses the action pipeline, so cards filled this way cannot trigger `on_play`.
4. Story 10 effect tests synthesize `actionResolved`; they do not prove the full deck-to-effect flow.
5. The Story 10.5 manual-scene changes have not been completed.
6. Story 10.5 documents enqueueing but omits the completion-wait implementation and the other direct reveal path.

## Required scope

Use one shared action-completion helper in `ActionQueue`; do not add a one-off global-signal loop to every gameplay class. Match the exact action dictionary by identity and return its resolved result.

Keep `JourneyDeck.revealTopCard()` as the low-level operation used only by `ActionProcessor`. Route click reveals and gameplay board filling through queued `REVEAL_CARD` actions. Preserve the deck's pending-click loop so rapid clicks select a slot only after the preceding reveal completes.

Add one end-to-end test that uses a real `JourneyDeck`, board, queue, processor, and Goatman effect. Existing unit tests should remain focused on their individual systems.

## File and change count

Total: **8 files, 18 bounded changes**. Of these, **2 production files contain 4 functional changes**; the remainder are tests, manual-test support, and documentation.

| File | Changes | Required work |
|---|---:|---|
| `src/main/singletons/actions/action_queue.gd` | 1 | Add a filtered `waitForActionToResolve(action)` API returning that action's result. |
| `src/main/decks/deck_types/journey_deck.gd` | 3 | Queue click reveals; await each result before the next pending click; route `fillEmptySlots()` through the same action path and remove/redefine the direct public helper. |
| `src/tests/card_test_scene.gd` | 3 | Disable stat cycling by default; use Goatman `M_0002`; print resolved `MODIFY_STATS` feedback. |
| `src/tests/card_test_scene.tscn` | 1 | Rename the loose-card button to `Add Goatman (No Reveal)`. |
| `tests/story_10_integration_test.gd` | 4 | Add real reveal/effect coverage, result-order coverage, rapid-request slot safety, and board-fill effect coverage. |
| `tests/story_10_integration_test.tscn` | 1 | Add the headless test scene. |
| `CodexOutputs/Outputs/Story 10 Implementation Guide.md` | 2 | Record the integration boundary and add the end-to-end suite to completion criteria. |
| `CodexOutputs/Outputs/Story 10.5 Manual Test Scene Update.md` | 3 | Specify the shared wait API, include board-fill policy, and replace the incomplete Step 1/checklist. |

## Explicitly outside this change

No functional changes are needed in `ActionProcessor`, `EffectProcessor`, `GlobalSignalBus`, `ActionType`, `Card`, `BoardController`, or the effect handler. Their current responsibilities already support the intended flow.

Unimplemented action types such as `DRAW_CARD`, `REVIVE_CARD`, `HIDE_CARD`, `MUTATE_CARD`, and `GAME_OVER` remain future stories and should not be folded into Story 10.5.

## Verification

Current baseline:

- ActionProcessor: 10 tests pass.
- EffectProcessor: 10 tests pass.
- EffectLibrary: 8 tests pass.

Completion requires those suites plus the new end-to-end suite and a manual deck-click check confirming Goatman moves from 3 to 5 health.
