extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE := preload("res://src/main/decks/deck_types/journey_deck.tscn")

var _results: Array[BoardRefillResult] = []
var _requests: Array[BoardRefillRequest] = []
var _enqueuedTypes: Array[String] = []
var _passed := 0
var _failures := 0


func _ready() -> void:
	GlobalSignalBus.boardRefillCompleted.connect(_recordResult)
	GlobalSignalBus.boardRefillRequested.connect(_recordRequest)
	GlobalSignalBus.actionEnqueued.connect(_recordAction)
	_testRequestContract()
	await _testInvalidTargets()
	await _testEmptyDeckSkipped()
	await _testSuccessfulExactSlotRefill()
	await _testGameControllerRefillBoundary()
	await _testCombatWithoutMovementSkipsRefill()
	if _failures > 0:
		push_error("FAIL: Story 13 board refill tests (%s failures, %s passed)" % [_failures, _passed])
		get_tree().quit(1)
		return
	print("PASS: Story 13 board refill tests (%s passed)" % _passed)
	get_tree().quit(0)


func _testRequestContract() -> void:
	var slot := CardSlot.new()
	var request := BoardRefillRequest.forEmptySlot(slot, 4)
	_expect(request.slot == slot, "A refill request must identify one exact slot.")
	_expect(request.cycleNumber == 4, "A refill request must retain its cycle number.")
	_expect(request.cause == "player_moved", "A refill request must identify why maintenance is needed.")


func _testInvalidTargets() -> void:
	var fixture := await _createRefillFixture(false)
	fixture.controller._onBoardRefillRequested(BoardRefillRequest.forEmptySlot(null, 4))
	await get_tree().process_frame
	_expect(_results.size() == 1 and !_results[0].succeeded, "A null refill slot must emit one failed result.")
	_results.clear()
	var occupied: CardSlot = fixture.grid.getSlotAt(Vector2i(0, 0))
	_expect(fixture.board.placeCard(CreateCard.new().createCard("M_0001"), occupied), "Occupied-slot fixture must be placed.")
	fixture.controller._onBoardRefillRequested(BoardRefillRequest.forEmptySlot(occupied, 4))
	await get_tree().process_frame
	_expect(_results.size() == 1 and !_results[0].succeeded, "An occupied refill slot must emit one failed result.")
	_expect(_enqueuedTypes.is_empty(), "Invalid refill requests must enqueue no reveal action.")
	await _destroyFixture(fixture.root)


func _testEmptyDeckSkipped() -> void:
	var fixture := await _createRefillFixture(false)
	var slot: CardSlot = fixture.grid.getSlotAt(Vector2i(0, 0))
	fixture.controller._onBoardRefillRequested(BoardRefillRequest.forEmptySlot(slot, 4))
	await get_tree().process_frame
	_expect(_results.size() == 1, "An empty deck must emit exactly one completed result.")
	var result: BoardRefillResult = _results[0]
	_expect(result.succeeded and result.skipped and result.revealedCard == null, "An empty deck must produce a successful skipped result.")
	_expect(slot.currentCard == null and _enqueuedTypes.is_empty(), "A skipped refill must leave the slot open and enqueue nothing.")
	await _destroyFixture(fixture.root)


func _testSuccessfulExactSlotRefill() -> void:
	var fixture := await _createRefillFixture(true)
	var requested: CardSlot = fixture.grid.getSlotAt(Vector2i(0, 0))
	var untouched: CardSlot = fixture.grid.getSlotAt(Vector2i(2, 2))
	fixture.controller._onBoardRefillRequested(BoardRefillRequest.forEmptySlot(requested, 8))
	await _waitForResult()
	_expect(_results.size() == 1 and _results[0].succeeded and !_results[0].skipped, "A valid refill must emit one successful result.")
	_expect(_results[0].revealedCard != null and requested.currentCard == _results[0].revealedCard, "The revealed card must be returned only through BoardRefillResult and placed in the requested slot.")
	_expect(untouched.currentCard == null, "A refill must leave every other empty slot unchanged.")
	_expect(_enqueuedTypes == [ActionType.REVEAL_CARD], "A valid refill must enqueue exactly one REVEAL_CARD.")
	await _destroyFixture(fixture.root)


