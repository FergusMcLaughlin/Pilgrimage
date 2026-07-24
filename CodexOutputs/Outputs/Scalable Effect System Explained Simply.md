# A Scalable Effect System, Explained Simply

Date: 2026-07-17

Related: [[Action System Explained Simply]] · [[Action Processor Delegation Principle]] · [[Story 8 Implementation Guide]]

## The Decision in One Sentence

Pilgrimage should have many **effect definitions**, but only a smaller set of reusable **game actions**.

The effect system decides what a card means. The action system carries out the resulting changes in a safe order.

```text
Card effect
    ↓ interprets
EffectSystem
    ↓ creates one or more
Actions
    ↓ wait in
ActionQueue
    ↓ routed by
ActionProcessor
    ↓ delegated to
Card, BoardController, Deck, or another game-state owner
```

This allows hundreds of card effects without adding hundreds of branches to `ActionProcessor`.

## Why This Separation Matters

An **action** is a basic change the game knows how to perform:

- deal damage;
- heal;
- modify a stat;
- draw, reveal, move, summon, or destroy a card; and
- apply or remove a status.

An **effect** explains why and when one or more actions should happen:

- "When played, deal 3 damage."
- "After this deals damage, heal its owner by the damage actually dealt."
- "When destroyed, draw two cards."
- "At the end of the turn, give every ally +1 attack."

There may eventually be hundreds of those effects, but they are mostly different arrangements of a much smaller vocabulary.

```text
LIFESTEAL is not a new kind of health mutation.

Lifesteal effect
    ├── requests DEAL_DAMAGE
    └── after damage resolves, requests HEAL using the actual damage dealt
```

The processor may therefore keep a readable `match` for basic actions. It does **not** need `_handleGoblinAmbush()`, `_handleHolyWell()`, or one method for every card ability.

## The Three Different Questions

Keeping these questions separate is the main defence against an incomprehensible system.

| Question | Owner | Example |
| --- | --- | --- |
| When should this ability activate? | Effect trigger | `on_play`, `after_damage`, `on_destroyed` |
| What does the ability request? | Effect definition | Deal 3 damage, then heal |
| How does the game safely perform that change? | Action processor and specialist owner | `Card.takeDamage()`, `BoardController.moveCard()` |

If a method is answering all three questions, it is probably doing too much.

## Recommended Small Design

Start with only two new permanent runtime files.

### `effect_data.gd`

This describes one effect in a consistent, inspectable shape. A first version only needs fields equivalent to:

```text
id          "lifesteal"
trigger     "after_damage"
operation   "heal"
target      "source"
amount      3, or a value taken from the triggering event
conditions  optional small dictionary
```

It should contain data and validation, not gameplay rules.

### `effect_system.gd`

This receives a gameplay event, finds interested effects, checks their conditions and targets, and creates actions.

It should initially keep common operations together in one readable file. Do not create one script per effect.

Only split targeting, conditions, or effect operations into another file after that section becomes difficult to understand on its own.

## What Existing Files Would Change

The first useful version probably requires **2 new permanent files** and changes to about **5 existing areas**:

| File or area | Change |
| --- | --- |
| `effect_data.gd` | New: understandable effect definition and validation |
| `effect_system.gd` | New: triggers, conditions, targeting, and action creation |
| `card_data.gd` | Change `effects` from IDs-only strings to parsed effect definitions, or retain IDs that resolve through one catalogue |
| `card_data_factory.gd` | Parse and validate effect data |
| `card_dictionary.json` | Store actual effect definitions or catalogue references |
| `action_processor.gd` | Publish a clear before/after result for effects to observe |
| `global_signal_bus.gd` | Add only the gameplay-event signals that have real consumers |

The exact filenames can be chosen when implementation begins. The important constraint is the responsibility split, not creating folders in advance.

Tests should use the existing test area. Temporary runtime tests do not need to become permanent files unless they remain valuable regression tests.

## A Simple Data Example

The current card JSON already lists effect IDs such as `heal_on_kill`. That is a useful starting point. The next step could make the meaning explicit:

```json
{
  "id": "heal_on_kill",
  "trigger": "after_destroy",
  "operation": "heal",
  "target": "source",
  "amount": 2
}
```

A card can then refer to that definition by ID. Shared effects are written once and reused by several cards.

For a sequence:

```json
{
  "id": "strike_and_restore",
  "trigger": "on_play",
  "steps": [
    {"operation": "deal_damage", "target": "selected_enemy", "amount": 3},
    {"operation": "heal", "target": "self", "amount": 2}
  ]
}
```

Each step creates a normal action. The queue preserves their order.

Do not attempt to support every possible field in the first version. Add vocabulary when a real card requires it.

## Where `_handleHeal()` Belongs

`ActionProcessor` may contain a small `_handleHeal(action)` method because `HEAL` is a basic action type.

Its job should be limited to:

