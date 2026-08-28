extends Node
class_name CombatResolver

@export var gameController: GameController
@export var boardController: BoardController
@export var slotGrid: SlotGrid

var isResolving = false

func _ready() -> void:
	GlobalSignalBus.playerCombatRequested.connect(_onPlayerCombatRequested)

func _hasRequiredRefs() -> bool:
	return(gameController != null and boardController != null and slotGrid != null)

func _isValidRequest(player: Card, defender: Card, playerSlot: CardSlot, targetSlot: CardSlot, cycleNumber: int) -> bool:
	if isResolving:
		return false
	if !_hasRequiredRefs():
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

func _onPlayerCombatRequested(player: Card, defender: Card, playerSlot: CardSlot, targetSlot: CardSlot, cycleNumber: int) -> void:
	if !_isValidRequest(player, defender, playerSlot, targetSlot, cycleNumber):
		return
	
	var context = CombatContext.create(
		cycleNumber,
		player,
		defender,
		playerSlot,
		targetSlot
	)
	
	_resolveCombat(context)

func _resolveCombat(context: CombatContext) -> void:
	isResolving = true
	GlobalSignalBus.emitCombatStarted(context)
	
	var defenderHit = ActionType.make(
		ActionType.DEAL_DAMAGE,
		context.attacker,
		context.defender,
		DealDamagePayload.create(context.attackerDamage, "combat", context.cycleNumber)
	)
	var retaliation = ActionType.make(
		ActionType.DEAL_DAMAGE,
		context.defender,
		context.attacker,
		DealDamagePayload.create(context.retaliationDamage, "combat_retaliation", context.cycleNumber)
	)
	
	if !defenderHit.isValid():
		_finishFailedCombat(context, "defender's damage was rejected")
		return
	if !retaliation.isValid():
		_finishFailedCombat(context, "retaliation was rejected")
		return
	if !ActionQueue.enqueueAction(defenderHit):
		_finishFailedCombat(context, "defender's damage could not be queued")
		return
	if !ActionQueue.enqueueAction(retaliation):
		_finishFailedCombat(context, "retaliation could not be queued")
		return
	
	var result = CombatResult.new()
	result.context = context
	result.defenderDamage = (await ActionQueue.waitForActionToResolve(defenderHit) as DamageResult)
	result.playerDamage = (await ActionQueue.waitForActionToResolve(retaliation) as DamageResult)
	
	if result.defenderDamage == null or !result.defenderDamage.succeeded:
		_finishFailedCombat(context, "defender's damage failed")
		return
	if result.playerDamage == null or !result.playerDamage.succeeded:
		_finishFailedCombat(context, "retaliation failed")
		return
	
	result.defenderDefeated = result.defenderDamage.wasLethal
	result.playerDefeated = result.playerDamage.wasLethal
	await _resolveDefeatedCards(result)

func _resolveDefeatedCards(result: CombatResult) -> void:
	var context = result.context
	
	if result.defenderDefeated:
		var removeDefender = ActionType.make(
			ActionType.REMOVE_CARD,
			context.attacker,
			context.defender,
			RemoveCardPayload.create(context.attackerInstanceId,"combat")
		)
		if !ActionQueue.enqueueAction(removeDefender):
			_finishFailedCombat(context, "defender removal was rejected")
			return
		result.defenderGraveyardEntry = (
			await ActionQueue.waitForActionToResolve(removeDefender) as GraveyardEntry
		)
		if result.defenderGraveyardEntry == null:
			_finishFailedCombat(context, "defender removal failed")
			return
	
	if result.playerDefeated:
		var removePlayer = ActionType.make(
			ActionType.REMOVE_CARD,
			context.defender,
			context.attacker,
			RemoveCardPayload.create(context.defenderInstanceId, "combat_retaliation")
		)
		if !ActionQueue.enqueueAction(removePlayer):
			_finishFailedCombat(context, "player removal was rejected")
			return
		result.playerGraveyardEntry = (
			await ActionQueue.waitForActionToResolve(removePlayer) as GraveyardEntry
		)
		if result.playerGraveyardEntry == null:
			_finishFailedCombat(context, "player removal failed")
			return
	
	await _resolveCombatMovement(result)

func _resolveCombatMovement(result: CombatResult) -> void:
	var context = result.context
	
	if result.defenderGraveyardEntry != null and !result.playerDefeated:
		var movePlayer = ActionType.make(
			ActionType.MOVE_CARD,
			context.attacker,
			context.targetSlot,
			MoveCardPayload.create("combat_advance")
		)
		if !ActionQueue.enqueueAction(movePlayer):
			_finishFailedCombat(context, "combat movement was rejected")
			return
		result.playerMoved = await ActionQueue.waitForActionToResolve(movePlayer)
		if !result.playerMoved:
			_finishFailedCombat(context, "combat movement failed")
			return
	
	_finishCombat(result)

func _finishCombat(result: CombatResult) -> void:
	result.succeeded = true
	GlobalSignalBus.emitCombatEnded(result)
	isResolving = false

func _finishFailedCombat(context: CombatContext, reason: String) -> void:
	var result = CombatResult.failed(context, reason)
	GlobalSignalBus.emitCombatEnded(result)
	isResolving = false
