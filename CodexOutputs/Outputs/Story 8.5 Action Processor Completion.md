# Story 8.5: Finish and Verify the Action Processor

Status: Implementation complete — 10/10 tests pass headlessly; final in-editor confirmation remains.

Related: [[Story 8 Implementation Guide]] · [[Action Processor Delegation Principle]] · [[Story 9 Effect Data Draft]]

## Goal

Finish Story 8 by protecting the complete `ActionQueue` → `ActionProcessor` → delegate flow with a permanent Godot test suite.

Do not add effects, combat, or new action types in this story.

## Existing Behaviour to Preserve

| Action | Required behaviour | Owner | Awaited? |
| --- | --- | --- | --- |
| `REVEAL_CARD` | Reveal the top journey card into a slot | `JourneyDeck.revealTopCard()` | Yes |
| `MOVE_CARD` | Move a card between board slots | `BoardController.moveCard()` | No |
| `MODIFY_STATS` | Apply a signed delta to health or attack | `Card.modifyStat()` | No |
| `REMOVE_CARD` | Clear a card from its board slot without deleting it | `BoardController.removeCard()` | No |
| `DELETE_CARD` | Clear any board reference, then free the card node | `ActionProcessor` | No |

Rules that must remain true:

- Positive health changes heal.
- Negative health changes deal damage.
- Health and attack clamp at zero.
- Reaching zero health does not automatically remove or delete a card.
- Removing a card leaves the card node alive.
- Deleting a card frees the node and never leaves a stale slot reference.
- Invalid payloads warn and return safely.
- An invalid or unsupported action never leaves the processor busy or blocks later actions.

## Work Remaining

### 1. Make the test suite permanent

- [x] Rename `tests/action_processor_test_template.gd` to `tests/action_processor_test.gd`.
- [x] Rename `tests/action_processor_test_template.tscn` to `tests/action_processor_test.tscn`.
- [x] Update the scene's script reference after the rename.
- [x] Remove wording that describes the suite as a template or example.

### 2. Keep the four existing tests passing

- [x] Positive health modification works through `ActionQueue`.
- [x] Negative health modification clamps health at zero without removing the card.
- [x] Malformed `MODIFY_STATS` data does not wedge the processor.
- [x] `DELETE_CARD` frees a card that is already outside active play.

### 3. Add the six missing tests

- [x] **FIFO:** enqueue two immediate stat changes and prove they resolve in insertion order.
- [x] **Unsupported action recovery:** enqueue a valid but unsupported action followed by a supported action; prove the second action still resolves.
- [x] **Move:** place a card in a source slot, enqueue `MOVE_CARD`, then prove the source is empty and the destination contains the card.
- [x] **Remove:** place a card, enqueue `REMOVE_CARD`, then prove the slot is empty and the card node is still valid.
- [x] **Delete from board:** place a card, enqueue `DELETE_CARD`, then prove the slot is empty and the card node is freed.
- [x] **Reveal wait:** enqueue `REVEAL_CARD` and prove `ActionProcessor.isProcessingAction` remains true until the reveal animation finishes.

All tests must exercise the public flow by enqueueing actions. Do not call private processor handlers directly.

### 4. Harden the test runner

- [x] Clear `ActionQueue` before and after every test.
- [x] Wait for `ActionProcessor` with a bounded frame timeout so failures cannot hang forever.
- [x] Clean up every node created by a test.
- [x] Ensure a failed assertion cannot be counted or printed as a passed test.
- [x] Ensure one test cannot leak board, queue, or processor state into the next test.

### 5. Runtime verification

- [ ] Run the permanent test scene in the Godot editor.
- [x] Run the permanent test scene headlessly.
- [x] Confirm all ten tests pass.
- [x] Confirm there are no assertion failures, script errors, orphan-node warnings, or stuck queued actions.
- [x] Confirm through the integration test that a revealed card is not processed as complete before its tween finishes.

### 6. Final cleanup

- [x] Run `git diff --check` and fix any whitespace errors.
- [x] Confirm no effect or combat code was introduced.
- [ ] Delete `Story 8.5 Finish Checklist (Throwaway).md` once this checklist is complete.
- [ ] Change this document's status to `Complete — runtime verified`.
- [ ] Commit the finished Story 8.5 implementation and tests.

## Definition of Done

Story 8.5 is complete only when:

- [x] All five action handlers still satisfy the behaviour table above.
- [x] The permanent suite contains all ten required tests.
- [x] All ten tests pass through the real queue-to-handler flow.
- [x] Reveal is the only handler awaited by `ActionProcessor`.
- [x] Invalid and unsupported actions cannot wedge the processor.
- [x] Remove and delete have distinct, verified lifecycle behaviour.
- [ ] The suite passes both in-editor and headlessly.
- [x] `git diff --check` passes.

## Handoff to Story 9

After every Definition of Done item is checked, Story 8 is closed. Story 9 can then implement validated effect-data loading without changing the action contract.
