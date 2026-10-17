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
	scene.encounterPreviewDefinition = load("res://data/encounters/quiet_road.tres").duplicate()
	scene.encounterPreviewDefinition.artwork = null
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
	bus.encounterOutcomeRequested.disconnect(_countOutcome)
	scene.queue_free()
	await get_tree().process_frame
	print("Encounter preview: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)
