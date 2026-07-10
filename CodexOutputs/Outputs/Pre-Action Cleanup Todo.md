# Pre-Action Cleanup Todo

Date: 2026-07-10

The pre-action cleanup list is complete enough to start Story 6: Action Types.

Completed or intentionally accepted decisions:

- SlotGrid missing-scene safety is done.
- SlotGrid bounds cleanup is done.
- BoardController export naming is done.
- BoardController movement restore safety is done.
- The `gridSize` row/column label is intentionally skipped because the current code is clear enough.
- InputManager direct placement is intentionally allowed for lab/debug testing. Real gameplay movement should go through the action system later.
- The `CardSlot.clearSlot()` placeholder is intentionally staying for now.
- Deck architecture is intentional as-is: `DeckCardBag` owns card ids, `Deck` owns generic deck scene behavior, and `JourneyDeck` owns journey-specific reveal/refill behavior.

---

## Definition Of Ready For Story 6

- [x] `SlotGrid` fails safely if misconfigured.
- [x] `getSlotAt()` is simple and readable.
- [x] `BoardController` naming is clean.
- [x] Debug/lab placement policy is decided.
- [x] `BoardController.moveCard()` cannot accidentally lose a card on failed placement.
- [x] Deck architecture is intentional.
- [x] Placeholder effect cleanup is intentionally kept for now.
- [x] `git diff --check` passes.

Start:

```text
Story 6: Add Action Types
```
