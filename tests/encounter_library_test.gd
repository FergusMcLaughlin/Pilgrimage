extends Node

const FIXTURE_PATH = "user://encounter_library_test.json"

var passed := 0
var failures := 0

func _ready() -> void:
	_testProductionEncounters()
	_testFactory()
	_testLibraryReload()
	_testJsonValidation()
	EncounterLibrary.loadEncounterData()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_PATH))
	print("Encounter library: %s checks passed, %s failures" % [passed, failures])
	get_tree().quit(1 if failures else 0)

func _testProductionEncounters() -> void:
	_expect(EncounterLibrary.getAllEncounterData().size() == 3, "All three encounters load from JSON.")
	var corpse := EncounterLibrary.getEncounterData("roadside_corpse")
	_expect(corpse.id == &"roadside_corpse", "Corpse ID is preserved.")
	_expect(corpse.title == "A Body Beside the Road", "Corpse title is preserved.")
	_expect(corpse.body == "A traveller lies beside the road. Their coat is torn and their belongings are scattered through the grass. You stop to consider whether to search the remains.", "Corpse body is preserved.")
	_expect(corpse.encounterType == EncounterDefinition.Type.CONTINUE_ONLY, "Corpse remains continue-only.")
	_expect(corpse.artwork == load("res://assets/images/ui/EncounterBG.png"), "Corpse artwork is preserved.")
	_expect(corpse.buttonLabel == "CONTINUE_BUTTON" and corpse.leaveButtonLabel == "LEAVE_BUTTON", "Default localisation keys are preserved.")
	var road := EncounterLibrary.getEncounterData("quiet_road")
	_expect(road.encounterType == EncounterDefinition.Type.CONTINUE_OR_LEAVE, "Quiet road remains a choice encounter.")
	_expect(road.title == "A Quiet Stretch of Road" and road.body == "The road is quiet. It must be safe to continue?", "Quiet road text is preserved.")
	_expect(road.artwork == corpse.artwork, "Quiet road artwork is preserved.")
	var cart := EncounterLibrary.getEncounterData("abandoned_cart")
	_expect(cart.encounterType == EncounterDefinition.Type.CONTINUE_OR_LEAVE, "Cart remains a choice encounter.")
	_expect(cart.artwork == null and cart.buttonLabel == "Search", "Cart remains text-only with its custom label.")
	_expect(cart.body == "A broken cart rests beside the road. Its owner is nowhere to be seen.", "Cart body is preserved.")

func _testFactory() -> void:
	var data := EncounterDataFactory.fromDictionary({"id": "defaults"})
	_expect(data.encounterType == EncounterDefinition.Type.CONTINUE_ONLY, "Factory defaults to continue-only.")
	_expect(data.artwork == null and data.title == "" and data.body == "", "Optional content defaults are supported.")
	_expect(data.buttonLabel == "CONTINUE_BUTTON" and data.leaveButtonLabel == "LEAVE_BUTTON", "Missing labels retain defaults.")

func _testLibraryReload() -> void:
	var queueSize := ActionQueue.getActionQueueSize()
	EncounterLibrary.encounterDataById["temporary"] = EncounterDefinition.new()
	EncounterLibrary.loadEncounterData()
	_expect(EncounterLibrary.getAllEncounterData().size() == 3, "Production definitions reload successfully.")
	_expect(!EncounterLibrary.hasEncounterData("temporary"), "Reload clears old entries.")
	_expect(EncounterLibrary.hasEncounterData("roadside_corpse"), "Production IDs remain available after reload.")
	_expect(ActionQueue.getActionQueueSize() == queueSize, "Loading authored data does not queue gameplay actions.")

func _testJsonValidation() -> void:
	_writeFixture("[]")
	_expect(EncounterJsonLoader.loadDictionaryFromFile(FIXTURE_PATH).is_empty(), "Non-dictionary JSON is rejected.")
	_writeFixture("{invalid json")
	_expect(EncounterJsonLoader.loadDictionaryFromFile(FIXTURE_PATH).is_empty(), "Malformed JSON is rejected.")
	_expect(EncounterJsonLoader.loadDictionaryFromFile("res://data/missing_encounter_dictionary.json").is_empty(), "Missing files return an empty dictionary.")

func _writeFixture(content: String) -> void:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)
