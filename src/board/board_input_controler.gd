extends Node

var cardBeingDragged: Card = null
var hoveredSlot: CardSlot = null
var draggingOffset: Vector2 = Vector2.ZERO
var originalCardRotation: float = 0.0
var inputLocked: bool = false

func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
	GlobalSignalBus.slotHovered.connect(_onSlotHovered)
	GlobalSignalBus.slotUnhovered.connect(_onSlotUnhovered)

func _input(event: InputEvent) -> void:
	if inputLocked or cardBeingDragged == null:
		return

	if event is InputEventMouseMotion:
		_updateDragging(event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finishDragging(event.global_position)

func _onCardPressed(card: Card) -> void:
	if inputLocked or cardBeingDragged != null:
		return

	if not card.canBeDragged():
		return

	_startDragging(card)

func _onSlotHovered(slot: CardSlot) -> void:
	if cardBeingDragged == null:
		return

	hoveredSlot = slot

func _onSlotUnhovered(slot: CardSlot) -> void:
	if hoveredSlot == slot:
		hoveredSlot = null

func _startDragging(card: Card) -> void:
	cardBeingDragged = card
	hoveredSlot = null

	var mousePosition := get_viewport().get_mouse_position()
	draggingOffset = card.global_position - mousePosition
	originalCardRotation = card.rotation

	card.beingDragged()

	GlobalSignalBus.emitCardDragStarted(card, mousePosition)

func _updateDragging(globalMousePosition: Vector2) -> void:
	if not is_instance_valid(cardBeingDragged):
		_clearDrag()
		return

	var newPosition := globalMousePosition + draggingOffset
	cardBeingDragged.updateDragPosition(newPosition)

	var parentNode := cardBeingDragged.get_parent()
	if parentNode != null and "global_position" in parentNode:
		var dragDistance = (newPosition - parentNode.global_position).length()
		var maxDistance := 100.0
		var weight = min(dragDistance / maxDistance, 1.0)
		cardBeingDragged.rotation = lerp(originalCardRotation, 0.0, weight)

	GlobalSignalBus.emitCardDragging(cardBeingDragged, newPosition)

func _finishDragging(globalMousePosition: Vector2) -> void:
	if cardBeingDragged == null:
		return

	var draggedCard := cardBeingDragged

	if hoveredSlot != null and hoveredSlot.tryPlaceCard(draggedCard):
		pass
	else:
		draggedCard.cancelDrag()

	GlobalSignalBus.emitCardDragEnded(draggedCard, globalMousePosition)
	_clearDrag()

func _clearDrag() -> void:
	cardBeingDragged = null
	hoveredSlot = null
	draggingOffset = Vector2.ZERO
	originalCardRotation = 0.0

func lockInput() -> void:
	inputLocked = true

func unlockInput() -> void:
	inputLocked = false
