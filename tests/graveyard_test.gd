extends Node

const SLOT_GRID_SCENE := preload("res://src/main/board/slot_grid/slot_grid.tscn")

var _createdNodes: Array[Node] = []
var _passed := 0
var _failures := 0


func _ready() -> void:
	await _runTest(_testRemoveRecordsEntryAndHistory)
	await _runTest(_testDuplicateCardIdsRemainDistinct)
	await _runTest(_testDeleteRemovesOnlyExactEntry)
	await _runTest(_testActiveDeleteBypassesGraveyard)
	await _runTest(_testRevivePreservesIdentity)
	await _runTest(_testFailedReviveKeepsEntry)
	await _runTest(_testResetClearsEntriesAndNumbering)

	if _failures > 0:
		push_error("FAIL: Graveyard tests (%s failures)" % _failures)
		get_tree().quit(1)
		return
	print("PASS: Graveyard tests (%s passed)" % _passed)
	get_tree().quit(0)


func _runTest(testMethod: Callable) -> void:
	await _beforeEach()
	await testMethod.call()
	_passed += 1
	await _afterEach()


func _beforeEach() -> void:
	await _waitForProcessor()
	ActionQueue.clearQueue()
	Graveyard.reset()
	BoardHistory.reset()


func _afterEach() -> void:
	ActionQueue.clearQueue()
	EffectProcessor.clearEffects()
	Graveyard.reset()
	BoardHistory.reset()
	for node in _createdNodes:
		if is_instance_valid(node):
			node.queue_free()
	_createdNodes.clear()
	await get_tree().process_frame


func _testRemoveRecordsEntryAndHistory() -> void:
	var board := await _createBoardFixture()
	var attacker := _createCard("M_0001")
	var target := _createCard("M_0002")
	var targetId := target.instanceId
	var slot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	_expect(board.controller.placeCard(target, slot), "Test target should enter its slot.")

	var result = await _enqueueAndWait(ActionType.make(
		ActionType.REMOVE_CARD,
		attacker,
		target,
		{"cause": "combat"},
	))
	var entry := result as GraveyardEntry

	_expect(entry != null, "REMOVE_CARD should resolve with a GraveyardEntry.")
	if entry == null:
		return
	_expect(slot.currentCard == null, "Removal should clear the occupied slot.")
	_expect(entry.cardId == "M_0002", "The entry should retain the card definition ID.")
	_expect(entry.instanceId == targetId, "The entry should retain logical identity.")
	_expect(entry.sourceInstanceId == attacker.instanceId, "The entry should identify the attacker.")
	_expect(entry.cause == "combat", "The entry should retain the removal cause.")
	_expect(entry.statSnapshot.get("health") == 3, "The entry should snapshot health.")
	_expect(entry.removedSequence == 1, "The first removal should use sequence 1.")
	var events := BoardHistory.getEvents("removed")
	_expect(events.size() == 1, "Removal should append one history event.")
	_expect(events[0].get("removed_sequence") == 1, "History should contain the final sequence.")
	await get_tree().process_frame
	_expect(!is_instance_valid(target), "The old visual card node should be freed.")


func _testDuplicateCardIdsRemainDistinct() -> void:
	var board := await _createBoardFixture()
	var first := _createCard("M_0001")
	var second := _createCard("M_0001")
	var firstId := first.instanceId
	var secondId := second.instanceId
	_expect(firstId != secondId, "Duplicate definitions need distinct logical identities.")
	_expect(board.controller.placeCard(first, board.grid.getSlotAt(Vector2i(0, 0))), "Place first copy.")
	_expect(board.controller.placeCard(second, board.grid.getSlotAt(Vector2i(1, 0))), "Place second copy.")

	var firstEntry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, first)) as GraveyardEntry
	var secondEntry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, second)) as GraveyardEntry

	_expect(firstEntry != null and secondEntry != null, "Both copies should enter the graveyard.")
	if firstEntry != null and secondEntry != null:
		_expect(firstEntry.cardId == secondEntry.cardId, "Definitions should still match.")
		_expect(firstEntry.instanceId != secondEntry.instanceId, "Logical instances should differ.")
		_expect(firstEntry.entryId != secondEntry.entryId, "Graveyard entries should differ.")


func _testDeleteRemovesOnlyExactEntry() -> void:
	var board := await _createBoardFixture()
	var first := _createCard("M_0001")
	var second := _createCard("M_0001")
	_expect(board.controller.placeCard(first, board.grid.getSlotAt(Vector2i(0, 0))), "Place first copy.")
	_expect(board.controller.placeCard(second, board.grid.getSlotAt(Vector2i(1, 0))), "Place second copy.")
	var firstEntry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, first)) as GraveyardEntry
	var secondEntry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, second)) as GraveyardEntry

	var deleted = await _enqueueAndWait(ActionType.make(ActionType.DELETE_CARD, null, firstEntry))
	_expect(deleted == true, "Deleting a graveyard entry should report success.")
	_expect(Graveyard.entries.size() == 1, "Only one entry should remain.")
	_expect(Graveyard.entries[0] == secondEntry, "Deletion must target the exact entry.")
	_expect(BoardHistory.getEvents("removed").size() == 2, "Deletion must preserve removal history.")
	_expect(BoardHistory.getEvents("deleted").size() == 1, "Deletion should append history.")


