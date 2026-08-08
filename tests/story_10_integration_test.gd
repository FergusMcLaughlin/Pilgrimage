extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")
const JOURNEY_DECK_SCENE := preload("res://src/main/decks/deck_types/journey_deck.tscn")

var _createdNodes: Array[Node] = []
var _passed := 0


func _ready() -> void:
	await _runTest(_testRevealWaitIgnoresUnrelatedResolution)
	await _runTest(_testGoatmanRevealTriggersHealthEffect)
	await _runTest(_testRapidRevealRequestsUseDifferentSlots)
	await _runTest(_testFillEmptySlotsTriggersRevealEffects)

	print("PASS: Story 10 integration tests (%s passed)" % _passed)
	get_tree().quit(0)


func _runTest(testMethod: Callable) -> void:
	await _beforeEach()
	await testMethod.call()
	_passed += 1
	await _afterEach()


func _beforeEach() -> void:
	await _waitForProcessor()
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()


func _afterEach() -> void:
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()

	for node in _createdNodes:
		if is_instance_valid(node):
			node.queue_free()
	_createdNodes.clear()

	await get_tree().process_frame


func _testRevealWaitIgnoresUnrelatedResolution() -> void:
	var fixture := await _createFixture(["M_0002"])
	var looseCard := _createCard("M_0001")
	var unrelatedAction := ActionType.make(
		ActionType.MODIFY_STATS,
		null,
		looseCard,
		{"stat": "attack", "amount": 1},
	)
	assert(ActionQueue.enqueueAction(unrelatedAction))

	var revealedCard: Card = await fixture.deck.revealToNextEmptySlot()
	await _waitForProcessor(240)

	assert(revealedCard != null, "The reveal wait must continue past an unrelated resolution.")
	assert(revealedCard.data.id == "M_0002", "The reveal must return its own resolved card.")
	assert(looseCard.attack == looseCard.data.baseAttack + 1)


func _testGoatmanRevealTriggersHealthEffect() -> void:
	var fixture := await _createFixture(["M_0002"])
	var resolvedTypes: Array[String] = []
	var recordResolved := func(action: Dictionary, _result: Variant) -> void:
		resolvedTypes.append(action.get("type", ""))
	GlobalSignalBus.actionResolved.connect(recordResolved)

	var goatman: Card = await fixture.deck.revealToNextEmptySlot()
	await _waitForProcessor(240)
	GlobalSignalBus.actionResolved.disconnect(recordResolved)

	assert(goatman != null, "A queued Goatman reveal must return the placed card.")
	assert(goatman == fixture.grid.getSlotAt(Vector2i(0, 0)).currentCard)
	assert(goatman.health == 5, "Goatman must gain 2 health after its reveal resolves.")
	assert(
		resolvedTypes == [ActionType.REVEAL_CARD, ActionType.MODIFY_STATS],
		"The reveal must resolve before its on_play stat action.",
	)


func _testRapidRevealRequestsUseDifferentSlots() -> void:
	var fixture := await _createFixture(["M_0001", "M_0003", "M_0004"])

	fixture.deck.queueRevealToNextEmptySlot()
	fixture.deck.queueRevealToNextEmptySlot()
	fixture.deck.queueRevealToNextEmptySlot()
	await _waitForDeck(fixture.deck, 360)

	var occupiedSlots: Array[CardSlot] = fixture.grid.getOccupiedSlots()
	assert(occupiedSlots.size() == 3, "Three rapid requests must reveal three cards.")
	var revealedCards: Array[Card] = []
	for slot in occupiedSlots:
		assert(slot.currentCard not in revealedCards, "Each reveal must occupy a different slot.")
		revealedCards.append(slot.currentCard)


func _testFillEmptySlotsTriggersRevealEffects() -> void:
	var fixture := await _createFixture(["M_0002", "M_0001"])

	await fixture.deck.fillEmptySlots(fixture.grid)
	await _waitForProcessor(360)

	var occupiedSlots: Array[CardSlot] = fixture.grid.getOccupiedSlots()
	assert(occupiedSlots.size() == 2, "Board filling must stop cleanly when the deck empties.")
	var goatman := occupiedSlots[0].currentCard
	assert(goatman.data.id == "M_0002")
	assert(goatman.health == 5, "Board-filled reveals must also trigger on_play effects.")


func _createFixture(cardIds: Array[String]) -> Dictionary:
	var root := Node.new()
	root.name = "Story10Fixture"

	var grid: SlotGrid = SLOT_GRID_SCENE.instantiate()
	grid.name = "SlotGrid"
	var controller := BoardController.new()
	controller.name = "BoardController"
	controller.slotGridPath = NodePath("../SlotGrid")
	var deck: JourneyDeck = JOURNEY_DECK_SCENE.instantiate()
	deck.name = "JourneyDeck"

	root.add_child(grid)
	root.add_child(controller)
	root.add_child(deck)
	add_child(root)
	_createdNodes.append(root)
	await get_tree().process_frame

	deck.boardController = controller
	deck.slotGrid = grid
	deck.journeyDeckCardBag.initialiseDeck(cardIds, false)
	deck.deckVisuals.refresh()

	return {
		"root": root,
		"grid": grid,
		"controller": controller,
		"deck": deck,
	}


func _createCard(cardId: String) -> Card:
	var card := CreateCard.new().createCard(cardId)
	assert(card != null, "Test setup could not create card %s." % cardId)
	add_child(card)
	_createdNodes.append(card)
	return card


func _waitForDeck(deck: JourneyDeck, maxFrames := 360) -> void:
	for _frame in range(maxFrames):
		if (
			!deck.isProcessingRevealQueue
			and deck.pendingRevealRequests == 0
			and !ActionQueue.queueHasActions()
			and !ActionProcessor.isProcessingAction
		):
			return
		await get_tree().process_frame

	assert(false, "JourneyDeck did not finish after %s frames." % maxFrames)


func _waitForProcessor(maxFrames := 120) -> void:
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame

	assert(false, "ActionProcessor did not become idle after %s frames." % maxFrames)
