class_name EncounterResult
extends RefCounted

var context: EncounterInteraction
var succeeded = false
var failureReason = ""

static func create(request: EncounterInteraction, success: bool, reason: String = "") -> EncounterResult:
	var result = EncounterResult.new()
	result.context = request
	result.succeeded = success
	result.failureReason = reason
	return result
