# Story 13: Resolve Combat, Move The Player, And Refill The Previous Slot

Date: 2026-08-16

Status: In progress

Related: [[Story 12 Cardinal Movement Implementation Guide]] · [[Amended Implementation Story Order]] · [[Action Processor Delegation Principle]] · [[Story 14 Pre-Chore - Graveyard and Death Contract]] · [[Post Story 13 Spike - Typed Gameplay Contracts]] · [[Future Story - Combat Integration Effect Reassessment]]

## Goal

Turn Story 12's combat request into one complete, ordered player action:

```text
playerCombatRequested
→ create a typed CombatContext
→ apply both snapshotted attacks through DEAL_DAMAGE
→ receive two typed DamageResult objects
→ remove defeated cards through REMOVE_CARD
→ move a surviving player after a victory
→ emit one typed CombatResult
→ GameController requests separate board maintenance
→ BoardRefillController resolves the vacated slot
→ emit one typed BoardRefillResult
→ settle AFTER_MOVE
→ complete the player cycle
```

Story 13 owns combat resolution and combat-caused board changes. Story 15 will own the decision to enter `GAME_OVER` after player death.

## Current Progress

Already started:

- [x] `ActionType.DEAL_DAMAGE` exists and is in `VALID_TYPES`.
- [x] `Card.temporaryHealth` exists.
- [x] Card visuals display temporary health.
- [x] `Card.applyDamage()` has been started.
- [x] `src/main/combat/combat_resolver.gd` exists as a placeholder.

Still required:

- [ ] Correct the temporary-health calculation in `Card.applyDamage()`.
- [ ] Return a typed `DamageResult` instead of a `Dictionary`.
- [ ] Add `CombatContext` and `CombatResult`.
- [ ] Route `DEAL_DAMAGE` through `ActionProcessor`.
- [ ] Implement `CombatResolver`.
- [ ] Add combat signals, removal attribution, movement, separate board-refill flow, UI feedback, and tests.

## Important Correction To Current Code

The current implementation contains:

```gdscript
var temporaryLost = mini(health, amount)
temporaryHealth -= temporaryLost

var baseLost = mini(health, amount)
health -= baseLost
```

This is incorrect for two reasons:

1. `temporaryLost` must be limited by `temporaryHealth`, not base `health`.
2. Temporary damage must be subtracted from the remaining damage before base health is changed.

For example, five incoming damage against three temporary health should remove three temporary health and two base health—not five from both pools.

The corrected typed implementation is provided below.

## Confirmed Combat Rules

### Every player action targets a card

Story 12 only permits occupied cardinal neighbours. The player never selects or moves into an empty slot.

### Damage is simultaneous

Both attack values are captured before either hit resolves:

```text
damage to defender = player attack at combat start
damage to player   = defender attack at combat start
```

The defender retaliates even when the player's damage is lethal. Zero attack deals zero damage safely.

### Temporary health is consumed first

```text
incoming damage
→ temporary health
→ remaining damage reaches base health
```

### Zero health is lethal

```gdscript
card.health <= 0
```

Attack equal to remaining health therefore defeats the card.

### Player movement requires a clean victory

The player moves only when:

```text
defender was removed
and
player survived
```

If both survive, neither moves. If both are defeated, the player does not move.

### Only the previous player slot is refilled

The legacy rule is:

```text
player defeats target
→ player moves into target slot
→ reveal one Journey card into the slot the player left
```

Do not call `fillEmptySlots()` after combat. Other empty slots must remain unchanged.

If the Journey Deck is empty, movement still succeeds and the previous slot remains empty. Story 15 later decides what deck exhaustion means.

## Why Use Typed Combat Objects

Generic actions remain dictionaries because every action shares the same queue contract:

```gdscript
{
	"type": ActionType.DEAL_DAMAGE,
	"source": attacker,
	"target": defender,
	"data": {"amount": 4},
}
```

Combat state and results are domain-specific and larger. They should be typed objects so consumers receive autocomplete, parser checks, stable fields, and one documented contract.

Use focused `RefCounted` contracts separated by domain:

```text
CombatContext  = immutable snapshot of the declared fight
DamageResult   = result of one DEAL_DAMAGE action
CombatResult   = final result after damage, removal, and combat-caused movement
BoardRefillRequest = request to maintain one vacated slot
BoardRefillResult  = result of the independent board-maintenance flow
```

