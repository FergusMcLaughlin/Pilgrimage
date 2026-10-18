class_name EncounterResolution

var outcome: EncounterDefinition.Outcome
var removeSource = true
var movePlayer = true

static func create(choice: EncounterDefinition.Outcome) -> EncounterResolution:
	var result := EncounterResolution.new()
	result.outcome = choice
	return result
