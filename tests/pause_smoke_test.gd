extends Node

const GAME := preload("res://src/tests scenes/card_test_scene.tscn")
var failures := 0
var passed := 0

func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900)
	var game = GAME.instantiate()
	# Match a running main scene; this test's own root stays Always to observe pause.
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	var controller: PauseController = game.get_node("PauseController")
	var menu: PauseMenuOverlay = game.get_node("CanvasLayerPause/PauseMenuOverlay")
	for frame in range(600):
		await get_tree().process_frame
		if ActionProcessor.isProcessingAction:
			break
	_expect(ActionProcessor.isProcessingAction and InputManager.inputLocked, "Initial dealing is in progress with gameplay input locked.")
	await _escape()
	_expect(get_tree().paused and menu.visible, "Escape opens pause during initial dealing.")
	var deckSize: int = game.journeyDeck.getDeckSize()
	var occupied: int = game.slotGrid.getOccupiedSlots().size()
	await get_tree().create_timer(0.25, true).timeout
	_expect(game.journeyDeck.getDeckSize() == deckSize and game.slotGrid.getOccupiedSlots().size() == occupied and ActionProcessor.isProcessingAction, "An in-flight deal remains suspended while paused.")
	await _escape()
	_expect(!get_tree().paused and InputManager.inputLocked, "Resume during dealing preserves its existing input lock.")
	for frame in range(600):
		await get_tree().process_frame
		if game.gameController.state == GameController.GameState.PLAYER_READY and !ActionProcessor.isProcessingAction:
			break
	_expect(controller.gameController == game.gameController and controller.pauseMenu == menu, "Saved scene assigns both controller references.")
	_expect(controller._canOpenPauseMenu(), "Gameplay settles into a state that permits pause.")
	var cycle: int = game.gameController.playerCycleNumber
	var deckOrder: Array = game.journeyDeck.journeyDeckCardBag.cards.duplicate()
	var boardSnapshot: Array = []
	for slot in game.slotGrid.getOccupiedSlots():
		var card: Card = slot.currentCard
		boardSnapshot.append([slot, card, card.health, card.attack])
	await get_tree().process_frame
	var timer: Timer = game.debugTimer
	var tweenState := {"finished": false}
	var tween: Tween = game.create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func(): tweenState.finished = true)
	await _escape()
	_expect(get_tree().paused and menu.visible, "A real Escape event opens the menu and pauses gameplay.")
	_expect(menu.can_process() and controller.can_process(), "Menu and controller process during pause.")
	_expect(menu.resumeGameButton.has_focus() and !InputManager.isGameplayInputAllowed(), "Resume gains focus and gameplay input locks.")
	var remaining := timer.time_left
	await get_tree().create_timer(0.25, true).timeout
	_expect(!game.can_process() and !game.gameController.can_process() and !game.journeyDeck.can_process(), "Gameplay nodes stop processing behind the menu.")
	_expect(is_equal_approx(timer.time_left, remaining), "The real gameplay debug timer freezes during pause.")
	_expect(!tweenState.finished, "A gameplay tween remains frozen during pause.")
	await _escape(true)
	_expect(get_tree().paused, "Keyboard repeat does not resume gameplay.")
	menu.mainMenuButton.pressed.emit()
	_expect(menu.confirmationPanel.visible and menu.cancelButton.has_focus(), "Main Menu opens confirmation with Cancel focus.")
	await _escape()
	_expect(get_tree().paused and !menu.confirmationPanel.visible and menu.mainMenuButton.has_focus(), "Escape cancels confirmation without resuming.")
	await _escape()
	_expect(!get_tree().paused and !menu.visible and InputManager.isGameplayInputAllowed(), "Escape resumes and unlocks gameplay.")
	await _escape()
	var rect := menu.resumeGameButton.get_global_rect()
	var motion := InputEventMouseMotion.new()
	motion.position = rect.get_center()
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = rect.get_center()
		click.pressed = pressed
		get_viewport().push_input(click, true)
		await get_tree().process_frame
	_expect(!get_tree().paused and !menu.visible, "Resume responds to mouse input while paused.")
	_expect(game.gameController.playerCycleNumber == cycle, "Pausing and resuming preserves the player cycle.")
	_expect(game.journeyDeck.journeyDeckCardBag.cards == deckOrder, "Pausing and resuming preserves deck order.")
	var boardUnchanged := true
	for entry in boardSnapshot:
		boardUnchanged = boardUnchanged and entry[0].currentCard == entry[1] and entry[1].health == entry[2] and entry[1].attack == entry[3]
	_expect(boardUnchanged, "Pausing and resuming preserves board card identity and stats.")
	await get_tree().create_timer(0.15, true).timeout
	_expect(tweenState.finished and timer.time_left < remaining, "Gameplay timer and tween continue after Resume.")
	timer.stop()
	var player: Card = game.gameController.playerCard
	var playerSlot: CardSlot = game.boardController.getSlotCardIsIn(player)
	var targetSlot: CardSlot = game.slotGrid.getCardinalNeighbours(playerSlot)[0]
	var defender: Card = targetSlot.currentCard
	player.health = 1000
	player.attack = 1000
	defender.health = 1
	defender.attack = 0
	GlobalSignalBus.emitCardPressed(defender)
	for frame in range(600):
		await get_tree().process_frame
		if ActionProcessor.isProcessingAction:
			break
	_expect(ActionProcessor.isProcessingAction and InputManager.inputLocked, "A real player move triggers combat/refill work.")
	await _escape()
	_expect(get_tree().paused and menu.visible, "Escape pauses the real combat/refill sequence.")
	var refillDeckSize: int = game.journeyDeck.getDeckSize()
	await get_tree().create_timer(0.25, true).timeout
	_expect(game.journeyDeck.getDeckSize() == refillDeckSize and ActionProcessor.isProcessingAction, "Real refill stays suspended while paused.")
	await _escape()
	_expect(InputManager.inputLocked, "Resuming real combat/refill retains the action lock.")
	for frame in range(600):
		await get_tree().process_frame
		if game.gameController.state == GameController.GameState.PLAYER_READY and !ActionProcessor.isProcessingAction:
			break
	_expect(game.gameController.playerCycleNumber == cycle + 1 and !InputManager.inputLocked, "Interrupted real combat/refill completes exactly one cycle after Resume.")
	for phase in [GameController.GameState.RESOLVING_MOVE, GameController.GameState.COMBAT, GameController.GameState.AFTER_MOVE]:
		game.gameController.setState(phase)
		InputManager.lockInput()
		var movement := {"progress": 0.0}
		var animation: Tween = game.create_tween()
		animation.tween_method(func(value: float): movement.progress = value, 0.0, 1.0, 0.2)
		await _escape()
		_expect(get_tree().paused and menu.visible, "Escape pauses during phase %s." % phase)
		var progress: float = movement.progress
		await get_tree().create_timer(0.25, true).timeout
		_expect(is_equal_approx(movement.progress, progress), "In-flight animation freezes during phase %s." % phase)
		await _escape()
		_expect(!get_tree().paused and InputManager.inputLocked, "Resume keeps action input locked during phase %s." % phase)
		await get_tree().create_timer(0.25, true).timeout
		_expect(is_equal_approx(movement.progress, 1.0), "In-flight animation completes after Resume during phase %s." % phase)
	game.queue_free()
	await get_tree().process_frame
	print("Pause smoke test: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _escape(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