Do not create one oversized object that calculates damage, mutates the board, refills slots, emits signals, and controls game state. `CombatResolver` owns combat only. `BoardRefillController` owns replacement-card decisions, and `GameController` coordinates the player-cycle boundary between them.

## Files

Create:

```text
src/main/combat/combat_context.gd
src/main/combat/damage_result.gd
src/main/combat/combat_result.gd
src/main/board/refill/board_refill_request.gd
src/main/board/refill/board_refill_result.gd
src/main/board/refill/board_refill_controller.gd
tests/damage_action_test.gd
tests/damage_action_test.tscn
tests/combat_resolver_test.gd
tests/combat_resolver_test.tscn
tests/board_refill_controller_test.gd
tests/board_refill_controller_test.tscn
```

Complete:

```text
src/main/combat/combat_resolver.gd
```

Update:

```text
src/main/cards/card.gd
src/main/cards/card_visuals.gd
src/main/singletons/actions/action_processor.gd
src/main/singletons/global_signal_bus.gd
src/main/singletons/graveyard/graveyard.gd
src/tests/card_test_scene.gd
src/tests/card_test_scene.tscn
```

`src/main/singletons/actions/action_object.gd` already contains `DEAL_DAMAGE` and does not need further Story 13 changes unless validation is deliberately strengthened.

## Step 1: Create `CombatContext`

Create `src/main/combat/combat_context.gd`:

```gdscript
class_name CombatContext
extends RefCounted

var cycleNumber: int
var attacker: Card
var defender: Card
var playerSlot: CardSlot
var targetSlot: CardSlot

var attackerInstanceId: int
var attackerCardId: String
var defenderInstanceId: int
var defenderCardId: String

var attackerDamage: int
var retaliationDamage: int


static func create(
	cycle: int,
	player: Card,
	target: Card,
	fromSlot: CardSlot,
	toSlot: CardSlot,
) -> CombatContext:
	var context := CombatContext.new()
	context.cycleNumber = cycle
	context.attacker = player
	context.defender = target
	context.playerSlot = fromSlot
	context.targetSlot = toSlot
	context.attackerInstanceId = player.instanceId
	context.attackerCardId = player.data.id
	context.defenderInstanceId = target.instanceId
	context.defenderCardId = target.data.id
	context.attackerDamage = maxi(player.attack, 0)
	context.retaliationDamage = maxi(target.attack, 0)
	return context
```

Create the context immediately after validating the Story 12 request. Never recalculate its attack values later in the combat.

The live card references are convenient while combat is resolving. Stable instance and definition IDs remain usable after a defeated card is freed.

## Step 2: Create `DamageResult`

Create `src/main/combat/damage_result.gd`:

```gdscript
class_name DamageResult
extends RefCounted

var succeeded := false
var failureReason := ""

var source: Card
var target: Card
var sourceInstanceId := 0
var sourceCardId := ""
var targetInstanceId := 0
var targetCardId := ""

var cause := ""
var cycleNumber := 0
var damageRequested := 0
var damageDealt := 0
var temporaryHealthLost := 0
var baseHealthLost := 0
var remainingTemporaryHealth := 0
var remainingHealth := 0
var wasLethal := false


static func rejected(reason: String) -> DamageResult:
	var result := DamageResult.new()
	result.failureReason = reason
	return result
```

`succeeded` distinguishes a valid zero-damage hit from a rejected damage action:

```text
valid zero damage → succeeded = true, damageDealt = 0
invalid action    → succeeded = false, failureReason is populated
```

Do not use an empty dictionary or `null` for both cases.

## Step 3: Correct `Card.applyDamage()`

Change its return type from `Dictionary` to `DamageResult`:

```gdscript
func applyDamage(amount: int) -> DamageResult:
	if amount < 0:
		return DamageResult.rejected("damage cannot be negative")

	var result := DamageResult.new()
	result.succeeded = true
	result.target = self
	result.targetInstanceId = instanceId
	result.targetCardId = data.id
	result.damageRequested = amount

	result.temporaryHealthLost = mini(temporaryHealth, amount)
	temporaryHealth -= result.temporaryHealthLost
	var remainingDamage := amount - result.temporaryHealthLost

	result.baseHealthLost = mini(health, remainingDamage)
	health -= result.baseHealthLost

	result.damageDealt = (
		result.temporaryHealthLost
		+ result.baseHealthLost
	)
	result.remainingTemporaryHealth = temporaryHealth
	result.remainingHealth = health
	result.wasLethal = health <= 0

	if is_node_ready():
		_refreshCard()

	return result
```

