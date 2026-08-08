# Permanent integration tests for the Story 8.5 action processor contract.
# No addon is required: run the scene with F6 or headlessly.
extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE := preload("res://src/main/decks/deck_types/journey_deck.tscn")

var _passed := 0
var _createdNodes: Array[Node] = []


func _ready() -> void:
	await _runTests()
	print("PASS: ActionProcessor tests (%s passed)" % _passed)
	get_tree().quit()


func _runTests() -> void:
	# Keep tests independent. Each test gets clean shared state.
	await _runTest(_testModifyStatsThroughQueue)
	await _runTest(_testNegativeHealthModificationDealsDamage)
	await _runTest(_testMalformedModifyDoesNotWedgeQueue)
	await _runTest(_testDeleteCardOutsideActivePlay)
	await _runTest(_testTwoActionsKeepFifoOrder)
	await _runTest(_testUnsupportedActionDoesNotBlockNextAction)
	await _runTest(_testMoveChangesSlots)
	await _runTest(_testRemoveMovesCardToGraveyard)
	await _runTest(_testDeleteClearsSlotBeforeFreeing)
	await _runTest(_testRevealBlocksUntilAnimationFinishes)


func _runTest(testMethod: Callable) -> void:
	await _beforeEach()
	await testMethod.call()
	_passed += 1
	await _afterEach()


func _beforeEach() -> void:
	# Autoloads survive for the whole test run. Do not inherit queued work
	# from the previous test.
	await _waitForProcessor()
	ActionQueue.clearQueue()
	Graveyard.reset()
	BoardHistory.reset()


func _afterEach() -> void:
	ActionQueue.clearQueue()
	Graveyard.reset()
	BoardHistory.reset()

	# Track everything created by a test and clean it in one place.
	for node in _createdNodes:
		if is_instance_valid(node):
			node.queue_free()

	_createdNodes.clear()

	# queue_free() completes at the end of the frame.
	await get_tree().process_frame


func _testModifyStatsThroughQueue() -> void:
	# Arrange: build a real card, just as game code does.
	var card := _createCard("M_0001")
	var startingHealth := card.health

	# Act: test the public flow, not ActionProcessor's private handler.
	var action := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		card,
		{"stat": "health", "amount": 2},
	)
	assert(ActionQueue.enqueueAction(action), "The valid action should enter the queue.")
	await _waitForProcessor()

	# Assert: use a message that explains the expected behaviour.
	assert(
		card.health == startingHealth + 2,
		"MODIFY_STATS should add 2 health through the action queue.",
	)


func _testMalformedModifyDoesNotWedgeQueue() -> void:
	# A malformed action-specific payload still has a valid shared envelope,
	# so ActionQueue accepts it and ActionProcessor must reject it safely.
	var card := _createCard("M_0001")
	var startingHealth := card.health
	var action := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		card,
		{"stat": "not_a_stat", "amount": 2},
	)

	assert(ActionQueue.enqueueAction(action))
	await _waitForProcessor()

	assert(card.health == startingHealth, "Invalid stat data must not change the card.")
	assert(!ActionProcessor.isProcessingAction, "A rejected action must not wedge the processor.")
	assert(!ActionQueue.queueHasActions(), "The rejected action should be consumed safely.")


func _testNegativeHealthModificationDealsDamage() -> void:
	var card := _createCard("M_0001")
	var action := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		card,
		{"stat": "health", "amount": -(card.health + 10)},
	)

	assert(ActionQueue.enqueueAction(action))
	await _waitForProcessor()

	assert(card.health == 0, "Negative health modification should deal damage and clamp at zero.")
	assert(is_instance_valid(card), "Zero health must not remove or delete the card automatically.")


func _testDeleteCardOutsideActivePlay() -> void:
	var card := _createCard("M_0001")
	var action := ActionType.make(ActionType.DELETE_CARD, null, card)

	assert(ActionQueue.enqueueAction(action))
	await _waitForProcessor()
	await get_tree().process_frame

	assert(!is_instance_valid(card), "DELETE_CARD should free a card that is outside active play.")


func _testTwoActionsKeepFifoOrder() -> void:
	var card := _createCard("M_0001")
	var poppedAmounts: Array[int] = []
	var recordPopped := func(action: Dictionary) -> void:
		if action.get("type") == ActionType.MODIFY_STATS:
			poppedAmounts.append(action.get("data", {}).get("amount", 0))

	GlobalSignalBus.actionPopped.connect(recordPopped)
	ActionQueue.enqueueAction(ActionType.make(
		ActionType.MODIFY_STATS, null, card, {"stat": "attack", "amount": 3}
	))
	ActionQueue.enqueueAction(ActionType.make(
		ActionType.MODIFY_STATS, null, card, {"stat": "attack", "amount": -1}
	))
	await _waitForProcessor()
	GlobalSignalBus.actionPopped.disconnect(recordPopped)

	assert(poppedAmounts == [3, -1], "Actions must be popped in insertion order.")
	assert(card.attack == card.data.baseAttack + 2, "Both FIFO stat changes should resolve.")


