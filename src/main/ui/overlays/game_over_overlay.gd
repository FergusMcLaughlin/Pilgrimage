extends Control

@export_file("*.tscn") var postGameScreen: String

@onready var continueButton: Button = %ContinueButton

func _ready() -> void:
	continueButton.pressed.connect(_onContinueButtonPressed)

func _onContinueButtonPressed() -> void:
	await ScreenLoader.loadScene(postGameScreen)
