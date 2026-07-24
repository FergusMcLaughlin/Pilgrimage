# Old Effect System Comparison

Date: 2026-07-18

Related: [[Scalable Effect System Explained Simply]] · [[Action System Explained Simply]] · [[Story 8 Implementation Guide]] · [[Story 8.5 Action Processor Completion]] · [[Story 9 Effect Data Draft]]

## Simple Conclusion

The old Pilgrimage project had a working but limited effect system.

The current project has a better foundation, but it does not have a working effect system yet.

The best direction is to keep the useful ideas from the old system while using the current action queue to safely carry out effects.

## How the Old System Worked

```text
Card is created
    ↓
Read the card's first effect ID
    ↓
Find its data in effect_dictionary.json
    ↓
Create a script for that effect
    ↓
Register the effect with EffectMediator
    ↓
A card is played
    ↓
EffectMediator runs matching effects
    ↓
The effect directly changes card stats
```

For example, `solitary_beast` counted Woods cards on the board and directly changed the Goatman's attack and health.

## What Was Good

- Cards referred to effects using IDs such as `solitary_beast`.
- Effect data was kept separate from card data.
- Effects could contain triggers and parameters.
- The card did not contain the detailed effect logic.
- `EffectMediator` provided one central place for effect events.
- Base stats and current stats were separate, allowing bonuses to be recalculated.

These are useful ideas and should be kept.

## Problems in the Old System

### Effects were registered too early

Effects were registered when a card was created, not when it entered play.

This meant a card in the deck or hand could react to cards being played.

### Every listener reacted

When a card was played, the mediator received the played card but did not use it.

It ran every registered effect with the `card_played` trigger. It could not easily tell the difference between:

- when this card is played;
- when another card is played;
- when an enemy is played; or
- when a Woods card is played.

### Effects changed card values directly

`SolitaryBeast` directly changed the host card's attack and health and then refreshed its visuals.

This bypassed action ordering, validation, animations, and other effects that might react to the change.

### One new script was needed for each effect

Every new effect type needed another factory branch and usually another script.

This would create many small, similar scripts as the card collection grew.

### Some effect data was unused

The old data included timing and frequency, but the runtime system did not enforce them.

### Only the first effect was used

If a card contained several effect IDs, the old helper only loaded the first one.

### Removed cards could keep listening

Listeners were removed when their card was freed. A card that left the board but remained alive could still react.

### The effect knew too much about the scene

`SolitaryBeast` reached through `GameController` to find the board. This made the effect harder to test and tied it to one scene structure.

## What Exists in the Current Project

The current project still has:

- effect IDs stored on cards;
- `effect_dictionary.json`; and
- reusable card data loading.

However, the current card only contains an `#add effects` placeholder. Nothing loads or executes the effect definitions yet.

The slot cleanup code also contains only a future effect-cleanup placeholder.

Therefore, the current effect dictionary is data with no runtime system connected to it.

## Why the Current Foundation Is Better

The new project introduces actions:

```text
Effect decides what should happen
    ↓
Create one or more actions
    ↓
ActionQueue keeps them in order
    ↓
ActionProcessor routes them
    ↓
Card, BoardController, or Deck performs the change
```

This gives the project one reusable set of operations such as:

- deal damage;
- heal;
- modify stats;
- move a card;
- destroy a card; and
- draw or reveal a card.

Many different effects can create these same actions. The processor does not need one handler for every card ability.

## Current Warning

The current action system is not finished yet.

`ActionProcessor` refers to action handlers for reveal, move, stat modification, damage, and destruction, but those handlers are not currently implemented.

The matching public methods on `Card` and `BoardController` are also still missing.

Story 8 should therefore be completed before building the new effect system on top of it.

## Recommended New Effect Flow

```text
Gameplay event happens
    ↓
EffectSystem finds active effects interested in that event
    ↓
Check trigger, conditions, and targets
    ↓
Create actions
    ↓
ActionQueue resolves them safely in order
```

The new system should keep:

- effect IDs;
- a shared effect catalogue;
- triggers;
- parameters; and
- a central effect system.

It should replace direct effect mutations with actions.

## Solitary Beast in the New System

`Solitary Beast` is a recalculated board modifier.

Its flow should be:

```text
Board state changes
    ↓
Confirm the Goatman is active on the board
    ↓
Count Woods cards
    ↓
Calculate the correct bonus from base stats
    ↓
Request the required stat change
```

The system must recalculate the final bonus or apply only the difference from the previous bonus. It must not add the complete bonus after every board event, because that would make the stats grow repeatedly.

## Recommended Next Steps

1. Finish the Story 8 action handlers and their Card and BoardController methods.
2. Add a small `EffectData` model with validation.
3. Add one central `EffectSystem`.
4. Register effects only while their cards are active in the correct game zone.
5. Support every effect ID on a card, not only the first.
6. Make effects create actions instead of directly changing cards.
7. Rebuild `solitary_beast` as the first complete test effect.

## Final Decision

Do not copy the complete old effect implementation into the new project.

Reuse its data-driven effect IDs, triggers, parameters, and central mediation idea. Connect those ideas to the new action system so effects decide what should happen while game-state owners safely perform the change.
