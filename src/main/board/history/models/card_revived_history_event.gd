extends BoardHistoryEvent
class_name CardRevivedHistoryEvent

var entryId: int
var instanceId: int

static func fromGraveyardEntry(entry: GraveyardEntry) -> CardRevivedHistoryEvent:
	if entry == null:
		return null
	var event = CardRevivedHistoryEvent.new()
	event.type = "revived"
	event.entryId = entry.entryId
	event.instanceId = entry.instanceId
	event.cardId = entry.cardId
	return event

func copy() -> BoardHistoryEvent:
	var event = CardRevivedHistoryEvent.new()
	event.sequence = sequence
	event.type = type
	event.cardId = cardId
	event.entryId = entryId
	event.instanceId = instanceId
	return event

func toDictionary() -> Dictionary:
	return {
		"sequence": sequence,
		"event": type,
		"entry_id": entryId,
		"instance_id": instanceId,
		"card_id": cardId
	}
