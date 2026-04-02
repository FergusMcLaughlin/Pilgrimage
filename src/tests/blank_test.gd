extends Node2D

var createCard = CreateCard.new()

func _ready() -> void:
	var card = createCard.createCard("M_0005")
	add_child(card)
	card.visuals.flip()
