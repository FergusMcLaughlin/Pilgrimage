class_name GraveyardEntry
extends RefCounted

var entryId: int
var instanceId: int
var cardId: String
var removedSequence: int
var sourceInstanceId: int
var cause: String
var statSnapshot: CardStatSnapshot

func toDictionary() -> Dictionary:
	return {
		"entry_id": entryId,
		"instance_id": instanceId,
		"card_id": cardId,
		"removed_sequence": removedSequence,
		"source_instance_id": sourceInstanceId,
		"cause": cause,
		"stat_snapshot": statSnapshot.toDictionary() if statSnapshot != null else {}
	}
