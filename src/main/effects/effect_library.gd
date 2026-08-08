extends Node

const EFFECT_DICTIONARY_PATH := "res://data/effect_dictionary.json"

var effectDataById: Dictionary = {}

func _ready() -> void:
	loadEffectData()
	validateCardEffectIds()

func loadEffectData(filepath: String = EFFECT_DICTIONARY_PATH) -> void:
	effectDataById.clear()

	var effectDictionaryData = EffectJsonLoader.loadDictionaryFromFile(filepath)

	for effectId in effectDictionaryData.keys():
		var rawDictionary = effectDictionaryData[effectId]
		if !(rawDictionary is Dictionary):
			push_warning("EffectLibrary: effect %s must be a Dictionary." % effectId)
			continue

		var data: EffectData = EffectDataFactory.fromDictionary(rawDictionary)
		effectDataById[effectId] = data

func getEffectData(effectId: String) -> EffectData:
	if !effectDataById.has(effectId):
		push_error("EffectDataRegistry: unknown effect id : " + effectId)
		return null

	return effectDataById[effectId]

func hasEffectData(effectId: String) -> bool:
	return effectDataById.has(effectId)

func getAllEffectData() -> Dictionary:
	return effectDataById

func validateCardEffectIds() -> int:
	var unknownEffectCount := 0

	for cardData in CardLibrary.getAllCardData().values():
		for effectId in cardData.effects:
			if !hasEffectData(effectId):
				unknownEffectCount += 1
				push_warning(
					"EffectLibrary: card %s references unknown effect %s."
					% [cardData.id, effectId]
					)

	return unknownEffectCount
