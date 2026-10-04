extends Control
class_name PauseMenuOverlay

@onready var resumeGameButton: Button = %ResumeGameButton
@onready var mainMenuButton: Button = %MainMenuButton
@onready var exitGameButton: Button = %ExitGameButton
@onready var confirmationPanel: PanelContainer = $ConfirmationPanel
@onready var confirmationText: Label = %ConfirmationText
@onready var cancelButton: Button = %CancelButton
@onready var confirmButton: Button = %ConfirmButton
@onready var errorLabel: Label = %ErrorLabel

func _ready() -> void:
	hide()
	resumeGameButton.pressed.connect(_onResumeGameButtonPressed)
	mainMenuButton.pressed.connect(_onMainMenuButtonPressed)
	exitGameButton.pressed.connect(_onExitGameButtonPressed)
	confirmationPanel.hide()
	cancelButton.pressed.connect(_onCancelButtonPressed)
	confirmButton.pressed.connect(_onConfirmButtonPressed)

func _onResumeGameButtonPressed() -> void:
	GlobalSignalBus.emitPauseResumeRequested()

func _onMainMenuButtonPressed() -> void:
	GlobalSignalBus.emitPauseMainMenuRequested()

func _onExitGameButtonPressed() -> void:
	GlobalSignalBus.emitPauseExitRequested()

func openMenu() -> void:
	errorLabel.hide()
	closeConfirmation()
	show()
	resumeGameButton.grab_focus()

func closeMenu() -> void:
	confirmationPanel.hide()
	hide()

func _onCancelButtonPressed() -> void:
	GlobalSignalBus.emitPauseCancelRequested()

func _onConfirmButtonPressed() -> void:
	GlobalSignalBus.emitPauseConfirmRequested()

func setMenuEnabled(enabled: bool) -> void:
	resumeGameButton.disabled = !enabled
	mainMenuButton.disabled = !enabled
	exitGameButton.disabled = !enabled

func openConfirmation(message: String) -> void:
	setMenuEnabled(false)
	confirmationText.text = message
	confirmationPanel.show()
	cancelButton.grab_focus()

func closeConfirmation() -> void:
	confirmationPanel.hide()
	setMenuEnabled(true)

func showLoadError() -> void:
	errorLabel.text = tr("PAUSE_LOAD_FAILED")
	errorLabel.show()
