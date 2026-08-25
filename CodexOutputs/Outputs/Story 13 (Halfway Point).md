# Story 13 (Halfway Point)

Date: 2026-08-22

Related: [[Story 13 Combat and Board Refill Implementation Guide]]

## Remaining Work

### 1. Correct The Existing Combat Implementation

- [x] In `combat_resolver.gd`, change `result.succeded = true` to `result.succeeded = true`.
- [x] Rename `combatEnded` and `emitCombatEnded()` to the Story 13 contract names `combatCompleted` and `emitCombatCompleted()`.
- [x] Update every connection and caller to use the renamed combat-completion signal.
- [x] In `ActionProcessor._handleRemoveCard()`, pass `action.data.source_instance_id` into `Graveyard.buryCard()`.
- [ ] ==Confirm mutual death records both stable killer instance IDs even after either card has been queued for deletion.==
- [ ] ==Make every accepted combat exit through exactly one typed `CombatResult`, including failures.==
- [ ] ==Ensure a failed combat cannot leave the game in `COMBAT` with input permanently locked.==

### 2. Add The Separate Board-Refill Contracts

- [ ] Create `src/main/board/refill/board_refill_request.gd`.
- [ ] Add the requested `CardSlot`, cycle number, and cause to `BoardRefillRequest`.
- [ ] Create `src/main/board/refill/board_refill_result.gd`.
- [ ] Add success, skipped, failure reason, original request, and revealed card fields to `BoardRefillResult`.
- [ ] Keep all Journey Deck and replacement-card fields out of `CombatResult`.

### 3. Implement `BoardRefillController`

- [ ] Create `src/main/board/refill/board_refill_controller.gd`.
- [ ] Add `boardRefillRequested(request: BoardRefillRequest)` to `GlobalSignalBus`.
- [ ] Add `boardRefillCompleted(result: BoardRefillResult)` to `GlobalSignalBus`.
- [ ] Add typed wrapper methods for both signals.
- [ ] Make the controller receive one specific vacated slot.
- [ ] Reject a null or occupied requested slot with a failed typed result.
- [ ] If the Journey Deck is empty, return a successful skipped result and leave the slot empty.
- [ ] Otherwise enqueue one `REVEAL_CARD` action for the requested slot and await its result.
- [ ] Emit exactly one typed `BoardRefillResult` on every exit path.
- [ ] Do not call `fillEmptySlots()` during combat maintenance.

### 4. Connect Combat And Refill Through `GameController`

- [ ] Connect `GameController` to `combatCompleted` and `boardRefillCompleted`.
- [ ] When combat succeeds and the player moved, request a refill for `result.context.playerSlot` only.
- [ ] When combat finishes without movement, skip refill and continue the player action.
- [ ] When combat fails, skip refill and safely continue out of the locked combat state.
- [ ] Wait for any requested refill to complete before starting `AFTER_MOVE`.
- [ ] Wait for the action system to settle before completing the player cycle.
- [ ] Confirm input unlocks only when the next `PLAYER_READY` cycle begins.
- [ ] Do not add Story 15 game-over decisions to Story 13.

### 5. Wire The Manual Test Scene

- [ ] Add a scene-owned `CombatResolver` node to `src/tests/card_test_scene.tscn`.
- [ ] Add a scene-owned `BoardRefillController` node.
- [ ] Assign the GameController, BoardController, SlotGrid, and JourneyDeck references.
- [ ] Connect the typed combat-completion and refill-completion signals.
- [ ] Display damage dealt, retaliation damage, defeat state, movement, and failure feedback.
- [ ] Display whether the previous slot was refilled, skipped because the deck was empty, or failed.
- [ ] Manually confirm that clicking an occupied cardinal neighbour completes the entire action cycle.

### 6. Add Story 13 Automated Tests

- [ ] Create `tests/damage_action_test.gd` and `tests/damage_action_test.tscn`.
- [ ] Test zero damage, temporary-health absorption, overflow into base health, lethal equality, overkill, invalid amounts, and typed attribution.
- [ ] Create `tests/combat_resolver_test.gd` and `tests/combat_resolver_test.tscn`.
- [ ] Test attack snapshots, mandatory retaliation, both-survive combat, defender death, player death, mutual death, removal attribution, movement after a clean victory, and failure recovery.
- [ ] Create `tests/board_refill_controller_test.gd` and `tests/board_refill_controller_test.tscn`.
- [ ] Test exact-slot refill, occupied-slot rejection, empty-deck skipping, reveal failure, and no changes to unrelated empty slots.
- [ ] Add or extend GameController coverage for the complete combat → refill → `AFTER_MOVE` → `PLAYER_READY` sequence.

### 7. Final Verification

- [ ] Run the Godot project parser/import check.
- [ ] Run all existing automated test scenes.
- [ ] Run all new Story 13 automated test scenes.
- [ ] Confirm `combatCompleted` emits exactly once per accepted combat.
- [ ] Confirm `boardRefillCompleted` emits exactly once per refill request.
- [ ] Confirm combat never refills unrelated empty slots.
- [ ] Remove trailing whitespace from `card.gd` and `action_processor.gd`.
- [ ] Run `git diff --check` and confirm it passes.
- [ ] Perform the manual test-scene combat flow once with a populated deck and once with an empty deck.