func _testActiveDeleteBypassesGraveyard() -> void:
	var board := await _createBoardFixture()
	var card := _createCard("M_0001")
	var slot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	_expect(board.controller.placeCard(card, slot), "Place active card.")

	var deleted = await _enqueueAndWait(ActionType.make(ActionType.DELETE_CARD, null, card))
	_expect(deleted == true, "Deleting an active card should report success.")
	_expect(slot.currentCard == null, "Active deletion should clear the slot.")
	_expect(Graveyard.entries.is_empty(), "Active deletion should bypass the graveyard.")
	_expect(BoardHistory.getEvents("deleted").size() == 1, "Active deletion should append history.")
	await get_tree().process_frame
	_expect(!is_instance_valid(card), "Active deletion should free the card node.")


func _testRevivePreservesIdentity() -> void:
	var board := await _createBoardFixture()
	var card := _createCard("M_0002")
	var originalId := card.instanceId
	var sourceSlot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	var reviveSlot: CardSlot = board.grid.getSlotAt(Vector2i(1, 0))
	_expect(board.controller.placeCard(card, sourceSlot), "Place card before removal.")
	var entry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, card)) as GraveyardEntry

	var revived := await _enqueueAndWait(ActionType.make(ActionType.REVIVE_CARD, entry, reviveSlot)) as Card
	_expect(revived != null, "REVIVE_CARD should return a recreated card.")
	if revived == null:
		return
	_expect(revived.instanceId == originalId, "Revival should preserve logical identity.")
	_expect(revived.data.id == "M_0002", "Revival should reconstruct the definition.")
	_expect(revived.health == revived.data.baseHealth, "Revival should use base health.")
	_expect(reviveSlot.currentCard == revived, "Revival should place the recreated card.")
	_expect(Graveyard.entries.is_empty(), "Successful revival should consume the entry.")
	_expect(BoardHistory.getEvents("revived").size() == 1, "Revival should append history.")


func _testFailedReviveKeepsEntry() -> void:
	var board := await _createBoardFixture()
	var deadCard := _createCard("M_0001")
	var blocker := _createCard("M_0003")
	var sourceSlot: CardSlot = board.grid.getSlotAt(Vector2i(0, 0))
	var blockedSlot: CardSlot = board.grid.getSlotAt(Vector2i(1, 0))
	_expect(board.controller.placeCard(deadCard, sourceSlot), "Place card before removal.")
	_expect(board.controller.placeCard(blocker, blockedSlot), "Place revival blocker.")
	var entry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, deadCard)) as GraveyardEntry

	var result = await _enqueueAndWait(ActionType.make(ActionType.REVIVE_CARD, entry, blockedSlot))
	_expect(result == null, "Revival into an occupied slot should fail.")
	_expect(Graveyard.getEntry(entry.entryId) == entry, "Failed revival must retain the entry.")
	_expect(BoardHistory.getEvents("revived").is_empty(), "Failed revival must not append history.")


func _testResetClearsEntriesAndNumbering() -> void:
	var entry := GraveyardEntry.new()
	entry.entryId = 99
	Graveyard.entries.append(entry)
	Graveyard.reset()
	_expect(Graveyard.entries.is_empty(), "Reset should clear all entries.")

	var board := await _createBoardFixture()
	var card := _createCard("M_0001")
	_expect(board.controller.placeCard(card, board.grid.getSlotAt(Vector2i(0, 0))), "Place card after reset.")
	var newEntry := await _enqueueAndWait(ActionType.make(ActionType.REMOVE_CARD, null, card)) as GraveyardEntry
	_expect(newEntry.entryId == 1, "Reset should restart entry numbering.")


func _enqueueAndWait(action: Dictionary) -> Variant:
	if !ActionQueue.enqueueAction(action):
		_expect(false, "Test action should be accepted by ActionQueue.")
		return null
	return await ActionQueue.waitForActionToResolve(action)


func _createBoardFixture() -> Dictionary:
	var fixture := Node.new()
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
	return {"grid": grid, "controller": controller}


func _createCard(cardId: String) -> Card:
	var card := CreateCard.new().createCard(cardId)
	_expect(card != null, "Could not create test card %s." % cardId)
	add_child(card)
	_createdNodes.append(card)
	return card


func _waitForProcessor(maxFrames := 120) -> void:
	for _frame in range(maxFrames):
		if !ActionQueue.queueHasActions() and !ActionProcessor.isProcessingAction:
			return
		await get_tree().process_frame
	_expect(false, "ActionProcessor did not become idle.")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)
