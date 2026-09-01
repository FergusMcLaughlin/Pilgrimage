extends Node

const SLOT_GRID_SCENE = preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE = preload("res://src/main/decks/deck_types/journey_deck.tscn")

var _results: Array[BoardRefillResult] = []
var _actions: Array[String] = []
var _passed = 0
var _failures = 0


func _ready() -> void:
	GlobalSignalBus.boardRefillCompleted.connect(_recordResult)
	GlobalSignalBus.actionEnqueued.connect(_recordAction)
	await _testShiftThenRevealAtFinalVacancy()
	await _testEmptyDeckStillShifts()
	await _testBottomRightFallbackExecutesAllRowSteps()
	await _testMiddleRightFallbackExecutesColumnStep()
	await _testPlanningFailureEmitsOneResultAndNoActions()
	await _testMoveFailureEmitsOneResultAndNeverReveals()
	await _testGameControllerWaitsForCompleteMaintenance()
	await _testStaleRequestFailsBeforePlanning()
	await _testMissingPlannedSourceFailsBeforeQueueingMove()
	await _testOccupiedPlannedDestinationFailsBeforeQueueingMove()
	await _testPlayerStepFailsBeforeQueueingMove()

	if _failures > 0:
		push_error("FAIL: Board refill shift integration tests (%s failures, %s passed)" % [_failures, _passed])
		get_tree().quit(1)
		return

	print("PASS: Board refill shift integration tests (%s passed)" % _passed)
	get_tree().quit(0)


func _testShiftThenRevealAtFinalVacancy() -> void:
	var fixture = await _createFixture(true)
	var sourceCard = _placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1, "Successful refill must emit exactly one result.")
	var result: BoardRefillResult = _results[0] if !_results.is_empty() else null
	_expect(result != null and result.succeeded and !result.skipped, "A populated deck must reveal after shifting.")
	_expect(result != null and result.completedSteps.size() == 1, "Successful right refill must record one completed shift.")
	_expect(fixture.grid.getSlotAt(Vector2i(1, 1)).currentCard == sourceCard, "The existing card must fill the player vacancy before reveal.")
	_expect(result != null and fixture.grid.getSlotAt(Vector2i(0, 1)).currentCard == result.revealedCard, "The replacement card must enter at the final edge vacancy.")
	_expect(_actions == [ActionType.MOVE_CARD, ActionType.REVEAL_CARD], "Refill must queue MOVE_CARD before exactly one REVEAL_CARD.")
	await _destroyFixture(fixture)


func _testEmptyDeckStillShifts() -> void:
	var fixture = await _createFixture(false)
	var sourceCard = _placeCard(fixture, Vector2i(2, 0))
	var request = _makeRequest(fixture, Vector2i(2, 1), Vector2i(2, 2), Vector2i.DOWN)

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1, "Empty-deck refill must emit exactly one result.")
	var result: BoardRefillResult = _results[0] if !_results.is_empty() else null
	_expect(result != null and result.succeeded and result.skipped, "An empty deck must succeed as skipped after shifting.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 1)).currentCard == sourceCard, "The required card shift must happen even when the deck is empty.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 0)).currentCard == null, "The final edge vacancy must remain open when the deck is empty.")
	_expect(_actions == [ActionType.MOVE_CARD], "Empty-deck refill must not queue REVEAL_CARD.")
	await _destroyFixture(fixture)


func _testBottomRightFallbackExecutesAllRowSteps() -> void:
	var fixture = await _createFixture(false)
	var middleCard = _placeCard(fixture, Vector2i(1, 2))
	var leftCard = _placeCard(fixture, Vector2i(0, 2))
	var request = _makeRequest(fixture, Vector2i(2, 2), Vector2i(2, 1), Vector2i.UP)

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1 and _results[0].succeeded and _results[0].skipped, "Bottom-right fallback must finish successfully with an empty deck.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 2)).currentCard == middleCard, "Bottom-middle must shift into bottom-right.")
	_expect(fixture.grid.getSlotAt(Vector2i(1, 2)).currentCard == leftCard, "Bottom-left must shift into bottom-middle.")
	_expect(fixture.grid.getSlotAt(Vector2i(0, 2)).currentCard == null, "Bottom-left must be the final empty refill slot.")
	_expect(_actions == [ActionType.MOVE_CARD, ActionType.MOVE_CARD], "Bottom-right fallback must execute two MOVE_CARD actions in order.")
	await _destroyFixture(fixture)


