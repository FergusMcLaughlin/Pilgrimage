# Story 13.5: Board Shift and Edge Refill Helper

Date: 2026-08-24

Status: Planned

Related: [[Story 13 Combat and Board Refill Implementation Guide]] · [[Post Story 13 Spike - Typed Gameplay Contracts]] · [[Amended Implementation Story Order]] · [[Story 14 Effects Implementation Guide]]

## Goal

Replace Story 13's temporary rule—reveal directly into the slot vacated by the player—with the real board-refill rule.

After the player moves, existing cards shift to close the vacancy. The vacancy propagates to an outer edge, where exactly one new Journey card is revealed.

A small deterministic BoardRefillPlanner calculates the transformation without mutating the board. BoardRefillController executes that plan through the action system.

## Core Pattern

Refill is vacancy propagation:

1. Start with the slot vacated by the player.
2. Determine the ordered path of existing cards that must move into it.
3. Move each card one step along that path.
4. The final source slot becomes the new vacancy.
5. That vacancy must be on the correct board ingress edge.
6. Reveal exactly one Journey card into it.

The new card does not necessarily enter the slot the player left.

## Authoritative Golden Sequence

These four moves are acceptance fixtures, not optional examples.

### 1. Player moves right

- The player finishes in the right slot of the row.
- Cards in that row shift right toward the old player slot.
- The vacancy propagates to the far-left slot.
- Reveal one card into that far-left slot.

    Before refill: [card] [empty] [player]
    After shifting: [empty] [card] [player]
    After reveal: [new] [card] [player]

### 2. Player moves down

- The player finishes at the bottom of the column.
- The card at the top moves down into the empty middle slot.
- The vacancy propagates to the top slot.
- Reveal one card into the top slot.

    Before refill: [card]  After reveal: [new]
                   [empty]               [card]
                   [player]              [player]

### 3. Player moves back up

- The player finishes in the middle-right slot.
- The previous bottom-right slot is empty.
- The bottom row shifts right to close it.
- The vacancy propagates to bottom-left.
- Reveal one card into bottom-left.

    Before refill: [card] [card] [empty]
    After shifting: [empty] [card] [card]
    After reveal: [new] [card] [card]

### 4. Player moves left into the centre

- The player's previous middle-right slot is empty.
- The top-right card moves down into it.
- The vacancy propagates to the top-right corner.
- Reveal one card into top-right.

    Before: top-right = card, middle-right = empty
    Shift: top-right = empty, middle-right = previous top-right card
    Refill: top-right = new card

## New Typed Planning Objects

Suggested files:

    src/main/board/board_refill/board_refill_planner.gd
    src/main/board/board_refill/board_shift_plan.gd
    src/main/board/board_refill/board_shift_step.gd

BoardShiftStep represents one existing-card movement:

    class_name BoardShiftStep
    extends RefCounted

    var card: Card
    var fromSlot: CardSlot
    var toSlot: CardSlot

BoardShiftPlan represents the complete decision:

    class_name BoardShiftPlan
    extends RefCounted

    var succeeded := false
    var failureReason := ""
    var vacatedPlayerSlot: CardSlot
    var playerDestinationSlot: CardSlot
    var movementDirection: Vector2i
    var steps: Array[BoardShiftStep] = []
    var refillSlot: CardSlot
    var cycleNumber := 0

The plan describes what should happen. It does not move cards, reveal cards, emit signals, or change game state.

## Planner Responsibility

BoardRefillPlanner receives:

- the current SlotGrid;
- the slot vacated by the player;
- the player's destination slot;
- the movement direction;
- the current cycle number.

It must:

- reproduce all four golden scenarios;
- return shift steps in execution order;
- make every step move a specific card into the current vacancy;
- propagate one vacancy through consecutive steps;
- choose exactly one final edge refill slot;
- reject stale, occupied, disconnected, diagonal, or impossible plans;
- make no board mutations;
- enqueue no actions and emit no signals.

Keep route selection in this planner. Do not split it between PlayerMovementController, CombatResolver, GameController, and BoardRefillController.

## Request Contract

Extend BoardRefillRequest with enough information to plan and validate the real shift:

    var vacatedPlayerSlot: CardSlot
    var playerDestinationSlot: CardSlot
    var movementDirection: Vector2i
    var cycleNumber: int
    var cause: String

Do not infer direction later from mutable card positions. CombatContext already contains the original and target slots, so GameController can construct the request after successful combat movement.

## Execution Through Actions

BoardRefillController owns execution:

