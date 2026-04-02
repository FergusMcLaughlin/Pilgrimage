extends Control
class_name CardSlot

@export var coordinates: Vector2i = Vector2i.ZERO
@export var allowedCardTypes: Array[String] = []

@onready var cardAnchor: Control = %CardAnchor

var currentCard: Card = null

func _ready() -> void:
	add_to_group("cardSlot")
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GlobalSignalBus.emitSlotClicked(self)

func _on_mouse_entered() -> void:
	GlobalSignalBus.emitSlotHovered(self)

func _on_mouse_exited() -> void:
	GlobalSignalBus.emitSlotUnhovered(self)

func setCard(card: Card) -> bool:
	if card == null:
		push_error("CardSlot: tried to place null card")
		return false
	
	if !canAcceptCard(card):
		push_warning("CardSlot: tried to place card into occupied slot")
		return false
	
	currentCard = card
	
	card.reparent(cardAnchor, true)
	card.position = Vector2.ZERO
	card.setCardState(CardState.State.IN_SLOT)
	
	GlobalSignalBus.emitSlotFilled(self, card)
	return true

func canAcceptCard(card: Card) -> bool:
	if currentCard != null:
		return false
	if allowedCardTypes.is_empty():
		return true
	return card.cardData.type in allowedCardTypes

func clearSlot() -> void:
	if currentCard != null and currentCard.has_method("cleanUpEffects"):
		#currentCard.cleanUpEffects()
		print("handle effects like this in the future please look at # code")
	
	currentCard = null
	GlobalSignalBus.emitSlotEmptied(self)	
