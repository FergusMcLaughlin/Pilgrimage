extends Control
class_name Card

var data: CardData
var health: int
var attack: int
var imagePath: String
var effectName: String # placeholde
var instanceId: int = 0

var currentState: int = CardState.State.IN_DECK

@onready var visuals: CardVisuals = %CardVisuals
@onready var shadow: CardShadow = %CardShadow
@onready var input: CardInput = %InputLayer
@onready var cardOutline: CardOutline = %CardOutline

func _ready() -> void:
	assert(visuals != null, "Card: issue finding CardVisuals")
	assert(shadow != null, "Card: issue finding CardShadow")
	assert(input != null, "Card: issue finding InputLayer")
	
	visuals.init(self)
	shadow.init(self, visuals.back)
	input.init(self)
	
	if instanceId == 0:
		instanceId = get_instance_id()

	if data != null:
		_refreshCard()

func setCardData(cardData: CardData) -> void:
	data = cardData
	health = data.baseHealth
	attack = data.baseAttack
	
	if is_node_ready():
		_refreshCard()

func modifyStat(statName: String, amount: int) -> bool:
	match statName:
		"health":
			health = maxi(health + amount, 0)
		"attack":
			attack = maxi(attack + amount, 0)
		_:
			return false

	_refreshCard()
	return true

func _refreshCard() -> void:
	visuals.refresh()
	shadow.refresh()

func setCardState(newCardState: int) -> void:
	CardStateMachine.setCardState(self, newCardState)

func flipCard() -> void:
	await visuals.flip()

func onCardHovered() -> void:
	if InputManager.cardBeingDragged == null:
		cardOutline.show_hover()
	GlobalSignalBus.emitCardHovered(self)

func onCardUnhovered() -> void:
	cardOutline.hide_hover()
	GlobalSignalBus.emitCardUnhovered(self)

func onCardPressed() -> void:
	GlobalSignalBus.emitCardPressed(self)

func onCardReasled() -> void:
	GlobalSignalBus.emitCardReleased(self)

func canBeDragged() -> bool:
	return self.currentState != CardState.State.IN_SLOT and self.currentState != CardState.State.BEING_DRAGGED

func beingDragged() -> void:
	setCardState(CardState.State.BEING_DRAGGED)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func updateDragPosition(newPosition: Vector2) -> void:
	global_position = newPosition

func endDragVisuals() -> void:
	visuals.handleDragging(false)

func cancelDrag() -> void:
	setCardState(CardState.State.ON_BOARD)
	mouse_filter = Control.MOUSE_FILTER_STOP

func placeInSlot() -> void:
	setCardState(CardState.State.IN_SLOT)
	mouse_filter = Control.MOUSE_FILTER_STOP
