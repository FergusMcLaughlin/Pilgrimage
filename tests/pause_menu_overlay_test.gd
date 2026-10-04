extends Node

const OVERLAY := preload("res://src/main/ui/overlays/pause_menu_overlay.tscn")

var requests: Array[String] = []
var loadFailure: Array[String] = []
var failures := 0
var passed := 0

func _ready() -> void:
	GlobalSignalBus.pauseResumeRequested.connect(func(): requests.append("resume"))
	GlobalSignalBus.pauseMainMenuRequested.connect(func(): requests.append("main_menu"))
	GlobalSignalBus.pauseExitRequested.connect(func(): requests.append("exit"))
	GlobalSignalBus.pauseCancelRequested.connect(func(): requests.append("cancel"))
	GlobalSignalBus.pauseConfirmRequested.connect(func(): requests.append("confirm"))
	GlobalSignalBus.sceneLoadFailed.connect(func(path: String, message: String): loadFailure.assign([path, message]))
	var overlay: PauseMenuOverlay = OVERLAY.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	_expect(!overlay.visible and !overlay.confirmationPanel.visible, "Overlay and confirmation start hidden.")
	overlay.openMenu()
	_expect(overlay.visible and overlay.resumeGameButton.has_focus(), "Opening focuses Resume.")
	overlay.resumeGameButton.pressed.emit()
	overlay.mainMenuButton.pressed.emit()
	overlay.exitGameButton.pressed.emit()
	_expect(requests == ["resume", "main_menu", "exit"], "Existing buttons emit exactly one bus request each.")
	for key in ["PAUSE_CONFIRM_MAIN_MENU", "PAUSE_CONFIRM_EXIT"]:
		overlay.openConfirmation(tr(key))
		await get_tree().process_frame
		_expect(overlay.confirmationPanel.visible and overlay.confirmationText.text == tr(key), "Confirmation displays the requested message.")
		_expect(overlay.resumeGameButton.disabled and overlay.mainMenuButton.disabled and overlay.exitGameButton.disabled, "Confirmation disables all underlying buttons.")
		_expect(overlay.cancelButton.has_focus(), "Cancel receives initial confirmation focus.")
		_expect(overlay.confirmationText.size.x <= overlay.confirmationPanel.size.x, "Text fits within the confirmation panel.")
		overlay.cancelButton.pressed.emit()
		overlay.confirmButton.pressed.emit()
		_expect(requests.slice(-2) == ["cancel", "confirm"], "Confirmation buttons emit bus requests.")
		_expect(overlay.confirmationPanel.visible, "Only the controller decides the result of confirmation requests.")
		overlay.closeConfirmation()
		_expect(!overlay.confirmationPanel.visible and !overlay.resumeGameButton.disabled and !overlay.mainMenuButton.disabled and !overlay.exitGameButton.disabled, "Closing confirmation restores the menu buttons.")
	overlay.openConfirmation(tr("PAUSE_CONFIRM_EXIT"))
	overlay.closeMenu()
	_expect(!overlay.visible and !overlay.confirmationPanel.visible, "Closing the menu hides confirmation too.")
	overlay.openMenu()
	_expect(!overlay.confirmationPanel.visible and !overlay.resumeGameButton.disabled and overlay.resumeGameButton.has_focus(), "Reopening clears stale confirmation state and restores focus.")
	GlobalSignalBus.emitSceneLoadFailed("res://missing.tscn", "load failed")
	_expect(loadFailure == ["res://missing.tscn", "load failed"], "Load failure wrapper preserves both arguments.")
	for key in ["PAUSE_CONFIRM_MAIN_MENU", "PAUSE_CONFIRM_EXIT", "PAUSE_CANCEL_BUTTON", "PAUSE_CONFIRM_BUTTON", "PAUSE_LOAD_FAILED"]:
		_expect(tr(key) != key, "Localisation resolves " + key)
	overlay.queue_free()
	await get_tree().process_frame
	print("Pause menu overlay: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
