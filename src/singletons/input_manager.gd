#Autoloaded as InputManager
extends Node
#
#var cardBeingDragged: Card = null
#var draggingOffset: Vector2 = Vector2.ZERO
#var originalCardRotation: float = 0.0
#var inputLocked: bool = false
#
#func _ready() -> void:
	#GlobalSignalBus.cardPressed.connect(_onCardPressed)
#
#func _input(event: InputEvent) -> void:
	#if inputLocked:
		#return
	#
	#if cardBeingDragged == null:
		#return
	#
	#if event is InputEventMouseMotion:
		#_updateDragging(event.global_position)
	#elif event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && !event.pressed:
		#_finishDragging(event.global_position)
#
#func _onCardPressed(card: Card) -> void:
	#if inputLocked:
		#return
#
	#if cardBeingDragged != null:
		#return
#
	#if !_canStartDragging(card):
		#return
	#
	#_startDragging(card)
#
#func _canStartDragging(card: Card) -> void:
	#if card == null:
		#return false
	#
	#if card.currentState == CardState.State.IN_SLOT:
		#return false
	#
	#if card.currentState == CardState.State.BEING_DRAGGED:
		#return false
	#
	#return true
#
#func _startDragging(card: Card) -> void:
	#cardBeingDragged = card
#
	#var mousePosition = card.get_viewport().get_mouse_position()
	#draggingOffset = card.global_position - mousePosition
	#originalCardRotation = card.rotation
	#
	#card.setCardState(CardState.State.BEING_DRAGGED)
	#
	#GlobalSignalBus.emitCardDragStarted(card)
#
#func _updateDragging(globalMousePosition: Vector2) -> void:
	#if cardBeingDragged == null:
		#return
#
	#var newPosition = globalMousePosition + draggingOffset
	#cardBeingDragged.global_position = newPosition
#
	#var dragDistance = (newPosition - cardBeingDragged.get_parent().global_position).length()
	#var maxDistance := 100.0
	#var weight := min(dragDistance / maxDistance, 1.0)
	#cardBeingDragged.rotation = lerp(originalCardRotation, 0.0, weight)
	#
	#GlobalSignalBus.emitCardDragging(cardBeingDragged, newPosition)
#
#func _finishDragging(globalMousePosition: Vector2) -> void:
	#if cardBeingDragged == null:
		#return
#
	#var draggedCard := cardBeingDragged
	#var targetSlot := _findDropTarget(globalMousePosition)
#
	#if targetSlot != null and _isCardSlotValid(draggedCard, targetSlot):
		#_dropCardInSlot(draggedCard, targetSlot)
	#else:
		#_return_card_to_hand(draggedCard) # must change
#
	#GlobalSignalBus.emitCardDragEnded(draggedCard, globalMousePosition)
#
	#cardBeingDragged = null
	#draggingOffset = Vector2.ZERO
	#originalCardRotation = 0.0
#
#func _find_drop_target(position: Vector2):
#
#func _is_card_slot_valid(card: Card, slot) -> bool:
#
#func _place_card_in_slot(card: Card, slot) -> void:
#
#func _return_card_to_hand(card: Card) -> void:
#
#func lockInput() -> void:
	#inputLocked = true
#
#func unlockInput() -> void:
	#inputLocked = false
