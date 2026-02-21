extends Node2D
class_name Card

var data: CardData
var health: int
var attack: int
var imagePath: String
var effectName: String # placeholder

@onready var visuals: CardVisuals = $CardVisuals
@onready var shadow: CardShadow = $CardShadow
@onready var area: Area2D = $Area2D

func _ready() -> void:
	assert(visuals != null, "Card: issue finding CardVisuals")
	assert(shadow != null, "Card: issue finding CardShadow")
	assert(area != null, "Card: issue finding CardArea")

	visuals.init(self)
	area.init(self)
	shadow.init(self)

func setCardData(cardData: CardData) -> void:
	data = cardData
	health = data.baseHealth
	attack = data.baseAttack
	#add effects
	
	visuals.refresh()
	shadow.refresh()

func flipCard() -> void:
	visuals.flip()
