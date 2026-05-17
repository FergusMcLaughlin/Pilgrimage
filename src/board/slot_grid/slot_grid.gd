extends Control
class_name slot_grid

@export var gridSize: Vector2i
@export var slotScene: PackedScene
@export var cellSize: Vector2 = Vector2(184, 248)

@onready var grid: GridContainer = %CardSlot

var slots = []

func _ready() -> void:
	_createGrid()

func _clearGrid() -> void:
	for child in grid.get_children():
		if child.is_in_group("cardSlot"):
			child.queue_free()
	
	slots.clear()

func _createGrid() -> void:
	_clearGrid()
	
	grid.columns = gridSize.y
	
	for row in range(gridSize.x):
		var rowSlots = []
		for col in range(gridSize.y):
			var slot = slotScene.instantiate()
			slot.custom_minimum_size = cellSize
			slot.coordinates = Vector2(col, row)
			slot.name = "CardSlot_" + str(col) + "_" + str(row)
			grid.add_child(slot)
			slot.add_to_group("cardSlots")
			rowSlots.append(slot)
		slots.append(rowSlots)
