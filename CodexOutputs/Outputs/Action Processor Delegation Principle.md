# Action Processor Delegation Principle

Date: 2026-07-13

Related: [[Action System Explained Simply]] · [[Story 6 Implementation Guide]]

## Principle

The `ActionProcessor` should **coordinate an action's resolution**, but it should delegate the actual specialist work to the class or system that owns that responsibility.

> The processor decides which door to use; the system behind that door does the actual work.

The processor is an orchestrator and router. It must not gradually become the owner of board rules, combat calculations, card stats, deck behaviour, and game-flow logic.

## Example: Moving a Card

The processor handles the `MOVE_CARD` action, but `BoardController` performs the safe board operation:

```text
MOVE_CARD action
      ↓
ActionProcessor recognises the action
      ↓
ActionProcessor calls BoardController.moveCard()
      ↓
BoardController validates and performs the move
      ↓
CardSlot manages its individual slot state
```

```gdscript
func _handleMoveCard(action: Dictionary) -> void:
	var card: Card = action["source"]
	var destinationSlot: CardSlot = action["target"]

	if !boardController.moveCard(card, destinationSlot):
		push_warning("ActionProcessor: MOVE_CARD failed.")
```

## Example: Dealing Damage

The processor handles the `DEAL_DAMAGE` action, but a contained combat or stats class should own the damage calculation and health mutation:

```text
DEAL_DAMAGE action
      ↓
ActionProcessor recognises the action
      ↓
ActionProcessor calls the combat/stats owner
      ↓
Combat rules calculate the result
      ↓
The target's health changes
```

A simple temporary implementation may live in the processor before the specialist class exists. Once combat grows beyond a trivial calculation, move it behind a focused combat API rather than expanding the processor indefinitely.

## Delegation Map

| Action | Specialist owner the processor should call |
| --- | --- |
| `MOVE_CARD` | `BoardController` |
| `REVEAL_CARD` | Journey deck/card factory plus `BoardController` |
| `DEAL_DAMAGE` | Combat system or card stats component |
| `MODIFY_STATS` | Card stats/data owner |
| `DESTROY_CARD` | Board controller plus card lifecycle owner |
| `DRAW_CARD` | Deck |
| `GAME_OVER` | Game/run controller |

## Boundary Check

When adding an action handler, ask:

1. Is this code merely validating the action and choosing the correct operation? Keep it in `ActionProcessor`.
2. Is this code implementing board, combat, stats, deck, or game-flow rules? Put it in the class that owns that domain and call it from the processor.
3. Could this operation be useful without the action system? If yes, it probably deserves a public method on its specialist owner.
4. Is the processor accumulating detailed rules for several unrelated domains? If yes, split those rules into contained specialist classes.

## Desired Shape

```text
                   ┌─► BoardController
                   ├─► Combat/Stats
ActionProcessor ───├─► Deck/JourneyDeck
                   ├─► Card lifecycle
                   └─► Game/Run controller
```

The action system controls **when and in what order** gameplay requests resolve. Specialist classes control **how their particular operations work**.