func _testMiddleRightFallbackExecutesColumnStep() -> void:
	var fixture = await _createFixture(false)
	var topCard = _placeCard(fixture, Vector2i(2, 0))
	var request = _makeRequest(fixture, Vector2i(2, 1), Vector2i(1, 1), Vector2i.LEFT)

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1 and _results[0].succeeded and _results[0].skipped, "Middle-right fallback must finish successfully with an empty deck.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 1)).currentCard == topCard, "Top-right must shift down into middle-right.")
	_expect(fixture.grid.getSlotAt(Vector2i(2, 0)).currentCard == null, "Top-right must be the final empty refill slot.")
	_expect(_actions == [ActionType.MOVE_CARD], "Middle-right fallback must execute one MOVE_CARD action.")
	await _destroyFixture(fixture)


func _testPlanningFailureEmitsOneResultAndNoActions() -> void:
	var fixture = await _createFixture(false)
	var request = _makeRequest(fixture, Vector2i(2, 2), Vector2i(2, 1), Vector2i.UP)

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1, "Planning failure must emit exactly one result.")
	var result: BoardRefillResult = _results[0] if !_results.is_empty() else null
	_expect(result != null and !result.succeeded and result.plan != null and !result.plan.succeeded, "Planning failure must retain the failed plan.")
	_expect(_actions.is_empty(), "Planning failure must queue no actions.")
	await _destroyFixture(fixture)


func _testMoveFailureEmitsOneResultAndNeverReveals() -> void:
	var fixture = await _createFixture(true)
	_placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	fixture.board.remove_from_group("boardController")

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResults(2)

	_expect(_results.size() == 1, "Movement failure must emit exactly one result.")
	var result: BoardRefillResult = _results[0] if !_results.is_empty() else null
	_expect(result != null and !result.succeeded and !result.failureReason.is_empty(), "Movement failure must be typed.")
	_expect(_actions == [ActionType.MOVE_CARD], "Movement failure must never queue reveal.")
	await _destroyFixture(fixture)


func _testGameControllerWaitsForCompleteMaintenance() -> void:
	var fixture = await _createFixture(false, true)
	var sourceCard = _placeCard(fixture, Vector2i(0, 1))
	var oldSlot: CardSlot = fixture.grid.getSlotAt(Vector2i(1, 1))
	var destinationSlot: CardSlot = fixture.grid.getSlotAt(Vector2i(2, 1))
	var player = _placePlayer(fixture, destinationSlot)
	fixture.game.playerCard = player
	fixture.game.playerCycleNumber = 7
	fixture.game.state = GameController.GameState.COMBAT
	InputManager.lockInput()

	var context = CombatContext.new()
	context.playerSlot = oldSlot
	context.targetSlot = destinationSlot
	context.cycleNumber = 7
	var combat = CombatResult.new()
	combat.context = context
	combat.succeeded = true
	combat.playerMoved = true

	GlobalSignalBus.emitCombatEnded(combat)
	await _waitForReady(fixture.game)

	_expect(_results.size() == 1 and _results[0].succeeded and _results[0].skipped, "GameController refill boundary must complete after empty-deck shifting.")
	_expect(oldSlot.currentCard == sourceCard, "GameController must wait until the planned shift has completed.")
	_expect(fixture.game.state == GameController.GameState.PLAYER_READY and !InputManager.inputLocked, "GameController must unlock input only after maintenance completes.")
	await _destroyFixture(fixture)


func _testStaleRequestFailsBeforePlanning() -> void:
	var fixture = await _createFixture(false, true)
	_placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	fixture.game.playerCycleNumber = 7
	fixture.game.state = GameController.GameState.COMBAT
	request.cycleNumber = 6

	fixture.controller._onBoardRefillRequested(request)
	await _waitForResult()

	_expect(_results.size() == 1, "A stale refill request must emit exactly one result.")
	var result: BoardRefillResult = _results[0] if !_results.is_empty() else null
	_expect(result != null and !result.succeeded, "A stale refill request must fail.")
	_expect(_actions.is_empty(), "A stale refill request must queue no actions.")
	_expect(fixture.grid.getSlotAt(Vector2i(1, 1)).currentCard == null, "A stale request must leave the vacancy unchanged.")
	await _destroyFixture(fixture)


func _testMissingPlannedSourceFailsBeforeQueueingMove() -> void:
	var fixture = await _createFixture(false)
	var sourceCard = _placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	var plan = fixture.controller.boardShiftPlanner.planBoardShift(fixture.grid, request)
	var result = BoardRefillResult.new()
	result.request = request
	fixture.board.removeCard(sourceCard)

	var succeeded = await fixture.controller._processShiftPlan(plan, result)

	_expect(!succeeded, "A missing planned source card must reject execution.")
	_expect(_actions.is_empty(), "A missing planned source card must fail before MOVE_CARD is queued.")
	await _destroyFixture(fixture)