1. read and validate the action payload;
2. identify the target card; and
3. call a focused method such as `target.heal(amount)`.

The card or stats owner should apply health limits and refresh visuals. The effect system decides when healing is requested. This keeps each method readable.

## Why Keep `HEAL` Separate From `MODIFY_STATS`?

Both eventually change health, but their game meaning can differ.

Effects may care about:

- "whenever healed";
- overhealing;
- blocked healing;
- lifesteal;
- increased healing; or
- health changes that are not healing.

Keeping `HEAL` as a distinct action makes those rules understandable. `MODIFY_STATS` remains useful for buffs, debuffs, and direct stat changes.

## Alternatives Considered

### 1. Put every effect in `ActionProcessor`

```text
match type:
    HEAL
    DEAL_DAMAGE
    HEAL_ON_KILL
    LIFESTEAL
    GOBLIN_AMBUSH
    ...
```

This starts simply but mixes card meaning with game-state mutation. The processor becomes the place where every feature meets every other feature. It is not recommended.

### 2. Create one script class per effect

This gives strong separation and can support completely unique behaviour. It also produces a large number of tiny files, makes similar effects harder to compare, and increases navigation cost for a solo developer.

Do not use it as the default. Reserve a custom script for the rare effect that genuinely cannot be expressed using triggers, targets, conditions, and action steps.

### 3. Call methods whose names come directly from JSON

This appears flexible, but spelling errors become runtime failures and it becomes difficult to discover what the game can do. It is also harder to validate and debug.

Use known operation IDs and an explicit registry or `match` instead.

### 4. Build a fully generic rules language now

A powerful language could express almost anything, but it would mean building and debugging a second programming language before the card set proves which features are needed.

Do not start there. Grow a small effect vocabulary from real cards.

### Recommended compromise

Use data for common effects, a small explicit interpreter in `EffectSystem`, and an escape hatch for rare custom effects later. This provides scale without hiding behaviour behind too much abstraction.

## Suggested Implementation Stories

This is best delivered in approximately **five small stories after Story 8**. Each story should finish with one real effect working end to end.

### Story 9: Effect data and one `on_play` effect

- Define the smallest effect shape.
- Parse it from card data.
- Implement one effect such as "on play, heal 2."
- Add `effect_data.gd` and update the existing loaders/data.

### Story 10: Gameplay events and the effect system

- Add `effect_system.gd`.
- Publish clear action results after resolution.
- Let effects listen for a small trigger set such as `on_play` and `after_damage`.
- Prove that unsupported or malformed effects warn safely.

### Story 11: Targeting and conditions

- Add only targets required by actual cards: self, action source, action target, selected enemy, or all allies.
- Add a few explicit conditions such as damaged, card type, or health threshold.
- Keep this code in `effect_system.gd` unless it has become harder to understand there.

### Story 12: Chained effects and result values

- Support ordered effect steps.
- Allow a later step to use a prior result, such as actual damage dealt.
- Add a recursion/depth guard so two reacting effects cannot loop forever.
- Verify lifesteal or a similarly chained effect.

### Story 13: Durations and statuses, only if the card set needs them

- Add temporary and persistent effects.
- Define when they expire.
- Add `APPLY_STATUS` and `REMOVE_STATUS` only when their concrete behaviour is known.

This is an estimate, not a demand to build all five stories immediately. Story 13 can wait until a real card needs persistent state.

## When Another File Is Justified

Add a file when it gives a concept a clear name and lets that concept be understood separately.

A split is justified when:

- targeting has several rules and can be read independently;
- condition checking has become a distinct reusable responsibility;
- persistent statuses need their own lifetime and state; or
- a rare custom effect is too unusual for the common vocabulary.

A split is **not** justified merely because every effect could technically be a class.

The likely growth path is:

```text
Initial effect system:       2 new files
After proven complexity:     perhaps 3–4 focused files
One file per card/effect:     avoid
```

## Rules That Keep It Understandable

1. Build effect vocabulary from real cards, not imagined future possibilities.
2. Prefer visible `match` statements and named fields over clever dynamic calls.
3. Keep basic mutations in `Card`, `BoardController`, and `Deck`.
4. Keep action ordering in `ActionQueue` and `ActionProcessor`.
5. Keep triggers, conditions, targets, and sequences in the effect system.
6. Log the effect ID and the actions it creates.
7. Give every action chain a depth or repetition limit.
8. Split a file only when the new boundary makes the system easier to explain.

## Final Mental Model

```text
EFFECT = why, when, and which requests
ACTION = one requested game change
QUEUE = the order of changes
PROCESSOR = routes each change
CARD / BOARD / DECK = safely performs its own change
```

Pilgrimage can support a large effect catalogue without a giant processor or hundreds of scripts. The smallest understandable route is two new effect-system files, about five incremental stories, and data-driven combinations of a stable set of actions. More files should be earned by demonstrated complexity rather than created in anticipation of it.
