extends Node

const ENCOUNTER_DICTIONARY_PATH := "res://data/encounter_dictionary.json"

var encounterDataById: Dictionary = {}

func _ready() -> void:
	loadEncounterData()

func loadEncounterData() -> void:
	encounterDataById.clear()

	var encounterDictionaryData = EncounterJsonLoader.loadDictionaryFromFile(ENCOUNTER_DICTIONARY_PATH)

	for encounterId in encounterDictionaryData.keys():
		var rawDictionary: Dictionary = encounterDictionaryData[encounterId]
		var data: EncounterDefinition = EncounterDataFactory.fromDictionary(rawDictionary)
		encounterDataById[encounterId] = data

func getEncounterData(encounterId: String) -> EncounterDefinition:
	if !encounterDataById.has(encounterId):
		push_error("EncounterDataRegistry: unknown encounter id : " + encounterId)
		return null

	return encounterDataById[encounterId]

func hasEncounterData(encounterId: String) -> bool:
	return encounterDataById.has(encounterId)

func getAllEncounterData() -> Dictionary:
	return encounterDataById
