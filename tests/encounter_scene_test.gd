extends Node

var passed := 0
var failures := 0
var encounterResults: Array[EncounterResult] = []

func _ready() -> void:
	GlobalSignalBus.encounterCompleted.connect(func(result): encounterResults.append(result))
	for outcome in [EncounterDefinition.Outcome.CONTINUE, EncounterDefinition.Outcome.LEAVE]:
		await _testCardClick(outcome)
	print("Encounter scene: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _testCardClick(outcome: EncounterDefinition.Outcome) -> void:
	encounterResults.clear()
	var scene = preload("res://src/tests scenes/card_test_scene.tscn").instantiate()
	scene.debug_stat_cycle = false
	add_child(scene)
	var game: GameController = scene.gameController
	for frame in range(2000):
		if game.state == GameController.GameState.PLAYER_READY:
			break
		await get_tree().process_frame
	_expect(game.state == GameController.GameState.PLAYER_READY, "Real test scene finishes setup.")
	var controller: EncounterController = scene.get_node("EncounterController")
	_expect(game.encounterController == controller and controller.gameController == game, "Scene links GameController and EncounterController both ways.")
	_expect(controller.modal == scene.encounterModal, "Controller uses the existing scene modal.")
	var cycle := game.playerCycleNumber
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var diagonal: CardSlot = scene.slotGrid.getSlotAt(Vector2i(0, 0))
	diagonal.currentCard.input._gui_input(click)
	_expect(game.state == GameController.GameState.PLAYER_READY and !scene.encounterModal.visible, "Diagonal card click does not open an encounter or start combat.")

	#added for testing: place a known adjacent encounter without relying on the shuffled deck.
	var target: CardSlot = scene.slotGrid.getSlotAt(Vector2i(1, 0))
	var previous := target.currentCard
	scene.boardController.removeCard(previous)
	previous.queue_free()
	var source := CreateCard.new().createCard("M_0012")
	if outcome == EncounterDefinition.Outcome.LEAVE:
		source.data = source.data.duplicate() as CardData
		source.data.encounterId = &"quiet_road"
		source.data.encounter = EncounterLibrary.getEncounterData("quiet_road")
	scene.boardController.placeCard(source, target)
	var sourceId := source.instanceId
	var fromSlot: CardSlot = scene.boardController.getSlotCardIsIn(game.playerCard)
	var playerHealth := game.playerCard.health
	source.input._gui_input(click)
	_expect(scene.encounterModal.visible and game.state == GameController.GameState.ENCOUNTER, "Actual card click opens its encounter.")
	_expect(fromSlot.currentCard == game.playerCard and target.currentCard == source, "Player and source stay in place while reading.")
	_expect(InputManager.inputLocked and scene.addPlayerButton.disabled, "Reading keeps gameplay and debug controls locked.")
	var pause: PauseController = scene.get_node("PauseController")
	pause._openPauseMenu()
	pause._onPauseResumeRequested()
	await get_tree().process_frame
	_expect(scene.encounterModal.visible and InputManager.inputLocked, "Pause/resume retains the real encounter and its lock.")
	var button: Button = scene.encounterModal.leaveButton if outcome == EncounterDefinition.Outcome.LEAVE else scene.encounterModal.continueButton
	_expect(button.has_focus(), "Resume restores the encounter button focus.")
	button.pressed.emit()
	button.pressed.emit()
	_expect(game.state != GameController.GameState.PLAYER_READY and scene.addPlayerButton.disabled, "Preview listener cannot prematurely unlock production consequences.")
	for frame in range(2000):
		await get_tree().process_frame
		if game.state == GameController.GameState.PLAYER_READY:
			break
	_expect(game.state == GameController.GameState.PLAYER_READY and game.playerCycleNumber == cycle + 1, "Encounter completes exactly one turn.")
	_expect(encounterResults.size() == 1 and encounterResults[0].succeeded, "Real controller reports one successful result.")
	_expect(target.currentCard == game.playerCard and game.playerCard.health == playerHealth, "Player advances without combat damage.")
	_expect(scene.slotGrid.getOccupiedSlots().size() == 9 and game.pendingRefillRequest == null, "Board refills and clears the pending request.")
	_expect(Graveyard.getEntries().size() == 1 and Graveyard.getEntries()[0].instanceId == sourceId, "Source is removed through the real graveyard path.")
	_expect(controller.resolvedEncounterSources[sourceId] == outcome, "Controller records the actual button choice.")
	_expect(!scene.encounterModal.visible and !InputManager.inputLocked and !scene.addPlayerButton.disabled, "Completion closes the modal and restores gameplay/debug input.")
	scene.queue_free()
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
