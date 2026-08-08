extends Node
var events: Array[Dictionary] = []
var _nextSequence = 1

func recordEvent(eventType: String, details: Dictionary = {}) -> Dictionary:
	var event = details.duplicate(true)
	event["sequence"] = _nextSequence
	event["event"] = eventType
	_nextSequence += 1
	events.append(event)
	return event.duplicate(true)

func getEvents(eventType: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if eventType.is_empty() or event.get("event") == eventType:
			result.append(event.duplicate(true))
	return result

func countRemovedCards(cardId: String = "") -> int:
	var count := 0
	for event in events:
		if event.get("event") != "removed":
			continue
		if !cardId.is_empty() and event.get("card_id") != cardId:
			continue
		count += 1
	return count

func getNextSequence() -> int:
	return _nextSequence

func reset() -> void:
	events.clear()
	_nextSequence = 1