1. Ask BoardRefillPlanner for a plan.
2. Emit one typed failure if planning fails.
3. Enqueue each MOVE_CARD step in order.
4. Await and validate every movement result.
5. Stop with one failed BoardRefillResult if a movement fails.
6. Enqueue exactly one REVEAL_CARD for the plan's refill slot.
7. Await the reveal.
8. Emit exactly one boardRefillCompleted.

The planner must never call BoardController.moveCard directly.

## Validation and Failure

Before execution, validate the complete plan:

- the player occupies the expected destination;
- the original player slot is empty;
- every planned source contains the expected card;
- every destination follows the propagated vacancy;
- no step targets or moves the player;
- the predicted final refill slot is empty;
- the request cycle is still current.

Planning is side-effect free. A planning failure changes nothing.

If runtime state changes during execution, report a typed failure. Do not silently mark a partially executed plan successful. GameController must still settle the cycle after boardRefillCompleted so input cannot remain permanently locked.

## Empty Journey Deck

Required existing-card shifts still happen when the deck is empty.

After shifting:

- BoardRefillResult succeeds with skipped = true;
- the final edge slot remains empty;
- the completed plan and final vacancy remain inspectable;
- Story 15 decides whether the empty deck ends the run.

## Result Contract

Extend BoardRefillResult:

    var request: BoardRefillRequest
    var plan: BoardShiftPlan
    var completedSteps: Array[BoardShiftStep] = []
    var revealedCard: Card
    var succeeded := false
    var skipped := false
    var failureReason := ""

Shift and replacement information remains outside CombatResult.

## Automated Planner Tests

Add tests/board_refill_planner_test.gd and its scene, covering:

1. Planning does not mutate the board.
2. Moving right shifts the row right and selects the far-left refill slot.
3. Moving down shifts the column down and selects the top refill slot.
4. Moving back up shifts the bottom row right and selects bottom-left.
5. Moving left into the centre shifts top-right down and selects top-right.
6. Every step's destination is the currently propagated vacancy.
7. The predicted final refill slot is empty.
8. A plan never moves the player.
9. Null slots and non-cardinal movement are rejected.
10. Stale slot/card relationships are rejected.
11. Impossible or disconnected routes return typed failures.
12. Identical state and input produce identical plans.

## Automated Execution Tests

Expand the board-refill integration tests:

1. Each golden scenario executes its plan in order.
2. Every shift uses MOVE_CARD.
3. Exactly one REVEAL_CARD follows successful shifts.
4. No reveal is queued before movement completion.
5. Only planned cards and slots change.
6. The player remains in the combat destination.
7. Exactly one BoardRefillResult is emitted.
8. The result contains the plan and completed steps.
9. Rejected or failed movement produces one failed result and no reveal.
10. Empty-deck execution shifts existing cards, leaves the edge vacancy open, and succeeds as skipped.
11. GameController waits for the whole shift-and-reveal sequence.
12. The cycle returns to PLAYER_READY with input unlocked and an idle action system.
13. Existing Story 13 combat, damage, Graveyard, and movement tests still pass.

## Manual Test

Add CombatResolver, BoardRefillPlanner, and BoardRefillController to the card test scene. Reproduce:

    right → down → up → left

After each move, verify:

- the player remains in the destination;
- existing cards shift into the propagated vacancy;
- exactly one new card enters at the expected outer edge;
- input unlocks only after shifting and revealing finish;
- no script errors occur.

## Keep Out Of Story 13.5

- New combat rules
- Diagonal player movement
- Larger or non-rectangular boards
- Random route selection
- Effects that alter refill direction
- Game-over decisions
- Production-scene architecture
- Final animation polish

## Definition Of Done

- [ ] BoardRefillPlanner exists and is side-effect free.
- [ ] Typed BoardShiftPlan and BoardShiftStep objects exist.
- [ ] BoardRefillRequest contains the required movement information.
- [ ] All four golden scenarios produce the specified transformations.
- [ ] Existing cards shift through ordered MOVE_CARD actions.
- [ ] Exactly one final edge vacancy is selected.
- [ ] Exactly one Journey card is revealed after successful shifts.
- [ ] Empty-deck behavior leaves only the final edge vacancy open.
- [ ] BoardRefillResult reports the plan, completed shifts, reveal, and failure.
- [ ] Failed planning or execution emits exactly one typed result.
- [ ] GameController waits for the complete refill operation.
- [ ] Planner and integration tests pass.
- [ ] The golden manual sequence passes.
- [ ] Existing tests pass.

## Handoff To Story 14

Story 14 effects may observe the final settled board only after boardRefillCompleted. Intermediate shift steps are not separate player moves or player cycles.