Keep `MODIFY_STATS` for healing and stat changes. Damage must go through `DEAL_DAMAGE` so Story 14 can react to real damage results.

The temporary-health visual you already added can remain. Clean its formatting to:

```gdscript
healthLable.text = (
	str(card.health)
	if card.temporaryHealth <= 0
	else "%s (+%s)" % [card.health, card.temporaryHealth]
)
```

## Step 4: Process `DEAL_DAMAGE`

Add the route to `ActionProcessor._resolveAction()`:

```gdscript
ActionType.DEAL_DAMAGE:
	return _handleDealDamage(action)
```

Add the typed handler:

```gdscript
func _handleDealDamage(action: Dictionary) -> DamageResult:
	var source = action["source"]
	var target = action["target"]
	var data: Dictionary = action["data"]

	if !(source is Card):
		return DamageResult.rejected("DEAL_DAMAGE source must be a Card")
	if !(target is Card):
		return DamageResult.rejected("DEAL_DAMAGE target must be a Card")
	if !data.has("amount") or !(data["amount"] is int):
		return DamageResult.rejected("DEAL_DAMAGE amount must be an integer")
	if data["amount"] < 0:
		return DamageResult.rejected("DEAL_DAMAGE amount cannot be negative")

	var result := target.applyDamage(data["amount"])
	result.source = source
	result.sourceInstanceId = source.instanceId
	result.sourceCardId = source.data.id
	result.cause = data.get("cause", "effect")
	result.cycleNumber = data.get("cycle_number", 0)
	return result
```

The action dictionary carries only the small command payload. The returned gameplay result is typed.

Also return the real result from `MOVE_CARD`:

```gdscript
ActionType.MOVE_CARD:
	return _handleMoveCard(action)


func _handleMoveCard(action: Dictionary) -> bool:
	# Keep the existing validation.
	return boardController.moveCard(card, destinationSlot)
```

Combat must know whether movement succeeded so its own result accurately reports the fight. It must not reveal or store a replacement card.

## Step 5: Create `CombatResult`

Create `src/main/combat/combat_result.gd`:

```gdscript
class_name CombatResult
extends RefCounted

var succeeded := false
var failureReason := ""
var context: CombatContext

var defenderDamage: DamageResult
var playerDamage: DamageResult

var defenderDefeated := false
var playerDefeated := false
var defenderGraveyardEntry: GraveyardEntry
var playerGraveyardEntry: GraveyardEntry

var playerMoved := false


func wasKill() -> bool:
	return defenderGraveyardEntry != null


func attackerSurvived() -> bool:
	return !playerDefeated


static func failed(
	combatContext: CombatContext,
	reason: String,
) -> CombatResult:
	var result := CombatResult.new()
	result.context = combatContext
	result.failureReason = reason
	return result
```

Do not copy every context field into `CombatResult`. Consumers reach declaration data through `result.context` and outcome data directly through `result`.

## Step 6: Add Typed Combat Signals

Add to `GlobalSignalBus`:

```gdscript
signal combatStarted(context: CombatContext)
signal combatCompleted(result: CombatResult)
```

Add wrappers:

```gdscript
func emitCombatStarted(context: CombatContext) -> void:
	emit_signal("combatStarted", context)


func emitCombatCompleted(result: CombatResult) -> void:
	emit_signal("combatCompleted", result)
```

Do not duplicate these objects into dictionaries at the signal boundary.

## Step 7: Complete `CombatResolver`

Replace the placeholder in `src/main/combat/combat_resolver.gd`:

```gdscript
extends Node
class_name CombatResolver

@export var gameController: GameController
@export var boardController: BoardController
@export var slotGrid: SlotGrid

var isResolving := false


func _ready() -> void:
	GlobalSignalBus.playerCombatRequested.connect(_onPlayerCombatRequested)
```

Remove the unused `_process()` method. Combat is signal-driven.

Validate the Story 12 request again:

