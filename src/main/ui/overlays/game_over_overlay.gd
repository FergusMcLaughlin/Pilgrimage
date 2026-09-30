extends Control

@onready var continueButton: Button = %ContinueButton

func _ready() -> void:
	continueButton.pressed.connect(_onContinueButtonPressed)

func _onContinueButtonPressed() -> void:
	if continueButton.disabled:
		return

	continueButton.disabled = true
	GlobalSignalBus.emitGameOverContinueRequested()
