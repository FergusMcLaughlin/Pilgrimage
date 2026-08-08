# Autoloaded as InputManager
extends Node

var cardBeingDragged: Card = null
var hoveredSlot: CardSlot = null
var draggingOffset: Vector2 = Vector2.ZERO
var originalCardRotation: float = 0.0
var inputLocked: bool = false
var originalCardMouseFilter: int = Control.MOUSE_FILTER_STOP
var nextCardZIndex: int = 10

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

	if not _canStartDragging(card):
		return

	_startDragging(card)

func _onSlotHovered(slot: CardSlot) -> void:
	hoveredSlot = slot

func _onSlotUnhovered(slot: CardSlot) -> void:
	if hoveredSlot == slot:
		hoveredSlot = null

func _canStartDragging(card: Card) -> bool:
	if card == null:
		return false

	if not is_instance_valid(card):
		return false

	if card.currentState == CardState.State.IN_SLOT:
		return false

	if card.currentState == CardState.State.BEING_DRAGGED:
		return false

	return true

func _startDragging(card: Card) -> void:
	cardBeingDragged = card
	hoveredSlot = null

	var mousePosition := get_viewport().get_mouse_position()
	draggingOffset = card.global_position - mousePosition
	originalCardRotation = card.rotation
	originalCardMouseFilter = card.mouse_filter

	_bringCardToFront(card)

	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.setCardState(CardState.State.BEING_DRAGGED)

	GlobalSignalBus.emitCardDragStarted(card, mousePosition)

func _updateDragging(globalMousePosition: Vector2) -> void:
	if cardBeingDragged == null:
		return

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
	var targetSlot := _findDropTarget()

	if targetSlot != null and _isCardSlotValid(draggedCard, targetSlot):
		_placeCardInSlot(draggedCard, targetSlot)
	else:
		_dropCard(draggedCard)

	_bringCardToFront(draggedCard)

	draggedCard.mouse_filter = originalCardMouseFilter

	GlobalSignalBus.emitCardDragEnded(draggedCard, globalMousePosition)

	_clearDrag()

func _clearDrag() -> void:
	cardBeingDragged = null
	hoveredSlot = null
	draggingOffset = Vector2.ZERO
	originalCardRotation = 0.0
	originalCardMouseFilter = Control.MOUSE_FILTER_STOP

func _findDropTarget() -> CardSlot:
	return hoveredSlot

func _isCardSlotValid(card: Card, slot: CardSlot) -> bool:
	if slot == null:
		return false

	if not is_instance_valid(slot):
		return false

	if not slot.canAcceptCard(card):
		return false

	return true

func _placeCardInSlot(card: Card, slot: CardSlot) -> void:
	var placedSuccessfully := slot.setCard(card)
	if not placedSuccessfully:
		_dropCard(card)

func _dropCard(card: Card) -> void:
	card.cancelDrag()
	card.rotation = originalCardRotation

func _bringCardToFront(card: Card) -> void:
	if card == null or not is_instance_valid(card):
		return

	card.z_as_relative = false
	card.z_index = nextCardZIndex
	nextCardZIndex += 1

func lockInput() -> void:
	inputLocked = true

func unlockInput() -> void:
	inputLocked = false
