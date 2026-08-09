# Future Story: Combat Integration Effect Reassessment

Date noted: 2026-08-09

Related: [[Story 14 Effects Implementation Guide]] · [[Story 14 Pre-Chore - Graveyard and Death Contract]] · [[Action Processor Delegation Principle]] · [[Future Story - Revival Presentation and Placement]]

## Why This Story Is Needed

The stateful effects were designed before the real combat and player action cycle existed. The amended order now implements those systems first, but the planned effect contracts must still be reassessed against the finished behavior before Story 14 is implemented.

When combat is implemented, every existing effect must be reassessed against real action ordering, damage results, kills, removal, completed player cycles, and animation timing.

This is not optional cleanup. It is the integration step that prevents temporary Story 11 assumptions from becoming permanent combat architecture.

## Trigger

Perform this reassessment at the end of Story 13 and while implementing Story 14, after working versions of:

- attack declaration and resolution;
- `DEAL_DAMAGE`;
- lethal-damage detection;
- combat-caused `REMOVE_CARD`;
- attacker/defender result data;
- the player action cycle and after-move phase;
- combat animation completion.

Do it before Story 14 is considered complete.

## Existing Effects to Reassess

### Gain Health on Play

- Confirm a combat summon/revival does or does not trigger `on_play` deliberately.
- Confirm an ordinary reveal still triggers exactly once after placement.
- Decide whether revival receives `on_play`, `on_revive`, both, or neither.

### Solitary Beast

- Confirm every combat-driven board change causes one recalculation.
- Confirm movement, removal, revival, and replacement actions cannot double-apply bonuses.
- Confirm a host dying during combat does not enqueue stat changes against its freed node.
- Confirm multiple board changes in one combat sequence settle on the correct final bonus.

### Waxing Ferocity

- Replace synthetic `attack_resolved` calls with the authoritative combat result event.
- Confirm “nonlethal” means the defender remains in active play after the complete attack.
- Confirm a lethal attack does not add +1 immediately before the removal reset.
- Confirm retaliation, multi-hit attacks, misses, prevented damage, and zero-damage attacks have explicit behavior.
- Confirm any successful card removal resets the bonus exactly once.

### Taste of Victory

- Replace tagged negative `MODIFY_STATS` damage inference with the real `DEAL_DAMAGE` result.
- Consume `temporary_health_lost` from the damage result rather than requested damage.
- Confirm only a successful combat kill attributed to the host grants the buff.
- Confirm simultaneous, reflected, environmental, and effect-caused kills have explicit attribution.
- Connect duration to completed player action cycles and confirm precisely when the fourth cycle expires.
- Confirm invalid moves do not tick duration, and a zero-work after-move phase adds no extra tick beyond its one completed player cycle.
- Confirm refresh remains non-stacking: restore to +3 and restart four cycles.
- Add temporary-health feedback to combat/debug UI if it is not already visible.

## Required Combat Result Contracts

The final combat system should publish enough information for effects without requiring them to reconstruct combat from unrelated signals.

Suggested attack result:

```gdscript
{
	"type": "attack_resolved",
	"attacker": attacker,
	"defender": defender,
	"damage_requested": 5,
	"damage_dealt": 5,
	"was_kill": true,
	"removal_entry": graveyardEntry,
}
```

Suggested damage action result:

```gdscript
{
	"damage_requested": 5,
	"damage_dealt": 5,
	"temporary_health_lost": 3,
	"base_health_lost": 2,
	"remaining_health": 2,
}
```

These are provisional shapes. Story 14 may refine them, but it must preserve clear attacker, defender, damage-allocation, and kill outcomes.

## Ordering Questions to Decide

Document one authoritative sequence, including animation boundaries. At minimum decide:

```text
attack requested
→ attack modifiers collected
→ damage calculated
→ damage applied
→ damage result published
→ lethal state determined
→ removal queued/resolved
→ kill effects trigger
→ board refill queued
→ combat completes
```

Clarify whether effects may alter an attack before damage, react after damage, react after removal, or use more than one phase.

Do not allow individual effects to invent their own ordering.

## Migration Work

- Remove test-only combat event producers from production paths.
- Keep `EffectProcessor.dispatchGameplayEvent()` only if it remains the intentional boundary for CombatResolver and GameController.
- Ensure Story 14 uses `DEAL_DAMAGE` rather than the discarded temporary damage convention.
- Update effect scripts to consume authoritative result fields.
- Keep effect-local unit tests small while requiring Story 14 integration tests to use real combat.
- Update effect JSON only if trigger names or parameters genuinely change.
- Update Story 14 documentation with the final combat event contracts.

## Required Integration Tests

1. A nonlethal real attack increases Waxing Ferocity once.
2. Repeated nonlethal attacks increase it linearly.
3. A lethal attack ends with the accumulated bonus reset.
4. An unrelated card removal also resets Waxing Ferocity.
5. A real attributed kill grants Taste of Victory once.
6. Temporary health absorbs real damage before base health.
7. Damage allocation matches the displayed and stored health values.
8. Taste of Victory expires after exactly four completed player action cycles.
9. A second kill refreshes rather than stacks the buff.
10. Solitary Beast recalculates correctly across a complete attack, removal, and refill chain.
11. Removed cards leave no active effect instances.
12. Combat cannot wedge `ActionProcessor` or leave queued actions unresolved.

## Definition of Done

- [ ] Every existing effect has been reviewed against real combat and player-cycle behavior.
- [ ] Placeholder attack and damage assumptions are removed from production behavior.
- [ ] Combat and damage results expose authoritative effect context.
- [ ] Waxing Ferocity uses real attack outcomes.
- [ ] Taste of Victory uses real temporary/base-health damage allocation.
- [ ] Solitary Beast remains correct across chained board changes.
- [ ] Reveal and revival trigger policy is explicit.
- [ ] Unit tests still cover effect-local rules.
- [ ] Integration tests cover the real combat pipeline.
- [ ] Story 14 documents the final real-combat integration.
- [ ] `git diff --check` passes.
