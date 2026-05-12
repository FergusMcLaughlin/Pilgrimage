extends Control
class_name slot_grid

@export var gridSize: Vector2i
@export var slotScene: PackedScene
@export var cellSize: Vector2 = Vector2(192, 179) # chage this

@onready var grid: GridContainer = %CardSlot

var slots = []

func _ready() -> void:
	_createGrid()

func _clearGrid() -> void:
	for child in get_children():
		if child.is_in_group("cardSlot"):
			child.queue_free()
	
	slots.clear()

func _createGrid() -> void:
	_clearGrid()
	
	for row in range(gridSize.x):
		var rowSlots = []
		for col in range(gridSize.y):
			var slot = slotScene.instantiate()
			slot.position = Vector2(
				(col - (gridSize.y-1)/2.0) * cellSize.x,
				(row - (gridSize.x-1)/2.0) * cellSize.y
			)
			slot.coordinates = Vector2(col, row)
			slot.name = "CardSlot_" + str(col) + "_" + str(row)
			add_child(slot)
			slot.add_to_group("cardSlots")
			rowSlots.append(slot)
		slots.append(rowSlots)
