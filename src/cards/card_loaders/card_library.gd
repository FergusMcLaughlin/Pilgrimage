#Autoloaded as CardLibrary
extends Node

const CARD_DICTIONARY_PATH := "res://data/card_dictionary.json"

var cardDataById: Dictionary = {}

func _ready() -> void:
	loadCardData()

func loadCardData() -> void:
	cardDataById.clear()

	var cardDictionaryData = CardJsonLoader.loadDictionaryFromFile(CARD_DICTIONARY_PATH)

	for cardId in cardDictionaryData.keys():
		var rawDictionary: Dictionary = cardDictionaryData[cardId]
		var data: CardData = CardDataFactory.fromDictionary(rawDictionary)
		cardDataById[cardId] = data

func getCardData(cardId: String) -> CardData:
	if !cardDataById.has(cardId):
		push_error("CardDataRegistry: unknown card id : " + cardId)
		return null

	return cardDataById[cardId]

func hasCardData(cardId: String) -> bool:
	return cardDataById.has(cardId)

func getAllCardData() -> Dictionary:
	return cardDataById
