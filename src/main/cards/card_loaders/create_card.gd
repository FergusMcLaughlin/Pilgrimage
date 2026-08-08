class_name CreateCard

var cardScene = preload("res://src/main/cards/card.tscn")
#var characterCardScene = preload("res://src/card/cardTypes/character_card.tscn")

func createCard(cardId: String, existingInstanceId: int = 0) -> Card:
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

	if existingInstanceId != 0:
		cardInstance.instanceId = existingInstanceId

	return cardInstance
