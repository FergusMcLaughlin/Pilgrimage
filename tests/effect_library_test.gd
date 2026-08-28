extends Node

const FIXTURE_PATH := "user://effect_library_test.json"
const EXPECTED_TEST_COUNT = 9

var _passed := 0


func _ready() -> void:
	_testProductionEffectLoads()
	_testFactoryCopiesFixedFields()
	_testFactoryValidatesGainHealthParameters()
	_testCardRetainsAndChecksMultipleEffectIds()
	_testNonDictionaryEntryIsSkipped()
	_testReloadClearsOldDefinitions()
	_testLoadingDoesNotQueueActions()
	_testUnknownReferencesWarnAndCheckingContinues()
	_testReferenceValidationPreservesCardsAndQueue()
	
	EffectLibrary.loadEffectData()
	_removeFixture()
	if _passed != EXPECTED_TEST_COUNT:
		push_error(
			"FAIL: EffectLibrary tests (%s/%s passed)"
			% [_passed, EXPECTED_TEST_COUNT]
		)
		get_tree().quit(1)
		return
	
	print("PASS: EffectLibrary tests (%s passed)" % _passed)
	get_tree().quit(0)
	

func _testProductionEffectLoads() -> void:
	EffectLibrary.loadEffectData()
	assert(EffectLibrary.hasEffectData("heal_self_on_play"))
	
	var effect := EffectLibrary.getEffectData("heal_self_on_play")
	assert(effect != null)
	assert(effect.id == "heal_self_on_play")
	assert(effect.name == "Gain Health on Play")
	assert(effect.trigger == "on_play")
	assert(effect.operation == "gain_health")
	assert(effect.target == "self")
	assert(effect.scriptPath == "res://src/main/effects/handlers/gain_health_on_play.gd")
	var parameters = effect.parameters as GainHealthParameters
	assert(parameters != null)
	assert(parameters.amount == 2)
	_passed += 1
	

func _testFactoryCopiesFixedFields() -> void:
	var effect := EffectDataFactory.fromDictionary({
		"id": "test_effect",
		"name": "Test Effect",
		"trigger": "test_trigger",
		"operation": "test_operation",
		"target": "test_target",
		"script_path": "res://test_effect.gd",
		"parameters": {"amount": 7}
	})
	
	assert(effect.id == "test_effect")
	assert(effect.name == "Test Effect")
	assert(effect.trigger == "test_trigger")
	assert(effect.operation == "test_operation")
	assert(effect.target == "test_target")
	assert(effect.scriptPath == "res://test_effect.gd")
	assert(effect.parameters == null)
	_passed += 1
	

func _testFactoryValidatesGainHealthParameters() -> void:
	for invalidAmount in [null, "2", 2.5, 0, -1]:
		var effect = EffectDataFactory.fromDictionary({
			"operation": "gain_health",
			"parameters": {"amount": invalidAmount}
		})
		assert(effect.parameters == null)
	var validEffect = EffectDataFactory.fromDictionary({
		"operation": "gain_health",
		"parameters": {"amount": 2.0}
	})
	var parameters = validEffect.parameters as GainHealthParameters
	assert(parameters != null)
	assert(parameters.amount == 2)
	_passed += 1
	

func _testCardRetainsAndChecksMultipleEffectIds() -> void:
	_writeFixture({
		"first_effect": {
			"id": "first_effect",
			"name": "First Effect",
			"trigger": "first_trigger",
			"operation": "first_operation",
			"target": "first_target",
			"parameters": {"amount": 1}
		},
		"second_effect": {
			"id": "second_effect",
			"name": "Second Effect",
			"trigger": "second_trigger",
			"operation": "second_operation",
			"target": "second_target",
			"parameters": {"amount": 2}
		}
	})
	EffectLibrary.loadEffectData(FIXTURE_PATH)
	
	var cardData := CardDataFactory.fromDictionary({
		"id": "multi_effect_card",
		"effects": ["first_effect", "second_effect"]
	})
	
	assert(cardData.effects == ["first_effect", "second_effect"])
	for effectId in cardData.effects:
		assert(EffectLibrary.hasEffectData(effectId))
	_passed += 1
	

func _testNonDictionaryEntryIsSkipped() -> void:
	_writeFixture({
		"valid_effect": {
			"id": "valid_effect",
			"name": "Valid Effect",
			"trigger": "anything",
			"operation": "anything",
			"target": "anything",
			"parameters": {"amount": 1}
		},
		"invalid_effect": "not a dictionary"
	})
	
	EffectLibrary.loadEffectData(FIXTURE_PATH)
	assert(EffectLibrary.hasEffectData("valid_effect"))
	assert(!EffectLibrary.hasEffectData("invalid_effect"))
	_passed += 1
	

func _testReloadClearsOldDefinitions() -> void:
	assert(EffectLibrary.hasEffectData("valid_effect"))
	EffectLibrary.loadEffectData()
	assert(!EffectLibrary.hasEffectData("valid_effect"))
	assert(EffectLibrary.hasEffectData("heal_self_on_play"))
	_passed += 1
	

func _testLoadingDoesNotQueueActions() -> void:
	ActionQueue.clearQueue()
	EffectLibrary.loadEffectData()
	assert(!ActionQueue.queueHasActions())
	assert(ActionQueue.getActionQueueSize() == 0)
	_passed += 1
	

func _testUnknownReferencesWarnAndCheckingContinues() -> void:
	EffectLibrary.loadEffectData()
	var originalCardData: Dictionary = CardLibrary.cardDataById
	var firstCard := CardDataFactory.fromDictionary({
		"id": "first_test_card",
		"effects": ["missing_first", "heal_self_on_play"]
	})
	var secondCard := CardDataFactory.fromDictionary({
		"id": "second_test_card",
		"effects": ["missing_second"]
	})
	
	CardLibrary.cardDataById = {
		firstCard.id: firstCard,
		secondCard.id: secondCard
	}
	var unknownCount := EffectLibrary.validateCardEffectIds()
	CardLibrary.cardDataById = originalCardData
	
	assert(unknownCount == 2, "Every unknown ID on every card must be checked.")
	_passed += 1
	

func _testReferenceValidationPreservesCardsAndQueue() -> void:
	EffectLibrary.loadEffectData()
	var originalCardData: Dictionary = CardLibrary.cardDataById
	var card := CardDataFactory.fromDictionary({
		"id": "unchanged_test_card",
		"effects": ["heal_self_on_play", "still_missing"]
	})
	var originalEffects := card.effects.duplicate()
	
	CardLibrary.cardDataById = {card.id: card}
	ActionQueue.clearQueue()
	var unknownCount := EffectLibrary.validateCardEffectIds()
	CardLibrary.cardDataById = originalCardData
	
	assert(unknownCount == 1)
	assert(card.effects == originalEffects, "Validation must not modify card effect IDs.")
	assert(!ActionQueue.queueHasActions(), "Reference validation must not queue actions.")
	_passed += 1
	

func _writeFixture(contents: Dictionary) -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	assert(file != null, "Could not create EffectLibrary test fixture.")
	file.store_string(JSON.stringify(contents))
	file.close()
	

func _removeFixture() -> void:
	if FileAccess.file_exists(FIXTURE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
