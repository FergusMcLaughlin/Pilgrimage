extends Node

#added for testing: isolate encounter behaviour from GameController's later completion/refill wiring.
class TestGame extends GameController:
	func _ready() -> void:
		pass

var results: Array[EncounterResult] = []
var actions: Array[String] = []
var passed := 0
var failures := 0

func _ready() -> void:
	GlobalSignalBus.encounterCompleted.connect(_onCompleted)
	GlobalSignalBus.actionEnqueued.connect(_onEnqueued)
	await _testSuccess("roadside_corpse", EncounterDefinition.Outcome.CONTINUE)
	await _testSuccess("quiet_road", EncounterDefinition.Outcome.LEAVE)
	await _testRetainedSource()
	await _testCancellation()
	await _testFailure(false)
	await _testFailure(true)
	print("Encounter controller: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _fixture(encounterId: String = "roadside_corpse") -> Dictionary:
	results.clear()
	actions.clear()
	ActionQueue.clearQueue()
	Graveyard.reset()
	BoardHistory.reset()
	var host := Node.new()
	var grid: SlotGrid = preload("res://src/main/board/slot_grid/slot_grid.tscn").instantiate()
	grid.name = "SlotGrid"
	var board := BoardController.new()
	board.slotGridPath = NodePath("../SlotGrid")
	var game := TestGame.new()
	var controller := EncounterController.new()
	var modal: EncounterModal = preload("res://src/main/ui/overlays/encounter_modal.tscn").instantiate()
	host.add_child(grid)
	host.add_child(board)
	host.add_child(game)
	host.add_child(modal)
	host.add_child(controller)
	add_child(host)
	controller.gameController = game
	controller.modal = modal
	game.encounterController = controller
	game.slotGrid = grid
	game.boardController = board
	game.runId = 5
	game.playerCycleNumber = 7
	game.state = GameController.GameState.PLAYER_READY
	var player := CreateCard.new().createCard("C_0000")
	var source := CreateCard.new().createCard("M_0012")
	# Each fixture's attachment is authored independently; never mutate CardLibrary's shared data.
	source.data = source.data.duplicate() as CardData
	source.data.imagePath = "res://assets/images/ui/EncounterBG.png"
	source.data.encounterId = encounterId
	source.data.encounter = EncounterLibrary.getEncounterData(encounterId)
	var fromSlot := grid.getSlotAt(Vector2i(1, 1))
	var toSlot := grid.getSlotAt(Vector2i(1, 0))
	board.placeCard(player, fromSlot)
	board.placeCard(source, toSlot)
	game.playerCard = player
	InputManager.unlockInput()
	return {"host":host, "game":game, "board":board, "controller":controller, "modal":modal, "player":player, "source":source, "sourceId":source.instanceId, "from":fromSlot, "to":toSlot}

func _begin(f: Dictionary) -> void:
	_expect(f.controller.beginEncounter(f.source, f.from, f.to), "Valid attachment opens.")
	_expect(f.modal.visible and InputManager.inputLocked, "Reading shows modal and locks input.")
	_expect(f.from.currentCard == f.player and f.to.currentCard == f.source and actions.is_empty(), "Reading applies no gameplay actions.")

func _testSuccess(encounterId: String, outcome: EncounterDefinition.Outcome) -> void:
	var f := _fixture(encounterId)
	_expect(!f.controller.canPresentEncounter(null), "Null definition is rejected.")
	var empty := EncounterDefinition.new()
	_expect(!f.controller.canPresentEncounter(empty), "Empty content is rejected.")
	_begin(f)
	GlobalSignalBus.emitEncounterOutcomeRequested(&"wrong", outcome)
	_expect(results.is_empty() and actions.is_empty(), "Wrong ID does not resolve.")
	if outcome == EncounterDefinition.Outcome.CONTINUE:
		GlobalSignalBus.emitEncounterOutcomeRequested(encounterId, EncounterDefinition.Outcome.LEAVE)
		_expect(actions.is_empty(), "Hidden Leave is rejected.")
	get_tree().paused = true
	GlobalSignalBus.emitEncounterOutcomeRequested(encounterId, outcome)
	_expect(actions.is_empty(), "Paused submission is rejected.")
	get_tree().paused = false
	GlobalSignalBus.emitEncounterOutcomeRequested(encounterId, outcome)
	GlobalSignalBus.emitEncounterOutcomeRequested(encounterId, outcome)
	await _settle()
	_expect(results.size() == 1 and results[0].succeeded, "Duplicate submissions produce one successful result.")
	_expect(actions == [ActionType.REMOVE_CARD, ActionType.MOVE_CARD], "Remove then move exactly once; controller does not refill.")
	_expect(f.to.currentCard == f.player and !f.from.isOccupied(), "Player advances after removal.")
	_expect(results[0].context.sourceRemoved and results[0].context.playerMoved, "Result records actual progress.")
	_expect(f.controller.resolvedEncounterSources[f.sourceId] == outcome, "Chosen outcome is recorded for this source instance.")
	_expect(f.controller.activeEncounter == null and !f.modal.visible, "Completion clears ownership and UI.")
	await _cleanup(f)

func _testRetainedSource() -> void:
	var f := _fixture()
	_begin(f)
	var policy := EncounterResolution.create(EncounterDefinition.Outcome.CONTINUE)
	policy.removeSource = false
	policy.movePlayer = false
	f.controller.resolution = policy
	f.controller.close()
	f.game.setState(GameController.GameState.RESOLVING_MOVE)
	f.controller._advanceEncounter()
	await _settle()
	_expect(results.size() == 1 and results[0].succeeded and actions.is_empty(), "Retained/no-move policy succeeds without actions.")
	_expect(f.from.currentCard == f.player and f.to.currentCard == f.source, "Retained policy preserves both cards.")
	f.game.state = GameController.GameState.PLAYER_READY
	InputManager.unlockInput()
	_expect(!f.controller.beginEncounter(f.source, f.from, f.to), "Resolved retained source cannot trigger twice.")
	await _cleanup(f)

func _testCancellation() -> void:
	var f := _fixture()
	_begin(f)
	f.controller.cancelEncounters()
	GlobalSignalBus.emitEncounterOutcomeRequested(&"roadside_corpse", EncounterDefinition.Outcome.CONTINUE)
	_expect(results.is_empty() and actions.is_empty() and !f.modal.visible, "Cancelled reading ignores late choices.")
	f.game.state = GameController.GameState.PLAYER_READY
	InputManager.unlockInput()
	_begin(f)
	ActionProcessor.set_process(false)
	GlobalSignalBus.emitEncounterOutcomeRequested(&"roadside_corpse", EncounterDefinition.Outcome.CONTINUE)
	var queued: GameAction = f.controller.activeEncounter.waitingAction
	f.controller.cancelEncounters()
	ActionQueue.clearQueue()
	GlobalSignalBus.emitActionResolved(queued, GraveyardEntry.new())
	ActionProcessor.set_process(true)
	_expect(results.is_empty() and actions == [ActionType.REMOVE_CARD], "Cancelled queued interaction ignores a late action result.")
	_expect(f.to.currentCard == f.source, "Cancelling and clearing queued removal leaves source in place.")
	await _cleanup(f)

func _testFailure(afterRemoval: bool) -> void:
	var f := _fixture()
	_begin(f)
	if afterRemoval:
		GlobalSignalBus.boardStateChanged.connect(func():
			f.player.health = 0
		, CONNECT_ONE_SHOT)
	else:
		f.board.remove_from_group("boardController")
	GlobalSignalBus.emitEncounterOutcomeRequested(&"roadside_corpse", EncounterDefinition.Outcome.CONTINUE)
	await _settle()
	_expect(results.size() == 1 and !results[0].succeeded, "Failed consequence emits one typed failure.")
	_expect(ActionType.MOVE_CARD not in actions, "Failed removal or invalid player prevents movement.")
	_expect(results[0].context.sourceRemoved == afterRemoval, "Partial progress remains available for turn recovery.")
	await _cleanup(f)

func _settle() -> void:
	for frame in range(240):
		if !results.is_empty() and !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	_expect(false, "Encounter did not settle.")

func _cleanup(f: Dictionary) -> void:
	ActionQueue.clearQueue()
	f.host.queue_free()
	await get_tree().process_frame
	Graveyard.reset()
	InputManager.unlockInput()

func _onCompleted(result: EncounterResult) -> void:
	results.append(result)

func _onEnqueued(action: GameAction) -> void:
	actions.append(action.type)

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
