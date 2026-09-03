extends Node

@export var playButton: Button
@export var initalScene: StringName = &""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	playButton.pressed.connect(_onButtonPressed)


func _onButtonPressed() -> void:
	SceneLoader.loadScene(initalScene)