func _testGameControllerRefillBoundary() -> void:
	await _resetSignals()
	var controller := GameController.new()
	add_child(controller)
	controller.playerCard = _makeBareCard()
	controller.playerCycleNumber = 4
	controller.state = GameController.GameState.COMBAT
	InputManager.lockInput()
	var context := CombatContext.new()
	context.playerSlot = CardSlot.new()
	context.cycleNumber = 4
	var combat := CombatResult.new()
	combat.context = context
	combat.succeeded = true
	combat.playerMoved = true
	GlobalSignalBus.emitCombatEnded(combat)
	await get_tree().process_frame
	_expect(_requests.size() == 1 and _requests[0].slot == context.playerSlot, "Moved combat must request refill for the previous player slot exactly once.")
	_expect(controller.state == GameController.GameState.COMBAT and InputManager.inputLocked, "GameController must wait for boardRefillCompleted before AFTER_MOVE.")
	var failedRefill := BoardRefillResult.new()
	failedRefill.request = _requests[0]
	failedRefill.failureReason = "fixture failure"
	GlobalSignalBus.emitBoardRefillResult(failedRefill)
	await _waitForReady(controller)
	_expect(controller.state == GameController.GameState.PLAYER_READY, "Refill failure must still settle the player cycle safely.")
	_expect(!InputManager.inputLocked, "A settled cycle must unlock input.")
	_expect(!ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction, "The action system must be idle after cycle completion.")
	controller.queue_free()
	await get_tree().process_frame


func _testCombatWithoutMovementSkipsRefill() -> void:
	await _resetSignals()
	var controller := GameController.new()
	add_child(controller)
	controller.playerCard = _makeBareCard()
	controller.playerCycleNumber = 9
	controller.state = GameController.GameState.COMBAT
	InputManager.lockInput()
	var combat := CombatResult.new()
	combat.context = CombatContext.new()
	combat.succeeded = true
	combat.playerMoved = false
	GlobalSignalBus.emitCombatEnded(combat)
	await _waitForReady(controller)
	_expect(_requests.is_empty(), "Combat without player movement must not request a refill.")
	_expect(controller.state == GameController.GameState.PLAYER_READY and !InputManager.inputLocked, "Combat without maintenance must complete and unlock input.")
	controller.queue_free()
	await get_tree().process_frame


func _createRefillFixture(withCards: bool) -> Dictionary:
	await _resetSignals()
	var root := Node.new()
	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var board := BoardController.new()
	board.name = "BoardController"
	board.slotGridPath = NodePath("../SlotGrid")
	var deck: JourneyDeck = JOURNEY_DECK_SCENE.instantiate()
	var controller := BoardRefillController.new()
	root.add_child(grid)
	root.add_child(board)
	root.add_child(deck)
	root.add_child(controller)
	add_child(root)
	await get_tree().process_frame
	deck.boardController = board
	deck.slotGrid = grid
	controller.journeyDeck = deck
	if withCards:
		deck.initialiseJourneyDeck(false)
	return {"root": root, "grid": grid, "board": board, "deck": deck, "controller": controller}


func _destroyFixture(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame
	await _resetSignals()


func _waitForResult(maxFrames := 240) -> void:
	for _frame in range(maxFrames):
		if !_results.is_empty():
			return
		await get_tree().process_frame
	_expect(false, "Board refill did not settle within %s frames." % maxFrames)


func _waitForReady(controller: GameController, maxFrames := 240) -> void:
	for _frame in range(maxFrames):
		if controller.state == GameController.GameState.PLAYER_READY:
			return
		await get_tree().process_frame
	_expect(false, "GameController did not return to PLAYER_READY.")


func _resetSignals() -> void:
	for _frame in range(240):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			break
		await get_tree().process_frame
	ActionQueue.clearQueue()
	_results.clear()
	_requests.clear()
	_enqueuedTypes.clear()


func _makeBareCard() -> Card:
	var card := Card.new()
	var data := CardData.new()
	data.id = "player"
	card.data = data
	return card


func _recordResult(result: BoardRefillResult) -> void:
	_results.append(result)


func _recordRequest(request: BoardRefillRequest) -> void:
	_requests.append(request)


func _recordAction(action: Dictionary) -> void:
	_enqueuedTypes.append(action.type)


func _expect(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		return
	_failures += 1
	push_error(message)
