extends Node

var failures := 0
var submissions := 0
var passed := 0

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func _countOutcome(_id, _outcome) -> void:
	submissions += 1

func _pressF6() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F6
	event.pressed = true
	Input.parse_input_event(event)

func _ready() -> void:
	var scene = load("res://src/tests scenes/card_test_scene.tscn").instantiate()
	scene.debug_stat_cycle = false
	add_child(scene)
	_expect(scene.addPlayerButton.disabled and scene.advancePlayerCycleButton.disabled, "Debug controls start disabled during setup.")
	var game = scene.get_node("GameController")
	for i in range(2000):
		await get_tree().process_frame
		if game.state == game.GameState.PLAYER_READY:
			break
	_expect(game.state == game.GameState.PLAYER_READY, "Run reaches PLAYER_READY.")
	var modal = scene.encounterModal
	var input = get_tree().root.get_node("InputManager")
	var bus = get_tree().root.get_node("GlobalSignalBus")
	bus.encounterOutcomeRequested.connect(_countOutcome)
	var cycle = game.playerCycleNumber
	_expect(!modal.visible, "Modal starts hidden.")
	_pressF6()
	await get_tree().process_frame
	_expect(modal.visible, "F6 opens the real modal.")
	_expect(input.inputLocked, "Preview locks gameplay input.")
	_expect(scene.addPlayerButton.disabled and scene.advancePlayerCycleButton.disabled, "Debug mutation buttons are disabled.")
	_expect(!modal.bodyText.scroll_active, "Description does not scroll.")
	_expect(!modal.continueButton.disabled and !modal.leaveButton.visible, "Continue-only fixture enables Continue and hides Leave.")
	modal.leaveButton.pressed.emit()
	_expect(submissions == 0 and modal.visible, "Hidden Leave is rejected.")
	_pressF6()
	await get_tree().process_frame
	_expect(modal.visible and submissions == 0, "Repeated F6 does not submit or reopen.")
	modal.continueButton.pressed.emit()
	modal.continueButton.pressed.emit()
	_expect(submissions == 1, "Double Continue submits once through the bus.")
	_expect(!modal.visible and !input.inputLocked, "Continue closes and restores input.")
	_expect(!scene.addPlayerButton.disabled and !scene.advancePlayerCycleButton.disabled, "Debug controls are restored.")
	_expect(game.playerCycleNumber == cycle, "Preview does not advance the turn.")
	scene.encounterPreviewId = "abandoned_cart"
	_pressF6()
	await get_tree().process_frame
	_expect(modal.visible and modal.leaveButton.visible and !modal.artwork.visible, "Choice fixture reopens with Leave and no artwork.")
	var pause = scene.get_node("PauseController")
	pause._openPauseMenu()
	modal.leaveButton.pressed.emit()
	_expect(submissions == 1 and modal.visible, "Paused submission is rejected.")
	pause._onPauseResumeRequested()
	_expect(input.inputLocked and modal.visible, "Pause resume preserves the preview input lock.")
	modal.leaveButton.pressed.emit()
	_expect(submissions == 2 and !modal.visible and !input.inputLocked, "Leave submits once, closes and restores input.")
	_expect(game.playerCycleNumber == cycle, "Neither outcome changes the player cycle.")
	_testResolutionLocks(scene, game)
	bus.encounterOutcomeRequested.disconnect(_countOutcome)
	scene.queue_free()
	await get_tree().process_frame
	print("Encounter preview: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _testResolutionLocks(scene, game) -> void:
	var card: Card
	for slot in scene.slotGrid.getOccupiedSlots():
		if slot.currentCard != game.playerCard:
			card = slot.currentCard
			break
	scene.cards.append(card)
	scene.activeCardIndex = scene.cards.size() - 1
	var originalState := card.currentState
	var originalHealth := card.health
	var originalAttack := card.attack
	var flips := [0]
	var listener := func(_card): flips[0] += 1
	GlobalSignalBus.cardFlipped.connect(listener)
	for state in [game.GameState.ENCOUNTER, game.GameState.RESOLVING_MOVE, game.GameState.COMBAT, game.GameState.AFTER_MOVE]:
		InputManager.lockInput()
		game.setState(state)
		_expect(scene.addPlayerButton.disabled and scene.advancePlayerCycleButton.disabled, "Debug buttons are disabled in phase %s." % state)
		var key := InputEventKey.new()
		key.keycode = KEY_Q
		key.pressed = true
		scene._input(key)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = true
		scene._input(click)
		scene._onDebugStatTimeout()
		scene._onDebugStateTimeout()
		_expect(card.currentState == originalState and card.health == originalHealth and card.attack == originalAttack, "Keyboard and timer debug mutation is blocked in phase %s." % state)
		_expect(flips[0] == 0, "Right-click debug flipping is blocked in phase %s." % state)
	game.setState(game.GameState.PLAYER_READY)
	InputManager.unlockInput()
	_expect(!scene.addPlayerButton.disabled and !scene.advancePlayerCycleButton.disabled, "Debug buttons are restored at PLAYER_READY.")
	GlobalSignalBus.cardFlipped.disconnect(listener)
	scene.cards.pop_back()
	scene.activeCardIndex = -1