```gdscript
func _isValidRequest(
	player: Card,
	defender: Card,
	playerSlot: CardSlot,
	targetSlot: CardSlot,
	cycleNumber: int,
) -> bool:
	if isResolving:
		return false
	if gameController == null or boardController == null:
		return false
	if slotGrid == null:
		return false
	if gameController.state != GameController.GameState.COMBAT:
		return false
	if gameController.playerCard != player:
		return false
	if gameController.playerCycleNumber != cycleNumber:
		return false
	if playerSlot == null or playerSlot.currentCard != player:
		return false
	if targetSlot == null or targetSlot.currentCard != defender:
		return false
	return targetSlot in slotGrid.getCardinalNeighbours(playerSlot)
```

Start resolution by creating the typed snapshot:

```gdscript
func _onPlayerCombatRequested(
	player: Card,
	defender: Card,
	playerSlot: CardSlot,
	targetSlot: CardSlot,
	cycleNumber: int,
) -> void:
	if !_isValidRequest(player, defender, playerSlot, targetSlot, cycleNumber):
		return

	var context := CombatContext.create(
		cycleNumber,
		player,
		defender,
		playerSlot,
		targetSlot,
	)
	_resolveCombat(context)
```

## Step 8: Resolve Both Damage Actions

Begin `_resolveCombat()`:

```gdscript
func _resolveCombat(context: CombatContext) -> void:
	isResolving = true
	GlobalSignalBus.emitCombatStarted(context)

	var defenderHit := ActionType.make(
		ActionType.DEAL_DAMAGE,
		context.attacker,
		context.defender,
		{
			"amount": context.attackerDamage,
			"cause": "combat",
			"cycle_number": context.cycleNumber,
		},
	)
	var retaliation := ActionType.make(
		ActionType.DEAL_DAMAGE,
		context.defender,
		context.attacker,
		{
			"amount": context.retaliationDamage,
			"cause": "combat_retaliation",
			"cycle_number": context.cycleNumber,
		},
	)

	if !ActionQueue.enqueueAction(defenderHit):
		_finishFailedCombat(context, "defender damage was rejected")
		return
	if !ActionQueue.enqueueAction(retaliation):
		_finishFailedCombat(context, "retaliation was rejected")
		return

	var result := CombatResult.new()
	result.context = context
	result.defenderDamage = (
		await ActionQueue.waitForActionToResolve(defenderHit)
		as DamageResult
	)
	result.playerDamage = (
		await ActionQueue.waitForActionToResolve(retaliation)
		as DamageResult
	)

	if result.defenderDamage == null or !result.defenderDamage.succeeded:
		_finishFailedCombat(context, "defender damage failed")
		return
	if result.playerDamage == null or !result.playerDamage.succeeded:
		_finishFailedCombat(context, "retaliation failed")
		return

	result.defenderDefeated = result.defenderDamage.wasLethal
	result.playerDefeated = result.playerDamage.wasLethal
	await _resolveDefeatedCards(result)
```

Both actions are enqueued before either result is awaited. That preserves retaliation after a lethal first hit.

## Step 9: Preserve Removal Attribution

Temporary health belongs in Graveyard snapshots:

```gdscript
entry.statSnapshot = {
	"health": card.health,
	"temporary_health": card.temporaryHealth,
	"attack": card.attack,
}
```

Also add an optional stable source ID to `Graveyard.buryCard()`:

```gdscript
func buryCard(
	card: Card,
	source,
	cause: String,
	boardController: BoardController,
	sourceInstanceId: int = 0,
) -> GraveyardEntry:
	# Existing validation and removal remain.
	entry.sourceInstanceId = (
		source.instanceId
		if source is Card and is_instance_valid(source)
		else sourceInstanceId
	)
```

Pass `action.data.source_instance_id` from `_handleRemoveCard()`. This preserves both kill attributions if both combatants are freed during the same combat.

==Remove defeated cards through actions:==

