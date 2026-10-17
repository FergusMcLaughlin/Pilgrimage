extends Node

const OVERLAY := preload("res://src/main/ui/overlays/pause_menu_overlay.tscn")
const DESTINATION := "res://src/main/screens/main_menu/main_menu.tscn"

# Exercise the production loading overlay and dismissal without replacing this test scene.
class ControlledLoader:
	extends "res://src/main/singletons/screen_loader.gd"
	var failRequest := true
	var pendingAtStart: Array[String] = []
	func _startLoading() -> void:
		pendingAtStart.assign([pendingFailurePath, pendingFailureMessage])
		if failRequest:
			_finishLoadingWithError("Expected test load failure")
		else:
			GlobalSignalBus.emitLoadFinished()

var passed := 0
var failures := 0
var loaderEvents: Array[Dictionary] = []

func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900)
	await _testControllerRecovery()
	await _testEncounterFocus()
	await _testLoaderDismissal()
	InputManager.unlockInput()
	get_tree().paused = false
	print("Pause recovery: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _fixture() -> Dictionary:
	var root := Node.new()
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	var game := GameController.new()
	var menu: PauseMenuOverlay = OVERLAY.instantiate()
	var controller := PauseController.new()
	controller.gameController = game
	controller.pauseMenu = menu
	controller.mainMenuScenePath = DESTINATION
	root.add_child(game)
	root.add_child(menu)
	root.add_child(controller)
	add_child(root)
	return {"root": root, "menu": menu, "controller": controller}

func _testControllerRecovery() -> void:
	var baseline := GlobalSignalBus.pauseMainMenuRequested.get_connections().size()
	var f := _fixture()
	var menu: PauseMenuOverlay = f.menu
	var controller: PauseController = f.controller
	InputManager.unlockInput()
	GlobalSignalBus.emitPauseMainMenuRequested()
	GlobalSignalBus.emitPauseConfirmRequested()
	_expect(controller.pauseView == PauseController.PauseView.CLOSED and !menu.visible, "Closed controller ignores button requests.")
	ScreenLoader.isLoading = true
	_expect(!controller._canOpenPauseMenu(), "Scene loading blocks pause opening.")
	ScreenLoader.isLoading = false
	get_tree().paused = true
	_expect(!controller._canOpenPauseMenu(), "An externally paused tree is not claimed by this controller.")
	get_tree().paused = false
	controller._openPauseMenu()
	for kind in ["main", "exit"]:
		if kind == "main":
			menu.mainMenuButton.pressed.emit()
		else:
			menu.exitGameButton.pressed.emit()
		var expectedKey := "PAUSE_CONFIRM_MAIN_MENU" if kind == "main" else "PAUSE_CONFIRM_EXIT"
		_expect(menu.confirmationText.text == tr(expectedKey) and menu.cancelButton.has_focus(), "Confirmation has correct text and Cancel focus: " + kind)
		var state := controller.pauseView
		GlobalSignalBus.emitPauseMainMenuRequested()
		GlobalSignalBus.emitPauseExitRequested()
		GlobalSignalBus.emitPauseResumeRequested()
		_expect(controller.pauseView == state and get_tree().paused, "Duplicate requests cannot replace confirmation or resume.")
		menu.cancelButton.pressed.emit()
		var button: Button = menu.mainMenuButton if kind == "main" else menu.exitGameButton
		_expect(controller.pauseView == PauseController.PauseView.MENU and button.has_focus(), "Cancel restores the requesting button focus.")
	controller.mainMenuScenePath = "res://tests/does_not_exist.tscn"
	menu.mainMenuButton.pressed.emit()
	menu.confirmButton.pressed.emit()
	var error: Label = menu.get_node("%ErrorLabel")
	_expect(get_tree().paused and menu.visible and error.visible and error.text == tr("PAUSE_LOAD_FAILED"), "Invalid destination reports a localised error while retaining pause.")
	_expect(!menu.resumeGameButton.disabled and !menu.mainMenuButton.disabled and !menu.exitGameButton.disabled, "Error leaves menu buttons usable.")
	menu.resumeGameButton.pressed.emit()
	controller._openPauseMenu()
	_expect(!error.visible, "Reopening clears the previous error.")
	controller.pauseView = PauseController.PauseView.LEAVING
	controller.requestedScenePath = DESTINATION
	menu.closeMenu()
	get_tree().paused = false
	GlobalSignalBus.emitPauseResumeRequested()
	GlobalSignalBus.emitPauseMainMenuRequested()
	GlobalSignalBus.emitPauseExitRequested()
	GlobalSignalBus.emitPauseConfirmRequested()
	_expect(controller.pauseView == PauseController.PauseView.LEAVING and !menu.visible, "Leaving ignores duplicate UI requests.")
	GlobalSignalBus.emitSceneLoadFailed("res://unrelated.tscn", "Expected unrelated test failure")
	_expect(!get_tree().paused and !menu.visible, "Wrong-path failures do not restore pause.")
	GlobalSignalBus.emitSceneLoadFailed(DESTINATION, "Expected matching test failure")
	_expect(get_tree().paused and menu.visible and error.visible and controller.pauseView == PauseController.PauseView.MENU, "Matching load failure restores a usable paused menu with error feedback.")
	menu.resumeGameButton.pressed.emit()
	_expect(!get_tree().paused and !InputManager.inputLocked, "Recovery Resume restores the original unlocked input state.")
	controller._openPauseMenu()
	f.root.queue_free()
	await get_tree().process_frame
	_expect(!get_tree().paused, "Destroying the paused fixture releases its tree pause.")
	_expect(GlobalSignalBus.pauseMainMenuRequested.get_connections().size() == baseline, "Destroying the controller removes its bus listener.")
	InputManager.unlockInput()
	f = _fixture()
	f.controller._openPauseMenu()
	GlobalSignalBus.emitPauseExitRequested()
	_expect(f.controller.pauseView == PauseController.PauseView.CONFIRM_EXIT, "Recreated controller receives requests without stale listeners.")
	f.root.queue_free()
	await get_tree().process_frame
	InputManager.unlockInput()

func _testEncounterFocus() -> void:
	var f := _fixture()
	var modal: EncounterModal = preload("res://src/main/ui/overlays/encounter_modal.tscn").instantiate()
	f.root.add_child(modal)
	var requests: Array[Dictionary] = []
	var listener := func(encounterId: StringName, outcome: EncounterDefinition.Outcome): requests.append({"id": encounterId, "outcome": outcome})
	GlobalSignalBus.encounterOutcomeRequested.connect(listener)
	var corpse := preload("res://data/encounters/roadside_corpse.tres")
	var quietRoad := preload("res://data/encounters/quiet_road.tres")
	for choice in ["continueOnly", "leave", "continue"]:
		requests.clear()
		modal.present(corpse if choice == "continueOnly" else quietRoad)
		var button: Button = modal.leaveButton if choice == "leave" else modal.continueButton
		button.grab_focus()
		InputManager.lockInput()
		f.controller._openPauseMenu()
		_expect(f.menu.resumeGameButton.has_focus(), "Pause takes focus from the encounter: " + choice)
		await _accept()
		_expect(!get_tree().paused and !f.menu.visible and InputManager.inputLocked, "Keyboard Resume preserves the encounter input lock: " + choice)
		_expect(button.has_focus(), "Resume restores the selected encounter button: " + choice)
		_expect(requests.is_empty(), "Accepting Resume does not also submit the encounter: " + choice)
		await _accept()
		var outcome := EncounterDefinition.Outcome.LEAVE if choice == "leave" else EncounterDefinition.Outcome.CONTINUE
		_expect(requests == [{"id": modal.definition.id, "outcome": outcome}], "Accept after Resume submits the selected outcome once: " + choice)
		modal.close()
	GlobalSignalBus.encounterOutcomeRequested.disconnect(listener)
	f.root.queue_free()
	await get_tree().process_frame
	InputManager.unlockInput()

func _accept() -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "ui_accept"
		event.pressed = pressed
		get_viewport().push_input(event)
		await get_tree().process_frame
	await get_tree().process_frame

func _testLoaderDismissal() -> void:
	var loader := ControlledLoader.new()
	add_child(loader)
	var listener := func(path: String, message: String): loaderEvents.append({"path": path, "message": message, "loading": loader.isLoading})
	GlobalSignalBus.sceneLoadFailed.connect(listener)
	loader.loadScene("res://tests/does_not_exist.tscn")
	_expect(loaderEvents.size() == 1 and !loader.isLoading, "Invalid load requests emit failure immediately without entering loading.")
	loaderEvents.clear()
	loader.pendingFailurePath = "res://stale.tscn"
	loader.pendingFailureMessage = "stale failure"
	loader.loadScene(DESTINATION)
	_expect(loader.isLoading, "Accepted request enters loading.")
	await _waitForDismissal(loader)
	_expect(loader.pendingAtStart == ["", ""], "Accepted request clears stale failure state before starting.")
	_expect(loaderEvents.size() == 1 and loaderEvents[0].path == DESTINATION and !loaderEvents[0].loading, "Failed request emits exactly once after dismissal and after loading resets.")
	_expect(loader.pendingFailurePath.is_empty() and loader.pendingFailureMessage.is_empty(), "Dismissal consumes pending failure data.")
	loader._onLoadScreenClosed()
	_expect(loaderEvents.size() == 1, "Repeated dismissal does not re-emit an old failure.")
	loaderEvents.clear()
	loader.failRequest = false
	loader.loadScene(DESTINATION)
	await _waitForDismissal(loader)
	_expect(!loader.isLoading and loaderEvents.is_empty(), "A successful retry dismisses without a failure notification.")
	await get_tree().process_frame
	_expect(loader.get_child_count() == 0, "Dismissal frees loading overlays.")
	GlobalSignalBus.sceneLoadFailed.disconnect(listener)
	loader.queue_free()
	await get_tree().process_frame

func _waitForDismissal(loader: ControlledLoader) -> void:
	for frame in range(600):
		await get_tree().process_frame
		if !loader.isLoading:
			return
	_expect(false, "Loading overlay must finish dismissal within the test deadline.")

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
