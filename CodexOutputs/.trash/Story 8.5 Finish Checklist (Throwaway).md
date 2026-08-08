# Story 8.5 Finish Checklist (Throwaway)

Delete this note once Story 8.5 is complete and committed.

## 1. Confirm the action meanings

- [x] `MODIFY_STATS` uses a signed delta: positive health heals and negative health deals damage.
- [x] `REMOVE_CARD` removes a card from active play without deleting its node.
- [x] `DELETE_CARD` completely deletes the card and clears any active board reference first.
- [x] Keep `REMOVE_CARD` and `DELETE_CARD` in `ActionType.VALID_TYPES`.

## 2. Finish the handlers

- [x] Call `target.modifyStat()` exactly once.
- [x] Route `REMOVE_CARD` to `BoardController.removeCard()` exactly once.
- [x] Route `DELETE_CARD` to `queue_free()` and clear an active board reference when present.
- [ ] Verify invalid remove/delete targets warn without wedging the processor.

## 3. Turn the template into the permanent test suite

- [ ] Rename/copy the template to `action_processor_test.gd` and `.tscn`.
- [ ] Fix the runner so a failed assertion cannot be counted and printed as a pass.
- [ ] Keep the per-test queue and node cleanup.

Add and pass these tests:

- [x] positive stat modification succeeds through the queue;
- [ ] negative health modification clamps health at zero without removing or freeing the card;
- [ ] two immediate actions resolve FIFO;
- [x] malformed data does not wedge the processor;
- [ ] an unsupported valid action does not block the next action;
- [ ] move clears the old slot and fills the destination;
- [ ] remove clears the occupied slot without freeing the card;
- [ ] delete clears any occupied slot and frees the card;
- [ ] reveal keeps `isProcessingAction` true until its tween finishes.

## 4. Final verification

- [ ] Run the permanent test scene headlessly.
- [ ] Confirm there are no assertion or script errors, not merely a zero process exit code.
- [ ] Run `git diff --check`.
- [ ] Review staged files for accidental Obsidian workspace state.
- [ ] Update the Story 8.5 note to say complete and runtime verified.
- [ ] Commit the finished Story 8.5 implementation.
- [ ] Delete this throwaway checklist.
