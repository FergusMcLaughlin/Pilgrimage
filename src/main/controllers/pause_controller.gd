extends Node
class_name PauseController

enum PauseView { CLOSED, MENU, CONFIRM_MAIN_MENU, CONFIRM_EXIT, LEAVING }

@export var gameController: GameController
@export var pauseMenu: PauseMenuOverlay
@export_file("*.tscn") var mainMenuScenePath: String

var pauseView: PauseView = PauseView.CLOSED
var ownsPause: bool = false
var requestedScenePath: String = ""
var inputWasLocked: bool = false
var focusBeforePause: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GlobalSignalBus.pauseResumeRequested.connect(_onPauseResumeRequested)
	GlobalSignalBus.pauseMainMenuRequested.connect(_onPauseMainMenuRequested)
	GlobalSignalBus.pauseExitRequested.connect(_onPauseExitRequested)
	GlobalSignalBus.pauseConfirmRequested.connect(_onPauseConfirmRequested)
	GlobalSignalBus.pauseCancelRequested.connect(_onPauseCancelRequested)
	GlobalSignalBus.sceneLoadFailed.connect(_onSceneLoadFailed)

func _unhandled_input(event: InputEvent) -> void:
	if !event.is_action_pressed("PAUSE_GAME", false):
		return
	get_viewport().set_input_as_handled()
	match pauseView:
		PauseView.CLOSED:
			if _canOpenPauseMenu():
				_openPauseMenu()
		PauseView.MENU:
			_onPauseResumeRequested()
		PauseView.CONFIRM_MAIN_MENU, PauseView.CONFIRM_EXIT:
			_onPauseCancelRequested()
		PauseView.LEAVING:
			pass

func _canOpenPauseMenu() -> bool:
	if !is_instance_valid(gameController) or !is_instance_valid(pauseMenu):
		return false
	if get_tree().paused or ScreenLoader.isCurrentlyLoadingScene():
		return false
	return true

func _openPauseMenu() -> void:
	focusBeforePause = get_viewport().gui_get_focus_owner()
	inputWasLocked = InputManager.inputLocked
	InputManager.lockInput()
	ownsPause = true
	pauseView = PauseView.MENU
	get_tree().paused = true
	pauseMenu.openMenu()

func _canUsePauseMenu() -> bool:
	return ownsPause and get_tree().paused \
		and is_instance_valid(pauseMenu) and pauseMenu.visible \
		and !ScreenLoader.isCurrentlyLoadingScene()

func _onPauseResumeRequested() -> void:
	if pauseView != PauseView.MENU or !_canUsePauseMenu():
		return
	pauseMenu.closeMenu()
	pauseView = PauseView.CLOSED
	ownsPause = false
	get_tree().paused = false
	if inputWasLocked:
		InputManager.lockInput()
	else:
		InputManager.unlockInput()
	_restoreFocusAfterPause.call_deferred()

func _restoreFocusAfterPause() -> void:
	var previousFocus := focusBeforePause
	focusBeforePause = null
	if get_tree().paused or pauseView != PauseView.CLOSED:
		return
	if !is_instance_valid(previousFocus):
		return
	if !previousFocus.is_visible_in_tree() or previousFocus.focus_mode == Control.FOCUS_NONE:
		return
	if previousFocus is BaseButton and previousFocus.disabled:
		return
	previousFocus.grab_focus()

func _onPauseMainMenuRequested() -> void:
	if pauseView != PauseView.MENU or !_canUsePauseMenu():
		return
	pauseView = PauseView.CONFIRM_MAIN_MENU
	pauseMenu.openConfirmation(tr("PAUSE_CONFIRM_MAIN_MENU"))

func _onPauseExitRequested() -> void:
	if pauseView != PauseView.MENU or !_canUsePauseMenu():
		return
	pauseView = PauseView.CONFIRM_EXIT
	pauseMenu.openConfirmation(tr("PAUSE_CONFIRM_EXIT"))

func _onPauseCancelRequested() -> void:
	if !_canUsePauseMenu():
		return
	var previousView := pauseView
	if previousView not in [PauseView.CONFIRM_MAIN_MENU, PauseView.CONFIRM_EXIT]:
		return
	pauseMenu.closeConfirmation()
	pauseView = PauseView.MENU
	if previousView == PauseView.CONFIRM_MAIN_MENU:
		pauseMenu.mainMenuButton.grab_focus()
	else:
		pauseMenu.exitGameButton.grab_focus()

func _onPauseConfirmRequested() -> void:
	if !_canUsePauseMenu():
		return
	if pauseView == PauseView.CONFIRM_EXIT:
		pauseView = PauseView.LEAVING
		get_tree().quit()
	elif pauseView == PauseView.CONFIRM_MAIN_MENU:
		if mainMenuScenePath.is_empty() or !ResourceLoader.exists(mainMenuScenePath, "PackedScene"):
			_onPauseCancelRequested()
			push_error("PauseController: invalid mainMenuScenePath.")
			pauseMenu.showLoadError()
			return
		requestedScenePath = mainMenuScenePath
		pauseView = PauseView.LEAVING
		pauseMenu.closeMenu()
		InputManager.lockInput()
		get_tree().paused = false
		ScreenLoader.loadScene(requestedScenePath)

func _onSceneLoadFailed(scenePath: String, message: String) -> void:
	if !ownsPause or pauseView != PauseView.LEAVING or scenePath != requestedScenePath:
		return
	if !is_instance_valid(pauseMenu):
		return
	requestedScenePath = ""
	InputManager.lockInput()
	get_tree().paused = true
	pauseView = PauseView.MENU
	pauseMenu.openMenu()
	push_error(message)
	pauseMenu.showLoadError()

func _exit_tree() -> void:
	GlobalSignalBus.pauseResumeRequested.disconnect(_onPauseResumeRequested)
	GlobalSignalBus.pauseMainMenuRequested.disconnect(_onPauseMainMenuRequested)
	GlobalSignalBus.pauseExitRequested.disconnect(_onPauseExitRequested)
	GlobalSignalBus.pauseConfirmRequested.disconnect(_onPauseConfirmRequested)
	GlobalSignalBus.pauseCancelRequested.disconnect(_onPauseCancelRequested)
	GlobalSignalBus.sceneLoadFailed.disconnect(_onSceneLoadFailed)
	if ownsPause:
		get_tree().paused = false
		ownsPause = false
