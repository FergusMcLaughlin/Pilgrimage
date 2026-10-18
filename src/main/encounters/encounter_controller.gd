class_name EncounterController
extends Node

@export var gameController: GameController
@export var modal: EncounterModal

var activeEncounter: EncounterInteraction
var resolution: EncounterResolution
var resolvedEncounterSources: Dictionary = {}

func _ready() -> void:
	GlobalSignalBus.encounterOutcomeRequested.connect(_onEncounterOutcomeRequested)
	GlobalSignalBus.actionResolved.connect(_onActionResolved)
	GlobalSignalBus.gameOverRequested.connect(cancelEncounters)

func canPresentEncounter(definition: EncounterDefinition) -> bool:
	if !is_instance_valid(modal) or definition == null:
		return false
	if String(definition.id).strip_edges().is_empty():
		return false
	if definition.title.strip_edges().is_empty() or definition.body.strip_edges().is_empty():
		return false
	return definition.encounterType in [
		EncounterDefinition.Type.CONTINUE_ONLY,
		EncounterDefinition.Type.CONTINUE_OR_LEAVE
	]

func presentModal(definition: EncounterDefinition) -> bool:
	return canPresentEncounter(definition) and modal.present(definition)

func close() -> void:
	if is_instance_valid(modal) and modal.is_inside_tree():
		modal.close()

func beginEncounter(source: Card, fromSlot: CardSlot, toSlot: CardSlot) -> bool:
	if activeEncounter != null or !is_instance_valid(gameController):
		return false
	if !is_instance_valid(source) or source.data == null or !source.data.hasEncounter:
		return false
	if resolvedEncounterSources.has(source.instanceId):
		return false
	var definition = source.data.encounter
	if !canPresentEncounter(definition) or definition.id != source.data.encounterId:
		push_error("EncounterController: invalid encounter : " + source.data.id)
		return false
	if !gameController.beginEncounter():
		return false
	activeEncounter = EncounterInteraction.create(
		gameController.runId, gameController.playerCycleNumber,
		source, gameController.playerCard, fromSlot, toSlot
	)
	if !presentModal(definition):
		_finishEncounter(false, "modal could not open")
		return false
	return true

func _onEncounterOutcomeRequested(encounterId: StringName, outcome: EncounterDefinition.Outcome) -> void:
	if !_isCurrent(activeEncounter) or get_tree().paused:
		return
	if gameController.state != GameController.GameState.ENCOUNTER:
		return
	if encounterId != activeEncounter.definition.id:
		return
	if outcome != EncounterDefinition.Outcome.CONTINUE:
		if outcome != EncounterDefinition.Outcome.LEAVE or activeEncounter.definition.encounterType != EncounterDefinition.Type.CONTINUE_OR_LEAVE:
			return
	if !_slotsAreValid(activeEncounter):
		_finishEncounter(false, "source/player changed while reading")
		return
	resolution = EncounterResolution.create(outcome)
	close()
	gameController.setState(GameController.GameState.RESOLVING_MOVE)
	_advanceEncounter()

func _advanceEncounter() -> void:
	if !_isCurrent(activeEncounter):
		return
	if resolution.movePlayer and !resolution.removeSource:
		_finishEncounter(false, "cannot move into a retained source")
		return
	var request = activeEncounter
	var action: GameAction
	if resolution.removeSource and !request.sourceRemoved:
		action = ActionType.make(
			ActionType.REMOVE_CARD, request.player, request.source,
			RemoveCardPayload.create(request.playerInstanceId, "encounter")
		)
	elif resolution.movePlayer and !request.playerMoved:
		if !_slotsAreValid(request):
			_finishEncounter(false, "player or movement slots changed")
			return
		action = ActionType.make(
			ActionType.MOVE_CARD, request.player, request.targetSlot,
			MoveCardPayload.create("encounter_advance")
		)
	else:
		_completeAfterSettlement(request)
		return
	request.waitingAction = action
	if !ActionQueue.enqueueAction(action):
		_finishEncounter(false, "encounter action was rejected")

func _onActionResolved(action: GameAction, result: Variant) -> void:
	if !_isCurrent(activeEncounter) or action != activeEncounter.waitingAction:
		return
	activeEncounter.waitingAction = null
	if action.type == ActionType.REMOVE_CARD:
		if !(result is GraveyardEntry):
			_finishEncounter(false, "source removal failed")
			return
		activeEncounter.sourceRemoved = true
	elif action.type == ActionType.MOVE_CARD:
		if result != true:
			_finishEncounter(false, "player movement failed")
			return
		activeEncounter.playerMoved = true
	_advanceEncounter()

func _completeAfterSettlement(request: EncounterInteraction) -> void:
	while _isCurrent(request) and (ActionQueue.queueHasActions() or ActionProcessor.isProcessingAction):
		await get_tree().process_frame
	if !_isCurrent(request):
		return
	if !_slotsAreValid(request):
		_finishEncounter(false, "cards changed during settlement")
		return
	resolvedEncounterSources[request.sourceInstanceId] = resolution.outcome
	_finishEncounter(true)

func _isCurrent(request: EncounterInteraction) -> bool:
	if request == null or request != activeEncounter or !is_inside_tree():
		return false
	if !is_instance_valid(gameController):
		return false
	return request.runId == gameController.runId and request.cycleNumber == gameController.playerCycleNumber \
		and gameController.state in [GameController.GameState.ENCOUNTER, GameController.GameState.RESOLVING_MOVE]

func _slotsAreValid(request: EncounterInteraction) -> bool:
	if !is_instance_valid(request.player) or request.player != gameController.playerCard or request.player.health <= 0:
		return false
	if !is_instance_valid(request.playerSlot) or !is_instance_valid(request.targetSlot):
		return false
	if request.playerMoved:
		return request.targetSlot.currentCard == request.player and !request.playerSlot.isOccupied()
	if request.playerSlot.currentCard != request.player:
		return false
	if request.sourceRemoved:
		return !request.targetSlot.isOccupied()
	return is_instance_valid(request.source) and request.targetSlot.currentCard == request.source

func _finishEncounter(succeeded: bool, reason: String = "") -> void:
	var result = EncounterResult.create(activeEncounter, succeeded, reason)
	activeEncounter = null
	resolution = null
	close()
	GlobalSignalBus.emitEncounterCompleted(result)

func cancelEncounters() -> void:
	activeEncounter = null
	resolution = null
	resolvedEncounterSources.clear()
	close()

func _exit_tree() -> void:
	cancelEncounters()
