extends Control

@export_file("*.tscn") var newGameScenePath: String
@export_file("*.tscn") var backButtonDestinationPath: String

@onready var startButton = %StartButton
@onready var backButton = %BackButton

func _ready() -> void:
	startButton.pressed.connect(_onStartButtonPressed)
	backButton.pressed.connect(_onBackButtonPressed)

func _onStartButtonPressed() -> void:
	await ScreenLoader.loadScene(newGameScenePath)

func _onBackButtonPressed() -> void:
	await ScreenLoader.loadScene(backButtonDestinationPath)
