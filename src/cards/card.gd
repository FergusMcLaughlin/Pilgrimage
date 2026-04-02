extends Control
class_name Card

var data: CardData
var health: int
var attack: int
var imagePath: String
var effectName: String # placeholder

var currentState: int = CardState.State.IN_DECK

@onready var visuals: CardVisuals = %CardVisuals
@onready var shadow: CardShadow = %CardShadow
@onready var input: CardInput = %InputLayer

func _ready() -> void:
	assert(visuals != null, "Card: issue finding CardVisuals")
	assert(shadow != null, "Card: issue finding CardShadow")
	assert(input != null, "Card: issue finding InputLayer")
	
	visuals.init(self)
	shadow.init(self, visuals.back)
	input.init(self)
	
	if data != null:
		_refreshCard()

func setCardData(cardData: CardData) -> void:
	data = cardData
	health = data.baseHealth
	attack = data.baseAttack
	#add effects
	
	if is_node_ready():
		_refreshCard()

func _refreshCard() -> void:
	visuals.refresh()
	shadow.refresh()

func setCardState(newCardState: int) -> void:
	CardStateMachine.setCardState(self, newCardState)

func flipCard() -> void:
	visuals.flip()

func onCardHovered() -> void:
	visuals.handleHovered(true)
	GlobalSignalBus.emitCardHovered(self)

func onCardUnhovered() -> void:
	visuals.handleHovered(false)
	GlobalSignalBus.emitCardUnhovered(self)

func onCardPressed() -> void:
	visuals.handleDragging(true)
	GlobalSignalBus.emitCardPressed(self)

func onCardReasled() -> void:
	visuals.handleDragging(false)
	GlobalSignalBus.emitCardReleased(self)
