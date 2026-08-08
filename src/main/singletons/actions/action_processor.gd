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
	if !action.is_empty():
		var result = await _resolveAction(action)
		GlobalSignalBus.emitActionResolved(action, result)
	
	isProcessingAction = false

func _resolveAction(action: Dictionary) -> Variant:
	match action["type"]:
		ActionType.REVEAL_CARD:
			return await _handleRevealCard(action)
		ActionType.MOVE_CARD:
			_handleMoveCard(action)
			return null
		ActionType.MODIFY_STATS:
			_handleModifyStats(action)
			return null
		ActionType.REMOVE_CARD:
			return _handleRemoveCard(action)
		ActionType.DELETE_CARD:
			return _handleDeleteCard(action)
		ActionType.REVIVE_CARD:
			return _handleReviveCard(action)
		_:
			push_warning("ActionProcessor: Unsupported action type: %s" % action["type"])
			return null
	
func _handleRevealCard(action: Dictionary) -> Card:
	var source = action["source"]
	var target = action["target"]
	
	if !(source is JourneyDeck):
		push_warning("ActionProcessor: REVEAL_CARD source must be a JourneyDeck.")
		return
	
	if !(target is CardSlot):
		push_warning("ActionProcessor: REVEAL_CARD target must be a CardSlot.")
		return
	
	var card: Card = await source.revealTopCard(target)
	return card

func _handleMoveCard(action: Dictionary) -> void:
	var card = action["source"]
	var destinationSlot = action["target"]
	
	if !(card is Card):
		push_warning("ActionProcessor: MOVE_CARD source must be a Card.")
		return
	
	if !(destinationSlot is CardSlot):
		push_warning("ActionProcessor: MOVE_CARD target must be a CardSlot.")
		return
	
	var boardController = _getBoardController()
	if boardController == null:
		push_warning("ActionProcessor: MOVE_CARD requires an active BoardController.")
		return
	
	if !boardController.moveCard(card, destinationSlot):
		push_warning("ActionProcessor: MOVE_CARD could not move the card.")

func _handleModifyStats(action: Dictionary) -> void:
	var data = action["data"]
	var target = action["target"]
	
	if !(target is Card):
		push_warning("ActionProcessor: MODIFY_STATS target must be a Card.")
		return
	
	if !data.has("stat") || !(data["stat"] is String):
		push_warning("ActionProcessor: MODIFY_STATS requires a String stat.")
		return
	
	if !data.has("amount") || !(data["amount"] is int):
		push_warning("ActionProcessor: MODIFY_STATS requires an integer amount.")
		return
	
	if !target.modifyStat(data["stat"], data["amount"]):
		push_warning("ActionProcessor: MODIFY_STATS rejected the requested change.")

func _handleRemoveCard(action: Dictionary) -> GraveyardEntry:
	var target = action["target"]
	
	if !(target is Card):
		push_warning("ActionProcessor: REMOVE_CARD target must be a Card.")
		return
	
	var boardController = _getBoardController()
	if boardController == null:
		push_warning("ActionProcessor: REMOVE_CARD requires an active BoardController.")
		return
	
	return Graveyard.buryCard(target, action["source"], action["data"].get("cause", "effect"), boardController)

func _handleDeleteCard(action: Dictionary) -> bool:
	var target = action["target"]
	if target is GraveyardEntry:
		return Graveyard.deleteEntry(target.entryId, action["source"])

	if target is Card:
		var boardController = _getBoardController()
		if boardController != null:
			boardController.removeCard(target)

		BoardHistory.recordEvent("deleted", {
			"instance_id": target.instanceId,
			"card_id": target.data.id,
			"from": "active_play"
		})
		target.queue_free()
		return true

	push_warning("ActionProcessor: inavlid DELETE_CARD target.")
	return false

func _handleReviveCard(action: Dictionary) -> Card:
	var entry = action["source"]
	var slot = action["target"]
	if !(entry is GraveyardEntry) or !(slot is CardSlot):
		push_warning("ActionProcessor: invalid REVIVE_CARD action.")
		return null

	var boardController = _getBoardController()
	if boardController == null:
		return null
	return Graveyard.reviveCard(entry.entryId, slot, boardController)
