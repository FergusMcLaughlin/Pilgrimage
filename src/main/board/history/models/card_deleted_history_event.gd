extends BoardHistoryEvent
class_name CardDeletedHistoryEvent

var entryId: int
var instanceId: int
var sourceInstanceId: int
var from: String

static func fromGraveyardEntry(entry: GraveyardEntry, source = null) -> CardDeletedHistoryEvent:
	if entry == null:
		return null
	var event = CardDeletedHistoryEvent.new()
	event.type = "deleted"
	event.entryId = entry.entryId
	event.instanceId = entry.instanceId
	event.cardId = entry.cardId
	event.sourceInstanceId = source.instanceId if is_instance_valid(source) and source is Card else 0
	event.from = "graveyard"
	return event

static func fromActiveCard(card: Card) -> CardDeletedHistoryEvent:
	if card == null or card.data == null:
		return null
	var event = CardDeletedHistoryEvent.new()
	event.type = "deleted"
	event.instanceId = card.instanceId
	event.cardId = card.data.id
	event.from = "active_play"
	return event

func copy() -> BoardHistoryEvent:
	var event = CardDeletedHistoryEvent.new()
	event.sequence = sequence
	event.type = type
	event.cardId = cardId
	event.entryId = entryId
	event.instanceId = instanceId
	event.sourceInstanceId = sourceInstanceId
	event.from = from
	return event

func toDictionary() -> Dictionary:
	return {
		"sequence": sequence,
		"event": type,
		"entry_id": entryId,
		"instance_id": instanceId,
		"card_id": cardId,
		"source_instance_id": sourceInstanceId,
		"from": from
	}
