extends Control
class_name SlotGrid

@export var gridSize: Vector2i
@export var slotScene: PackedScene
@export var cellSize: Vector2 = Vector2(184, 248)

@onready var grid: GridContainer = %CardSlotGrid

var slots = []

func _ready() -> void:
	_createGrid()

func _clearGrid() -> void:
	for child in grid.get_children():
		if child.is_in_group("cardSlots"):
			child.queue_free()

	slots.clear()

func _createGrid() -> void:
	if slotScene == null:
		push_error("SlotGrid: slotScene is not assigned.")
		return

	_clearGrid()

	grid.columns = gridSize.y

	for row in range(gridSize.x):
		var rowSlots = []
		for col in range(gridSize.y):
			var slot = slotScene.instantiate()
			slot.custom_minimum_size = cellSize
			slot.coordinates = Vector2i(col, row)
			slot.name = "CardSlot_" + str(col) + "_" + str(row)
			grid.add_child(slot)
			slot.add_to_group("cardSlots")
			rowSlots.append(slot)
		slots.append(rowSlots)

func getSlotAt(coordinates: Vector2i) -> CardSlot:
	if coordinates.x < 0 || coordinates.y < 0:
		return null
	if coordinates.y >= slots.size():
		return null
	var rowSlots = slots[coordinates.y]
	if coordinates.x >= rowSlots.size():
		return null
	return rowSlots[coordinates.x]

func getEmptySlots() -> Array[CardSlot]:
	var emptySlots: Array[CardSlot] = []
	for row in slots:
		for slot in row:
			if not slot.isOccupied():
				emptySlots.append(slot)
	return emptySlots

func getOccupiedSlots() -> Array[CardSlot]:
	var occupiedSlots: Array[CardSlot] = []
	for row in slots:
		for slot in row:
			if slot.isOccupied():
				occupiedSlots.append(slot)
	return occupiedSlots

func getCenterSlot() -> CardSlot:
	return getSlotAt(Vector2i(gridSize.y / 2, gridSize.x / 2))

func getCardinalNeighbours(slot: CardSlot) -> Array[CardSlot]:
	var cardinalNeighbours: Array[CardSlot] = []

	if slot == null:
		return cardinalNeighbours

	var candidateCoordinates = slot.coordinates
	var possibleNeighbours = [
		Vector2i(candidateCoordinates.x - 1, candidateCoordinates.y),
		Vector2i(candidateCoordinates.x + 1, candidateCoordinates.y),
		Vector2i(candidateCoordinates.x, candidateCoordinates.y - 1),
		Vector2i(candidateCoordinates.x, candidateCoordinates.y + 1)
	]

	for coordinate in possibleNeighbours:
		var neighbour  = getSlotAt(coordinate)
		if neighbour != null:
			cardinalNeighbours.append(neighbour)

	return cardinalNeighbours
