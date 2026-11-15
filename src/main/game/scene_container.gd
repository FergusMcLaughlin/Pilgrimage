extends Control
class_name SceneContainer

var currentScene: Node

func setCurrentScene(scene: Node) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	currentScene = scene
	add_child(scene)