```gdscript
func _resolveDefeatedCards(result: CombatResult) -> void:
	var context := result.context

	if result.defenderDefeated:
		var removeDefender := ActionType.make(
			ActionType.REMOVE_CARD,
			context.attacker,
			context.defender,
			{
				"cause": "combat",
				"source_instance_id": context.attackerInstanceId,
			},
		)
		if ActionQueue.enqueueAction(removeDefender):
			result.defenderGraveyardEntry = (
				await ActionQueue.waitForActionToResolve(removeDefender)
				as GraveyardEntry
			)

	if result.playerDefeated:
		var removePlayer := ActionType.make(
			ActionType.REMOVE_CARD,
			context.defender,
			context.attacker,
			{
				"cause": "combat_retaliation",
				"source_instance_id": context.defenderInstanceId,
			},
		)
		if ActionQueue.enqueueAction(removePlayer):
			result.playerGraveyardEntry = (
				await ActionQueue.waitForActionToResolve(removePlayer)
				as GraveyardEntry
			)

	await _resolveCombatMovement(result)
```

A combat kill is proven by a non-null `GraveyardEntry`, not merely by a lethal health value.

## Step 10: Finish Combat-Caused Movement

Only advance a living player after the defender was successfully removed:

```gdscript
func _resolveCombatMovement(result: CombatResult) -> void:
	var context := result.context

	if result.defenderGraveyardEntry != null and !result.playerDefeated:
		var movePlayer := ActionType.make(
			ActionType.MOVE_CARD,
			context.attacker,
			context.targetSlot,
			{"cause": "combat_advance"},
		)
		if ActionQueue.enqueueAction(movePlayer):
			result.playerMoved = await ActionQueue.waitForActionToResolve(movePlayer)

	_finishCombat(result)
```

`CombatResolver` stops after movement and emits its result. It does not inspect the Journey Deck, enqueue `REVEAL_CARD`, choose a refill policy, or expose a revealed card.

Combat ordering ends here:

```text
REMOVE_CARD defender
→ MOVE_CARD player
→ combatCompleted(CombatResult)
```

Complete `CombatResolver` with both exit paths before moving on to board refill:

```gdscript
func _finishCombat(result: CombatResult) -> void:
	result.succeeded = true
	GlobalSignalBus.emitCombatCompleted(result)
	isResolving = false


func _finishFailedCombat(
	context: CombatContext,
	reason: String,
) -> void:
	var result := CombatResult.failed(context, reason)
	GlobalSignalBus.emitCombatCompleted(result)
	isResolving = false
```

Both methods release the resolver guard and publish exactly one typed result. They do not refill the board or complete the player cycle; `GameController` coordinates those later steps.

## Step 11: Create A Separate Board-Refill Flow

Create `BoardRefillRequest`:

```gdscript
class_name BoardRefillRequest
extends RefCounted

var slot: CardSlot
var cycleNumber: int
var cause: String


static func forVacatedSlot(
	vacatedSlot: CardSlot,
	cycle: int,
) -> BoardRefillRequest:
	var request := BoardRefillRequest.new()
	request.slot = vacatedSlot
	request.cycleNumber = cycle
	request.cause = "player_vacated_slot"
	return request
```

Create `BoardRefillResult`:

```gdscript
class_name BoardRefillResult
extends RefCounted

var succeeded := false
var skipped := false
var failureReason := ""
var request: BoardRefillRequest
var revealedCard: Card
```

==The revealed card belongs here—not in `CombatResult`.==

Add signals:

```gdscript
signal boardRefillRequested(request: BoardRefillRequest)
signal boardRefillCompleted(result: BoardRefillResult)
```

==Create a scene-owned `BoardRefillController` that owns `JourneyDeck` interaction:==

```gdscript
extends Node
class_name BoardRefillController

@export var journeyDeck: JourneyDeck


func _ready() -> void:
	GlobalSignalBus.boardRefillRequested.connect(_onBoardRefillRequested)


func _onBoardRefillRequested(request: BoardRefillRequest) -> void:
	var result := BoardRefillResult.new()
	result.request = request

	if request.slot == null or request.slot.isOccupied():
		result.failureReason = "refill slot is invalid or occupied"
		GlobalSignalBus.emitBoardRefillCompleted(result)
		return

	if journeyDeck == null or journeyDeck.isEmpty():
		result.succeeded = true
		result.skipped = true
		GlobalSignalBus.emitBoardRefillCompleted(result)
		return

	var reveal := ActionType.make(
		ActionType.REVEAL_CARD,
		journeyDeck,
		request.slot,
		{"cause": request.cause},
	)
	if !ActionQueue.enqueueAction(reveal):
		result.failureReason = "refill action was rejected"
		GlobalSignalBus.emitBoardRefillCompleted(result)
		return

	result.revealedCard = (
		await ActionQueue.waitForActionToResolve(reveal)
		as Card
	)
	result.succeeded = result.revealedCard != null
	if !result.succeeded:
		result.failureReason = "refill reveal failed"
	GlobalSignalBus.emitBoardRefillCompleted(result)
```

