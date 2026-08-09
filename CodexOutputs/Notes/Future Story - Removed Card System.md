# Future Story: Removed Card System

Date noted: 2026-07-22

Status: Promoted to [[Story 14 Pre-Chore - Graveyard and Death Contract]]

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

## Design Decision

The promoted story resolves the open storage question: use lightweight graveyard records plus an append-only lifecycle history. Do not retain hidden live `Card` nodes. Revival reconstructs a card through `CreateCard` while preserving its logical gameplay identity.

## Story Boundary

Do not reopen Story 8 to build this system. Story 8 only needed to route `REMOVE_CARD` and clear the occupied board slot safely. Implement the collection, lifecycle, history, and return-to-play behavior in [[Story 14 Pre-Chore - Graveyard and Death Contract]].
