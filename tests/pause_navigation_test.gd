extends Node

const GAME := preload("res://src/tests scenes/card_test_scene.tscn")
var passed := 0
var failures := 0

func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900)
	# Remain a root observer while the real ScreenLoader replaces current_scene.
	var game = GAME.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.debug_stat_cycle = false
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	get_tree().current_scene = game
	await _settleRun(game)
	var oldPlayerId: int = game.gameController.playerCard.get_instance_id()
	var controller: PauseController = game.get_node("PauseController")
	var menu: PauseMenuOverlay = game.get_node("CanvasLayerPause/PauseMenuOverlay")
	controller._openPauseMenu()
	menu.mainMenuButton.pressed.emit()
	_expect(get_tree().paused and menu.confirmationPanel.visible, "Main Menu requires confirmation before leaving the run.")
	menu.confirmButton.pressed.emit()
	_expect(!get_tree().paused and ScreenLoader.isLoading and InputManager.inputLocked, "Confirm starts loading with the tree unpaused and gameplay input locked.")
	await _waitForScene("res://src/main/screens/main_menu/main_menu.tscn")
	_expect(!is_instance_valid(game) and !is_instance_valid(controller), "Successful navigation frees the old run and controller.")
	_expect(!get_tree().paused and !ScreenLoader.isLoading, "Main Menu is usable after loading-overlay dismissal.")
	_expect(GlobalSignalBus.pauseMainMenuRequested.get_connections().is_empty(), "Successful navigation leaves no old pause request listeners.")
	var main = get_tree().current_scene
	main.newGameButton.pressed.emit()
	await _waitForScene("res://src/main/screens/character_select_screne/character_select_screne.tscn")
	get_tree().current_scene.startButton.pressed.emit()
	await _waitForScene("res://src/tests scenes/card_test_scene.tscn")
	var fresh = get_tree().current_scene
	await _settleRun(fresh)
	_expect(fresh.gameController.playerCard.get_instance_id() != oldPlayerId and fresh.gameController.playerCycleNumber == 1, "New Game through character selection starts a fresh run.")
	_expect(!InputManager.inputLocked, "Fresh run unlocks gameplay after setup.")
	var freshController: PauseController = fresh.get_node("PauseController")
	freshController._openPauseMenu()
	_expect(get_tree().paused and freshController.pauseMenu.visible, "Fresh run has a working pause controller.")
	freshController.pauseMenu.resumeGameButton.pressed.emit()
	_expect(!get_tree().paused and !InputManager.inputLocked, "Fresh run resumes normally.")
	print("Pause navigation: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _waitForScene(path: String) -> void:
	for frame in range(1200):
		await get_tree().process_frame
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.scene_file_path == path and !ScreenLoader.isLoading:
			return
	_expect(false, "Scene transition must finish: " + path)

func _settleRun(game: Node) -> void:
	for frame in range(1200):
		await get_tree().process_frame
		if game.gameController.state == GameController.GameState.PLAYER_READY and !ActionProcessor.isProcessingAction:
			return
	_expect(false, "Run must finish initial dealing.")

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
