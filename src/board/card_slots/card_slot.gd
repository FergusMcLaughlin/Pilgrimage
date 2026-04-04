extends Control
class_name CardSlot

@export var coordinates: Vector2i = Vector2i.ZERO
@export var allowedCardTypes: Array[String] = []

@onready var cardAnchor: Control = %CardAnchor

var currentCard: Card = null

func _ready() -> void:
	modulate = Color(1, 0, 0, 0.3)
	add_to_group("cardSlot")
	mouse_filter = Control.MOUSE_FILTER_STOP
	$SlotBackground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CardAnchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GlobalSignalBus.emitSlotClicked(self)

func _on_mouse_entered() -> void:
	print("SLOT HOVERED")
	GlobalSignalBus.emitSlotHovered(self)

func _on_mouse_exited() -> void:
	GlobalSignalBus.emitSlotUnhovered(self)

func isOccupied() -> bool:
	return currentCard != null

func canAcceptCard(card: Card) -> bool:
	if card == null:
		return false

	if isOccupied():
		return false

	if allowedCardTypes.is_empty():
		return true

	return card.cardData.type in allowedCardTypes

func tryPlaceCard(card: Card) -> bool:
	if not canAcceptCard(card):
		return false
	
	return setCard(card)

func setCard(card: Card) -> bool:
	if card == null:
		push_error("CardSlot: tried to place null card")
		return false

	if not canAcceptCard(card):
		push_warning("CardSlot: tried to place invalid card in slot")
		return false

	currentCard = card

	card.placeInSlot()
	card.reparent(cardAnchor, true)
	card.position = Vector2.ZERO #look here

	GlobalSignalBus.emitSlotFilled(self, card)
	return true

func clearSlot() -> void:
	if currentCard == null:
		return

	if currentCard.has_method("cleanUpEffects"):
		# currentCard.cleanUpEffects()
		print("handle effects like this in the future please look at # code")

	currentCard = null
	GlobalSignalBus.emitSlotEmptied(self)

func getCurrentCard() -> Card:
	return currentCard