func _testUnsupportedActionDoesNotBlockNextAction() -> void:
	var card := _createCard("M_0001")
	var startingAttack := card.attack

	assert(ActionQueue.enqueueAction(ActionType.make(ActionType.DRAW_CARD)))
	assert(ActionQueue.enqueueAction(ActionType.make(
		ActionType.MODIFY_STATS, null, card, {"stat": "attack", "amount": 2}
	)))
	await _waitForProcessor()

	assert(card.attack == startingAttack + 2, "An action after an unsupported action must resolve.")
	assert(!ActionProcessor.isProcessingAction, "Unsupported actions must not wedge the processor.")


func _testMoveChangesSlots() -> void:
	var board := await _createBoardFixture()
	var card := _createCard("M_0001")
	var source: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	var destination: CardSlot = board.grid.getSlotAt(Vector2i(1, 0))

	assert(board.controller.placeCard(card, source), "Test setup should place the card.")
	assert(ActionQueue.enqueueAction(ActionType.make(ActionType.MOVE_CARD, card, destination)))
	await _waitForProcessor()

	assert(source.currentCard == null, "MOVE_CARD must clear the source slot.")
	assert(destination.currentCard == card, "MOVE_CARD must fill the destination slot.")


func _testRemoveMovesCardToGraveyard() -> void:
	var board := await _createBoardFixture()
	var card := _createCard("M_0001")
	var slot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	var instanceId := card.instanceId

	assert(board.controller.placeCard(card, slot), "Test setup should place the card.")
	assert(ActionQueue.enqueueAction(ActionType.make(
		ActionType.REMOVE_CARD,
		null,
		card,
		{"cause": "test"},
	)))
	await _waitForProcessor()
	await get_tree().process_frame

	assert(slot.currentCard == null, "REMOVE_CARD must clear the occupied slot.")
	assert(!is_instance_valid(card), "REMOVE_CARD must free the old visual card node.")
	assert(Graveyard.entries.size() == 1, "REMOVE_CARD must add one graveyard entry.")
	assert(Graveyard.entries[0].instanceId == instanceId)
	assert(Graveyard.entries[0].cause == "test")
	assert(BoardHistory.getEvents("removed").size() == 1)


func _testDeleteClearsSlotBeforeFreeing() -> void:
	var board := await _createBoardFixture()
	var card := _createCard("M_0001")
	var slot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))

	assert(board.controller.placeCard(card, slot), "Test setup should place the card.")
	assert(ActionQueue.enqueueAction(ActionType.make(ActionType.DELETE_CARD, null, card)))
	await _waitForProcessor()
	await get_tree().process_frame

	assert(slot.currentCard == null, "DELETE_CARD must clear the occupied slot.")
	assert(!is_instance_valid(card), "DELETE_CARD must free the occupied card.")
	assert(Graveyard.entries.is_empty(), "DELETE_CARD must bypass the graveyard.")
	assert(BoardHistory.getEvents("deleted").size() == 1)


func _testRevealBlocksUntilAnimationFinishes() -> void:
	var board := await _createBoardFixture()
	var deck: JourneyDeck = JOURNEY_DECK_SCENE.instantiate()
	board.fixture.add_child(deck)
	deck.boardController = board.controller
	deck.slotGrid = board.grid
	deck.initialiseJourneyDeck(false)
	var slot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	var resolvedCards: Array[Card] = []
	var recordResolved := func(action: Dictionary, result: Variant) -> void:
		if action.get("type") == ActionType.REVEAL_CARD:
			resolvedCards.append(result as Card)

	GlobalSignalBus.actionResolved.connect(recordResolved)

	assert(ActionQueue.enqueueAction(ActionType.make(ActionType.REVEAL_CARD, deck, slot)))
	await get_tree().process_frame

	assert(ActionProcessor.isProcessingAction, "REVEAL_CARD must stay busy during its tween.")
	assert(slot.currentCard == null, "The slot must not fill before reveal animation finishes.")
	await _waitForProcessor(240)
	GlobalSignalBus.actionResolved.disconnect(recordResolved)

	assert(slot.currentCard != null, "REVEAL_CARD must place a card after its tween.")
	assert(resolvedCards.size() == 1, "REVEAL_CARD must publish one resolved result.")
	assert(resolvedCards[0] == slot.currentCard, "The resolved result must be the placed card.")
	assert(!ActionProcessor.isProcessingAction, "The processor must become idle after reveal.")


func _createBoardFixture() -> Dictionary:
	var fixture := Node.new()
	fixture.name = "BoardFixture"
	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var controller := BoardController.new()
	controller.name = "BoardController"
	controller.slotGridPath = NodePath("../SlotGrid")
	fixture.add_child(grid)
	fixture.add_child(controller)
	add_child(fixture)
	_createdNodes.append(fixture)
	await get_tree().process_frame

	return {"fixture": fixture, "grid": grid, "controller": controller}


func _createCard(cardId: String) -> Card:
	# CreateCard supplies real CardData and the real card scene.
	var card := CreateCard.new().createCard(cardId)
	assert(card != null, "Test setup could not create card %s." % cardId)

	add_child(card)
	_createdNodes.append(card)

	# add_child() makes the card ready, including its visuals.
	return card


func _waitForProcessor(maxFrames := 120) -> void:
	# Async tests need a timeout so a broken queue cannot hang forever.
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame

	assert(false, "ActionProcessor did not become idle after %s frames." % maxFrames)
