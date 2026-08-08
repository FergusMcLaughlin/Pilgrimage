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
			_handleRemoveCard(action)
			return null
		ActionType.DELETE_CARD:
			_handleDeleteCard(action)
			return null
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

func _handleRemoveCard(action: Dictionary) -> void:
	var target = action["target"]
	
	if !(target is Card):
		push_warning("ActionProcessor: REMOVE_CARD target must be a Card.")
		return
	
	var boardController = _getBoardController()
	if boardController == null:
		push_warning("ActionProcessor: REMOVE_CARD requires an active BoardController.")
		return
	
	var cardWasRemoved: bool = boardController.removeCard(target)
	if !cardWasRemoved:
		push_warning("ActionProcessor: REMOVE_CARD target is not on the active board.")

func _handleDeleteCard(action: Dictionary) -> void:
	var target = action["target"]

	if !(target is Card):
		push_warning("ActionProcessor: DELETE_CARD target must be a Card.")
		return

	# A deleted card must not remain referenced by an occupied board slot.
	# Deletion also works for cards that are already outside active play.
	var boardController = _getBoardController()
	if boardController != null:
		boardController.removeCard(target)

	target.queue_free()
