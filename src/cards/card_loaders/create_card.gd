class_name CreateCard

var cardScene = preload("res://src/cards/card.tscn")
#var characterCardScene = preload("res://src/card/cardTypes/character_card.tscn")

func createCard(cardId: String) -> Card:
	var createCardData: CardData = CardLibrary.getCardData(cardId)
	if createCardData == null:
		push_error("Failed to load card, could not find %s in CardDataRegistry" % cardId)
		return null
	
	var cardInstance: Card
	if createCardData.isPlayer:
		#cardInstance = characterCardScene.instantiate()
		cardInstance = cardScene.instantiate() # remove
		
	else:
		cardInstance = cardScene.instantiate()
	
	cardInstance.setCardData(createCardData)
	return cardInstance
