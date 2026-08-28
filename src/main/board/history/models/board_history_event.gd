extends RefCounted
class_name BoardHistoryEvent

var sequence: int
var type: String
var cardId: String

func copy() -> BoardHistoryEvent:
	var event = BoardHistoryEvent.new()
	event.sequence = sequence
	event.type = type
	event.cardId = cardId
	return event

func toDictionary() -> Dictionary:
	return {
		"sequence": sequence,
		"event": type,
		"card_id": cardId
	}