func _testOccupiedPlannedDestinationFailsBeforeQueueingMove() -> void:
	var fixture = await _createFixture(false)
	_placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	var plan = fixture.controller.boardShiftPlanner.planBoardShift(fixture.grid, request)
	var result = BoardRefillResult.new()
	result.request = request
	_placeCard(fixture, Vector2i(1, 1))

	var succeeded = await fixture.controller._processShiftPlan(plan, result)

	_expect(!succeeded, "An occupied planned destination must reject execution.")
	_expect(_actions.is_empty(), "An occupied planned destination must fail before MOVE_CARD is queued.")
	await _destroyFixture(fixture)


func _testPlayerStepFailsBeforeQueueingMove() -> void:
	var fixture = await _createFixture(false)
	_placeCard(fixture, Vector2i(0, 1))
	var request = _makeRequest(fixture, Vector2i(1, 1), Vector2i(2, 1), Vector2i.RIGHT)
	var plan = fixture.controller.boardShiftPlanner.planBoardShift(fixture.grid, request)
	var result = BoardRefillResult.new()
	result.request = request
	var player: Card = request.playerDestinationSlot.currentCard
	plan.steps[0].card = player

	var succeeded = await fixture.controller._processShiftPlan(plan, result)

	_expect(!succeeded, "A plan that tries to move the player must reject execution.")
	_expect(_actions.is_empty(), "A player shift must fail before MOVE_CARD is queued.")
	await _destroyFixture(fixture)


func _createFixture(withDeckCards: bool, includeGameController: bool = true) -> Dictionary:
	await _resetState()
	var root = Node.new()
	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var board = BoardController.new()
	board.name = "BoardController"
	board.slotGridPath = NodePath("../SlotGrid")
	var deck: JourneyDeck = JOURNEY_DECK_SCENE.instantiate()
	var controller = BoardRefillController.new()
	root.add_child(grid)
	root.add_child(board)
	root.add_child(deck)
	root.add_child(controller)
	var game: GameController = null
	if includeGameController:
		game = GameController.new()
		root.add_child(game)
	add_child(root)
	await get_tree().process_frame

	deck.boardController = board
	deck.slotGrid = grid
	controller.journeyDeck = deck
	controller.slotGrid = grid
	controller.gameController = game
	game.playerCycleNumber = 7
	game.state = GameController.GameState.COMBAT
	if withDeckCards:
		deck.initialiseJourneyDeck(false)
	return {"root": root, "grid": grid, "board": board, "deck": deck, "controller": controller, "game": game}


func _makeRequest(fixture: Dictionary, vacatedCoordinates: Vector2i, destinationCoordinates: Vector2i, direction: Vector2i) -> BoardRefillRequest:
	var vacatedSlot: CardSlot = fixture.grid.getSlotAt(vacatedCoordinates)
	var destinationSlot: CardSlot = fixture.grid.getSlotAt(destinationCoordinates)
	if destinationSlot.currentCard == null:
		_placePlayer(fixture, destinationSlot)
	return BoardRefillRequest.afterPlayerMove(vacatedSlot, destinationSlot, direction, 7)


func _placePlayer(fixture: Dictionary, slot: CardSlot) -> Card:
	var player = CreateCard.new().createCard("C_0000")
	_expect(fixture.board.placeCard(player, slot), "Fixture player must be placed.")
	return player


func _placeCard(fixture: Dictionary, coordinates: Vector2i) -> Card:
	var card = CreateCard.new().createCard("M_0001")
	_expect(fixture.board.placeCard(card, fixture.grid.getSlotAt(coordinates)), "Fixture card must be placed at %s." % coordinates)
	return card


func _waitForResult(maxFrames: int = 240) -> void:
	for _frame in range(maxFrames):
		if !_results.is_empty():
			return
		await get_tree().process_frame
	_expect(false, "Board refill did not settle.")


func _waitForResults(expectedCount: int, maxFrames: int = 240) -> void:
	for _frame in range(maxFrames):
		if _results.size() >= expectedCount:
			return
		await get_tree().process_frame
	await get_tree().process_frame


func _waitForReady(game: GameController, maxFrames: int = 240) -> void:
	for _frame in range(maxFrames):
		if game.state == GameController.GameState.PLAYER_READY:
			return
		await get_tree().process_frame
	_expect(false, "GameController did not return to PLAYER_READY.")


func _destroyFixture(fixture: Dictionary) -> void:
	fixture.root.queue_free()
	await get_tree().process_frame
	await _resetState()


func _resetState() -> void:
	for _frame in range(240):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			break
		await get_tree().process_frame
	ActionQueue.clearQueue()
	_results.clear()
	_actions.clear()
	InputManager.unlockInput()


func _recordResult(result: BoardRefillResult) -> void:
	_results.append(result)


func _recordAction(action: GameAction) -> void:
	_actions.append(action.type)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
