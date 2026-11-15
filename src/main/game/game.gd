extends Control
class_name Game

@export_file("*.tscn") var firstScenePath: String
@onready var sceneContainer = %SceneContainer

func _ready() -> void:
	ScreenLoader.sceneContainer = sceneContainer
	sceneContainer.setCurrentScene(load(firstScenePath).instantiate())

func _exit_tree() -> void:
	ScreenLoader.sceneContainer = null