This controller receives a specific slot. It does not search `getEmptySlots()`, and combat never calls `fillEmptySlots()`.

## Step 12: Let GameController Coordinate Maintenance

The completed `CombatResolver` now emits either a successful or failed result independently. `GameController` listens for that result and requests board maintenance only when movement created a vacated slot:

```gdscript
func _onCombatCompleted(result: CombatResult) -> void:
	if result.succeeded and result.playerMoved:
		GlobalSignalBus.emitBoardRefillRequested(
			BoardRefillRequest.forVacatedSlot(
				result.context.playerSlot,
				result.context.cycleNumber,
			)
		)
		return

	_finishResolvedPlayerAction()


func _onBoardRefillCompleted(_result: BoardRefillResult) -> void:
	_finishResolvedPlayerAction()


func _finishResolvedPlayerAction() -> void:
	if beginAfterMovePhase():
		await _waitForActionSystemIdle()
		completePlayerCycle()
```

The board-refill outcome has no bearing on `CombatResult`. It only gates completion of the overall player action so input cannot unlock during board maintenance.

Normal flow after a victory:

```text
COMBAT resolves
→ combatCompleted
→ boardRefillRequested
→ boardRefillCompleted
→ AFTER_MOVE
→ PLAYER_READY
```

Combat with no player movement skips the refill request and proceeds directly to `AFTER_MOVE`. A failed combat follows the same no-refill route; `GameController` completes the action without pretending that combat produced a refill result.

Story 13 does not enter `GAME_OVER`. Story 15 consumes `result.playerDefeated` and the player removal result.

## Step 13: Wire The Test Scene

Add separate scene-owned combat and refill controllers:

```gdscript
@onready var combatResolver: CombatResolver = $CombatResolver
@onready var boardRefillController: BoardRefillController = $BoardRefillController


func _ready() -> void:
	combatResolver.gameController = gameController
	combatResolver.boardController = boardController
	combatResolver.slotGrid = slotGrid
	boardRefillController.journeyDeck = journeyDeck
```

Display the typed result:

```gdscript
func _onCombatCompleted(result: CombatResult) -> void:
	if !result.succeeded:
		movementStatus.text = "Combat failed: %s" % result.failureReason
		return

	movementStatus.text = (
		"Combat: dealt %s, took %s\nKill: %s | Moved: %s"
		% [
			result.defenderDamage.damageDealt,
			result.playerDamage.damageDealt,
			result.wasKill(),
			result.playerMoved,
		]
	)


func _onBoardRefillCompleted(result: BoardRefillResult) -> void:
	var refillText := "Deck empty; slot left open" if result.skipped else (
		"Revealed: %s" % result.revealedCard.data.name
		if result.succeeded
		else "Refill failed: %s" % result.failureReason
	)
	movementStatus.text += "\n" + refillText
```

## Automated Tests: Typed Damage

Create `tests/damage_action_test.gd/.tscn` covering:

1. `DEAL_DAMAGE` remains a valid action type.
2. Missing/non-Card source returns a rejected `DamageResult`.
3. Missing/non-Card target returns a rejected `DamageResult`.
4. Missing/non-integer amount returns a rejected `DamageResult`.
5. Negative damage is rejected and changes nothing.
6. Valid zero damage succeeds and reports zero damage.
7. Ordinary damage reduces base health.
8. Damage cannot reduce base health below zero.
9. Temporary health absorbs damage first.
10. Only overflow reaches base health.
11. Damage is not double-counted across both pools.
12. The result contains requested, dealt, temporary, and base amounts.
13. The result contains remaining health and lethal state.
14. The result contains source/target references and stable IDs.
15. Cause and cycle attribution survive the action boundary.
16. Card visuals refresh after damage.
17. `MODIFY_STATS` healing still works independently.

## Automated Tests: Typed Combat

Create `tests/combat_resolver_test.gd/.tscn` covering:

