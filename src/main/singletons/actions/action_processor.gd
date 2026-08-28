extends Node

var isProcessingAction = false

func _getBoardController() -> BoardController:
	return get_tree().get_first_node_in_group("boardController") as BoardController

func _process(_delta: float) -> void:
	if isProcessingAction || !ActionQueue.queueHasActions():
		return
	
	_processNextAction()

func _processNextAction() -> void:
	isProcessingAction = true
	
	var action = ActionQueue.popNextAction()
	if action != null:
		var result = await _resolveAction(action)
		GlobalSignalBus.emitActionResolved(action, result)
	
	isProcessingAction = false

func _resolveAction(action: GameAction) -> Variant:
	match action.type:
		ActionType.REVEAL_CARD:
			return await _handleRevealCard(action)
		ActionType.MOVE_CARD:
			return _handleMoveCard(action)
		ActionType.MODIFY_STATS:
			_handleModifyStats(action)
			return null
		ActionType.DEAL_DAMAGE:
			return _handleDealDamage(action)
		ActionType.REMOVE_CARD:
			return _handleRemoveCard(action)
		ActionType.DELETE_CARD:
			return _handleDeleteCard(action)
		ActionType.REVIVE_CARD:
			return _handleReviveCard(action)
		_:
			push_warning("ActionProcessor: Unsupported action type: %s" % action.type)
			return null

func _handleRevealCard(action: GameAction) -> Card:
	var source = action.source as JourneyDeck
	var target = action.target as CardSlot
	var payload = action.payload as RevealCardPayload
	if source == null:
		push_warning("ActionProcessor: REVEAL_CARD source must be a JourneyDeck.")
		return null
	if target == null:
		push_warning("ActionProcessor: REVEAL_CARD target must be a CardSlot.")
		return null
	if payload == null:
		push_warning("ActionProcessor: REVEAL_CARD requires RevealCardPayload.")
		return null
	
	return await source.revealTopCard(target)

func _handleMoveCard(action: GameAction) -> bool:
	var card = action.source as Card
	var destinationSlot = action.target as CardSlot
	var payload = action.payload as MoveCardPayload
	if card == null:
		push_warning("ActionProcessor: MOVE_CARD source must be a Card.")
		return false
	if destinationSlot == null:
		push_warning("ActionProcessor: MOVE_CARD target must be a CardSlot.")
		return false
	if payload == null:
		push_warning("ActionProcessor: MOVE_CARD requires MoveCardPayload.")
		return false
	
	var boardController = _getBoardController()
	if boardController == null:
		push_warning("ActionProcessor: MOVE_CARD requires an active BoardController.")
		return false
	
	var moved = boardController.moveCard(card, destinationSlot)
	if !moved:
		push_warning("ActionProcessor: MOVE_CARD could not move the card.")
	return moved

func _handleModifyStats(action: GameAction) -> void:
	var target = action.target as Card
	var payload = action.payload as ModifyStatsPayload
	if target == null:
		push_warning("ActionProcessor: MODIFY_STATS target must be a Card.")
		return
	if payload == null:
		push_warning("ActionProcessor: MODIFY_STATS requires ModifyStatsPayload.")
		return
	if payload.stat.is_empty():
		push_warning("ActionProcessor: MODIFY_STATS requires a stat.")
		return
	
	if !target.modifyStat(payload.stat, payload.amount):
		push_warning("ActionProcessor: MODIFY_STATS rejected the requested change.")

func _handleDealDamage(action: GameAction) -> DamageResult:
	var source = action.source as Card
	var target = action.target as Card
	var payload = action.payload as DealDamagePayload
	if source == null:
		return DamageResult.rejected("ActionProcessor: DEAL_DAMAGE source must be a Card.")
	if target == null:
		return DamageResult.rejected("ActionProcessor: DEAL_DAMAGE target must be a Card.")
	if payload == null:
		return DamageResult.rejected("ActionProcessor: DEAL_DAMAGE requires DealDamagePayload.")
	if payload.amount < 0:
		return DamageResult.rejected("ActionProcessor: DEAL_DAMAGE amount must not be negative.")
	
	var result = target.applyDamage(payload.amount)
	result.source = source
	result.sourceInstanceId = source.instanceId
	result.sourceCardId = source.data.id
	result.cause = payload.cause
	result.cycleNumber = payload.cycleNumber
	return result

func _handleRemoveCard(action: GameAction) -> GraveyardEntry:
	var target = action.target as Card
	var payload = action.payload as RemoveCardPayload
	
	if target == null:
		push_warning("ActionProcessor: REMOVE_CARD target must be a Card.")
		return null
	if payload == null:
		push_warning("ActionProcessor: REMOVE_CARD requires RemoveCardPayload.")
		return null
	
	var boardController = _getBoardController()
	if boardController == null:
		push_warning("ActionProcessor: REMOVE_CARD requires an active BoardController.")
		return null
	
	return Graveyard.buryCard(
		target,
		action.source,
		payload.cause,
		boardController,
		payload.sourceInstanceId
	)

func _handleDeleteCard(action: GameAction) -> bool:
	var target = action.target
	if target is GraveyardEntry:
		return Graveyard.deleteEntry(target.entryId, action.source)
	
	if target is Card:
		var boardController = _getBoardController()
		if boardController == null or !boardController.removeCard(target):
			return false
	
		BoardHistory.recordEvent(CardDeletedHistoryEvent.fromActiveCard(target))
		target.queue_free()
		return true
	
	push_warning("ActionProcessor: inavlid DELETE_CARD target.")
	return false

func _handleReviveCard(action: GameAction) -> Card:
	var entry = action.source as GraveyardEntry
	var slot = action.target as CardSlot
	if entry == null or slot == null:
		push_warning("ActionProcessor: invalid REVIVE_CARD action.")
		return null
	
	var boardController = _getBoardController()
	if boardController == null:
		return null
	return Graveyard.reviveCard(entry.entryId, slot, boardController)
