extends Control

@export_file("*.tscn") var backButtonDestinationPath: String

@onready var backButton = %BackButton

func _ready() -> void:
	backButton.pressed.connect(_onBackButtonPressed)

func _onBackButtonPressed() -> void:
	await ScreenLoader.loadScene(backButtonDestinationPath)
