extends Node

func _ready() -> void:
	var menu: PauseMenuOverlay = preload("res://src/main/ui/overlays/pause_menu_overlay.tscn").instantiate()
	var game := GameController.new()
	var controller := PauseController.new()
	controller.gameController = game
	controller.pauseMenu = menu
	add_child(game)
	add_child(menu)
	add_child(controller)
	controller._openPauseMenu()
	menu.exitGameButton.pressed.emit()
	if controller.pauseView != PauseController.PauseView.CONFIRM_EXIT or !menu.confirmationPanel.visible:
		_fail("Exit must open confirmation first.")
		return
	menu.cancelButton.pressed.emit()
	if controller.pauseView != PauseController.PauseView.MENU:
		_fail("Cancel must return to the pause menu without quitting.")
		return
	menu.exitGameButton.pressed.emit()
	menu.confirmButton.pressed.emit()
	if controller.pauseView != PauseController.PauseView.LEAVING:
		_fail("Confirmed Exit must enter LEAVING and request shutdown.")
		return
	# Production get_tree().quit() is responsible for ending this process.
	print("Pause exit: 3 checks passed, 0 failures")

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
