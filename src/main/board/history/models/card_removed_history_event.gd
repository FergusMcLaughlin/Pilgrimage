extends BoardHistoryEvent
class_name CardRemovedHistoryEvent

var entryId: int
var instanceId: int
var sourceInstanceId: int
var cause: String
var statSnapshot: CardStatSnapshot
var removedSequence: int

static func fromGraveyardEntry(entry: GraveyardEntry) -> CardRemovedHistoryEvent:
	if entry == null:
		return null
	var event = CardRemovedHistoryEvent.new()
	event.type = "removed"
	event.entryId = entry.entryId
	event.instanceId = entry.instanceId
	event.cardId = entry.cardId
	event.sourceInstanceId = entry.sourceInstanceId
	event.cause = entry.cause
	event.statSnapshot = entry.statSnapshot.copy() if entry.statSnapshot != null else null
	event.removedSequence = entry.removedSequence
	return event

func copy() -> BoardHistoryEvent:
	var event = CardRemovedHistoryEvent.new()
	event.sequence = sequence
	event.type = type
	event.cardId = cardId
	event.entryId = entryId
	event.instanceId = instanceId
	event.sourceInstanceId = sourceInstanceId
	event.cause = cause
	event.statSnapshot = statSnapshot.copy() if statSnapshot != null else null
	event.removedSequence = removedSequence
	return event

func toDictionary() -> Dictionary:
	return {
		"sequence": sequence,
		"event": type,
		"entry_id": entryId,
		"instance_id": instanceId,
		"card_id": cardId,
		"removed_sequence": removedSequence,
		"source_instance_id": sourceInstanceId,
		"cause": cause,
		"stat_snapshot": statSnapshot.toDictionary() if statSnapshot != null else {}
	}
