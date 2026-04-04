# Autoloaded as InputManager
extends Node

var cardBeingDragged: Card = null
var hoveredSlot: CardSlot = null
var draggingOffset: Vector2 = Vector2.ZERO
var originalCardRotation: float = 0.0
var inputLocked: bool = false
var originalCardMouseFilter: int = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	GlobalSignalBus.cardPressed.connect(_onCardPressed)
	GlobalSignalBus.slotHovered.connect(_onSlotHovered)
	GlobalSignalBus.slotUnhovered.connect(_onSlotUnhovered)

	print("InputManager ready")

func _input(event: InputEvent) -> void:
	if inputLocked:
		return

	if cardBeingDragged == null:
		return

	if event is InputEventMouseMotion:
		_updateDragging(event.global_position)

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finishDragging(event.global_position)

func _onCardPressed(card: Card) -> void:
	print("InputManager _onCardPressed -> ", card)

	if inputLocked:
		print("InputManager: input locked")
		return

	if cardBeingDragged != null:
		print("InputManager: already dragging a card")
		return

	if not _canStartDragging(card):
		print("InputManager: _canStartDragging returned false")
		return

	_startDragging(card)

func _onSlotHovered(slot: CardSlot) -> void:
	hoveredSlot = slot
	print("InputManager hovered slot -> ", slot.coordinates)

func _onSlotUnhovered(slot: CardSlot) -> void:
	if hoveredSlot == slot:
		hoveredSlot = null
		print("InputManager unhovered slot -> ", slot.coordinates)

func _canStartDragging(card: Card) -> bool:
	if card == null:
		print("InputManager: card is null")
		return false

	if not is_instance_valid(card):
		print("InputManager: card is not valid")
		return false

	if card.currentState == CardState.State.IN_SLOT:
		print("InputManager: card is already in slot")
		return false

	if card.currentState == CardState.State.BEING_DRAGGED:
		print("InputManager: card already being dragged")
		return false

	return true

func _startDragging(card: Card) -> void:
	cardBeingDragged = card
	hoveredSlot = null

	var mousePosition := get_viewport().get_mouse_position()
	draggingOffset = card.global_position - mousePosition
	originalCardRotation = card.rotation
	originalCardMouseFilter = card.mouse_filter

	print("InputManager _startDragging")
	print("mousePosition -> ", mousePosition)
	print("card.global_position -> ", card.global_position)
	print("draggingOffset -> ", draggingOffset)
	print("card parent -> ", card.get_parent())

	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.setCardState(CardState.State.BEING_DRAGGED)

	GlobalSignalBus.emitCardDragStarted(card, mousePosition)

func _updateDragging(globalMousePosition: Vector2) -> void:
	if cardBeingDragged == null:
		return

	if not is_instance_valid(cardBeingDragged):
		print("InputManager: dragged card became invalid")
		cardBeingDragged = null
		return

	var newPosition := globalMousePosition + draggingOffset
	cardBeingDragged.global_position = newPosition

	var parentNode := cardBeingDragged.get_parent()
	if parentNode != null and "global_position" in parentNode:
		var dragDistance = (newPosition - parentNode.global_position).length()
		var maxDistance := 100.0
		var weight = min(dragDistance / maxDistance, 1.0)
		cardBeingDragged.rotation = lerp(originalCardRotation, 0.0, weight)

	print("InputManager _updateDragging -> ", newPosition)

	GlobalSignalBus.emitCardDragging(cardBeingDragged, newPosition)

func _finishDragging(globalMousePosition: Vector2) -> void:
	if cardBeingDragged == null:
		return

	var draggedCard := cardBeingDragged
	var targetSlot := _findDropTarget()

	print("InputManager _finishDragging")
	print("drop mouse position -> ", globalMousePosition)
	print("targetSlot -> ", targetSlot)

	if targetSlot != null and _isCardSlotValid(draggedCard, targetSlot):
		_placeCardInSlot(draggedCard, targetSlot)
	else:
		_dropCard(draggedCard)

	draggedCard.mouse_filter = originalCardMouseFilter

	GlobalSignalBus.emitCardDragEnded(draggedCard, globalMousePosition)

	cardBeingDragged = null
	hoveredSlot = null
	draggingOffset = Vector2.ZERO
	originalCardRotation = 0.0

func _findDropTarget() -> CardSlot:
	return hoveredSlot

func _isCardSlotValid(card: Card, slot: CardSlot) -> bool:
	if slot == null:
		print("InputManager: slot is null")
		return false

	if not is_instance_valid(slot):
		print("InputManager: slot is invalid")
		return false

	if not slot.canAcceptCard(card):
		print("InputManager: slot rejected card")
		return false

	return true

func _placeCardInSlot(card: Card, slot: CardSlot) -> void:
	print("InputManager _placeCardInSlot -> ", slot.coordinates)

	var placedSuccessfully := slot.setCard(card)
	if not placedSuccessfully:
		print("InputManager: slot.setCard failed, dropping card instead")
		_dropCard(card)

func _dropCard(card: Card) -> void:
	print("InputManager _dropCard")

	card.setCardState(CardState.State.ON_BOARD)
	card.rotation = originalCardRotation

func lockInput() -> void:
	inputLocked = true
	print("InputManager locked")

func unlockInput() -> void:
	inputLocked = false
	print("InputManager unlocked")
