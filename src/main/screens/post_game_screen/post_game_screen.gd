extends Control

@export_file("*.tscn") var mainMenuScenePath: String

@onready var mainMenuButton = %MainMenuButton
@onready var exitGameButton = %ExitGameButton

func _ready() -> void:
	mainMenuButton.pressed.connect(_onMainMenuButtonPressed)
	exitGameButton.pressed.connect(_exitGame)

func _onMainMenuButtonPressed() -> void:
		await ScreenLoader.loadScene(mainMenuScenePath)

func _exitGame() -> void:
	if not ScreenLoader.isCurrentlyLoadingScene():
		get_tree().quit()
