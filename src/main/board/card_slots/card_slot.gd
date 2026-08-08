extends Control
class_name CardSlot

@export var coordinates: Vector2i = Vector2i.ZERO
@export var allowedCardTypes: Array[String] = []

@onready var cardAnchor: Control = %CardAnchor

var currentCard: Card = null

func _ready() -> void:
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
	GlobalSignalBus.emitSlotHovered(self)

func _on_mouse_exited() -> void:
	GlobalSignalBus.emitSlotUnhovered(self)

func isOccupied() -> bool:
	return currentCard != null

func canAcceptCard(card: Card) -> bool:
	if card == null:
		return false

	if card.data == null:
		return false

	if isOccupied():
		return false

	if allowedCardTypes.is_empty():
		return true

	return card.data.type in allowedCardTypes

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

	if card.get_parent() == null:
		cardAnchor.add_child(card)
	else:
		card.reparent(cardAnchor, false)
	card.position = Vector2.ZERO
	card.rotation = 0.0
	card.scale = Vector2.ONE

	card.placeInSlot()

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
