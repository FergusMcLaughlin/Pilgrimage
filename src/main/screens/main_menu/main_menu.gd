extends Control

@export_file("*.tscn") var newGameScenePath: String
@export_file("*.tscn") var loadingMenuScenePath: String
@export_file("*.tscn") var settingsMenuScenePath: String

@onready var newGameButton: Button = %NewGameButton
@onready var loadGameButton: Button = %LoadGameButton
@onready var SettingsMenuButton: Button = %SettingsMenuButton
@onready var ExitGameButton: Button = %ExitGameButton

func _ready() -> void:
	newGameButton.pressed.connect(_onNewGameButtonPressed)
	loadGameButton.pressed.connect(_onLoadGameButtonPressed)
	SettingsMenuButton.pressed.connect(_onSettingsMenuButtonPressed)
	ExitGameButton.pressed.connect(_exitGame)

func _onNewGameButtonPressed() -> void:
	await ScreenLoader.loadScene(newGameScenePath)

func _onLoadGameButtonPressed() -> void:
	await ScreenLoader.loadScene(loadingMenuScenePath)

func _onSettingsMenuButtonPressed() -> void:
	await ScreenLoader.loadScene(settingsMenuScenePath)

func _exitGame() -> void:
	if not ScreenLoader.isCurrentlyLoadingScene():
		get_tree().quit()
