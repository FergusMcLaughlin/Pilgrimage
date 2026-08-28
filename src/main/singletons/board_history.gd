extends Node
var events: Array[BoardHistoryEvent] = []
var _nextSequence = 1

func recordEvent(event: BoardHistoryEvent) -> BoardHistoryEvent:
	if event == null:
		return null
	event.sequence = _nextSequence
	if event is CardRemovedHistoryEvent:
		event.removedSequence = event.sequence
	_nextSequence += 1
	var storedEvent = event.copy()
	events.append(storedEvent)
	return storedEvent.copy()

func getEvents(eventType: String = "") -> Array[BoardHistoryEvent]:
	var result: Array[BoardHistoryEvent] = []
	for event in events:
		if eventType.is_empty() or event.type == eventType:
			result.append(event.copy())
	return result

func countRemovedCards(cardId: String = "") -> int:
	var count := 0
	for event in events:
		if event.type != "removed":
			continue
		if !cardId.is_empty() and event.cardId != cardId:
			continue
		count += 1
	return count

func getNextSequence() -> int:
	return _nextSequence

func reset() -> void:
	events.clear()
	_nextSequence = 1
