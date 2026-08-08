class_name EffectContext
extends RefCounted

var processor: Node

func _init(effectProcessor: Node) -> void:
	processor = effectProcessor

func queueAction(action: Dictionary) -> bool:
	return ActionQueue.enqueueAction(action)

func getBoardController() -> BoardController:
	return processor.get_tree().get_first_node_in_group("boardController") as BoardController
