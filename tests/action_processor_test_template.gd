# Lightweight test template for Story 8.5 and later gameplay systems.
#
# Duplicate this script and its .tscn file when starting another test suite.
# No addon is required: run the scene with F6 and read the assertions/output.
# The two example tests are expected to pass after the Story 8.5 handlers exist.
extends Node

var _passed := 0
var _createdNodes: Array[Node] = []


func _ready() -> void:
	await _runTests()
	print("PASS: ActionProcessor template tests (%s passed)" % _passed)
	get_tree().quit()


func _runTests() -> void:
	# Keep tests independent. Each test gets clean shared state.
	await _runTest(_testModifyStatsThroughQueue)
	await _runTest(_testNegativeHealthModificationDealsDamage)
	await _runTest(_testMalformedModifyDoesNotWedgeQueue)
	await _runTest(_testDeleteCardOutsideActivePlay)

	# Add Story 8.5 tests here, one at a time:
	# await _runTest(_testTwoActionsKeepFifoOrder)
	# await _runTest(_testMoveChangesSlots)
	# await _runTest(_testRemoveClearsSlotWithoutFreeing)
	# await _runTest(_testDeleteClearsSlotBeforeFreeing)
	# await _runTest(_testRevealBlocksUntilAnimationFinishes)


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


func _afterEach() -> void:
	ActionQueue.clearQueue()

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