1. `CombatContext` snapshots both attack values and stable identities.
2. Later stat changes cannot alter snapshotted damage.
3. Missing references reject combat safely.
4. Requests outside `COMBAT` are rejected.
5. Stale cycles, slots, cards, and non-cardinal requests are rejected.
6. Duplicate requests while resolving do not duplicate combat.
7. Both damage actions return `DamageResult` objects.
8. Retaliation occurs after lethal defender damage.
9. Equal damage and health is lethal.
10. If both survive, neither card moves.
11. A defeated defender is removed with player attribution.
12. A clean victory moves the player into the target slot.
13. Player-only death causes no movement.
14. Mutual death preserves both removal attributions.
15. `combatCompleted` emits exactly one `CombatResult`.
16. Failed combat emits a typed failure result.
17. `CombatResult` contains no Journey Deck or revealed-card outcome.
18. Combat does not enqueue `REVEAL_CARD`.

## Automated Tests: Board Refill Flow

Create `tests/board_refill_controller_test.gd/.tscn` covering:

1. A request identifies one exact vacated slot and cycle number.
2. A null or occupied slot returns a failed `BoardRefillResult`.
3. A valid request enqueues exactly one `REVEAL_CARD`.
4. The revealed card is returned only in `BoardRefillResult`.
5. Other empty slots remain unchanged.
6. An empty Journey Deck produces a successful skipped result.
7. Combat without player movement produces no refill request.
8. GameController waits for `boardRefillCompleted` before `AFTER_MOVE`.
9. Refill failure still allows the player cycle to settle safely.
10. The completed cycle returns to `PLAYER_READY` and unlocks input.
11. The action queue and processor are idle afterward.
12. Existing action, Graveyard, GameController, movement, and combat tests still pass.

## Keep Out Of Story 13

- Alternative movement patterns
- Clicking or moving into empty slots
- Critical hits, misses, armour, elements, or attack modifiers
- Multi-hit or multi-target combat
- Stateful Story 14 effects
- Game-over and empty-deck outcome decisions
- Production-scene architecture
- Final gameplay UI

## Definition Of Done

- [x] `DEAL_DAMAGE` is registered as an action type.
- [x] Temporary-health storage and basic visual feedback exist.
- [ ] The current temporary-health damage bug is corrected.
- [ ] `CombatContext`, `DamageResult`, and `CombatResult` exist.
- [ ] `BoardRefillRequest`, `BoardRefillResult`, and `BoardRefillController` exist separately.
- [ ] Large combat dictionaries are not passed through signals or returned as results.
- [ ] `DEAL_DAMAGE` returns a typed, attributed `DamageResult`.
- [ ] Both attacks use values snapshotted in `CombatContext`.
- [ ] Retaliation occurs even when the defender is defeated.
- [ ] Temporary health absorbs damage before base health.
- [ ] Lethal removal uses `REMOVE_CARD`, Graveyard, and BoardHistory.
- [ ] Mutual-death attribution survives freed card nodes.
- [ ] A surviving player moves only after defender removal succeeds.
- [ ] `CombatResult` contains no replacement-card or Journey Deck fields.
- [ ] Combat emits its result before the independent refill flow begins.
- [ ] BoardRefillController refills exactly the requested previous player slot.
- [ ] Combat never calls `fillEmptySlots()`.
- [ ] `combatCompleted` emits one typed `CombatResult`.
- [ ] `boardRefillCompleted` emits one typed `BoardRefillResult`.
- [ ] Combat and any requested board maintenance settle before the player cycle completes.
- [ ] Failed combat cannot leave input permanently locked.
- [ ] Manual typed-result feedback works.
- [ ] New and existing tests pass.
- [ ] `git diff --check` passes.

## Handoff To Story 14

Story 14 consumes `CombatResult` and its two `DamageResult` objects. SolitaryBeast, WaxingFerocity, and TasteOfVictory must not infer combat outcomes from loose dictionary keys, negative `MODIFY_STATS`, or unrelated removal counts.

Complete [[Post Story 13 Spike - Typed Gameplay Contracts]] before Story 14 locks in its effect-event APIs.

Perform [[Future Story - Combat Integration Effect Reassessment]] against these final typed contracts before Story 14 is considered complete.

## Handoff To Story 15

`CombatResult.playerDefeated` and `CombatResult.playerGraveyardEntry` are Story 15's authoritative player-death inputs. Story 15 decides when to enter `GAME_OVER`, permanently lock input, and display the end reason.
