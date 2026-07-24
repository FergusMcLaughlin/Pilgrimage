# Future Story: Removed Card System

Date noted: 2026-07-22

Related: [[Story 8 Implementation Guide]] · [[Story 8.5 Action Processor Completion]]

## Why This Story Is Needed

Story 8 establishes the difference between two actions:

- `DELETE_CARD` permanently deletes a card with `queue_free()`.
- `REMOVE_CARD` clears the card from its occupied board slot without deleting the card.

The current `REMOVE_CARD` implementation is sufficient for Story 8, but it is not the complete long-term removal system.

## Future Behaviour

A later story must make removed cards work as a persistent gameplay zone:

- take the removed card out of the active board scene or active-play hierarchy;
- preserve the card or the information required to reconstruct it;
- store removed cards in a dedicated collection;
- prevent removed cards from remaining visible or interactable on the board;
- allow future effects to inspect or count removed cards;
- support returning a removed card to play;
- define how restored cards choose their destination slot;
- keep `REMOVE_CARD` distinct from permanent `DELETE_CARD` behaviour.

## Important Design Question

Decide whether the removed-card collection stores live `Card` nodes, card data/resources, card IDs, or dedicated lightweight records. That choice should be made when the revival/return effect is designed, because it determines whether cards are reparented and reused or reconstructed when returned.

## Story Boundary

Do not reopen Story 8 to build this system. Story 8 only needs to route `REMOVE_CARD` and clear the occupied board slot safely. The collection, lifecycle, and return-to-play behaviour belong to this future story.
